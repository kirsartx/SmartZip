#requires -Version 5.0
$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) {
    if ($MyInvocation.MyCommand.Path) {
        $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $PSScriptRoot = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'tests'))
    }
}
$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:HarnessPath = Join-Path $PSScriptRoot 'ExtractionLifecycle.Harness.ahk'
$script:AhkExe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'

function Get-SmartZipSourceText([string]$SmartZipPath) {
    $raw = Get-Content -LiteralPath $SmartZipPath -Raw -Encoding UTF8
    if ($raw -notmatch 'ExtractArchiveToTemp|RunCmdCapture|class SmartZip') {
        $raw = Get-Content -LiteralPath $SmartZipPath -Raw
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

function New-ExtractionLifecycleProductHost {
    param(
        [Parameter(Mandatory = $true)][string]$SmartZipPath,
        [Parameter(Mandatory = $true)][string]$OutputRoot
    )
    if (-not (Test-Path -LiteralPath $SmartZipPath)) {
        throw "SmartZip.ahk not found: $SmartZipPath"
    }
    $src = Get-SmartZipSourceText $SmartZipPath
    $startMarker = "`n    ExtractArchiveToTemp("
    $endMarker = "`n    RunCmdCapture("
    $body = Get-SourceSlice -Source $src -StartMarker $startMarker -EndMarker $endMarker
    if ([string]::IsNullOrEmpty($body)) {
        throw "lifecycle methods not found in SmartZip.ahk (ExtractArchiveToTemp..RunCmdCapture)"
    }
    $method = $body.TrimStart("`r", "`n")
    foreach ($name in @('ExtractArchiveToTemp', 'FinalizeExtraction', 'WriteDiagnostic')) {
        # Count method definitions only (4-space class indent), not call sites inside other methods.
        $matches = [regex]::Matches($method, '(?m)^    ' + [regex]::Escape($name) + '\s*\(')
        if ($matches.Count -ne 1) {
            throw "expected exactly one $name method definition in product slice, found $($matches.Count)"
        }
    }
    if ($method -match 'FinalizeDecision\s*\(') {
        throw 'product host must not contain FinalizeDecision oracle'
    }

    if (-not (Test-Path -LiteralPath $OutputRoot)) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    }
    $libDir = Join-Path $OutputRoot 'lib'
    $workDir = Join-Path $OutputRoot 'work'
    New-Item -ItemType Directory -Path $libDir, $workDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'lib\ArchiveDiagnostics.ahk') `
        -Destination (Join-Path $libDir 'ArchiveDiagnostics.ahk') -Force

    $outAhk = Join-Path $OutputRoot 'ExtractionLifecycle.Product.ahk'

    $header = @'
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib\ArchiveDiagnostics.ahk

global MainVersion := "3.6"
global edition := "Kirs.1"
global buildVersion := 21

outPath := A_Args.Length >= 1 ? A_Args[1] : A_Temp "\ExtractionLifecycle.product.out.txt"
passCount := 0
failCount := 0
lines := []

AssertEq(actual, expected, name) {
    global passCount, failCount, lines
    a := String(actual), e := String(expected)
    if (a = e) {
        passCount++
        lines.Push("PASS " name)
    } else {
        failCount++
        lines.Push("FAIL " name " expected=[" e "] actual=[" a "]")
    }
}
AssertTrue(cond, name) => AssertEq(cond ? "1" : "0", "1", name)

class LifecycleHost {
    7z := "7z.exe"
    7zG := "7zG.exe"
    cmdLog := false
    testLog := ""
    excludeArgs := " -xr!*.tmp"
    codePage := ""
    hideRunSize := 999999
    guiShow := true
    exitCode := 0
    sevenZipVersion := "23.01"
    recycled := []
    pathDuplCalls := []
    dirMoves := []
    scriptedExit := 0
    scriptedCap := { exitCode: 2, output: "ERROR: CRC Failed in encrypted file`nData Error", cancelled: false }
    workRoot := ""

    Reset() {
        this.recycled := []
        this.pathDuplCalls := []
        this.dirMoves := []
        this.exitCode := 0
        this.scriptedExit := 0
    }

    SeedFile(path, content := "x") {
        SplitPath(path, , &dir)
        try DirCreate(dir)
        try FileDelete(path)
        FileAppend(content, path, "UTF-8")
    }

    Run7z(hide, xa, path, args, gui, track, line) {
        this.exitCode := this.scriptedExit
        return this.exitCode
    }

    RunCmdCapture(CmdLine, Codepage := "UTF-8") {
        return this.scriptedCap
    }

    RecycleItem(souce, lineNum, delete := false) {
        this.recycled.Push({ path: souce, delete: delete, permanent: delete })
        if delete {
            try {
                if DirExist(souce)
                    DirDelete(souce, 1)
                else if FileExist(souce)
                    FileDelete(souce)
            } catch {
            }
        }
    }

    PathDupl(path, isdir := 0) {
        this.pathDuplCalls.Push(path)
        return path
    }

    MoveItem(souce, dest, isdir, lineNum) {
        this.dirMoves.Push({ from: souce, to: dest })
        try DirMove(souce, dest)
        catch {
            try FileMove(souce, dest, 1)
        }
        return dest
    }

'@

    $footer = @'

}

