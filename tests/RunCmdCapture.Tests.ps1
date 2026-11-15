#requires -Version 5.0
<#
.SYNOPSIS
  Pester 3.4 wrapper for RunCmdCapture.Harness.ahk
#>

$ErrorActionPreference = 'Stop'

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:SmartZipPath = Join-Path $script:RepoRoot 'SmartZip.ahk'
$script:HarnessPath = Join-Path $PSScriptRoot 'RunCmdCapture.Harness.ahk'
$script:FragmentPath = Join-Path $PSScriptRoot 'RunCmdCapture.Fragment.ahk'
. (Join-Path $PSScriptRoot 'TestHelper.ps1')
$script:AhkExe = (Resolve-AhkExe)

function Get-SmartZipSourceText {
    $raw = Get-Content -LiteralPath $script:SmartZipPath -Raw -Encoding UTF8
    if ($raw -notmatch 'RunCmdCapture|CreateProcess') {
        $raw = Get-Content -LiteralPath $script:SmartZipPath -Raw
    }
    return $raw
}

function Get-SourceSlice {
    param(
        [string]$Source,
        [string]$StartMarker,
        [string]$EndMarker
    )
    $start = $Source.IndexOf($StartMarker)
    if ($start -lt 0) { return $null }
    $end = $Source.IndexOf($EndMarker, $start + $StartMarker.Length)
    if ($end -lt 0) { return $Source.Substring($start) }
    return $Source.Substring($start, $end - $start)
}

function Export-RunCmdCaptureFragment {
    param([string]$DestinationPath)
    $src = Get-SmartZipSourceText
    $body = Get-SourceSlice -Source $src -StartMarker "`n    RunCmdCapture(" -EndMarker "`n    RunCmd(CmdLine"
    if ([string]::IsNullOrEmpty($body)) {
        throw "RunCmdCapture method not found in SmartZip.ahk"
    }
    # Build a host class wrapping the extracted method body.
    # Strip the leading newline and re-indent into class RunCmdCaptureHost.
    $method = $body.TrimStart("`r", "`n")
    $method = $method.Replace('capturedSize += received', "this.captureReadCalls += 1`r`n                    capturedSize += received")
    $pipePattern = 'DllCall\("CreatePipe",[^\r\n]*?\)'
    $retryMethod = ([regex]::new($pipePattern)).Replace($method, '(hPipeR := 0, hPipeW := 0, 0)', 1)
    $failedMethod = [regex]::Replace($method, $pipePattern, '(hPipeR := 0, hPipeW := 0, 0)')
    # The product method is indented with 4 spaces as a class method; keep as-is inside host class.
    $fragment = @"
#Requires AutoHotkey v2.0

class RunCmdCaptureHost {
    CMDPID := 0
    captureReadCalls := 0

$method
}
class RetryCaptureHost {
    CMDPID := 0
    captureReadCalls := 0
$retryMethod
}
class FailedCaptureHost {
    CMDPID := 0
    captureReadCalls := 0
$failedMethod
}
"@
    Set-Content -LiteralPath $DestinationPath -Value $fragment -Encoding UTF8
}

function Invoke-RunCmdCaptureHarness {
    $stage = New-AhkTestStage -Name 'Capture'
    try {
    $harness = Join-Path $stage 'RunCmdCapture.Harness.ahk'
    Copy-Item -LiteralPath $script:HarnessPath -Destination $harness
    Export-RunCmdCaptureFragment -DestinationPath (Join-Path $stage 'RunCmdCapture.Fragment.ahk')
    $outFile = Join-Path $stage 'results.txt'
    $code = Invoke-AhkResultRunner -ScriptPath $harness -ScriptArguments @($outFile) -ResultPath $outFile `
        -StandardOutputPath (Join-Path $stage 'stdout.txt') -StandardErrorPath (Join-Path $stage 'stderr.txt')
    $map = @{}
    if (Test-Path -LiteralPath $outFile) {
        Get-Content -LiteralPath $outFile -Encoding UTF8 | ForEach-Object {
            if ($_ -match '^(PASS|FAIL)\s+(\S+)') {
                $map[$matches[2]] = $matches[1]
            }
            elseif ($_ -match '^SUMMARY\s+passed=(\d+)\s+failed=(\d+)') {
                $map['__summary_passed'] = $matches[1]
                $map['__summary_failed'] = $matches[2]
            }
        }
    }
    return [pscustomobject]@{ ExitCode = $code; Map = $map }
    } finally { Remove-AhkTestStage $stage }
}

Describe 'RunCmdCaptureBehavior' {
    BeforeAll {
        $script:CapFragmentBefore = if (Test-Path $script:FragmentPath) { (Get-FileHash $script:FragmentPath).Hash } else { '' }
        $script:CapRun = Invoke-RunCmdCaptureHarness
        $script:CapMap = $script:CapRun.Map
    }

    It 'harness exits 0' {
        $script:CapRun.ExitCode | Should Be 0
    }
    It 'does not create or overwrite a repository fragment' {
        $after = if (Test-Path $script:FragmentPath) { (Get-FileHash $script:FragmentPath).Hash } else { '' }
        $after | Should Be $script:CapFragmentBefore
    }

    $cases = @(
        'capture_exit_code_7',
        'capture_stdout_complete',
        'capture_not_cancelled_on_7',
        'capture_stderr_exit_3',
        'capture_stderr_complete',
        'capture_multiline_exit_2',
        'capture_keeps_wrong_password_line',
        'capture_keeps_headers_error_line',
        'capture_keeps_trailing_success_line',
        'capture_exit_255',
        'capture_cancelled_true_on_255',
        'capture_default_cp_exit_0',
        'capture_default_cp_output',
        'capture_clears_cmdpid'
        'capture_preserves_split_utf8'
        'capture_large_output_complete'
        'capture_large_exit_7'
        'capture_large_read_efficiency'
        'capture_retries_default_pipe'
        'capture_pipe_failure_returns_error'
    )

    foreach ($name in $cases) {
        It "behavior $name PASS" {
            $script:CapMap.ContainsKey($name) | Should Be $true
            $script:CapMap[$name] | Should Be 'PASS'
        }
    }
}
