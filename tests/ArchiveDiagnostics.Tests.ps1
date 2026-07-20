#requires -Version 5.0
<#
.SYNOPSIS
  Pester 3.4 wrapper for ArchiveDiagnostics.Harness.ahk
.NOTES
  Classic Should syntax only. Run:
    Invoke-Pester -Script tests/ArchiveDiagnostics.Tests.ps1 -PassThru
#>

$ErrorActionPreference = 'Stop'

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:HarnessPath = Join-Path $PSScriptRoot 'ArchiveDiagnostics.Harness.ahk'
$script:LibPath = Join-Path $script:RepoRoot 'lib\ArchiveDiagnostics.ahk'
$script:AhkExe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'
$script:StaticPath = Join-Path $PSScriptRoot 'SmartZip.Static.Tests.ps1'
$script:Results = @{}

function Invoke-ArchiveHarness {
    param(
        [ValidateSet('classify', 'volumes', 'all')]
        [string]$Mode = 'classify'
    )
    if (-not (Test-Path -LiteralPath $script:AhkExe)) {
        throw "AutoHotkey not found: $($script:AhkExe)"
    }
    if (-not (Test-Path -LiteralPath $script:HarnessPath)) {
        throw "Harness not found: $($script:HarnessPath)"
    }
    $outFile = Join-Path $env:TEMP ("ArchiveDiagnostics.Harness.{0}.{1}.out.txt" -f $Mode, [guid]::NewGuid().ToString('N'))
    $errFile = Join-Path $env:TEMP ("ArchiveDiagnostics.Harness.{0}.{1}.err.txt" -f $Mode, [guid]::NewGuid().ToString('N'))
    $args = @('/ErrorStdOut', $script:HarnessPath, $outFile, $Mode)
    $p = Start-Process -FilePath $script:AhkExe -ArgumentList $args -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput (Join-Path $env:TEMP 'ArchiveDiagnostics.Harness.stdout.txt') `
        -RedirectStandardError $errFile
    $map = @{}
    if (Test-Path -LiteralPath $outFile) {
        Get-Content -LiteralPath $outFile -Encoding UTF8 | ForEach-Object {
            $line = $_
            if ($line -match '^(PASS|FAIL)\s+(\S+)') {
                $map[$matches[2]] = $matches[1]
            }
            elseif ($line -match '^SUMMARY\s+passed=(\d+)\s+failed=(\d+)') {
                $map['__summary_passed'] = $matches[1]
                $map['__summary_failed'] = $matches[2]
            }
        }
    }
    return [pscustomobject]@{
        ExitCode = $p.ExitCode
        Map      = $map
        OutFile  = $outFile
        ErrFile  = $errFile
    }
}

Describe 'ArchiveDiagnosticsFiles' {
    It 'lib/ArchiveDiagnostics.ahk exists' {
        $script:LibPath | Should Exist
    }
    It 'tests/ArchiveDiagnostics.Harness.ahk exists' {
        $script:HarnessPath | Should Exist
    }
    It 'AutoHotkey 2.0.26 toolchain exists' {
        $script:AhkExe | Should Exist
    }
}

Describe 'ArchiveDiagnosticsClassify' {
    BeforeAll {
        $script:ClassifyRun = Invoke-ArchiveHarness -Mode classify
        $script:Results = $script:ClassifyRun.Map
    }

    It 'harness exits 0 on classify mode' {
        $script:ClassifyRun.ExitCode | Should Be 0
    }

    $caseNames = @(
        'status_ok',
        'status_ok_with_warning',
        'status_need_password',
        'status_wrong_password',
        'status_missing_volume',
        'status_not_archive',
        'status_unsupported_method',
        'status_header_corrupt',
        'status_truncated',
        'status_data_corrupt',
        'status_cancelled',
        'status_io_error',
        'status_unknown_error',
        'result_status',
        'result_stage',
        'result_exit_code',
        'result_archive_path',
        'result_output',
        'result_archive_type_default',
        'result_password_used_default',
        'result_volume_first_default',
        'result_missing_volumes_array',
        'result_warning_lines_array',
        'result_error_lines_array',
        'result_temp_output_dir_default',
        'result_partial_output_dir_default',
        'result_is_clean_success_ok',
        'result_may_delete_source_ok',
        'result_is_clean_success_warning_false',
        'result_may_delete_source_warning_false',
        'cancelled_exit_255',
        'cancelled_not_clean',
        'cancelled_no_delete',
        'missing_volume_beats_headers',
        'need_password_enter_prompt',
        'wrong_password_beats_headers',
        'wrong_password_keeps_multiple_error_lines',
        'wrong_password_cannot_open_encrypted',
        'unsupported_method',
        'truncated_unexpected_end',
        'header_corrupt_plain',
        'wrong_password_beats_crc_phrase',
        'data_corrupt_crc_failed',
        'data_corrupt_data_error',
        'not_archive',
        'ok_with_warning',
        'ok_with_warning_not_clean',
        'ok_with_warning_no_delete',
        'ok_with_warning_collects_warnings',
        'ok_clean',
        'ok_clean_is_clean',
        'ok_clean_may_delete',
        'ok_never_sets_password_used',
        'io_error_access_denied',
        'io_error_disk_full',
        'unknown_error',
        'priority_wrong_password_multi',
        'collects_wrong_password_line',
        'collects_headers_error_line_secondary',
        'redact_strips_password_value',
        'redact_replaces_with_placeholder',
        'redact_keeps_full_path_when_requested',
        'redact_name_mode_strips_password',
        'redact_name_mode_strips_directories',
        'redact_name_mode_keeps_filename',
        'redact_unquoted_dash_p',
        'redact_unquoted_dash_p_placeholder',
        'classifier_never_sets_password_used'
    )

    foreach ($name in $caseNames) {
        It "case $name PASS" {
            $script:Results.ContainsKey($name) | Should Be $true
            $script:Results[$name] | Should Be 'PASS'
        }
    }
}