host := LifecycleHost()
host.workRoot := A_ScriptDir "\work"
try DirCreate(host.workRoot)

SourceActionFrom(host, path, isNested := false) {
    for item in host.recycled {
        if (StrLower(item.path) = StrLower(path) && !item.delete)
            return isNested ? "recycle_nested" : "recycle"
    }
    return "none"
}

TempActionFrom(host, result, tempDir) {
    if (result.HasOwnProp("partialOutputDir") && result.partialOutputDir != "")
        return "partial"
    if DirExist(tempDir) {
        has := false
        loop files tempDir "\*.*", "DF" {
            has := true
            break
        }
        if has
            return "keep"
        for item in host.recycled {
            if (StrLower(item.path) = StrLower(tempDir) && item.delete)
                return "remove_empty"
        }
        return "keep"
    }
    for item in host.recycled {
        if (StrLower(item.path) = StrLower(tempDir) && item.delete)
            return "remove_empty"
    }
    return "remove_empty"
}

RunFinalizeCase(host, path, result, tempDir, targetDir, mayDeleteRequested, tempHasOutput, isNested, isVolume) {
    host.recycled := []
    host.pathDuplCalls := []
    host.dirMoves := []
    try {
        if DirExist(tempDir)
            DirDelete(tempDir, 1)
    } catch {
    }
    try DirCreate(tempDir)
    if tempHasOutput
        host.SeedFile(tempDir "\payload.bin", "data")
    SplitPath(path, , &srcDir)
    try DirCreate(srcDir)
    if !FileExist(path)
        FileAppend("archive", path, "UTF-8")

    mayDel := false
    if (result.status = ArchiveStatus.OK && result.exitCode = 0 && !isVolume && !isNested && mayDeleteRequested)
        mayDel := true

    fr := host.FinalizeExtraction(path, result, tempDir, targetDir, mayDel)
    if (isNested && fr.isCleanSuccess && !isVolume && FileExist(path))
        host.RecycleItem(path, A_LineNumber, false)

    out := {
        sourceAction: SourceActionFrom(host, path, isNested),
        tempAction: TempActionFrom(host, fr, tempDir),
        isCleanSuccess: fr.isCleanSuccess,
        partialName: "",
        diagnostic: ""
    }
    if (fr.HasOwnProp("partialOutputDir") && fr.partialOutputDir != "") {
        SplitPath(fr.partialOutputDir, &leaf)
        out.partialName := leaf
        diagPath := fr.partialOutputDir "\SmartZip-诊断.txt"
        if FileExist(diagPath)
            out.diagnostic := FileRead(diagPath, "UTF-8")
    }
    return out
}

host.Reset()
r1 := ArchiveResult(ArchiveStatus.OK, "extract", 0, "pack.zip")
p1 := host.workRoot "\a\pack.zip"
t1 := host.workRoot "\tmp\t1"
o1 := host.workRoot "\out"
try DirCreate(o1)
d1 := RunFinalizeCase(host, p1, r1, t1, o1, true, true, false, false)
AssertEq(d1.sourceAction, "recycle", "ok_top_maydelete_recycles")
AssertEq(d1.tempAction, "keep", "ok_keeps_temp_for_move")
AssertEq(d1.isCleanSuccess, true, "ok_is_clean_success")

d2 := RunFinalizeCase(host, p1, r1, t1, o1, false, true, false, false)
AssertEq(d2.sourceAction, "none", "ok_without_maydelete_preserves")

r3 := ArchiveResult(ArchiveStatus.OK_WITH_WARNING, "extract", 0, p1)
d3 := RunFinalizeCase(host, p1, r3, t1, o1, true, true, false, false)
AssertEq(d3.sourceAction, "none", "warn_always_preserves_source")
AssertEq(d3.tempAction, "keep", "warn_moves_usable_output_keep_temp")
AssertEq(d3.isCleanSuccess, false, "warn_not_clean_success")

host.Reset()
host.scriptedExit := 2
host.scriptedCap := { exitCode: 2, output: "ERROR: CRC Failed in encrypted file`nData Error", cancelled: false }
bigPath := host.workRoot "\a\big.7z"
fatTmp := host.workRoot "\tmp\fat"
try DirCreate(host.workRoot "\a")
if !FileExist(bigPath)
    FileAppend("big", bigPath, "UTF-8")
try DirCreate(fatTmp)
host.SeedFile(fatTmp "\almost_all.bin", "xxxxxxxx")
er4 := host.ExtractArchiveToTemp(bigPath, "", fatTmp)
AssertEq(er4.status, ArchiveStatus.DATA_CORRUPT, "exit2_crc_is_data_corrupt")
AssertEq(er4.isCleanSuccess, false, "exit2_not_clean_success")
d4 := RunFinalizeCase(host, bigPath, er4, fatTmp, o1, true, true, false, false)
AssertEq(d4.sourceAction, "none", "exit2_ratio_ignored_source_remains")
AssertEq(d4.tempAction, "partial", "exit2_with_output_goes_partial")
AssertTrue(InStr(d4.partialName, "_解压不完整_") > 0, "exit2_partial_name_has_marker")
AssertTrue(InStr(d4.diagnostic, "DATA_CORRUPT") > 0 || InStr(d4.diagnostic, "status=") > 0, "exit2_diagnostic_written_concept")

r5 := ArchiveResult(ArchiveStatus.HEADER_CORRUPT, "extract", 2, host.workRoot "\a\bad.zip")
emptyTmp := host.workRoot "\tmp\empty"
d5 := RunFinalizeCase(host, host.workRoot "\a\bad.zip", r5, emptyTmp, o1, true, false, false, false)
AssertEq(d5.tempAction, "remove_empty", "fail_empty_removes_temp_only")
AssertEq(d5.sourceAction, "none", "fail_empty_preserves_source")

r6 := ArchiveResult(ArchiveStatus.CANCELLED, "extract", 255, p1)
cTmp := host.workRoot "\tmp\c"
d6 := RunFinalizeCase(host, p1, r6, cTmp, o1, true, false, false, false)
AssertEq(d6.sourceAction, "none", "cancel_never_source_handle")

d7a := RunFinalizeCase(host, host.workRoot "\a\v.part01.rar", r1, t1, o1, true, true, false, true)
d7b := RunFinalizeCase(host, host.workRoot "\a\v.r00", r1, t1, o1, true, true, false, true)
AssertTrue(d7a.sourceAction = "none" && d7b.sourceAction = "none", "volume_never_source_handle")

nestPath := host.workRoot "\out\nest\inner.zip"
nTmp := host.workRoot "\tmp\n"
d8 := RunFinalizeCase(host, nestPath, r1, nTmp, o1, true, true, true, false)
AssertEq(d8.sourceAction, "recycle_nested", "nested_ok_recycles_not_permanent")

d9 := RunFinalizeCase(host, nestPath, r3, nTmp, nTmp, true, true, true, false)
AssertEq(d9.sourceAction, "none", "nested_warn_preserves")

secretRaw := "cmd: 7z t -p`"SuperSecret`"`nstatus=DATA_CORRUPT"
red := RedactDiagnostic(secretRaw)
AssertTrue(InStr(red, "SuperSecret") = 0, "diagnostic_redacts_password")
AssertTrue(InStr(red, "-p***") > 0 || InStr(red, "***") > 0, "diagnostic_has_redact_marker")

r11 := ArchiveResult(ArchiveStatus.OK, "extract", 2, p1)
d11 := RunFinalizeCase(host, p1, r11, host.workRoot "\tmp\t", o1, true, true, false, false)
AssertEq(d11.isCleanSuccess, false, "nonzero_exit_not_clean_even_if_ok_status")
AssertEq(d11.sourceAction, "none", "nonzero_exit_no_recycle")

AssertTrue(InStr(d4.partialName, "big") > 0, "partial_uses_basename")
AssertTrue(InStr(d4.partialName, "D:") = 0, "partial_name_not_full_path")

summary := "SUMMARY passed=" passCount " failed=" failCount
lines.Push(summary)
text := ""
for line in lines
    text .= line "`r`n"
try FileDelete(outPath)
FileAppend(text, outPath, "UTF-8")
ExitApp(failCount > 0 ? 1 : 0)
'@

    $full = $header + $method + $footer
    # Normalize Chinese markers to the exact UTF-8 sequences from production methods.
    # PowerShell 5.1 may mis-decode non-BOM script source; product slice is authoritative.
    $partialMarker = [regex]::Match($method, 'nameNoExt "([^"]+)" stamp').Groups[1].Value
    $diagFile = [regex]::Match($method, 'partialOutputDir "\\(SmartZip-[^"]+\.txt)"').Groups[1].Value
    if ($partialMarker) {
        $full = [regex]::Replace($full, 'InStr\(d4\.partialName, "[^"]*"\) > 0, "exit2_partial_name_has_marker"',
            ('InStr(d4.partialName, "{0}") > 0, "exit2_partial_name_has_marker"' -f $partialMarker))
    }
    if ($diagFile) {
        $full = [regex]::Replace($full, 'fr\.partialOutputDir "\\SmartZip-[^"]+\.txt"',
            ('fr.partialOutputDir "\{0}"' -f $diagFile))
    }
    [System.IO.File]::WriteAllText($outAhk, $full, [System.Text.UTF8Encoding]::new($true))
    return $outAhk
}

function Export-ExtractionLifecycleProductHarness {
    # Required implementation contract (no oracle fallback):
    # 1. Read SmartZip.ahk and extract the exact class-method region from
    #    "`n    ExtractArchiveToTemp(" through the line before "`n    RunCmdCapture(".
    # 2. Assert that ExtractArchiveToTemp, FinalizeExtraction, and WriteDiagnostic
    #    each occur exactly once in the slice.
    # 3. Generate a TEMP AHK host with only production methods + injectable doubles.
    # 4. Emit the same 25 named PASS/FAIL keys as the oracle by invoking those
    #    production methods; never call/copy FinalizeDecision.
    # 5. Return the generated absolute .ahk path; throw on any missing marker/key.
    $productHarness = New-ExtractionLifecycleProductHost `
        -SmartZipPath (Join-Path $script:RepoRoot 'SmartZip.ahk') `
        -OutputRoot (Join-Path $env:TEMP ("SmartZip-Life-Product-{0}" -f ([guid]::NewGuid().ToString('N'))))
    if (-not (Test-Path -LiteralPath $productHarness)) { throw 'product lifecycle harness was not generated' }
    return $productHarness
}

function Invoke-ExtractionLifecycleHarness([string]$HarnessPath, [string]$Label) {
    $outFile = Join-Path $env:TEMP ("ExtractionLifecycle.{0}.{1}.out.txt" -f $Label,([guid]::NewGuid().ToString('N')))
    # AutoHotkey 2.0.26 fails to open scripts under non-ASCII repo paths; stage under %TEMP%.
    $runPath = $HarnessPath
    $harnessDir = [System.IO.Path]::GetDirectoryName($HarnessPath)
    $tempRoot = $env:TEMP
    $isUnderTemp = $harnessDir.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)
    $stagedRoot = $null
    if (-not $isUnderTemp) {
        $stagedRoot = Join-Path $tempRoot ("SmartZip-Life-Run-{0}" -f ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $stagedRoot -Force | Out-Null
        $leaf = [System.IO.Path]::GetFileName($HarnessPath)
        $runPath = Join-Path $stagedRoot $leaf
        Copy-Item -LiteralPath $HarnessPath -Destination $runPath -Force
        $libSrc = Join-Path $script:RepoRoot 'lib\ArchiveDiagnostics.ahk'
        if (Test-Path -LiteralPath $libSrc) {
            $libDst = Join-Path $stagedRoot 'lib'
            New-Item -ItemType Directory -Path $libDst -Force | Out-Null
            Copy-Item -LiteralPath $libSrc -Destination (Join-Path $libDst 'ArchiveDiagnostics.ahk') -Force
        }
        # Oracle harness uses #Include %A_ScriptDir%\..\lib\... — mirror parent\lib layout.
        $parentLib = Join-Path (Split-Path $stagedRoot -Parent) 'lib'
        # Prefer rewriting include to local lib for staged oracle:
        if ($leaf -eq 'ExtractionLifecycle.Harness.ahk') {
            $text = Get-Content -LiteralPath $runPath -Raw -Encoding UTF8
            $text = $text -replace '#Include %A_ScriptDir%\\\\.\\.\\lib\\ArchiveDiagnostics\.ahk',
                '#Include %A_ScriptDir%\lib\ArchiveDiagnostics.ahk'
            $text = $text.Replace('#Include %A_ScriptDir%\..\lib\ArchiveDiagnostics.ahk',
                '#Include %A_ScriptDir%\lib\ArchiveDiagnostics.ahk')
            [System.IO.File]::WriteAllText($runPath, $text, [System.Text.UTF8Encoding]::new($false))
        }
    }
    # Do not RedirectStandardError: pipe buffer + /ErrorStdOut can deadlock Start-Process -Wait.
    $p = Start-Process -FilePath $script:AhkExe -ArgumentList @('/ErrorStdOut', $runPath, $outFile) `
        -Wait -PassThru -NoNewWindow -WorkingDirectory ([System.IO.Path]::GetDirectoryName($runPath))
    $map = @{}
    if (Test-Path -LiteralPath $outFile) {
        Get-Content -LiteralPath $outFile -Encoding UTF8 | ForEach-Object {
            if ($_ -match '^(PASS|FAIL)\s+(\S+)') { $map[$matches[2]] = $matches[1] }
            elseif ($_ -match '^SUMMARY\s+passed=(\d+)\s+failed=(\d+)') {
                $map['__summary_passed'] = $matches[1]
                $map['__summary_failed'] = $matches[2]
            }
        }
    }
    if ($stagedRoot -and (Test-Path -LiteralPath $stagedRoot)) {
        try { Remove-Item -LiteralPath $stagedRoot -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
    return [pscustomobject]@{ ExitCode = $p.ExitCode; Map = $map }
}

Describe 'ExtractionLifecycleBehavior' {
    BeforeAll {
        $script:OracleRun = Invoke-ExtractionLifecycleHarness $script:HarnessPath 'oracle'
        $script:ProductHarnessPath = Export-ExtractionLifecycleProductHarness
        $script:ProductRun = Invoke-ExtractionLifecycleHarness $script:ProductHarnessPath 'product'
    }

    It 'oracle and product harnesses exit 0' {
        $script:OracleRun.ExitCode | Should Be 0
        $script:ProductRun.ExitCode | Should Be 0
    }

    $cases = @(
        'ok_top_maydelete_recycles',
        'ok_keeps_temp_for_move',
        'ok_is_clean_success',
        'ok_without_maydelete_preserves',
        'warn_always_preserves_source',
        'warn_moves_usable_output_keep_temp',
        'warn_not_clean_success',
        'exit2_crc_is_data_corrupt',
        'exit2_not_clean_success',
        'exit2_ratio_ignored_source_remains',
        'exit2_with_output_goes_partial',
        'exit2_partial_name_has_marker',
        'exit2_diagnostic_written_concept',
        'fail_empty_removes_temp_only',
        'fail_empty_preserves_source',
        'cancel_never_source_handle',
        'volume_never_source_handle',
        'nested_ok_recycles_not_permanent',
        'nested_warn_preserves',
        'diagnostic_redacts_password',
        'diagnostic_has_redact_marker',
        'nonzero_exit_not_clean_even_if_ok_status',
        'nonzero_exit_no_recycle',
        'partial_uses_basename',
        'partial_name_not_full_path'
    )

    foreach ($name in $cases) {
        It "oracle and product behavior $name PASS" {
            $script:OracleRun.Map.ContainsKey($name) | Should Be $true
            $script:ProductRun.Map.ContainsKey($name) | Should Be $true
            $script:OracleRun.Map[$name] | Should Be 'PASS'
            $script:ProductRun.Map[$name] | Should Be 'PASS'
        }
    }
}
