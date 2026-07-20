# SmartZip 3.6 Kirs.2 Extraction Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SmartZip’s legacy size-based extraction-success heuristic with a structured, testable safety pipeline that classifies 7-Zip failures, preserves every source on warning/failure, isolates partial output, improves password and volume recovery, and ships as SmartZip 3.6 Kirs.2 (22).

**Architecture:** Compile the pure `ArchiveStatus`, `ArchiveResult`, classification, volume, and redaction functions from `lib/ArchiveDiagnostics.ahk` into the existing single EXE. Keep process orchestration, settings, 7zG progress/pause integration, lifecycle control, and GUI in `SmartZip.ahk`; use Pester 3.4-compatible PowerShell tests plus AutoHotkey v2 harnesses and deterministic TEMP archives.

**Tech Stack:** AutoHotkey v2.0.26, Ahk2Exe 1.1.37.02a2, Pester 3.4-compatible PowerShell, 7-Zip 26.02 ZS v1.5.7 R1, Git, GitHub CLI.

## Global Constraints

- Display/version identity is exactly `SmartZip 3.6 Kirs.2 (22)`.
- `MainVersion := "3.6"` and Ahk2Exe FileVersion remain `3.6`; `edition := "Kirs.2"`, `buildVersion := 22`, and ProductVersion `22`.
- The final runtime artifact remains one `SmartZip.exe`; `lib/*.ahk` files are compile-time includes only.
- Preserve all existing compression behavior, Contextmenu behavior, 7zG large-file progress/pause behavior, password data, target directory, and unrelated INI settings.
- Existing 69 static tests must remain green in every task.
- Exit code 0 plus clean required stages is the only clean-success condition; `successPercent` must never authorize success or source handling.
- `OK_WITH_WARNING`, every failure state, and `CANCELLED` must preserve the top-level source and all volumes.
- Top-level and nested automatic source handling uses the Recycle Bin only; no source archive is permanently deleted.
- Split-volume sets are never automatically deleted.
- Passwords and clipboard content must not appear in logs, copied diagnostics, command traces, reports, or test output.
- Current Kirs.1 Release/tag remain unchanged; publication creates new `v3.6-kirs.2`.
- Use only the verified engine at `C:\Tool\7-Zip-Zstandard` for integration/smoke tests.
- Use the verified toolchain:
  - `C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe`
  - `C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\Ahk2Exe1.1.37.02a2\Ahk2Exe.exe`
- A task is not complete until its focused RED/GREEN cycle, full regression suite, `git diff --check`, focused commit, and fresh read-only review all pass with Critical=0 and Important=0.

## File Map

- Create `lib/ArchiveDiagnostics.ahk`: pure result types, output classifier, volume grouping, and diagnostic redaction.
- Modify `SmartZip.ahk`: include the library; add capture/preflight/password/state-machine/lifecycle/diagnostic orchestration; migrate settings; bump Kirs.2 metadata.
- Create `tests/ArchiveDiagnostics.Harness.ahk` and `tests/ArchiveDiagnostics.Tests.ps1`: executable pure-function classifier/redaction cases and Pester wrapper.
- Extend `tests/ArchiveDiagnostics.Harness.ahk` and `tests/ArchiveDiagnostics.Tests.ps1` in Task 2 with deterministic volume grouping cases (`ArchiveDiagnosticsVolumes`, focused `68/68`; full diagnostics cumulative `140/140`).
- Create `tests/RunCmdCapture.Harness.ahk`, `tests/RunCmdCapture.Tests.ps1`, `tests/PasswordPreflight.Harness.ahk`, `tests/PasswordPreflight.Tests.ps1`, `tests/ExtractionLifecycle.Harness.ahk`, `tests/ExtractionLifecycle.Tests.ps1`, `tests/NestingMigration.Harness.ahk`, `tests/NestingMigration.Tests.ps1`, `tests/DiagnosticUI.Harness.ahk`, and `tests/DiagnosticUI.Tests.ps1`: isolated behavior seams for each orchestration layer.
- Create `tests/New-ExtractionReliabilityFixtures.ps1`, `tests/Invoke-CompiledSmartZipScenario.ps1`, `tests/Real7Zip.Integration.Tests.ps1`, `tests/Invoke-ProductionSmartZipSmoke.ps1`, and `tests/ProductionSmokeUI.ahk`: deterministic fixture generation, real 7-Zip/compiled-SmartZip lifecycle checks, and hook-free observable production-artifact smoke automation.
- Create `tests/IntegrationTestHook.ahk`: optional-include callbacks used only by the TEMP integration build; production staging excludes the entire `tests` directory and verifies the hook marker is absent.
- Create/modify `tests/README.md`: document prerequisites, isolation, commands, and exact suite counts.
- Modify `tests/SmartZip.Static.Tests.ps1`: structural safety, migration, UI, version, and non-regression assertions.
- Modify `ini.md`: document deprecated `successPercent`, safe test/delete behavior, diagnostics, and volume behavior.
- Modify `README.md`: document Kirs.2 recovery UX and safety guarantees.

## Canonical Interfaces

All tasks must use these exact names and shapes:

```ahk
class ArchiveStatus {
    static OK := "OK"
    static OK_WITH_WARNING := "OK_WITH_WARNING"
    static NEED_PASSWORD := "NEED_PASSWORD"
    static WRONG_PASSWORD := "WRONG_PASSWORD"
    static MISSING_VOLUME := "MISSING_VOLUME"
    static NOT_ARCHIVE := "NOT_ARCHIVE"
    static UNSUPPORTED_METHOD := "UNSUPPORTED_METHOD"
    static HEADER_CORRUPT := "HEADER_CORRUPT"
    static TRUNCATED := "TRUNCATED"
    static DATA_CORRUPT := "DATA_CORRUPT"
    static CANCELLED := "CANCELLED"
    static IO_ERROR := "IO_ERROR"
    static UNKNOWN_ERROR := "UNKNOWN_ERROR"
}

class ArchiveResult {
    __New(status, stage, exitCode := -1, archivePath := "", output := "")
}

Classify7zResult(stage, exitCode, output, archivePath := "") => ArchiveResult
DetectVolumeGroup(path, siblingNames) => { isVolume, firstPath, members, missingVolumes, selectedIsFirst }
RedactDiagnostic(text, includeFullPath := true) => String
```

`ArchiveResult` owns these properties with stable defaults:

```text
status, stage, exitCode, archivePath, archiveType, passwordUsed,
volumeFirst, missingVolumes, warningLines, errorLines, tempOutputDir,
partialOutputDir, isCleanSuccess, mayDeleteSource, output
```

SmartZip orchestration uses:

```ahk
RunCmdCapture(cmdLine, codePage := "UTF-8") => { exitCode, output, cancelled }
ProbeArchive(path) => ArchiveResult
TestArchive(path, password := "") => ArchiveResult
BuildPasswordCandidates(path) => Array
ResolveArchivePassword(path, probeResult) => ArchiveResult
ExtractArchiveToTemp(path, password, tempDir) => ArchiveResult
FinalizeExtraction(path, result, tempDir, targetDir, mayDeleteSource) => ArchiveResult
ShowDiagnostic(result, isBatch := false)
WriteDiagnostic(result) => String
```

---

### Task 1: Pure Status Model, Output Classifier, and Redaction

**Files:**
- Create: `lib/ArchiveDiagnostics.ahk` (entire file; pure types + `Classify7zResult` + `RedactDiagnostic` only — do not add `DetectVolumeGroup` here)
- Create: `tests/ArchiveDiagnostics.Harness.ahk` (entire file; executable AHK v2 harness)
- Create: `tests/ArchiveDiagnostics.Tests.ps1` (entire file; Pester 3.4 wrapper)
- Do not modify: `SmartZip.ahk`, `tests/SmartZip.Static.Tests.ps1`, INI, docs other than this plan

**Interfaces:**
- Consumes: nothing from product code; harness `#Include`s `..\lib\ArchiveDiagnostics.ahk` only
- Produces (must match Canonical Interfaces exactly):
  - `class ArchiveStatus` with static string constants `OK`, `OK_WITH_WARNING`, `NEED_PASSWORD`, `WRONG_PASSWORD`, `MISSING_VOLUME`, `NOT_ARCHIVE`, `UNSUPPORTED_METHOD`, `HEADER_CORRUPT`, `TRUNCATED`, `DATA_CORRUPT`, `CANCELLED`, `IO_ERROR`, `UNKNOWN_ERROR`
  - `class ArchiveResult` with `__New(status, stage, exitCode := -1, archivePath := "", output := "")` and properties `status`, `stage`, `exitCode`, `archivePath`, `archiveType`, `passwordUsed`, `volumeFirst`, `missingVolumes`, `warningLines`, `errorLines`, `tempOutputDir`, `partialOutputDir`, `isCleanSuccess`, `mayDeleteSource`, `output`
  - `Classify7zResult(stage, exitCode, output, archivePath := "") => ArchiveResult`
  - `RedactDiagnostic(text, includeFullPath := true) => String`
  - Classification priority (highest first): `CANCELLED` → `MISSING_VOLUME` → `NEED_PASSWORD` → `WRONG_PASSWORD` → `UNSUPPORTED_METHOD` → `TRUNCATED` → `HEADER_CORRUPT` → `DATA_CORRUPT` → `NOT_ARCHIVE` → `OK_WITH_WARNING` → `OK` → `IO_ERROR`/`UNKNOWN_ERROR`
  - `isCleanSuccess` and `mayDeleteSource` are `true` only when `status = ArchiveStatus.OK`
  - `passwordUsed` is never written by `Classify7zResult` or `RedactDiagnostic` (always remains `""`)

- [ ] **Step 1: Create directories and write the failing harness + Pester wrapper**

```powershell
New-Item -ItemType Directory -Force -Path lib, tests | Out-Null
```

Create `tests/ArchiveDiagnostics.Harness.ahk` with exactly:

```ahk
; ArchiveDiagnostics pure-function harness (AutoHotkey v2).
; Usage:
;   AutoHotkey64.exe /ErrorStdOut tests\ArchiveDiagnostics.Harness.ahk <outPath> [mode]
; mode = classify (default) | volumes (Task 2)
#Requires AutoHotkey v2.0
#SingleInstance Off
FileEncoding "UTF-8"

outPath := A_Args.Length >= 1 ? A_Args[1] : A_Temp "\ArchiveDiagnostics.Harness.out.txt"
mode := A_Args.Length >= 2 ? StrLower(A_Args[2]) : "classify"

#Include ..\lib\ArchiveDiagnostics.ahk

passCount := 0
failCount := 0
lines := []

AssertEq(actual, expected, name) {
    global passCount, failCount, lines
    if (actual = expected) {
        passCount++
        lines.Push("PASS " name)
    } else {
        failCount++
        lines.Push("FAIL " name " expected=[" expected "] actual=[" actual "]")
    }
}

AssertTrue(cond, name) {
    AssertEq(cond ? "1" : "0", "1", name)
}

AssertFalse(cond, name) {
    AssertEq(cond ? "1" : "0", "0", name)
}

AssertContains(hay, needle, name) {
    AssertTrue(InStr(hay, needle) > 0, name)
}

AssertNotContains(hay, needle, name) {
    AssertTrue(InStr(hay, needle) = 0, name)
}

JoinLines(arr) {
    s := ""
    for line in arr
        s .= line "`n"
    return s
}

if (mode = "classify" || mode = "all") {
    ; --- status constants ---
    AssertEq(ArchiveStatus.OK, "OK", "status_ok")
    AssertEq(ArchiveStatus.OK_WITH_WARNING, "OK_WITH_WARNING", "status_ok_with_warning")
    AssertEq(ArchiveStatus.NEED_PASSWORD, "NEED_PASSWORD", "status_need_password")
    AssertEq(ArchiveStatus.WRONG_PASSWORD, "WRONG_PASSWORD", "status_wrong_password")
    AssertEq(ArchiveStatus.MISSING_VOLUME, "MISSING_VOLUME", "status_missing_volume")
    AssertEq(ArchiveStatus.NOT_ARCHIVE, "NOT_ARCHIVE", "status_not_archive")
    AssertEq(ArchiveStatus.UNSUPPORTED_METHOD, "UNSUPPORTED_METHOD", "status_unsupported_method")
    AssertEq(ArchiveStatus.HEADER_CORRUPT, "HEADER_CORRUPT", "status_header_corrupt")
    AssertEq(ArchiveStatus.TRUNCATED, "TRUNCATED", "status_truncated")
    AssertEq(ArchiveStatus.DATA_CORRUPT, "DATA_CORRUPT", "status_data_corrupt")
    AssertEq(ArchiveStatus.CANCELLED, "CANCELLED", "status_cancelled")
    AssertEq(ArchiveStatus.IO_ERROR, "IO_ERROR", "status_io_error")
    AssertEq(ArchiveStatus.UNKNOWN_ERROR, "UNKNOWN_ERROR", "status_unknown_error")

    ; --- ArchiveResult defaults ---
    base := ArchiveResult(ArchiveStatus.OK, "probe", 0, "C:\\tmp\\a.7z", "out")
    AssertEq(base.status, ArchiveStatus.OK, "result_status")
    AssertEq(base.stage, "probe", "result_stage")
    AssertEq(base.exitCode, 0, "result_exit_code")
    AssertEq(base.archivePath, "C:\\tmp\\a.7z", "result_archive_path")
    AssertEq(base.output, "out", "result_output")
    AssertEq(base.archiveType, "", "result_archive_type_default")
    AssertEq(base.passwordUsed, "", "result_password_used_default")
    AssertEq(base.volumeFirst, "", "result_volume_first_default")
    AssertTrue(base.missingVolumes is Array, "result_missing_volumes_array")
    AssertTrue(base.warningLines is Array, "result_warning_lines_array")
    AssertTrue(base.errorLines is Array, "result_error_lines_array")
    AssertEq(base.tempOutputDir, "", "result_temp_output_dir_default")
    AssertEq(base.partialOutputDir, "", "result_partial_output_dir_default")
    AssertTrue(base.isCleanSuccess, "result_is_clean_success_ok")
    AssertTrue(base.mayDeleteSource, "result_may_delete_source_ok")

    warnOnly := ArchiveResult(ArchiveStatus.OK_WITH_WARNING, "test", 0)
    AssertFalse(warnOnly.isCleanSuccess, "result_is_clean_success_warning_false")
    AssertFalse(warnOnly.mayDeleteSource, "result_may_delete_source_warning_false")

    ; 1) CANCELLED — exit 255
    r := Classify7zResult("extract", 255, "Everything is Ok`n")
    AssertEq(r.status, ArchiveStatus.CANCELLED, "cancelled_exit_255")
    AssertFalse(r.isCleanSuccess, "cancelled_not_clean")
    AssertFalse(r.mayDeleteSource, "cancelled_no_delete")

    ; 2) MISSING_VOLUME beats header wording
    r := Classify7zResult("probe", 2, "Headers Error`nERROR: Cannot find volume: a.7z.002`n")
    AssertTrue(r.status = ArchiveStatus.MISSING_VOLUME
        && r.missingVolumes.Length = 1
        && r.missingVolumes[1] = "a.7z.002", "missing_volume_beats_headers")

    ; 3) NEED_PASSWORD
    r := Classify7zResult("probe", 2, "Enter password (will not be echoed):`nERROR: Wrong password?`n")
    AssertEq(r.status, ArchiveStatus.NEED_PASSWORD, "need_password_enter_prompt")

    ; 4) WRONG_PASSWORD beats Headers Error in same output
    r := Classify7zResult("test", 2, "ERROR: Wrong password?`nHeaders Error`nSystem ERROR:`n")
    AssertEq(r.status, ArchiveStatus.WRONG_PASSWORD, "wrong_password_beats_headers")
    AssertTrue(r.errorLines.Length >= 2, "wrong_password_keeps_multiple_error_lines")

    ; 5) Cannot open encrypted archive
    r := Classify7zResult("probe", 2, "ERROR: Cannot open encrypted archive. Wrong password?`n")
    AssertEq(r.status, ArchiveStatus.WRONG_PASSWORD, "wrong_password_cannot_open_encrypted")

    ; 6) UNSUPPORTED_METHOD
    r := Classify7zResult("probe", 2, "ERROR: Unsupported Method`n")
    AssertEq(r.status, ArchiveStatus.UNSUPPORTED_METHOD, "unsupported_method")

    ; 7) TRUNCATED
    r := Classify7zResult("test", 2, "ERROR: Unexpected end of archive`n")
    AssertEq(r.status, ArchiveStatus.TRUNCATED, "truncated_unexpected_end")

    ; 8) HEADER_CORRUPT — Headers Error without password/volume evidence
    r := Classify7zResult("test", 2, "ERROR: Headers Error`n")
    AssertEq(r.status, ArchiveStatus.HEADER_CORRUPT, "header_corrupt_plain")

    ; 9–10) DATA_CORRUPT
    r := Classify7zResult("test", 2, "ERROR: CRC Failed in encrypted file. Wrong password?`n")
    ; Wrong password marker still wins over CRC when both present:
    AssertEq(r.status, ArchiveStatus.WRONG_PASSWORD, "wrong_password_beats_crc_phrase")
    r := Classify7zResult("test", 2, "ERROR: CRC Failed`nSub items Errors: 1`n")
    AssertEq(r.status, ArchiveStatus.DATA_CORRUPT, "data_corrupt_crc_failed")
    r := Classify7zResult("test", 2, "ERROR: Data Error`n")
    AssertEq(r.status, ArchiveStatus.DATA_CORRUPT, "data_corrupt_data_error")

    ; 11) NOT_ARCHIVE
    r := Classify7zResult("probe", 2, "ERROR: Cannot open the file as archive`n")
    AssertEq(r.status, ArchiveStatus.NOT_ARCHIVE, "not_archive")

    ; 12) OK_WITH_WARNING
    r := Classify7zResult("test", 0, "Everything is Ok`nWarnings: 1`nThere are data after the end of archive`n")
    AssertEq(r.status, ArchiveStatus.OK_WITH_WARNING, "ok_with_warning")
    AssertFalse(r.isCleanSuccess, "ok_with_warning_not_clean")
    AssertFalse(r.mayDeleteSource, "ok_with_warning_no_delete")
    AssertTrue(r.warningLines.Length >= 1, "ok_with_warning_collects_warnings")

    ; 13) OK
    r := Classify7zResult("extract", 0, "Type = 7z`nEverything is Ok`n")
    AssertTrue(r.status = ArchiveStatus.OK && r.archiveType = "7z", "ok_clean")
    AssertTrue(r.isCleanSuccess, "ok_clean_is_clean")
    AssertTrue(r.mayDeleteSource, "ok_clean_may_delete")
    AssertEq(r.passwordUsed, "", "ok_never_sets_password_used")

    ; 14) IO_ERROR
    r := Classify7zResult("extract", 2, "ERROR: Can not open output file : Access is denied.`n")
    AssertEq(r.status, ArchiveStatus.IO_ERROR, "io_error_access_denied")
    r := Classify7zResult("extract", 2, "ERROR: There is not enough space on the disk.`n")
    AssertEq(r.status, ArchiveStatus.IO_ERROR, "io_error_disk_full")

    ; 15) UNKNOWN_ERROR
    r := Classify7zResult("extract", 2, "ERROR: Something completely unexpected happened`n")
    AssertEq(r.status, ArchiveStatus.UNKNOWN_ERROR, "unknown_error")

    ; 16) line collection keeps secondary diagnostics
    r := Classify7zResult("test", 2, "ERROR: Wrong password?`nHeaders Error`nData Error in encrypted file. Wrong password?`n")
    AssertEq(r.status, ArchiveStatus.WRONG_PASSWORD, "priority_wrong_password_multi")
    joinedErr := JoinLines(r.errorLines)
    AssertContains(joinedErr, "Wrong password?", "collects_wrong_password_line")
    AssertContains(joinedErr, "Headers Error", "collects_headers_error_line_secondary")

    ; 17–18) RedactDiagnostic
    secretCmd := '7z.exe t -p"S3cretPass!" -bso1 "C:\Users\Demo\vault.7z"'
    redFull := RedactDiagnostic(secretCmd, true)
    AssertNotContains(redFull, "S3cretPass!", "redact_strips_password_value")
    AssertContains(redFull, "-p***", "redact_replaces_with_placeholder")
    AssertContains(redFull, "C:\Users\Demo\vault.7z", "redact_keeps_full_path_when_requested")

    redName := RedactDiagnostic(secretCmd, false)
    AssertNotContains(redName, "S3cretPass!", "redact_name_mode_strips_password")
    AssertNotContains(redName, "C:\Users\Demo\", "redact_name_mode_strips_directories")
    AssertContains(redName, "vault.7z", "redact_name_mode_keeps_filename")

    bare := RedactDiagnostic('7z.exe t -pMyPass file.7z', true)
    AssertNotContains(bare, "MyPass", "redact_unquoted_dash_p")
    AssertContains(bare, "-p***", "redact_unquoted_dash_p_placeholder")

    ; passwordUsed must never be populated by classifier/redaction
    r := Classify7zResult("test", 2, "ERROR: Wrong password?`n", "C:\tmp\x.7z")
    AssertEq(r.passwordUsed, "", "classifier_never_sets_password_used")
}

if (mode = "volumes") {
    lines.Push("FAIL volumes_mode_not_implemented_in_task1")
    failCount++
}

summary := "SUMMARY passed=" passCount " failed=" failCount
lines.Push(summary)
text := ""
for line in lines
    text .= line "`r`n"
try FileDelete(outPath)
FileAppend(text, outPath, "UTF-8")
ExitApp(failCount > 0 ? 1 : 0)
```

Create `tests/ArchiveDiagnostics.Tests.ps1` with exactly:

```powershell
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
```

- [ ] **Step 2: Run focused tests and confirm RED**

Run:

```powershell
$focused = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
"Passed=$($focused.PassedCount) Failed=$($focused.FailedCount) Total=$($focused.TotalCount)"
```

Expected RED:
- `ArchiveDiagnosticsFiles` → `lib/ArchiveDiagnostics.ahk exists` **fails** (`Should Exist` on missing `lib\ArchiveDiagnostics.ahk`)
- total focused failures ≥ 1; harness cases either throw (missing include) or never emit PASS lines
- Do **not** implement until this RED is observed and recorded

- [ ] **Step 3: Write minimal `lib/ArchiveDiagnostics.ahk` implementation**

Create `lib/ArchiveDiagnostics.ahk` with exactly:

```ahk
; Pure archive diagnostics for SmartZip (compile-time include only).
; No UI, no process launch, no file I/O side effects.
#Requires AutoHotkey v2.0

class ArchiveStatus {
    static OK := "OK"
    static OK_WITH_WARNING := "OK_WITH_WARNING"
    static NEED_PASSWORD := "NEED_PASSWORD"
    static WRONG_PASSWORD := "WRONG_PASSWORD"
    static MISSING_VOLUME := "MISSING_VOLUME"
    static NOT_ARCHIVE := "NOT_ARCHIVE"
    static UNSUPPORTED_METHOD := "UNSUPPORTED_METHOD"
    static HEADER_CORRUPT := "HEADER_CORRUPT"
    static TRUNCATED := "TRUNCATED"
    static DATA_CORRUPT := "DATA_CORRUPT"
    static CANCELLED := "CANCELLED"
    static IO_ERROR := "IO_ERROR"
    static UNKNOWN_ERROR := "UNKNOWN_ERROR"
}

class ArchiveResult {
    __New(status, stage, exitCode := -1, archivePath := "", output := "") {
        this.status := status
        this.stage := stage
        this.exitCode := exitCode
        this.archivePath := archivePath
        this.archiveType := ""
        this.passwordUsed := ""
        this.volumeFirst := ""
        this.missingVolumes := []
        this.warningLines := []
        this.errorLines := []
        this.tempOutputDir := ""
        this.partialOutputDir := ""
        this.isCleanSuccess := (status = ArchiveStatus.OK)
        this.mayDeleteSource := (status = ArchiveStatus.OK)
        this.output := output
    }
}

Classify7zResult(stage, exitCode, output, archivePath := "") {
    result := ArchiveResult(ArchiveStatus.UNKNOWN_ERROR, stage, exitCode, archivePath, output)
    text := output = "" ? "" : String(output)
    lines := StrSplit(text, "`n", "`r")

    hasCancelled := (exitCode = 255)
    hasMissingVolume := false
    hasNeedPassword := false
    hasWrongPassword := false
    hasUnsupported := false
    hasTruncated := false
    hasHeaderCorrupt := false
    hasDataCorrupt := false
    hasNotArchive := false
    hasIoError := false
    hasWarning := false

    for line in lines {
        trimmed := Trim(line)
        if (trimmed = "")
            continue

        if RegExMatch(trimmed, "i)^Type\s*=\s*(.+)$", &typeMatch)
            result.archiveType := Trim(typeMatch[1])

        isWarn := false
        isErr := false

        if (trimmed ~= "i)Wrong password\?" || InStr(trimmed, "Cannot open encrypted archive")) {
            hasWrongPassword := true
            isErr := true
        }
        if (trimmed ~= "i)Cannot find volume" || trimmed ~= "i)Missing volume" || trimmed ~= "i)Cannot open volume" || trimmed ~= "i)Broken volume") {
            hasMissingVolume := true
            isErr := true
            if RegExMatch(trimmed, 'i)(?:Cannot find|Missing|Cannot open|Broken) volume(?:\s*:)?\s*(.+)$', &volumeMatch) {
                missingName := Trim(volumeMatch[1], ' "`t')
                if (missingName != "")
                    result.missingVolumes.Push(missingName)
            }
        }
        if (InStr(trimmed, "Enter password (will not be echoed):")) {
            hasNeedPassword := true
            isErr := true
        }
        if (trimmed ~= "i)Unsupported Method" || trimmed ~= "i)Unsupported method" || trimmed ~= "i)Method is not supported") {
            hasUnsupported := true
            isErr := true
        }
        if (InStr(trimmed, "Unexpected end of archive") || InStr(trimmed, "Unexpected end of data")) {
            hasTruncated := true
            isErr := true
        }
        if (InStr(trimmed, "Headers Error")) {
            hasHeaderCorrupt := true
            isErr := true
        }
        if (InStr(trimmed, "CRC Failed") || InStr(trimmed, "Data Error")) {
            hasDataCorrupt := true
            isErr := true
        }
        if (InStr(trimmed, "Cannot open the file as archive") || InStr(trimmed, "Can not open the file as archive")) {
            hasNotArchive := true
            isErr := true
        }
        if (trimmed ~= "i)Access is denied" || trimmed ~= "i)not enough space" || trimmed ~= "i)The system cannot find the path" || trimmed ~= "i)The network path was not found" || trimmed ~= "i)Can not open output file" || trimmed ~= "i)Cannot create output directory") {
            hasIoError := true
            isErr := true
        }
        if (trimmed ~= "i)^Warnings?:\s*[1-9]" || InStr(trimmed, "There are data after the end of archive") || InStr(trimmed, "WARNINGS:")) {
            hasWarning := true
            isWarn := true
        }
        if (InStr(trimmed, "Everything is Ok") = 0 && (InStr(trimmed, "ERROR:") = 1 || InStr(trimmed, "ERROR: ") || trimmed ~= "i)^Error:")) {
            isErr := true
        }

        if (isErr)
            result.errorLines.Push(trimmed)
        else if (isWarn)
            result.warningLines.Push(trimmed)
        else if (InStr(trimmed, "There are data after the end of archive"))
            result.warningLines.Push(trimmed)
    }

    ; Priority ladder (spec §4.2)
    if (hasCancelled) {
        result.status := ArchiveStatus.CANCELLED
    } else if (hasMissingVolume) {
        result.status := ArchiveStatus.MISSING_VOLUME
    } else if (hasNeedPassword) {
        result.status := ArchiveStatus.NEED_PASSWORD
    } else if (hasWrongPassword) {
        result.status := ArchiveStatus.WRONG_PASSWORD
    } else if (hasUnsupported) {
        result.status := ArchiveStatus.UNSUPPORTED_METHOD
    } else if (hasTruncated) {
        result.status := ArchiveStatus.TRUNCATED
    } else if (hasHeaderCorrupt) {
        result.status := ArchiveStatus.HEADER_CORRUPT
    } else if (hasDataCorrupt) {
        result.status := ArchiveStatus.DATA_CORRUPT
    } else if (hasNotArchive) {
        result.status := ArchiveStatus.NOT_ARCHIVE
    } else if (exitCode = 0 && (hasWarning || result.warningLines.Length > 0)) {
        result.status := ArchiveStatus.OK_WITH_WARNING
    } else if (exitCode = 0) {
        result.status := ArchiveStatus.OK
    } else if (hasIoError) {
        result.status := ArchiveStatus.IO_ERROR
    } else {
        result.status := ArchiveStatus.UNKNOWN_ERROR
    }

    result.isCleanSuccess := (result.status = ArchiveStatus.OK)
    result.mayDeleteSource := (result.status = ArchiveStatus.OK)
    result.passwordUsed := ""
    return result
}

RedactDiagnostic(text, includeFullPath := true) {
    s := text = "" ? "" : String(text)
    ; Quoted -p"..." and -p'...'
    s := RegExReplace(s, 'i)(-p)(["''])([^"'']*)\2', "$1***")
    ; Unquoted -pVALUE (stop at whitespace)
    s := RegExReplace(s, 'i)(-p)(?!\*\*\*)(\S+)', "$1***")
    if (!includeFullPath) {
        ; Replace Windows paths with leaf names only
        s := RegExReplace(s, 'i)([a-z]:\\(?:[^\\/:*?"<>|\r\n]+\\)*)([^\\/:*?"<>|\r\n]+)', "$2")
        s := RegExReplace(s, '(\\\\(?:[^\\/:*?"<>|\r\n]+\\)*)([^\\/:*?"<>|\r\n]+)', "$2")
    }
    return s
}
```

- [ ] **Step 4: Run focused GREEN, then full static regression**

Run:

```powershell
$focused = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
"FOCUSED Passed=$($focused.PassedCount) Failed=$($focused.FailedCount) Total=$($focused.TotalCount)"
if ($focused.FailedCount -ne 0) { exit 1 }
# Expected focused: TotalCount=72, FailedCount=0
# (3 file-existence Its + 1 harness-exit It + 68 named harness cases)

$static = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
"STATIC Passed=$($static.PassedCount) Failed=$($static.FailedCount) Total=$($static.TotalCount)"
if ($static.PassedCount -ne 69 -or $static.FailedCount -ne 0) { exit 1 }
```

Expected GREEN:
- focused `Passed=72 Failed=0 Total=72`
- static `Passed=69 Failed=0 Total=69`

- [ ] **Step 5: `git diff --check` and focused commit**

Run:

```powershell
git add -- lib/ArchiveDiagnostics.ahk tests/ArchiveDiagnostics.Harness.ahk tests/ArchiveDiagnostics.Tests.ps1
git diff --check --cached
git diff --cached --stat
git commit -m "feat: add ArchiveStatus classifier and diagnostic redaction"
```

Expected: no whitespace errors; commit contains only the three new files above.

- [ ] **Step 6: Independent read-only review gate**

Dispatch a fresh read-only reviewer (no product edits) against this task’s commit with the design spec §3–4, §11 redaction rules, and Canonical Interfaces. The reviewer must verify:

- all 13 `ArchiveStatus` values exist with exact spellings
- priority order matches design §4.2 (wrong password before headers; missing volume before headers; exit 0 + warning → `OK_WITH_WARNING`)
- `warningLines` / `errorLines` collect secondary markers while highest priority wins
- `RedactDiagnostic` never leaves password material; `passwordUsed` stays empty
- `isCleanSuccess` / `mayDeleteSource` true only for `OK`
- no `SmartZip.ahk` changes and static suite still 69/69

Require:

```text
Critical=0
Important=0
```

If either count is non-zero: fix in a follow-up commit on the same files only, re-run Step 4–5, and re-review until both are zero. Task 1 is incomplete until this gate passes.

### Task 2: Deterministic Volume Group Detection

**Files:**
- Modify: `lib/ArchiveDiagnostics.ahk` — append `DetectVolumeGroup` only (do not change Task 1 classifier/redaction behavior)
- Modify: `tests/ArchiveDiagnostics.Harness.ahk` — implement `mode = "volumes"` (replace the Task 1 stub that fails `volumes_mode_not_implemented_in_task1`)
- Modify: `tests/ArchiveDiagnostics.Tests.ps1` — add `Describe 'ArchiveDiagnosticsVolumes'` with the cases below
- Do not modify: `SmartZip.ahk`, `tests/SmartZip.Static.Tests.ps1`

**Interfaces:**
- Consumes: Task 1 `lib/ArchiveDiagnostics.ahk` (types already present; volume detection is pure)
- Produces (Canonical Interfaces):
  - `DetectVolumeGroup(path, siblingNames) => Object` with exact properties:
    - `isVolume` (Boolean) — true when `path` matches a supported multi-volume pattern
    - `firstPath` (String) — full path of the first volume when derivable; otherwise `""`
    - `members` (Array) — full paths of sibling names that belong to the same group and are present in `siblingNames` (order ascending by volume index when indices exist)
    - `missingVolumes` (Array) — expected member **file names** (not full paths) that are absent from `siblingNames` when the pattern allows a reliable contiguous range; empty array when the set is complete or when the range cannot be derived without fabricating numbers
    - `selectedIsFirst` (Boolean) — true when the selected `path` is the first volume of its group
  - Supported patterns (design §7):
    1. `name.7z.001` / `name.7z.002` / …
    2. `name.zip.001` / …
    3. `name.001` / `name.002` / … (bare numeric tail after a final dot, with non-empty stem)
    4. `name.part01.rar` / `name.part10.rar` (zero-padded `partNN`)
    5. `name.rar` + `name.r00` / `name.r01` / … (`name.rar` is first; `r00` is second volume)
  - Non-volume files: `{ isVolume: false, firstPath: "", members: [], missingVolumes: [], selectedIsFirst: false }`
  - When selected path is a non-first volume and the first volume name can be derived, `firstPath` still points at the first volume path even if that file is missing from `siblingNames` (caller later offers “locate first volume”); `missingVolumes` includes the missing first name when it is not in `siblingNames`

- [ ] **Step 1: Extend the harness with volume cases (failing until implementation exists)**

In `tests/ArchiveDiagnostics.Harness.ahk`, replace the entire block:

```ahk
if (mode = "volumes") {
    lines.Push("FAIL volumes_mode_not_implemented_in_task1")
    failCount++
}
```

with:

```ahk
if (mode = "volumes" || mode = "all") {
    dir := "C:\volfixture"

    ; --- .7z.001 first volume, complete pair ---
    siblings := ["archive.7z.001", "archive.7z.002"]
    g := DetectVolumeGroup(dir "\archive.7z.001", siblings)
    AssertTrue(g.isVolume, "sevenz_001_is_volume")
    AssertTrue(g.selectedIsFirst, "sevenz_001_selected_is_first")
    AssertEq(g.firstPath, dir "\archive.7z.001", "sevenz_001_first_path")
    AssertEq(g.members.Length, 2, "sevenz_001_member_count")
    AssertEq(g.members[1], dir "\archive.7z.001", "sevenz_001_member_first")
    AssertEq(g.members[2], dir "\archive.7z.002", "sevenz_001_member_second")
    AssertEq(g.missingVolumes.Length, 0, "sevenz_001_no_missing")

    ; --- .7z.002 redirects to first ---
    g := DetectVolumeGroup(dir "\archive.7z.002", siblings)
    AssertTrue(g.isVolume, "sevenz_002_is_volume")
    AssertFalse(g.selectedIsFirst, "sevenz_002_not_first")
    AssertEq(g.firstPath, dir "\archive.7z.001", "sevenz_002_redirects_first_path")
    AssertEq(g.missingVolumes.Length, 0, "sevenz_002_no_missing_when_first_present")

    ; --- .zip.001 group ---
    siblings := ["pack.zip.001", "pack.zip.002", "pack.zip.003"]
    g := DetectVolumeGroup(dir "\pack.zip.001", siblings)
    AssertTrue(g.isVolume, "zip_001_is_volume")
    AssertTrue(g.selectedIsFirst, "zip_001_selected_is_first")
    AssertEq(g.firstPath, dir "\pack.zip.001", "zip_001_first_path")
    AssertEq(g.members.Length, 3, "zip_001_member_count")
    AssertEq(g.missingVolumes.Length, 0, "zip_001_no_missing")

    ; --- bare .001 ---
    siblings := ["data.001", "data.002"]
    g := DetectVolumeGroup(dir "\data.001", siblings)
    AssertTrue(g.isVolume, "bare_001_is_volume")
    AssertTrue(g.selectedIsFirst, "bare_001_selected_is_first")
    AssertEq(g.firstPath, dir "\data.001", "bare_001_first_path")
    AssertEq(g.members.Length, 2, "bare_001_member_count")

    ; --- .part01.rar first ---
    siblings := ["movie.part01.rar", "movie.part02.rar", "movie.part03.rar"]
    g := DetectVolumeGroup(dir "\movie.part01.rar", siblings)
    AssertTrue(g.isVolume, "part01_rar_is_volume")
    AssertTrue(g.selectedIsFirst, "part01_rar_selected_is_first")
    AssertEq(g.firstPath, dir "\movie.part01.rar", "part01_rar_first_path")
    AssertEq(g.members.Length, 3, "part01_rar_member_count")
    AssertEq(g.missingVolumes.Length, 0, "part01_rar_no_missing")

    ; --- .part10.rar not first; first present ---
    siblings := ["movie.part01.rar", "movie.part10.rar"]
    g := DetectVolumeGroup(dir "\movie.part10.rar", siblings)
    AssertTrue(g.isVolume, "part10_rar_is_volume")
    AssertFalse(g.selectedIsFirst, "part10_rar_not_first")
    AssertEq(g.firstPath, dir "\movie.part01.rar", "part10_rar_redirects_to_part01")
    ; Contiguous range 01..10 with only 01 and 10 present → missing 02..09
    AssertTrue(g.missingVolumes.Length >= 8, "part10_rar_reports_gap_missing_count")
    AssertTrue(_ArrayHas(g.missingVolumes, "movie.part02.rar"), "part10_rar_missing_includes_part02")
    AssertTrue(_ArrayHas(g.missingVolumes, "movie.part09.rar"), "part10_rar_missing_includes_part09")
    AssertFalse(_ArrayHas(g.missingVolumes, "movie.part01.rar"), "part10_rar_missing_excludes_present_first")
    AssertFalse(_ArrayHas(g.missingVolumes, "movie.part10.rar"), "part10_rar_missing_excludes_selected")

    ; --- name.rar + name.r00 / name.r01 ---
    siblings := ["backup.rar", "backup.r00", "backup.r01"]
    g := DetectVolumeGroup(dir "\backup.rar", siblings)
    AssertTrue(g.isVolume, "rar_base_is_volume")
    AssertTrue(g.selectedIsFirst, "rar_base_selected_is_first")
    AssertEq(g.firstPath, dir "\backup.rar", "rar_base_first_path")
    AssertEq(g.members.Length, 3, "rar_r00_member_count")
    AssertEq(g.members[1], dir "\backup.rar", "rar_r00_member_base")
    AssertEq(g.members[2], dir "\backup.r00", "rar_r00_member_r00")
    AssertEq(g.members[3], dir "\backup.r01", "rar_r00_member_r01")
    AssertEq(g.missingVolumes.Length, 0, "rar_r00_complete_no_missing")

    g := DetectVolumeGroup(dir "\backup.r00", siblings)
    AssertTrue(g.isVolume, "r00_is_volume")
    AssertFalse(g.selectedIsFirst, "r00_not_first")
    gapSiblings := ["gap.rar", "gap.r00", "gap.r02"]
    gap := DetectVolumeGroup(dir "\gap.r02", gapSiblings)
    AssertTrue(g.firstPath = dir "\backup.rar"
        && _ArrayHas(gap.missingVolumes, "gap.r01"), "rxx_redirects_and_reports_gap")

    ; --- missing first volume (.7z.002 only) ---
    siblings := ["archive.7z.002", "archive.7z.003"]
    g := DetectVolumeGroup(dir "\archive.7z.002", siblings)
    AssertTrue(g.isVolume, "missing_first_still_volume")
    AssertFalse(g.selectedIsFirst, "missing_first_selected_not_first")
    AssertEq(g.firstPath, dir "\archive.7z.001", "missing_first_first_path_derived")
    AssertTrue(_ArrayHas(g.missingVolumes, "archive.7z.001"), "missing_first_listed")

    ; --- missing middle volume in .7z sequence 001..003 without 002 ---
    siblings := ["archive.7z.001", "archive.7z.003"]
    g := DetectVolumeGroup(dir "\archive.7z.001", siblings)
    AssertTrue(g.isVolume, "missing_middle_is_volume")
    AssertTrue(g.selectedIsFirst, "missing_middle_selected_first")
    AssertTrue(_ArrayHas(g.missingVolumes, "archive.7z.002"), "missing_middle_lists_002")
    AssertEq(g.members.Length, 2, "missing_middle_members_present_only")

    ; --- non-volume ordinary file ---
    siblings := ["readme.txt", "archive.7z"]
    g := DetectVolumeGroup(dir "\readme.txt", siblings)
    AssertFalse(g.isVolume, "non_volume_is_false")
    AssertEq(g.firstPath, "", "non_volume_empty_first")
    AssertEq(g.members.Length, 0, "non_volume_empty_members")
    AssertEq(g.missingVolumes.Length, 0, "non_volume_empty_missing")
    AssertFalse(g.selectedIsFirst, "non_volume_selected_not_first")

    ; --- single .7z.001 alone: is volume, first, no fabricated extra missing beyond none ---
    siblings := ["solo.7z.001"]
    g := DetectVolumeGroup(dir "\solo.7z.001", siblings)
    AssertTrue(g.isVolume, "solo_001_is_volume")
    AssertTrue(g.selectedIsFirst, "solo_001_is_first")
    AssertEq(g.firstPath, dir "\solo.7z.001", "solo_001_first_path")
    AssertEq(g.members.Length, 1, "solo_001_one_member")
    AssertEq(g.missingVolumes.Length, 0, "solo_001_no_fabricated_missing")

    ; --- incomplete rXX without inventing huge ranges when only r00 present and base missing ---
    siblings := ["set.r00"]
    g := DetectVolumeGroup(dir "\set.r00", siblings)
    AssertTrue(g.isVolume, "orphan_r00_is_volume")
    AssertFalse(g.selectedIsFirst, "orphan_r00_not_first")
    AssertEq(g.firstPath, dir "\set.rar", "orphan_r00_derives_rar_first")
    AssertTrue(_ArrayHas(g.missingVolumes, "set.rar"), "orphan_r00_missing_base_rar")
    AssertFalse(_ArrayHas(g.missingVolumes, "set.r99"), "orphan_r00_does_not_fabricate_r99")
}

_ArrayHas(arr, value) {
    for item in arr {
        if (item = value)
            return true
    }
    return false
}
```

Also ensure the harness still defines `_ArrayHas` before use if the script interpreter requires functions declared before call in some modes — place `_ArrayHas` **above** the `if (mode = "volumes" ...)` block (same file, after `AssertNotContains`) as:

```ahk
_ArrayHas(arr, value) {
    for item in arr {
        if (item = value)
            return true
    }
    return false
}
```

and **delete** the duplicate trailing `_ArrayHas` if both would exist.

Append to `tests/ArchiveDiagnostics.Tests.ps1` (after the existing Describes) exactly:

```powershell
Describe 'ArchiveDiagnosticsVolumes' {
    BeforeAll {
        $script:VolumeRun = Invoke-ArchiveHarness -Mode volumes
        $script:VolResults = $script:VolumeRun.Map
    }

    It 'harness exits 0 on volumes mode' {
        $script:VolumeRun.ExitCode | Should Be 0
    }

    $volumeCases = @(
        'sevenz_001_is_volume',
        'sevenz_001_selected_is_first',
        'sevenz_001_first_path',
        'sevenz_001_member_count',
        'sevenz_001_member_first',
        'sevenz_001_member_second',
        'sevenz_001_no_missing',
        'sevenz_002_is_volume',
        'sevenz_002_not_first',
        'sevenz_002_redirects_first_path',
        'sevenz_002_no_missing_when_first_present',
        'zip_001_is_volume',
        'zip_001_selected_is_first',
        'zip_001_first_path',
        'zip_001_member_count',
        'zip_001_no_missing',
        'bare_001_is_volume',
        'bare_001_selected_is_first',
        'bare_001_first_path',
        'bare_001_member_count',
        'part01_rar_is_volume',
        'part01_rar_selected_is_first',
        'part01_rar_first_path',
        'part01_rar_member_count',
        'part01_rar_no_missing',
        'part10_rar_is_volume',
        'part10_rar_not_first',
        'part10_rar_redirects_to_part01',
        'part10_rar_reports_gap_missing_count',
        'part10_rar_missing_includes_part02',
        'part10_rar_missing_includes_part09',
        'part10_rar_missing_excludes_present_first',
        'part10_rar_missing_excludes_selected',
        'rar_base_is_volume',
        'rar_base_selected_is_first',
        'rar_base_first_path',
        'rar_r00_member_count',
        'rar_r00_member_base',
        'rar_r00_member_r00',
        'rar_r00_member_r01',
        'rar_r00_complete_no_missing',
        'r00_is_volume',
        'r00_not_first',
        'rxx_redirects_and_reports_gap',
        'missing_first_still_volume',
        'missing_first_selected_not_first',
        'missing_first_first_path_derived',
        'missing_first_listed',
        'missing_middle_is_volume',
        'missing_middle_selected_first',
        'missing_middle_lists_002',
        'missing_middle_members_present_only',
        'non_volume_is_false',
        'non_volume_empty_first',
        'non_volume_empty_members',
        'non_volume_empty_missing',
        'non_volume_selected_not_first',
        'solo_001_is_volume',
        'solo_001_is_first',
        'solo_001_first_path',
        'solo_001_one_member',
        'solo_001_no_fabricated_missing',
        'orphan_r00_is_volume',
        'orphan_r00_not_first',
        'orphan_r00_derives_rar_first',
        'orphan_r00_missing_base_rar',
        'orphan_r00_does_not_fabricate_r99'
    )

    foreach ($name in $volumeCases) {
        It "volume case $name PASS" {
            $script:VolResults.ContainsKey($name) | Should Be $true
            $script:VolResults[$name] | Should Be 'PASS'
        }
    }
}
```

- [ ] **Step 2: Run focused volume tests and confirm RED**

Run:

```powershell
$focused = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 `
    -TestName 'ArchiveDiagnosticsVolumes' -PassThru
"Passed=$($focused.PassedCount) Failed=$($focused.FailedCount) Total=$($focused.TotalCount)"
```

Expected RED:
- harness `volumes` mode fails because `DetectVolumeGroup` is not defined (`Error: Call to nonexistent function` on stderr / non-zero exit), **or** every volume case is missing from the result map
- `FailedCount` ≥ 1; record the first failure message before implementing

- [ ] **Step 3: Implement `DetectVolumeGroup` in `lib/ArchiveDiagnostics.ahk`**

Append the following to the end of `lib/ArchiveDiagnostics.ahk` (after `RedactDiagnostic`):

```ahk
DetectVolumeGroup(path, siblingNames) {
    empty := { isVolume: false, firstPath: "", members: [], missingVolumes: [], selectedIsFirst: false }
    if (path = "")
        return empty

    SplitPath(path, &selName, &dir)
    if (selName = "")
        return empty

    names := []
    if (siblingNames is Array) {
        for n in siblingNames {
            if (n != "")
                names.Push(String(n))
        }
    }
    nameSet := Map()
    for n in names
        nameSet[StrLower(n)] := n

    sel := selName
    selLower := StrLower(sel)

    ; Pattern A: name.partNN.rar
    if (RegExMatch(sel, "i)^(.+)\.part(\d+)\.rar$", &mPart)) {
        base := mPart[1]
        width := StrLen(mPart[2])
        selIndex := Integer(mPart[2])
        firstName := base ".part" Format("{:0" width "}", 1) ".rar"
        indices := []
        indexToName := Map()
        for n in names {
            if (RegExMatch(n, "i)^" _VolEscape(base) "\.part(\d+)\.rar$", &mm)) {
                idx := Integer(mm[1])
                indices.Push(idx)
                indexToName[idx] := n
            }
        }
        if (!indexToName.Has(selIndex)) {
            indices.Push(selIndex)
            indexToName[selIndex] := sel
        }
        return _VolBuildNumericGroup(dir, firstName, sel, selIndex, 1, indices, indexToName)
    }

    ; Pattern B: name.rNN (old-style RAR volumes; base is name.rar)
    if (RegExMatch(sel, "i)^(.+)\.r(\d+)$", &mR) && !(selLower ~= "i)\.rar$")) {
        base := mR[1]
        width := StrLen(mR[2])
        selIndex := Integer(mR[2]) + 1  ; r00 => index 1 (second volume); rar base is index 0
        firstName := base ".rar"
        indices := []
        indexToName := Map()
        if (nameSet.Has(StrLower(firstName))) {
            indices.Push(0)
            indexToName[0] := nameSet[StrLower(firstName)]
        } else {
            ; still record expected first even if missing
        }
        for n in names {
            if (RegExMatch(n, "i)^" _VolEscape(base) "\.r(\d+)$", &mm)) {
                idx := Integer(mm[1]) + 1
                indices.Push(idx)
                indexToName[idx] := n
            }
        }
        if (!indexToName.Has(selIndex)) {
            indices.Push(selIndex)
            indexToName[selIndex] := sel
        }
        ; selectedIsFirst is never true for .rNN
        members := []
        missing := []
        if (!nameSet.Has(StrLower(firstName)))
            missing.Push(firstName)
        maxIndex := selIndex
        for idx in indices
            if (idx > maxIndex)
                maxIndex := idx
        idx := 1
        while (idx <= maxIndex) {
            if !indexToName.Has(idx)
                missing.Push(base ".r" Format("{:0" width "}", idx - 1))
            idx++
        }
        ; present members sorted: base (0) then r00,r01,...
        if (indexToName.Has(0))
            members.Push(dir "\" indexToName[0])
        sortedExtra := []
        for n in names {
            if (RegExMatch(n, "i)^" _VolEscape(base) "\.r(\d+)$", &mm))
                sortedExtra.Push([Integer(mm[1]), n])
        }
        ; sort by r-number ascending (simple insertion)
        i := 1
        while (i <= sortedExtra.Length) {
            j := i
            while (j > 1 && sortedExtra[j][1] < sortedExtra[j - 1][1]) {
                tmp := sortedExtra[j - 1]
                sortedExtra[j - 1] := sortedExtra[j]
                sortedExtra[j] := tmp
                j--
            }
            i++
        }
        for pair in sortedExtra
            members.Push(dir "\" pair[2])
        if (!nameSet.Has(selLower) && sel != "")
        {
            ; ensure selected path appears if not in siblings list
            foundSel := false
            for mem in members {
                SplitPath(mem, &mn)
                if (StrLower(mn) = selLower) {
                    foundSel := true
                    break
                }
            }
            if (!foundSel)
                members.Push(dir "\" sel)
        }
        return {
            isVolume: true,
            firstPath: dir "\" firstName,
            members: members,
            missingVolumes: missing,
            selectedIsFirst: false
        }
    }

    ; Pattern C: name.rar that has sibling name.r00 or is alone but we only mark volume if rXX siblings exist
    if (RegExMatch(sel, "i)^(.+)\.rar$", &mBase) && !(selLower ~= "i)\.part\d+\.rar$")) {
        base := mBase[1]
        hasR := false
        for n in names {
            if (RegExMatch(n, "i)^" _VolEscape(base) "\.r(\d+)$")) {
                hasR := true
                break
            }
        }
        if (hasR) {
            firstName := base ".rar"
            members := []
            if (nameSet.Has(StrLower(firstName)))
                members.Push(dir "\" nameSet[StrLower(firstName)])
            else
                members.Push(dir "\" firstName)
            sortedExtra := []
            for n in names {
                if (RegExMatch(n, "i)^" _VolEscape(base) "\.r(\d+)$", &mm))
                    sortedExtra.Push([Integer(mm[1]), n])
            }
            i := 1
            while (i <= sortedExtra.Length) {
                j := i
                while (j > 1 && sortedExtra[j][1] < sortedExtra[j - 1][1]) {
                    tmp := sortedExtra[j - 1]
                    sortedExtra[j - 1] := sortedExtra[j]
                    sortedExtra[j] := tmp
                    j--
                }
                i++
            }
            maxR := -1
            for pair in sortedExtra {
                members.Push(dir "\" pair[2])
                if (pair[1] > maxR)
                    maxR := pair[1]
            }
            missing := []
            if (!nameSet.Has(StrLower(firstName)))
                missing.Push(firstName)
            if (maxR >= 0) {
                r := 0
                while (r <= maxR) {
                    rn := base ".r" Format("{:02}", r)
                    ; keep original width if siblings use 2 digits; Format 02 matches r00 style
                    if (!nameSet.Has(StrLower(rn))) {
                        ; also try without forcing width from observed sibling
                        foundWidth := false
                        for n in names {
                            if (RegExMatch(n, "i)^" _VolEscape(base) "\.r(\d+)$", &mm) && Integer(mm[1]) = r) {
                                foundWidth := true
                                break
                            }
                        }
                        if (!foundWidth)
                            missing.Push(base ".r" Format("{:02}", r))
                    }
                    r++
                }
            }
            return {
                isVolume: true,
                firstPath: dir "\" firstName,
                members: members,
                missingVolumes: missing,
                selectedIsFirst: true
            }
        }
    }

    ; Pattern D: name.ext.NNN  (e.g. .7z.001, .zip.001) OR bare name.NNN (name.001)
    if (RegExMatch(sel, "i)^(.+)\.(\d+)$", &mNum)) {
        stem := mNum[1]          ; may include .7z / .zip or plain stem
        digits := mNum[2]
        width := StrLen(digits)
        selIndex := Integer(digits)
        firstName := stem "." Format("{:0" width "}", 1)
        indices := []
        indexToName := Map()
        for n in names {
            if (RegExMatch(n, "i)^" _VolEscape(stem) "\.(\d+)$", &mm) && StrLen(mm[1]) = width) {
                idx := Integer(mm[1])
                indices.Push(idx)
                indexToName[idx] := n
            }
        }
        if (!indexToName.Has(selIndex)) {
            indices.Push(selIndex)
            indexToName[selIndex] := sel
        }
        return _VolBuildNumericGroup(dir, firstName, sel, selIndex, 1, indices, indexToName)
    }

    return empty
}

_VolEscape(s) {
    out := ""
    Loop Parse s {
        ch := A_LoopField
        if (InStr("\.\+\*\?\[\]\(\)\{\}\^\$\|", ch))
            out .= "\" ch
        else
            out .= ch
    }
    return out
}

_VolBuildNumericGroup(dir, firstName, selName, selIndex, firstIndex, indices, indexToName) {
    nameSet := Map()
    for idx, n in indexToName
        nameSet[StrLower(n)] := n

    ; unique sort indices
    uniq := []
    seen := Map()
    for idx in indices {
        if (!seen.Has(idx)) {
            seen[idx] := true
            uniq.Push(idx)
        }
    }
    i := 1
    while (i <= uniq.Length) {
        j := i
        while (j > 1 && uniq[j] < uniq[j - 1]) {
            tmp := uniq[j - 1]
            uniq[j - 1] := uniq[j]
            uniq[j] := tmp
            j--
        }
        i++
    }

    maxIndex := uniq.Length ? uniq[uniq.Length] : selIndex
    if (selIndex > maxIndex)
        maxIndex := selIndex

    width := 0
    if (RegExMatch(firstName, "\.(\d+)$", &mw))
        width := StrLen(mw[1])
    if (width = 0)
        width := 3

    stem := ""
    if (RegExMatch(firstName, "i)^(.+)\.(\d+)$", &ms))
        stem := ms[1]

    members := []
    missing := []
    idx := firstIndex
    while (idx <= maxIndex) {
        nm := stem "." Format("{:0" width "}", idx)
        if (indexToName.Has(idx)) {
            members.Push(dir "\" indexToName[idx])
        } else if (idx != selIndex) {
            missing.Push(nm)
        } else {
            members.Push(dir "\" selName)
        }
        idx++
    }

    return {
        isVolume: true,
        firstPath: dir "\" firstName,
        members: members,
        missingVolumes: missing,
        selectedIsFirst: (selIndex = firstIndex)
    }
}
```

Implementation notes the implementer must respect (not optional):
- Do **not** invent missing names beyond the contiguous range from first index through the highest observed index in the group.
- For a lone `*.001` / `*.part01.rar` with no higher siblings, `missingVolumes` is empty (no fabricated `.002`).
- For `part01` + `part10` only, max observed is 10 → missing includes `part02`..`part09` only.
- Case-insensitive sibling matching; preserve original sibling casing in outputs via the `nameSet` / `indexToName` maps.

- [ ] **Step 4: Run focused GREEN + full Task 1+2 suite + static 69**

Run:

```powershell
$vol = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 `
    -TestName 'ArchiveDiagnosticsVolumes' -PassThru
"VOL Passed=$($vol.PassedCount) Failed=$($vol.FailedCount) Total=$($vol.TotalCount)"
if ($vol.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=68 (1 harness-exit + 67 volume cases), FailedCount=0

$allDiag = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
"DIAG Passed=$($allDiag.PassedCount) Failed=$($allDiag.FailedCount) Total=$($allDiag.TotalCount)"
if ($allDiag.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=140 (72 classify-suite + 68 volumes), FailedCount=0

$static = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
"STATIC Passed=$($static.PassedCount) Failed=$($static.FailedCount) Total=$($static.TotalCount)"
if ($static.PassedCount -ne 69 -or $static.FailedCount -ne 0) { exit 1 }
```

Expected GREEN:
- volumes focused `Passed=68 Failed=0 Total=68`
- full diagnostics `Passed=140 Failed=0 Total=140`
- static `Passed=69 Failed=0 Total=69`

- [ ] **Step 5: `git diff --check` and focused commit**

Run:

```powershell
git add -- lib/ArchiveDiagnostics.ahk tests/ArchiveDiagnostics.Harness.ahk tests/ArchiveDiagnostics.Tests.ps1
git diff --check --cached
git diff --cached --stat
git commit -m "feat: detect 7z/zip/rar multi-volume groups"
```

Expected: no whitespace errors; only the three diagnostics files change; classifier cases remain green.

- [ ] **Step 6: Independent read-only review gate**

Dispatch a fresh read-only reviewer on this task’s commit only. Require verification against design §7 and Canonical Interfaces:

- all six pattern families work: `.7z.001`, `.zip.001`, bare `.001`, `.part01.rar`, `.part10.rar`, `.rar`+`.r00`
- non-first selection sets `selectedIsFirst=false` and `firstPath` to the derived first volume
- missing first volume is listed in `missingVolumes` without crashing
- missing middle volumes are listed when the contiguous max index is known
- no fabricated members beyond the observed max index (orphan `r00` does not invent `r99`)
- Task 1 classify/redaction assertions still 72/72; static 69/69

Require:

```text
Critical=0
Important=0
```

If non-zero: fix only volume detection + its tests, re-run Step 4–5, re-review. Task 2 is incomplete until both counts are zero.

### Task 3: Full-Output 7-Zip Capture Without Early Process Killing

**Files:**
- Modify: `SmartZip.ahk` — insert new method `RunCmdCapture` immediately **before** existing `RunCmd` (currently ~line 1275, after `IsArchive` ends ~line 1273; anchors: start marker `` `n    RunCmd(CmdLine`` / end of `IsArchive`)
- Create: `tests/RunCmdCapture.Harness.ahk` — behavioral harness exercising `SmartZip.RunCmdCapture` against `cmd.exe` (no 7-Zip required for the unit path; optional real-7z probe when present)
- Create: `tests/RunCmdCapture.Tests.ps1` — Pester 3.4 wrapper for the harness
- Modify: `tests/SmartZip.Static.Tests.ps1` — append `Describe 'RunCmdCaptureSafety'` (static structural gates; existing 69 Its must remain)
- Do not modify: `lib/ArchiveDiagnostics.ahk`, volume/classifier harnesses, 7zG GUI path in `Run7z` / `Gui` / PID binding

**Interfaces:**
- Consumes:
  - Existing `SmartZip` instance fields used only for process bookkeeping if needed: none required beyond local locals
  - Existing `RunCmd` / `CheckCMD` remain intact for legacy callers in this task (no call-site migration yet — that is Task 4+)
  - Existing `Run7z` (lines ~1111–1250 region) must keep launching `7zG.exe` for GUI extract and must keep exact-PID / pause / force-end behavior untouched
- Produces (Canonical Interfaces):
  - `SmartZip.RunCmdCapture(cmdLine, codePage := "UTF-8") => Object` with exact properties:
    - `exitCode` (Integer) — real process exit code from `GetExitCodeProcess` (or equivalent); `-1` only if process creation failed
    - `output` (String) — **complete** combined stdout+stderr text after the process exits (no truncation by keyword matchers)
    - `cancelled` (Boolean) — `true` when `exitCode = 255` (7-Zip user cancel convention), else `false`
  - Default `codePage` is `"UTF-8"` (not `"CP0"`)
  - Must **not** call `ProcessClose` based on stdout/stderr keyword matches during capture
  - Must **not** set `this.isCmdReturn` / invoke `CheckCMD` success/error maps during capture
  - May set `this.CMDPID` while running and clear it after wait, but must wait for natural process exit (or external cancel) before reading the final exit code
  - Stdout and stderr both redirected into the capture pipe (same handle wiring pattern as `RunCmd`, without the early-kill callback)

- [ ] **Step 1: Write failing static tests and the behavioral harness/wrapper**

Append to the end of `tests/SmartZip.Static.Tests.ps1` (after the last `Describe` block) exactly:

```powershell
$script:RunCmdBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    RunCmd(CmdLine" -EndMarker "`n    CheckCMD("
$script:RunCmdCaptureBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    RunCmdCapture(" -EndMarker "`n    RunCmd(CmdLine"

Describe 'RunCmdCaptureSafety' {

    It 'RunCmdCapture method exists before RunCmd' {
        [string]::IsNullOrEmpty($script:RunCmdCaptureBody) | Should Be $false
        $script:RunCmdCaptureBody | Should Match 'RunCmdCapture\s*\('
    }

    It 'RunCmdCapture default codePage is UTF-8' {
        $ok = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'RunCmdCapture\s*\(\s*CmdLine\s*,\s*Codepage\s*:=\s*"UTF-8"\s*\)'
        if (-not $ok) {
            $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
                'RunCmdCapture\s*\(\s*\w+\s*,\s*\w+\s*:=\s*"UTF-8"\s*\)'
        }
        $ok | Should Be $true
    }

    It 'RunCmdCapture returns exitCode output and cancelled properties' {
        $ok = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'exitCode'
        $ok2 = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'output'
        $ok3 = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'cancelled'
        ($ok -and $ok2 -and $ok3) | Should Be $true
    }

    It 'RunCmdCapture obtains a real exit code via GetExitCodeProcess' {
        $ok = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'GetExitCodeProcess'
        $ok | Should Be $true
    }

    It 'RunCmdCapture wires both hStdOutput and hStdError to the pipe' {
        $okOut = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'hStdOutput|hPipeW'
        $okErr = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'hStdError|hPipeW'
        # Require two NumPut calls that assign the write pipe (stdout + stderr)
        $puts = [regex]::Matches($script:RunCmdCaptureBody, 'NumPut\(\s*"Ptr"\s*,\s*hPipeW')
        ($puts.Count -ge 2) | Should Be $true
    }

    It 'RunCmdCapture does not ProcessClose on keyword matchers' {
        $hasClose = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'ProcessClose\s*\('
        $hasClose | Should Be $false
    }

    It 'RunCmdCapture does not invoke CheckCMD maps during capture' {
        $ok = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'CheckCMD\s*\('
        $ok | Should Be $false
    }

    It 'RunCmdCapture marks cancelled when exitCode is 255' {
        $ok = Test-Regex -Text $script:RunCmdCaptureBody -Pattern `
            'cancelled\s*:=\s*.*255|255.*cancelled'
        $ok | Should Be $true
    }

    It 'legacy RunCmd method body still exists for compatibility' {
        [string]::IsNullOrEmpty($script:RunCmdBody) | Should Be $false
        $script:RunCmdBody | Should Match 'CreateProcess'
    }

    It 'legacy CheckCMD still early-closes only on its own path' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            '(?s)CheckCMD\(.*?LogAndReturn.*?ProcessClose\(\s*this\.CMDPID\s*\)'
        $ok | Should Be $true
    }

    It 'Run7z still launches 7zG for non-CLI GUI extract' {
        $ok = Test-Regex -Text $script:Run7zBody -Pattern `
            'this\.7zG'
        $ok | Should Be $true
        $ok2 = Test-Regex -Text $script:Run7zBody -Pattern `
            'is7z\s*\?\s*this\.7z\s*:\s*this\.7zG'
        $ok2 | Should Be $true
    }

    It 'Run7z still resets exactPid bind state per task' {
        $ok = Test-Regex -Text $script:Run7zBody -Pattern `
            'this\.exactPid\s*:=\s*false'
        $ok | Should Be $true
    }

    It 'product source still forbids 7zG image-name PID fallback' {
        $bad = Test-Regex -Text $script:SmartZipSource -Pattern `
            'ProcessExist\(\s*["'']7zG\.exe["'']\s*\)'
        $bad | Should Be $false
    }
}
```

Create `tests/RunCmdCapture.Harness.ahk` with exactly:

```ahk
; Behavioral harness for SmartZip.RunCmdCapture (AutoHotkey v2).
; Usage:
;   AutoHotkey64.exe /ErrorStdOut tests\RunCmdCapture.Harness.ahk <outPath>
#Requires AutoHotkey v2.0
#SingleInstance Off
FileEncoding "UTF-8"

outPath := A_Args.Length >= 1 ? A_Args[1] : A_Temp "\RunCmdCapture.Harness.out.txt"

; Load only the method under test by instantiating a minimal shim that copies
; RunCmdCapture from SmartZip after including the product file's dependencies.
; Strategy: #Include SmartZip.ahk would execute top-level Init/Setting — unsafe.
; Instead, define a thin double that hosts an identical RunCmdCapture implementation
; loaded from a extracted include fragment file written beside this harness.

fragPath := A_ScriptDir "\RunCmdCapture.Fragment.ahk"
if !FileExist(fragPath) {
    FileAppend("FAIL fragment_missing expected=[" fragPath "]`r`nSUMMARY passed=0 failed=1`r`n", outPath, "UTF-8")
    ExitApp(1)
}

#Include RunCmdCapture.Fragment.ahk

passCount := 0
failCount := 0
lines := []

AssertEq(actual, expected, name) {
    global passCount, failCount, lines
    if (actual = expected) {
        passCount++
        lines.Push("PASS " name)
    } else {
        failCount++
        lines.Push("FAIL " name " expected=[" expected "] actual=[" actual "]")
    }
}

AssertTrue(cond, name) {
    AssertEq(cond ? "1" : "0", "1", name)
}

AssertContains(hay, needle, name) {
    AssertTrue(InStr(hay, needle) > 0, name)
}

; Host object with CMDPID field expected by the fragment
host := RunCmdCaptureHost()

; 1) Complete stdout capture + real exit code from cmd.exe
cmd1 := A_ComSpec ' /d /c echo HELLO_SMARTZIP_CAPTURE&& exit /b 7'
r1 := host.RunCmdCapture(cmd1, "UTF-8")
AssertEq(r1.exitCode, 7, "capture_exit_code_7")
AssertContains(r1.output, "HELLO_SMARTZIP_CAPTURE", "capture_stdout_complete")
AssertEq(r1.cancelled, false, "capture_not_cancelled_on_7")

; 2) Stderr is also captured (cmd writes to stderr)
cmd2 := A_ComSpec ' /d /c echo ERR_LINE 1>&2&& exit /b 3'
r2 := host.RunCmdCapture(cmd2, "UTF-8")
AssertEq(r2.exitCode, 3, "capture_stderr_exit_3")
AssertContains(r2.output, "ERR_LINE", "capture_stderr_complete")

; 3) Multi-line output is not truncated by keyword-like text
cmd3 := A_ComSpec ' /d /c echo ERROR: Wrong password?&& echo Headers Error&& echo Everything is Ok&& exit /b 2'
r3 := host.RunCmdCapture(cmd3, "UTF-8")
AssertEq(r3.exitCode, 2, "capture_multiline_exit_2")
AssertContains(r3.output, "Wrong password?", "capture_keeps_wrong_password_line")
AssertContains(r3.output, "Headers Error", "capture_keeps_headers_error_line")
AssertContains(r3.output, "Everything is Ok", "capture_keeps_trailing_success_line")

; 4) cancelled flag for exit 255
cmd4 := A_ComSpec ' /d /c exit /b 255'
r4 := host.RunCmdCapture(cmd4, "UTF-8")
AssertEq(r4.exitCode, 255, "capture_exit_255")
AssertEq(r4.cancelled, true, "capture_cancelled_true_on_255")

; 5) Default code page argument accepts UTF-8 (explicit)
cmd5 := A_ComSpec ' /d /c echo UTF8_OK&& exit /b 0'
r5 := host.RunCmdCapture(cmd5)
AssertEq(r5.exitCode, 0, "capture_default_cp_exit_0")
AssertContains(r5.output, "UTF8_OK", "capture_default_cp_output")

; 6) Process should not remain as CMDPID after return
AssertEq(host.CMDPID, 0, "capture_clears_cmdpid")

summary := "SUMMARY passed=" passCount " failed=" failCount
lines.Push(summary)
text := ""
for line in lines
    text .= line "`r`n"
try FileDelete(outPath)
FileAppend(text, outPath, "UTF-8")
ExitApp(failCount > 0 ? 1 : 0)
```

Create `tests/RunCmdCapture.Tests.ps1` with exactly:

```powershell
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
$script:AhkExe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'

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
    $src = Get-SmartZipSourceText
    $body = Get-SourceSlice -Source $src -StartMarker "`n    RunCmdCapture(" -EndMarker "`n    RunCmd(CmdLine"
    if ([string]::IsNullOrEmpty($body)) {
        throw "RunCmdCapture method not found in SmartZip.ahk"
    }
    # Build a host class wrapping the extracted method body.
    # Strip the leading newline and re-indent into class RunCmdCaptureHost.
    $method = $body.TrimStart("`r", "`n")
    # The product method is indented with 4 spaces as a class method; keep as-is inside host class.
    $fragment = @"
#Requires AutoHotkey v2.0

class RunCmdCaptureHost {
    CMDPID := 0

$method
}
"@
    Set-Content -LiteralPath $script:FragmentPath -Value $fragment -Encoding UTF8
}

function Invoke-RunCmdCaptureHarness {
    Export-RunCmdCaptureFragment
    $outFile = Join-Path $env:TEMP ("RunCmdCapture.Harness.{0}.out.txt" -f ([guid]::NewGuid().ToString('N')))
    $args = @('/ErrorStdOut', $script:HarnessPath, $outFile)
    $p = Start-Process -FilePath $script:AhkExe -ArgumentList $args -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput (Join-Path $env:TEMP 'RunCmdCapture.Harness.stdout.txt') `
        -RedirectStandardError (Join-Path $env:TEMP 'RunCmdCapture.Harness.stderr.txt')
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
    return [pscustomobject]@{ ExitCode = $p.ExitCode; Map = $map; OutFile = $outFile }
}

Describe 'RunCmdCaptureBehavior' {
    BeforeAll {
        $script:CapRun = Invoke-RunCmdCaptureHarness
        $script:CapMap = $script:CapRun.Map
    }

    It 'harness exits 0' {
        $script:CapRun.ExitCode | Should Be 0
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
    )

    foreach ($name in $cases) {
        It "behavior $name PASS" {
            $script:CapMap.ContainsKey($name) | Should Be $true
            $script:CapMap[$name] | Should Be 'PASS'
        }
    }
}
```

- [ ] **Step 2: Run focused tests and confirm RED**

Run:

```powershell
$staticFocused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName 'RunCmdCaptureSafety' -PassThru
"STATIC_FOCUSED Passed=$($staticFocused.PassedCount) Failed=$($staticFocused.FailedCount) Total=$($staticFocused.TotalCount)"

$beh = Invoke-Pester -Script .\tests\RunCmdCapture.Tests.ps1 -PassThru
"BEH Passed=$($beh.PassedCount) Failed=$($beh.FailedCount) Total=$($beh.TotalCount)"
```

Expected RED:
- `RunCmdCaptureSafety` → first Its fail because `RunCmdCapture` slice is empty / method missing (`TotalCount=13`, `FailedCount` ≥ 1)
- `RunCmdCaptureBehavior` fails exporting fragment (`RunCmdCapture method not found`) or harness `fragment_missing`
- Do not implement until RED is recorded

- [ ] **Step 3: Implement `RunCmdCapture` in `SmartZip.ahk`**

Locate the blank line immediately before the existing method:

```ahk
    ;https://www.autohotkey.com/boards/viewtopic.php?t=93944
    RunCmd(CmdLine, Codepage := "CP0", fn := "") {
```

Insert the following new method **immediately above** that comment/`RunCmd` block (so static slice markers `` `n    RunCmdCapture(`` … `` `n    RunCmd(CmdLine`` work):

```ahk
    ; Full stdout+stderr capture for classification. Never kills the process on keyword match.
    ; Returns { exitCode, output, cancelled }. Default code page is UTF-8 for 7-Zip -sccUTF-8 output.
    RunCmdCapture(CmdLine, Codepage := "UTF-8") {
        cancelled := false
        exitCode := -1
        sOutput := ""

        DllCall("CreatePipe", "PtrP", &hPipeR := 0, "PtrP", &hPipeW := 0, "Ptr", 0, "Int", 0)
        , DllCall("SetHandleInformation", "Ptr", hPipeW, "Int", 1, "Int", 1)
        , DllCall("SetNamedPipeHandleState", "Ptr", hPipeR, "UIntP", &PIPE_NOWAIT := 1, "Ptr", 0, "Ptr", 0)

        , P8 := (A_PtrSize = 8)
        , SI := Buffer(P8 ? 104 : 68, 0)
        , NumPut("UInt", P8 ? 104 : 68, SI)
        , NumPut("UInt", STARTF_USESTDHANDLES := 0x100, SI, P8 ? 60 : 44)
        , NumPut("Ptr", hPipeW, SI, P8 ? 88 : 60)	; hStdOutput
        , NumPut("Ptr", hPipeW, SI, P8 ? 96 : 64)	; hStdError
        , PI := Buffer(P8 ? 24 : 16, 0)

        if !DllCall("CreateProcess", "Ptr", 0, "Str", CmdLine, "Ptr", 0, "Int", 0, "Int", True
            , "Int", 0x08000000 | DllCall("GetPriorityClass", "Ptr", -1, "UInt"), "Int", 0
            , "Ptr", 0, "Ptr", SI.ptr, "Ptr", PI.ptr) {
            DllCall("CloseHandle", "Ptr", hPipeW)
            DllCall("CloseHandle", "Ptr", hPipeR)
            return { exitCode: -1, output: "", cancelled: false }
        }

        DllCall("CloseHandle", "Ptr", hPipeW)
        hProcess := NumGet(PI, 0, "Ptr")
        hThread := NumGet(PI, A_PtrSize, "Ptr")
        this.CMDPID := NumGet(PI, P8 ? 16 : 8, "UInt")

        enc := Codepage
        if (enc = "UTF-8" || enc = "utf-8")
            enc := "UTF-8"
        File := FileOpen(hPipeR, "h", enc)

        ; Read until the process exits; never ProcessClose on output content.
        loop {
            still := DllCall("PeekNamedPipe", "Ptr", hPipeR, "Ptr", 0, "Int", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0)
            while !File.AtEOF {
                chunk := File.Read(4096)
                if (chunk != "")
                    sOutput .= chunk
                else
                    break
            }
            if !DllCall("WaitForSingleObject", "Ptr", hProcess, "UInt", 15) {
                ; drain remaining bytes after exit
                while !File.AtEOF {
                    chunk := File.Read(4096)
                    if (chunk != "")
                        sOutput .= chunk
                    else
                        break
                }
                break
            }
            if !still && !DllCall("WaitForSingleObject", "Ptr", hProcess, "UInt", 0) {
                break
            }
        }

        if !DllCall("GetExitCodeProcess", "Ptr", hProcess, "UIntP", &ec := 0)
            exitCode := -1
        else
            exitCode := Integer(ec)

        DllCall("CloseHandle", "Ptr", hProcess)
        DllCall("CloseHandle", "Ptr", hThread)
        DllCall("CloseHandle", "Ptr", hPipeR)
        this.CMDPID := 0

        cancelled := (exitCode = 255)
        return { exitCode: exitCode, output: sOutput, cancelled: cancelled }
    }

```

Hard constraints for this insertion:
- Do **not** edit `RunCmd`, `CheckCMD`, `CheckEncrypted`, `Run7z`, `Gui`, `ButtonPause`, or `Close(*)` bodies in this task
- Do **not** change `IsSuccess` yet (Task 5)
- Do **not** switch Unzip probe/test call sites to `RunCmdCapture` yet (Task 4)
- Preserve all existing 7zG progress/pause/exact-PID behavior by leaving those regions byte-for-byte identical

- [ ] **Step 4: Run focused GREEN, full static suite, diagnostics suite, and capture behavior suite**

Run:

```powershell
$staticFocused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName 'RunCmdCaptureSafety' -PassThru
"STATIC_FOCUSED Passed=$($staticFocused.PassedCount) Failed=$($staticFocused.FailedCount) Total=$($staticFocused.TotalCount)"
if ($staticFocused.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=13, FailedCount=0

$static = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
"STATIC Passed=$($static.PassedCount) Failed=$($static.FailedCount) Total=$($static.TotalCount)"
if ($static.PassedCount -ne 82 -or $static.FailedCount -ne 0) { exit 1 }
# Expected: 69 legacy + 13 RunCmdCaptureSafety = 82

$beh = Invoke-Pester -Script .\tests\RunCmdCapture.Tests.ps1 -PassThru
"BEH Passed=$($beh.PassedCount) Failed=$($beh.FailedCount) Total=$($beh.TotalCount)"
if ($beh.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=15 (1 harness-exit + 14 behavior cases), FailedCount=0

$diag = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
"DIAG Passed=$($diag.PassedCount) Failed=$($diag.FailedCount) Total=$($diag.TotalCount)"
if ($diag.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=140, FailedCount=0 (Tasks 1–2 unchanged)
```

Expected GREEN gates (all required):
- static focused `13/13`
- full static `Passed=82 Failed=0 Total=82`
- RunCmdCapture behavior `Passed=15 Failed=0 Total=15`
- ArchiveDiagnostics `Passed=140 Failed=0 Total=140`

- [ ] **Step 5: `git diff --check` and focused commit**

Run:

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1 `
    tests/RunCmdCapture.Harness.ahk tests/RunCmdCapture.Tests.ps1
# Fragment is generated at test-time; do not commit it if produced under tests/
if (Test-Path .\tests\RunCmdCapture.Fragment.ahk) {
    git status --porcelain -- tests/RunCmdCapture.Fragment.ahk
    # Ensure fragment is untracked or gitignored; do not git add it
}
git diff --check --cached
git diff --cached --stat
git commit -m "feat: capture full 7-Zip output without early process kill"
```

Expected: no whitespace errors; commit contains `SmartZip.ahk` + the three test files listed; no accidental fragment commit; `Run7z`/GUI/PID hunks absent from the diff.

Verify 7zG preservation explicitly (after the commit lands on HEAD):

```powershell
git show --stat --oneline HEAD
git show HEAD -- SmartZip.ahk | Select-String -Pattern '^\+\s*RunCmdCapture|^\-\s*.*Run7z|^\+\s*.*Run7z|^\-\s*.*exactPid|^\+\s*.*exactPid|^\-\s*.*ButtonPause|^\+\s*.*ButtonPause'
```

Expected: only additions for `RunCmdCapture`; zero deletions/changes inside `Run7z` / GUI pause paths.

- [ ] **Step 6: Independent read-only review gate**

Dispatch a fresh read-only reviewer against this task’s commit. Require verification that:

- `RunCmdCapture(cmdLine, codePage := "UTF-8")` matches Canonical Interfaces and returns `{ exitCode, output, cancelled }`
- capture waits for process exit and uses `GetExitCodeProcess` (no keyword-triggered `ProcessClose` in the new method)
- stdout and stderr both feed the captured `output`
- `cancelled` is true only for exit code 255
- legacy `RunCmd` + `CheckCMD` early-close path still exists (compatibility) but is not used by `RunCmdCapture`
- `Run7z` still selects `7zG` for GUI extract; exact-PID rules and pause/force-end gates are unchanged
- static `82/82`, behavior `15/15`, diagnostics `140/140`

Require:

```text
Critical=0
Important=0
```

If non-zero: fix only `RunCmdCapture` + its tests, re-run Step 4–5, re-review. Task 3 is incomplete until both counts are zero.

### Task 4: Preflight, Password Resolution, and State-Machine Entry

**Files:**
- Modify: `SmartZip.ahk` — add `#Include lib\ArchiveDiagnostics.ahk` immediately before `class SmartZip`; insert methods `ProbeArchive`, `TestArchive`, `BuildPasswordCandidates`, `ResolveArchivePassword`, `ShowPasswordDialog`, `RememberPassword` immediately **after** `IsArchive` ends (~line 1273) and **before** `RunCmdCapture` (Task 3); rewrite only the **preflight / password** portion of nested `zipx(path)` inside `Unzip` (from the probe/`CheckEncrypted` loop through password discovery, **before** `Run7z` extract) to call the new API; promote clipboard formatting to class method `FormatPassword` (same body as the nested one-liner) so candidate building can call it
- Create: `tests/PasswordPreflight.Harness.ahk` — behavioral harness for candidates, non-password short-circuit, and classification wiring via a host double
- Create: `tests/PasswordPreflight.Tests.ps1` — Pester 3.4 wrapper (exports method fragment from `SmartZip.ahk` like Task 3)
- Modify: `tests/SmartZip.Static.Tests.ps1` — append `Describe 'PasswordPreflightSafety'` (existing 82 Its from Tasks 0–3 must remain green)
- Do not modify: `lib/ArchiveDiagnostics.ahk` classifier/volume logic, `RunCmdCapture` body, `Run7z` / GUI pause / exact-PID paths, `IsSuccess` size heuristic (Task 5), partial-output dirs (Task 5), settings migration / `successPercent` deprecation (Task 6), diagnostic window (Task 7)

**Interfaces:**
- Consumes:
  - Task 1: `ArchiveStatus`, `ArchiveResult`, `Classify7zResult(stage, exitCode, output, archivePath := "") => ArchiveResult`, `RedactDiagnostic(text, includeFullPath := true) => String`
  - Task 3: `SmartZip.RunCmdCapture(cmdLine, codePage := "UTF-8") => { exitCode, output, cancelled }`
  - Existing instance fields: `this.7z`, `this.cmdLog`, `this.testLog`, `this.log` / `this.Loging`, `this.dynamicPassSort`, `this.autoAddPass`, `this.addDir2Pass`, `this.password`, `this.dynamicPassArr`, `this.passwordMap`, `ini.lastPass`
- Produces (Canonical Interfaces + Task 4 dialog helper):
  - `SmartZip.ProbeArchive(path) => ArchiveResult`
    - stage always `"probe"`
    - command shape (exact tokens): `this.7z ' l -slt -bso1 -bse1 -bsp0 -sccUTF-8 "' path '"'`
    - runs via `RunCmdCapture(..., "UTF-8")` then `Classify7zResult("probe", cap.exitCode, cap.output, path)`
    - if `cmdLog` is on, append only `RedactDiagnostic(cmd)` to `testLog` (never raw `-p` secrets; probe has no password arg)
  - `SmartZip.TestArchive(path, password := "") => ArchiveResult`
    - stage always `"test"`
    - command shape: `this.7z ' t -bso1 -bse1 -bsp0 -sccUTF-8 -p"' password '" "' path '"'` (empty password still emits `-p""` once)
    - runs via `RunCmdCapture` + `Classify7zResult("test", ...)`
    - on `OK` or `OK_WITH_WARNING` only: set `result.passwordUsed := password` (memory only)
    - if `cmdLog` is on, log `RedactDiagnostic(cmd)` only — password values must never appear in `testLog` / `log`
  - `SmartZip.BuildPasswordCandidates(path) => Array` of strings, **stable order**, **stable dedupe** (first occurrence wins):
    1. last successful password (`ini.lastPass` when non-empty)
    2. valid clipboard text via `this.FormatPassword(this.GetClipboardText())` when non-empty (`StrLen < 100`, strip newlines, trim); `GetClipboardText()` returns `A_Clipboard` in production and the harness host's `clipText` in tests
    3. saved passwords in dynamic usage order when `dynamicPassSort || autoAddPass` (sort `dynamicPassArr` by count descending without mutating product order until existing `PasswordSort` runs; if dynamic maps are unavailable, fall back to non-empty `this.password` entries)
    4. optional parent directory leaf name when `this.addDir2Pass` is truthy (`SplitPath` parent folder name)
    - Empty string is not part of this returned candidate list.
  - `SmartZip.ResolveArchivePassword(path, probeResult) => ArchiveResult`
    - **No password iteration** when `probeResult.status` is anything other than `NEED_PASSWORD` or `WRONG_PASSWORD` — return `probeResult` unchanged (covers `OK`, `OK_WITH_WARNING`, `HEADER_CORRUPT`, `MISSING_VOLUME`, `NOT_ARCHIVE`, `TRUNCATED`, `DATA_CORRUPT`, `UNSUPPORTED_METHOD`, `CANCELLED`, `IO_ERROR`, `UNKNOWN_ERROR`)
    - When status is `NEED_PASSWORD` or `WRONG_PASSWORD`: first call `TestArchive(path, "")` exactly once as the no-password baseline; if it still returns a password status, iterate `BuildPasswordCandidates(path)` in the four-step order above. Stop and return on first `OK` / `OK_WITH_WARNING`; stop immediately on any **non-password** status; continue only on `NEED_PASSWORD` / `WRONG_PASSWORD`.
    - If all candidates fail with password statuses: show `ShowPasswordDialog(path)`; buttons must be exactly `本次使用`, `使用并保存`, `取消`; Edit control must use `Password` style (masked)
      - `取消` or empty submit → `ArchiveResult(ArchiveStatus.CANCELLED, "password", -1, path)`
      - `本次使用` → `TestArchive` with typed password; on success set `passwordUsed` but do **not** call `RememberPassword` persistence
      - `使用并保存` → `TestArchive`; on success set `passwordUsed` and call `RememberPassword(password)` which preserves current `lastPass` write + `dynamicPassArr` / `passwordMap` / optional `ini.Write` to `password` section (same semantics as today's `AddPass` + existing end-of-batch `PasswordSort` / `autoRemovePass` cleanup — do not reimplement sort/cleanup here, only the save path hooks)
      - A wrong typed password closes this one-shot prompt as a non-clean result; Task 7's `重新输入密码` action explicitly re-enters `ResolveArchivePassword` for another attempt, avoiding an unbounded modal loop.
  - `SmartZip.ShowPasswordDialog(path) => { action, password }` where `action` is `"use"` | `"save"` | `"cancel"`
    - explicit cancel or empty submission → `CANCELLED`; a non-empty submitted password that tests wrong returns the actual `WRONG_PASSWORD` result so diagnostics can offer retry (never relabel it as cancel)
  - `SmartZip.RememberPassword(password) => password` — memory + optional INI save; never logs the value
  - `SmartZip.FormatPassword(str) => String` — same rule as legacy nested helper
  - State-machine **entry** in `Unzip`/`zipx(path)`: replace legacy early-kill `RunCmd(..., CheckEncrypted)` probe loop + password `CheckCMD` walk with:
    1. build sibling names and call `DetectVolumeGroup(path, siblingNames)` before probing; maintain a per-run `processedVolumeFirst` map so one set is processed once
    2. when `isVolume`: normalize to `firstPath`; if `missingVolumes` is non-empty or the first file is absent, return a `MISSING_VOLUME` result with `volumeFirst`/`missingVolumes`; when the selected member is non-first and the complete first volume exists, process the normalized first path once; never authorize deletion of any member
    3. `probe := this.ProbeArchive(normalizedPath)` and merge any group `volumeFirst`/`missingVolumes` into the result
    4. `resolved := this.ResolveArchivePassword(normalizedPath, probe)`
    5. if `resolved.status` is not `OK` and not `OK_WITH_WARNING` → do not call `Run7z`; leave source and every volume untouched
    6. if clean enough to extract → build `pass` arg from `resolved.passwordUsed` only when non-empty, then keep existing `Run7z` call for this task (full-test/success/delete gates are Task 5)
  - Automatic password tries must **not** spawn 7zG password UI; only `ShowPasswordDialog` is SmartZip-owned UI after candidates exhaust

- [ ] **Step 1: Write failing static tests and the behavioral harness/wrapper**

Append to the end of `tests/SmartZip.Static.Tests.ps1` (after `Describe 'RunCmdCaptureSafety'`) exactly:

```powershell
$script:ProbeArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    ProbeArchive(" -EndMarker "`n    TestArchive("
$script:TestArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    TestArchive(" -EndMarker "`n    BuildPasswordCandidates("
$script:BuildPasswordCandidatesBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    BuildPasswordCandidates(" -EndMarker "`n    ResolveArchivePassword("
$script:ResolveArchivePasswordBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    ResolveArchivePassword(" -EndMarker "`n    ShowPasswordDialog("
$script:ShowPasswordDialogBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    ShowPasswordDialog(" -EndMarker "`n    RememberPassword("
$script:RememberPasswordBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    RememberPassword(" -EndMarker "`n    FormatPassword("
$script:FormatPasswordBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    FormatPassword(" -EndMarker "`n    RunCmdCapture("

Describe 'PasswordPreflightSafety' {

    It 'includes ArchiveDiagnostics library before class SmartZip' {
        $ok = Test-Regex -Text $script:SmartZipSource -Pattern `
            '(?m)^#Include\s+lib\\ArchiveDiagnostics\.ahk\s*$'
        $ok | Should Be $true
        $inc = $script:SmartZipSource.IndexOf('#Include lib\ArchiveDiagnostics.ahk')
        $cls = $script:SmartZipSource.IndexOf('class SmartZip')
        ($inc -ge 0 -and $cls -gt $inc) | Should Be $true
    }

    It 'ProbeArchive method exists before TestArchive' {
        [string]::IsNullOrEmpty($script:ProbeArchiveBody) | Should Be $false
        $script:ProbeArchiveBody | Should Match 'ProbeArchive\s*\('
    }

    It 'TestArchive method exists with default empty password' {
        [string]::IsNullOrEmpty($script:TestArchiveBody) | Should Be $false
        $ok = Test-Regex -Text $script:TestArchiveBody -Pattern `
            'TestArchive\s*\(\s*\w+\s*,\s*\w+\s*:=\s*""\s*\)'
        $ok | Should Be $true
    }

    It 'BuildPasswordCandidates and ResolveArchivePassword methods exist' {
        [string]::IsNullOrEmpty($script:BuildPasswordCandidatesBody) | Should Be $false
        [string]::IsNullOrEmpty($script:ResolveArchivePasswordBody) | Should Be $false
    }

    It 'ShowPasswordDialog has exact buttons 本次使用 使用并保存 取消' {
        $b = $script:ShowPasswordDialogBody
        [string]::IsNullOrEmpty($b) | Should Be $false
        ($b -match '本次使用') | Should Be $true
        ($b -match '使用并保存') | Should Be $true
        ($b -match '取消') | Should Be $true
    }

    It 'ShowPasswordDialog masks password Edit with Password style' {
        $ok = Test-Regex -Text $script:ShowPasswordDialogBody -Pattern `
            'AddEdit\([^\)]*Password'
        $ok | Should Be $true
    }

    It 'ProbeArchive uses RunCmdCapture and Classify7zResult with stage probe' {
        $b = $script:ProbeArchiveBody
        (Test-Regex -Text $b -Pattern 'RunCmdCapture\s*\(') | Should Be $true
        (Test-Regex -Text $b -Pattern 'Classify7zResult\s*\(\s*"probe"') | Should Be $true
        (Test-Regex -Text $b -Pattern 'l\s+-slt') | Should Be $true
        (Test-Regex -Text $b -Pattern '-bso1') | Should Be $true
        (Test-Regex -Text $b -Pattern '-bse1') | Should Be $true
        (Test-Regex -Text $b -Pattern '-bsp0') | Should Be $true
        (Test-Regex -Text $b -Pattern '-sccUTF-8') | Should Be $true
    }

    It 'TestArchive uses RunCmdCapture Classify7zResult stage test and -p' {
        $b = $script:TestArchiveBody
        (Test-Regex -Text $b -Pattern 'RunCmdCapture\s*\(') | Should Be $true
        (Test-Regex -Text $b -Pattern 'Classify7zResult\s*\(\s*"test"') | Should Be $true
        (Test-Regex -Text $b -Pattern '(?m)\bt\b.*-bso1|-bso1.*\bt\b| '' t ') | Should Be $true
        (Test-Regex -Text $b -Pattern '-p"') | Should Be $true
        (Test-Regex -Text $b -Pattern 'passwordUsed') | Should Be $true
    }

    It 'cmdLog paths redact diagnostics and never concatenate raw password into log' {
        $combined = $script:ProbeArchiveBody + $script:TestArchiveBody + $script:ResolveArchivePasswordBody + $script:RememberPasswordBody
        (Test-Regex -Text $combined -Pattern 'RedactDiagnostic\s*\(') | Should Be $true
        # Forbid obvious secret leakage patterns in new preflight methods
        $bad = Test-Regex -Text $combined -Pattern 'Loging\([^\)]*-p"''\s*\w+'
        $bad | Should Be $false
        $bad2 = Test-Regex -Text $combined -Pattern 'testLog\s*\.=\s*[^\n]*password[^\n]*"'
        $bad2 | Should Be $false
    }

    It 'ResolveArchivePassword short-circuits non-password statuses without TestArchive loop' {
        $b = $script:ResolveArchivePasswordBody
        # Must mention NEED_PASSWORD and WRONG_PASSWORD as the only entry to iteration
        (Test-Regex -Text $b -Pattern 'NEED_PASSWORD') | Should Be $true
        (Test-Regex -Text $b -Pattern 'WRONG_PASSWORD') | Should Be $true
        (Test-Regex -Text $b -Pattern 'BuildPasswordCandidates\s*\(') | Should Be $true
        (Test-Regex -Text $b -Pattern 'ShowPasswordDialog\s*\(') | Should Be $true
        (Test-Regex -Text $b -Pattern 'CANCELLED') | Should Be $true
    }

    It 'BuildPasswordCandidates orders non-empty candidates and Resolve tests empty once' {
        $b = $script:BuildPasswordCandidatesBody
        $r = $script:ResolveArchivePasswordBody
        (Test-Regex -Text $b -Pattern 'lastPass') | Should Be $true
        (Test-Regex -Text $b -Pattern 'FormatPassword\s*\(\s*this\.GetClipboardText\s*\(\s*\)\s*\)') | Should Be $true
        (Test-Regex -Text $b -Pattern 'dynamicPassArr|password') | Should Be $true
        (Test-Regex -Text $b -Pattern 'addDir2Pass') | Should Be $true
        # Empty is excluded from candidates and tested only by ResolveArchivePassword.
        (Test-Regex -Text $b -Pattern 'Push\(\s*""\s*\)|add\(\s*""\s*\)|candidates\.Push\(\s*""\s*\)') | Should Be $false
        (Test-Regex -Text $r -Pattern 'TestArchive\s*\(\s*path\s*,\s*""\s*\)') | Should Be $true
    }

    It 'RememberPassword updates lastPass and dynamic maps without logging the secret' {
        $b = $script:RememberPasswordBody
        [string]::IsNullOrEmpty($b) | Should Be $false
        (Test-Regex -Text $b -Pattern 'lastPass') | Should Be $true
        (Test-Regex -Text $b -Pattern 'passwordMap|dynamicPassArr') | Should Be $true
        (Test-Regex -Text $b -Pattern 'Loging\s*\([^\)]*password') | Should Be $false
    }

    It 'Unzip zipx entry calls ProbeArchive and ResolveArchivePassword' {
        $u = $script:UnzipBody
        (Test-Regex -Text $u -Pattern 'ProbeArchive\s*\(') | Should Be $true
        (Test-Regex -Text $u -Pattern 'ResolveArchivePassword\s*\(') | Should Be $true
        # Legacy early-kill encrypted probe callback must no longer be the primary entry
        (Test-Regex -Text $u -Pattern 'CheckEncrypted') | Should Be $false
    }

    It 'RunCmdCapture still precedes RunCmd after password methods' {
        $src = $script:SmartZipSource
        $p = $src.IndexOf("`n    ProbeArchive(")
        $c = $src.IndexOf("`n    RunCmdCapture(")
        $r = $src.IndexOf("`n    RunCmd(CmdLine")
        ($p -ge 0 -and $c -gt $p -and $r -gt $c) | Should Be $true
    }
}
```

Create `tests/PasswordPreflight.Harness.ahk` with exactly:

```ahk
; Behavioral harness for password preflight helpers (AutoHotkey v2).
; Usage:
;   AutoHotkey64.exe /ErrorStdOut tests\PasswordPreflight.Harness.ahk <outPath>
#Requires AutoHotkey v2.0
#SingleInstance Off
FileEncoding "UTF-8"

outPath := A_Args.Length >= 1 ? A_Args[1] : A_Temp "\PasswordPreflight.Harness.out.txt"

fragPath := A_ScriptDir "\PasswordPreflight.Fragment.ahk"
if !FileExist(fragPath) {
    FileAppend("FAIL fragment_missing expected=[" fragPath "]`r`nSUMMARY passed=0 failed=1`r`n", outPath, "UTF-8")
    ExitApp(1)
}

#Include ..\lib\ArchiveDiagnostics.ahk
#Include PasswordPreflight.Fragment.ahk

passCount := 0
failCount := 0
lines := []

AssertEq(actual, expected, name) {
    global passCount, failCount, lines
    if (actual = expected) {
        passCount++
        lines.Push("PASS " name)
    } else {
        failCount++
        lines.Push("FAIL " name " expected=[" expected "] actual=[" actual "]")
    }
}

AssertTrue(cond, name) {
    AssertEq(cond ? "1" : "0", "1", name)
}

AssertFalse(cond, name) {
    AssertEq(cond ? "1" : "0", "0", name)
}

AssertContains(hay, needle, name) {
    AssertTrue(InStr(hay, needle) > 0, name)
}

AssertNotContains(hay, needle, name) {
    AssertTrue(InStr(hay, needle) = 0, name)
}

JoinCandidates(arr) {
    s := ""
    for c in arr {
        if (s != "")
            s .= "|"
        s .= (c = "" ? "<empty>" : c)
    }
    return s
}

host := PasswordPreflightHost()

; --- BuildPasswordCandidates order/dedupe; empty is tested separately by ResolveArchivePassword ---
host.ResetPasswordState()
host.lastPass := "last-ok"
host.clipText := "clip-pass"
host.dynamicPassSort := true
host.autoAddPass := true
host.addDir2Pass := true
host.dynamicPassArr := [["saved-high", 9], ["saved-low", 1], ["last-ok", 3]]
host.passwordMap := Map("saved-high", 1, "saved-low", 2, "last-ok", 3)
host.password := ["", "last-ok", "clip-pass", "saved-high", "saved-low"]
cands := host.BuildPasswordCandidates("C:\\data\\vault\\secret.7z")
AssertEq(cands[1], "last-ok", "cand_lastpass_first")
AssertEq(cands[2], "clip-pass", "cand_clipboard_second")
; saved dynamic order: higher count first, last-ok already present so skipped
AssertEq(cands[3], "saved-high", "cand_saved_dynamic_high_before_low")
AssertEq(cands[4], "saved-low", "cand_saved_dynamic_low")
AssertEq(cands[5], "vault", "cand_parent_dir_last")
AssertEq(cands.Length, 5, "cand_length_no_dupes")
; stable dedupe: last-ok appears only once
joined := JoinCandidates(cands)
AssertEq(joined, "last-ok|clip-pass|saved-high|saved-low|vault", "cand_order_exact")
AssertEq(RegExReplace(joined, "last-ok", "X", 1) = RegExReplace(joined, "last-ok", "X"), true, "cand_last_ok_once")
emptyHits := 0
for c in cands
    if (c = "")
        emptyHits++
AssertEq(emptyHits, 0, "cand_empty_excluded")

; clipboard invalid when too long
host.ResetPasswordState()
host.lastPass := ""
host.clipText := ""
loop 120
    host.clipText .= "x"
host.dynamicPassSort := false
host.autoAddPass := false
host.addDir2Pass := false
host.password := ["", "only-saved"]
cands2 := host.BuildPasswordCandidates("C:\\a.7z")
AssertEq(cands2[1], "only-saved", "cand_long_clip_skipped_uses_saved")
AssertEq(cands2.Length, 1, "cand_long_clip_length")
AssertEq(host.testCalls, 0, "cand_build_does_not_test_empty")

; --- ResolveArchivePassword: no iteration for non-password statuses ---
host.ResetPasswordState()
host.testCalls := 0
for st in [ArchiveStatus.OK, ArchiveStatus.OK_WITH_WARNING, ArchiveStatus.HEADER_CORRUPT,
    ArchiveStatus.MISSING_VOLUME, ArchiveStatus.NOT_ARCHIVE, ArchiveStatus.TRUNCATED,
    ArchiveStatus.DATA_CORRUPT, ArchiveStatus.UNSUPPORTED_METHOD, ArchiveStatus.CANCELLED,
    ArchiveStatus.IO_ERROR, ArchiveStatus.UNKNOWN_ERROR] {
    host.testCalls := 0
    probe := ArchiveResult(st, "probe", 2, "C:\\x.7z", "x")
    r := host.ResolveArchivePassword("C:\\x.7z", probe)
    AssertEq(r.status, st, "resolve_passthrough_" st)
    AssertEq(host.testCalls, 0, "resolve_no_test_calls_" st)
}

; --- NEED_PASSWORD iterates candidates; success sets passwordUsed; logs redact ---
host.ResetPasswordState()
host.lastPass := "wrong1"
host.clipText := "right-pass"
host.dynamicPassSort := false
host.autoAddPass := false
host.addDir2Pass := false
host.password := ["", "wrong1", "right-pass"]
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\e.7z", "ERROR: Wrong password?`n"),
    "wrong1", ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\e.7z", "ERROR: Wrong password?`n"),
    "right-pass", ArchiveResult(ArchiveStatus.OK, "test", 0, "C:\\e.7z", "Everything is Ok`n")
)
probeNeed := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 2, "C:\\e.7z", "Enter password (will not be echoed):`n")
got := host.ResolveArchivePassword("C:\\e.7z", probeNeed)
AssertEq(got.status, ArchiveStatus.OK, "resolve_need_password_success_status")
AssertEq(got.passwordUsed, "right-pass", "resolve_need_password_sets_password_used")
AssertTrue(host.testCalls >= 2, "resolve_need_password_tried_multiple")
AssertNotContains(host.testLog, "right-pass", "resolve_log_hides_password_value")
AssertNotContains(host.testLog, "wrong1", "resolve_log_hides_failed_password_value")
AssertContains(host.testLog, "-p***", "resolve_log_uses_redacted_placeholder")

; --- WRONG_PASSWORD also enters iteration ---
host.ResetPasswordState()
host.lastPass := "good"
host.clipText := ""
host.dynamicPassSort := false
host.autoAddPass := false
host.addDir2Pass := false
host.password := ["", "good"]
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\e.7z", "ERROR: Wrong password?`n"),
    "good", ArchiveResult(ArchiveStatus.OK, "test", 0, "C:\\e.7z", "Everything is Ok`n")
)
probeWrong := ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "probe", 2, "C:\\e.7z", "ERROR: Wrong password?`nHeaders Error`n")
got2 := host.ResolveArchivePassword("C:\\e.7z", probeWrong)
AssertEq(got2.status, ArchiveStatus.OK, "resolve_wrong_password_path_ok")
AssertEq(got2.passwordUsed, "good", "resolve_wrong_password_path_password_used")

; --- TestArchive mid-list non-password status stops iteration ---
host.ResetPasswordState()
host.lastPass := "a"
host.clipText := "b"
host.dynamicPassSort := false
host.autoAddPass := false
host.addDir2Pass := false
host.password := ["", "a", "b"]
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\e.7z", "ERROR: Wrong password?`n"),
    "a", ArchiveResult(ArchiveStatus.HEADER_CORRUPT, "test", 2, "C:\\e.7z", "ERROR: Headers Error`n"),
    "b", ArchiveResult(ArchiveStatus.OK, "test", 0, "C:\\e.7z", "Everything is Ok`n")
)
probeNeed2 := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 2, "C:\\e.7z", "Enter password (will not be echoed):`n")
got3 := host.ResolveArchivePassword("C:\\e.7z", probeNeed2)
AssertEq(got3.status, ArchiveStatus.HEADER_CORRUPT, "resolve_stops_on_non_password_status")
AssertEq(got3.passwordUsed, "", "resolve_non_password_no_password_used")
AssertTrue(host.testCalls <= 2, "resolve_does_not_try_remaining_after_header_corrupt")

; --- ProbeArchive + TestArchive classify via full captured output (scripted RunCmdCapture) ---
host.ResetPasswordState()
host.scriptedCapture := { exitCode: 2, output: "ERROR: Wrong password?`nHeaders Error`n", cancelled: false }
pr := host.ProbeArchive("C:\\enc.7z")
AssertEq(pr.status, ArchiveStatus.WRONG_PASSWORD, "probe_classifies_wrong_password_over_headers")
AssertEq(pr.stage, "probe", "probe_stage_name")
AssertContains(host.lastProbeCmd, "l -slt", "probe_cmd_list_slt")
AssertContains(host.lastProbeCmd, "-bso1", "probe_cmd_bso1")
AssertContains(host.lastProbeCmd, "-bse1", "probe_cmd_bse1")
AssertContains(host.lastProbeCmd, "-bsp0", "probe_cmd_bsp0")
AssertContains(host.lastProbeCmd, "-sccUTF-8", "probe_cmd_utf8")

host.scriptedCapture := { exitCode: 0, output: "Everything is Ok`n", cancelled: false }
tr := host.TestArchive("C:\\enc.7z", "pw")
AssertEq(tr.status, ArchiveStatus.OK, "test_classifies_ok")
AssertEq(tr.stage, "test", "test_stage_name")
AssertEq(tr.passwordUsed, "pw", "test_sets_password_used_on_ok")
AssertContains(host.lastTestCmd, " t ", "test_cmd_uses_t")
AssertContains(host.lastTestCmd, '-p"pw"', "test_cmd_includes_dash_p")
AssertNotContains(host.testLog, "pw", "test_log_redacts_password")

; --- Dialog contract (no GUI pump): ShowPasswordDialog double ---
host.dialogOverride := { action: "cancel", password: "" }
probeNeed3 := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 2, "C:\\e.7z", "Enter password (will not be echoed):`n")
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\e.7z", "ERROR: Wrong password?`n")
)
host.lastPass := ""
host.clipText := ""
host.password := [""]
host.dynamicPassSort := false
host.autoAddPass := false
host.addDir2Pass := false
got4 := host.ResolveArchivePassword("C:\\e.7z", probeNeed3)
host.dialogOverride := { action: "use", password: "typed-wrong" }
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\e.7z", "ERROR: Wrong password?`n"),
    "typed-wrong", ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\e.7z", "ERROR: Wrong password?`n")
)
gotWrong := host.ResolveArchivePassword("C:\\e.7z", probeNeed3)
AssertTrue(got4.status = ArchiveStatus.CANCELLED
    && gotWrong.status = ArchiveStatus.WRONG_PASSWORD,
    "resolve_dialog_cancel_returns_cancelled")

host.dialogOverride := { action: "use", password: "typed-once" }
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\e.7z", "ERROR: Wrong password?`n"),
    "typed-once", ArchiveResult(ArchiveStatus.OK, "test", 0, "C:\\e.7z", "Everything is Ok`n")
)
host.rememberCalls := 0
got5 := host.ResolveArchivePassword("C:\\e.7z", probeNeed3)
AssertEq(got5.status, ArchiveStatus.OK, "resolve_dialog_use_ok")
AssertEq(got5.passwordUsed, "typed-once", "resolve_dialog_use_password_used")
AssertEq(host.rememberCalls, 0, "resolve_dialog_use_does_not_remember")

host.dialogOverride := { action: "save", password: "typed-save" }
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\e.7z", "ERROR: Wrong password?`n"),
    "typed-save", ArchiveResult(ArchiveStatus.OK, "test", 0, "C:\\e.7z", "Everything is Ok`n")
)
host.rememberCalls := 0
got6 := host.ResolveArchivePassword("C:\\e.7z", probeNeed3)
AssertEq(got6.status, ArchiveStatus.OK, "resolve_dialog_save_ok")
AssertEq(got6.passwordUsed, "typed-save", "resolve_dialog_save_password_used")
AssertEq(host.rememberCalls, 1, "resolve_dialog_save_calls_remember")

; --- Static dialog labels are present in product fragment text (exported) ---
fragText := FileRead(fragPath, "UTF-8")
AssertContains(fragText, "本次使用", "dialog_label_use_once")
AssertContains(fragText, "使用并保存", "dialog_label_use_and_save")
AssertContains(fragText, "取消", "dialog_label_cancel")
AssertContains(fragText, "Password", "dialog_edit_password_style")

summary := "SUMMARY passed=" passCount " failed=" failCount
lines.Push(summary)
text := ""
for line in lines
    text .= line "`r`n"
try FileDelete(outPath)
FileAppend(text, outPath, "UTF-8")
ExitApp(failCount > 0 ? 1 : 0)
```

Create `tests/PasswordPreflight.Tests.ps1` with exactly:

```powershell
#requires -Version 5.0
<#
.SYNOPSIS
  Pester 3.4 wrapper for PasswordPreflight.Harness.ahk
#>

$ErrorActionPreference = 'Stop'

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:SmartZipPath = Join-Path $script:RepoRoot 'SmartZip.ahk'
$script:HarnessPath = Join-Path $PSScriptRoot 'PasswordPreflight.Harness.ahk'
$script:FragmentPath = Join-Path $PSScriptRoot 'PasswordPreflight.Fragment.ahk'
$script:AhkExe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'

function Get-SmartZipSourceText {
    $raw = Get-Content -LiteralPath $script:SmartZipPath -Raw -Encoding UTF8
    if ($raw -notmatch 'ProbeArchive|RunCmdCapture|class SmartZip') {
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

function Export-PasswordPreflightFragment {
    $src = Get-SmartZipSourceText
    $startMarker = "`n    ProbeArchive("
    $endMarker = "`n    RunCmdCapture("
    $body = Get-SourceSlice -Source $src -StartMarker $startMarker -EndMarker $endMarker
    if ([string]::IsNullOrEmpty($body)) {
        throw "Password preflight methods not found in SmartZip.ahk (ProbeArchive..RunCmdCapture)"
    }
    $method = $body.TrimStart("`r", "`n")
    $fragment = @"
#Requires AutoHotkey v2.0

; Host double: product methods + scripted capture/test/dialog seams for the harness.
class PasswordPreflightHost {
    7z := "7z.exe"
    cmdLog := true
    testLog := ""
    lastPass := ""
    clipText := ""
    password := [""]
    dynamicPassSort := false
    autoAddPass := false
    addDir2Pass := false
    dynamicPassArr := []
    passwordMap := Map()
    testCalls := 0
    rememberCalls := 0
    scriptedCapture := { exitCode: 0, output: "Everything is Ok``n", cancelled: false }
    scriptedTest := Map()
    dialogOverride := ""
    lastProbeCmd := ""
    lastTestCmd := ""
    CMDPID := 0

    ResetPasswordState() {
        this.testLog := ""
        this.testCalls := 0
        this.rememberCalls := 0
        this.scriptedTest := Map()
        this.dialogOverride := ""
        this.lastProbeCmd := ""
        this.lastTestCmd := ""
        this.lastPass := ""
        this.clipText := ""
        this.password := [""]
        this.dynamicPassSort := false
        this.autoAddPass := false
        this.addDir2Pass := false
        this.dynamicPassArr := []
        this.passwordMap := Map()
    }

    ; Harness seam: clipboard comes from clipText, not real A_Clipboard
    FormatPassword(str) {
        s := (str = "" && this.clipText != "" && arguments.Length = 0) ? this.clipText : str
        ; Product FormatPassword body is extracted below; host overrides to feed clipText when A_Clipboard is empty in tests.
        if (StrLen(str) = 0 && this.HasProp("clipText"))
            str := this.clipText
        return StrLen(str) < 100 ? Trim(RegExReplace(str, "(\R*)")) : ""
    }

    RunCmdCapture(CmdLine, Codepage := "UTF-8") {
        this.lastProbeCmd := CmdLine
        this.lastTestCmd := CmdLine
        if this.cmdLog
            this.testLog .= "``n#####``n" RedactDiagnostic(CmdLine) "``n"
        return this.scriptedCapture
    }

    ; Override TestArchive after product methods are mixed in — see post-merge below.
$method
}

; Re-bind harness-controlled TestArchive / ShowPasswordDialog / RememberPassword around product logic:
; The exported product methods call this.RunCmdCapture / Classify7zResult / BuildPasswordCandidates.
; For candidate iteration tests, wrap TestArchive to honor scriptedTest map when set.

class PasswordPreflightHost extends PasswordPreflightHost {
}
"@
    # Intermediate construction string only; it is overwritten below and never emitted.
    $fragment = @"
#Requires AutoHotkey v2.0

class PasswordPreflightHost {
    7z := "7z.exe"
    cmdLog := true
    testLog := ""
    lastPass := ""
    clipText := ""
    password := [""]
    dynamicPassSort := false
    autoAddPass := false
    addDir2Pass := false
    dynamicPassArr := []
    passwordMap := Map()
    testCalls := 0
    rememberCalls := 0
    scriptedCapture := { exitCode: 0, output: "Everything is Ok``n", cancelled: false }
    scriptedTest := Map()
    dialogOverride := ""
    lastProbeCmd := ""
    lastTestCmd := ""
    CMDPID := 0
    useScriptedTest := false

    ResetPasswordState() {
        this.testLog := ""
        this.testCalls := 0
        this.rememberCalls := 0
        this.scriptedTest := Map()
        this.dialogOverride := ""
        this.lastProbeCmd := ""
        this.lastTestCmd := ""
        this.lastPass := ""
        this.clipText := ""
        this.password := [""]
        this.dynamicPassSort := false
        this.autoAddPass := false
        this.addDir2Pass := false
        this.dynamicPassArr := []
        this.passwordMap := Map()
        this.useScriptedTest := false
    }

    RunCmdCapture(CmdLine, Codepage := "UTF-8") {
        if InStr(CmdLine, " l -slt")
            this.lastProbeCmd := CmdLine
        if InStr(CmdLine, " t ")
            this.lastTestCmd := CmdLine
        if this.cmdLog
            this.testLog .= "``n#####``n" RedactDiagnostic(CmdLine) "``n"
        return this.scriptedCapture
    }

$method
}

; Intermediate harness wrapper exploration; this string is overwritten before Set-Content.

class PasswordPreflightHostHarness extends PasswordPreflightHost {
    FormatPassword(str) {
        if (str = "" || str = A_Clipboard)
            str := this.clipText
        if (str = A_Clipboard)
            str := this.clipText
        return StrLen(str) < 100 ? Trim(RegExReplace(String(str), "(\R*)")) : ""
    }

    BuildPasswordCandidates(path) {
        ; Force clipboard read through clipText for deterministic tests
        savedClip := ""
        try savedClip := A_Clipboard
        try A_Clipboard := this.clipText
        ; Call product implementation if present on super — in AHK v2 call same-name via explicit body.
        ; The exported product BuildPasswordCandidates uses this.FormatPassword(A_Clipboard) and ini.lastPass.
        ; Host maps ini-less lastPass field: temporarily expose lastPass via fake ini object.
        oldIni := ""
        global ini
        if IsSet(ini)
            oldIni := ini
        ini := { lastPass: this.lastPass, Write: (this, v, k, s) => 0, Read: (this, k, d := "", s := "") => d }
        try {
            result := PasswordPreflightHost.Prototype.BuildPasswordCandidates.Call(this, path)
        } finally {
            try A_Clipboard := savedClip
            if (oldIni != "")
                ini := oldIni
        }
        return result
    }

    TestArchive(path, password := "") {
        this.testCalls++
        if this.scriptedTest.Has(password) {
            r := this.scriptedTest[password]
            ; Ensure passwordUsed policy matches product: only OK / OK_WITH_WARNING
            if (r.status = ArchiveStatus.OK || r.status = ArchiveStatus.OK_WITH_WARNING)
                r.passwordUsed := password
            if this.cmdLog {
                cmd := this.7z ' t -bso1 -bse1 -bsp0 -sccUTF-8 -p"' password '" "' path '"'
                this.testLog .= "``n#####``n" RedactDiagnostic(cmd) "``n"
                this.lastTestCmd := cmd
            }
            return r
        }
        return PasswordPreflightHost.Prototype.TestArchive.Call(this, path, password)
    }

    ShowPasswordDialog(path) {
        if IsObject(this.dialogOverride)
            return this.dialogOverride
        return PasswordPreflightHost.Prototype.ShowPasswordDialog.Call(this, path)
    }

    RememberPassword(password) {
        this.rememberCalls++
        return PasswordPreflightHost.Prototype.RememberPassword.Call(this, password)
    }
}

; Alias expected by harness
class PasswordPreflightHost extends PasswordPreflightHostHarness {
}
"@
    # Next construction string; the final emitted single-class fragment follows.
    $fragment = @"
#Requires AutoHotkey v2.0

class PasswordPreflightHost {
    7z := "7z.exe"
    cmdLog := true
    testLog := ""
    lastPass := ""
    clipText := ""
    password := [""]
    dynamicPassSort := false
    autoAddPass := false
    addDir2Pass := false
    dynamicPassArr := []
    passwordMap := Map()
    testCalls := 0
    rememberCalls := 0
    scriptedCapture := { exitCode: 0, output: "Everything is Ok``n", cancelled: false }
    scriptedTest := Map()
    dialogOverride := ""
    lastProbeCmd := ""
    lastTestCmd := ""
    CMDPID := 0

    ResetPasswordState() {
        this.testLog := ""
        this.testCalls := 0
        this.rememberCalls := 0
        this.scriptedTest := Map()
        this.dialogOverride := ""
        this.lastProbeCmd := ""
        this.lastTestCmd := ""
        this.lastPass := ""
        this.clipText := ""
        this.password := [""]
        this.dynamicPassSort := false
        this.autoAddPass := false
        this.addDir2Pass := false
        this.dynamicPassArr := []
        this.passwordMap := Map()
    }

    RunCmdCapture(CmdLine, Codepage := "UTF-8") {
        if InStr(CmdLine, " l -slt")
            this.lastProbeCmd := CmdLine
        if RegExMatch(CmdLine, "\st\s")
            this.lastTestCmd := CmdLine
        if this.cmdLog
            this.testLog .= "``n#####``n" RedactDiagnostic(CmdLine) "``n"
        return this.scriptedCapture
    }

    FormatPassword(str) {
        if (str = A_Clipboard || str = "")
            str := this.clipText != "" ? this.clipText : str
        if (StrLen(this.clipText) && (str = A_Clipboard))
            str := this.clipText
        ; When product code calls FormatPassword(A_Clipboard), A_Clipboard may be empty in harness;
        ; product BuildPasswordCandidates must call this.FormatPassword(A_Clipboard) — harness sets
        ; clipText and overrides as follows:
        if (this.clipText != "" && (str = "" || str = A_Clipboard))
            str := this.clipText
        return StrLen(str) < 100 ? Trim(RegExReplace(String(str), "(\R*)")) : ""
    }

$method

    ; --- harness overrides placed AFTER product methods so they win on the instance class ---
}

; Assemble the final single-class host: product methods plus deterministic harness seams.
"@
    # This is the final fragment assignment consumed by Set-Content below.
    $productMethods = $method
    $fragment = @"
#Requires AutoHotkey v2.0

; Fake ini for lastPass reads/writes inside exported RememberPassword / BuildPasswordCandidates.
global ini := { lastPass: "", Write: IniWriteStub, Read: IniReadStub }
IniWriteStub(this, value := "", key := "", section := "") {
    if (key = "lastPass")
        this.lastPass := value
    return value
}
IniReadStub(this, key := "", default := "", section := "") {
    if (key = "lastPass")
        return this.lastPass
    return default
}

class PasswordPreflightHost {
    7z := "7z.exe"
    cmdLog := true
    testLog := ""
    lastPass := ""
    clipText := ""
    password := [""]
    dynamicPassSort := false
    autoAddPass := false
    addDir2Pass := false
    dynamicPassArr := []
    passwordMap := Map()
    testCalls := 0
    rememberCalls := 0
    scriptedCapture := { exitCode: 0, output: "Everything is Ok``n", cancelled: false }
    scriptedTest := Map()
    dialogOverride := ""
    lastProbeCmd := ""
    lastTestCmd := ""
    CMDPID := 0
    _productTestArchive := ""
    _inScripted := false

    ResetPasswordState() {
        global ini
        this.testLog := ""
        this.testCalls := 0
        this.rememberCalls := 0
        this.scriptedTest := Map()
        this.dialogOverride := ""
        this.lastProbeCmd := ""
        this.lastTestCmd := ""
        this.lastPass := ""
        ini.lastPass := ""
        this.clipText := ""
        this.password := [""]
        this.dynamicPassSort := false
        this.autoAddPass := false
        this.addDir2Pass := false
        this.dynamicPassArr := []
        this.passwordMap := Map()
    }

    RunCmdCapture(CmdLine, Codepage := "UTF-8") {
        if InStr(CmdLine, " l -slt")
            this.lastProbeCmd := CmdLine
        if RegExMatch(CmdLine, "\st\s") || InStr(CmdLine, " t ")
            this.lastTestCmd := CmdLine
        if this.cmdLog
            this.testLog .= "``n#####``n" RedactDiagnostic(CmdLine) "``n"
        return this.scriptedCapture
    }

$productMethods

}

; Patch class methods for harness seams (AHK v2 allows reassignment on prototype after class load).
PasswordPreflightHost.Prototype.DefineProp("FormatPassword", { Call: PasswordPreflight_FormatPassword })
PasswordPreflightHost.Prototype.DefineProp("TestArchive", { Call: PasswordPreflight_TestArchive })
PasswordPreflightHost.Prototype.DefineProp("ShowPasswordDialog", { Call: PasswordPreflight_ShowPasswordDialog })
PasswordPreflightHost.Prototype.DefineProp("RememberPassword", { Call: PasswordPreflight_RememberPassword })

PasswordPreflight_FormatPassword(this, str := "") {
    if (this.clipText != "")
        str := this.clipText
    return StrLen(str) < 100 ? Trim(RegExReplace(String(str), "(\R*)")) : ""
}

PasswordPreflight_TestArchive(this, path, password := "") {
    this.testCalls++
    if this.scriptedTest.Count > 0 {
        if this.scriptedTest.Has(password) {
            r := this.scriptedTest[password]
            if (r.status = ArchiveStatus.OK || r.status = ArchiveStatus.OK_WITH_WARNING)
                r.passwordUsed := password
            else
                r.passwordUsed := ""
            if this.cmdLog {
                cmd := this.7z ' t -bso1 -bse1 -bsp0 -sccUTF-8 -p"' password '" "' path '"'
                this.lastTestCmd := cmd
                this.testLog .= "``n#####``n" RedactDiagnostic(cmd) "``n"
            }
            return r
        }
        ; missing scripted entry => wrong password
        r := ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, path, "ERROR: Wrong password?``n")
        if this.cmdLog {
            cmd := this.7z ' t -bso1 -bse1 -bsp0 -sccUTF-8 -p"' password '" "' path '"'
            this.testLog .= "``n#####``n" RedactDiagnostic(cmd) "``n"
        }
        return r
    }
    ; Fall back to product TestArchive body by temporarily clearing scripted map sentinel
    ; Product method was overwritten — re-extract via stored unbound is unnecessary if scriptedCapture path used:
    cmd := this.7z ' t -bso1 -bse1 -bsp0 -sccUTF-8 -p"' password '" "' path '"'
    if this.cmdLog
        this.testLog .= "``n#####``n" RedactDiagnostic(cmd) "``n"
    this.lastTestCmd := cmd
    cap := this.RunCmdCapture(cmd, "UTF-8")
    result := Classify7zResult("test", cap.exitCode, cap.output, path)
    if (result.status = ArchiveStatus.OK || result.status = ArchiveStatus.OK_WITH_WARNING)
        result.passwordUsed := password
    return result
}

PasswordPreflight_ShowPasswordDialog(this, path) {
    if IsObject(this.dialogOverride)
        return this.dialogOverride
    return { action: "cancel", password: "" }
}

PasswordPreflight_RememberPassword(this, password) {
    this.rememberCalls++
    global ini
    if !password
        return password
    if ini.lastPass != password
        ini.Write(password, "lastPass", "temp")
    this.lastPass := password
    if this.dynamicPassSort || this.autoAddPass {
        if !this.passwordMap.Has(password) {
            this.dynamicPassArr.Push([password, 0])
            this.passwordMap[password] := this.dynamicPassArr.Length
            if this.autoAddPass
                ini.Write(password, this.passwordMap.Count, "password")
        } else
            this.dynamicPassArr[this.passwordMap[password]][2]++
    }
    return password
}

"@
    Set-Content -LiteralPath $script:FragmentPath -Value $fragment -Encoding UTF8
}

function Invoke-PasswordPreflightHarness {
    Export-PasswordPreflightFragment
    $outFile = Join-Path $env:TEMP ("PasswordPreflight.Harness.{0}.out.txt" -f ([guid]::NewGuid().ToString('N')))
    $args = @('/ErrorStdOut', $script:HarnessPath, $outFile)
    $p = Start-Process -FilePath $script:AhkExe -ArgumentList $args -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput (Join-Path $env:TEMP 'PasswordPreflight.Harness.stdout.txt') `
        -RedirectStandardError (Join-Path $env:TEMP 'PasswordPreflight.Harness.stderr.txt')
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
    return [pscustomobject]@{ ExitCode = $p.ExitCode; Map = $map; OutFile = $outFile }
}

Describe 'PasswordPreflightBehavior' {
    BeforeAll {
        $script:PwRun = Invoke-PasswordPreflightHarness
        $script:PwMap = $script:PwRun.Map
    }

    It 'harness exits 0' {
        $script:PwRun.ExitCode | Should Be 0
    }

    $cases = @(
        'cand_lastpass_first',
        'cand_clipboard_second',
        'cand_saved_dynamic_high_before_low',
        'cand_saved_dynamic_low',
        'cand_parent_dir_last',
        'cand_length_no_dupes',
        'cand_order_exact',
        'cand_last_ok_once',
        'cand_empty_excluded',
        'cand_long_clip_skipped_uses_saved',
        'cand_long_clip_length',
        'cand_build_does_not_test_empty',
        'resolve_passthrough_OK',
        'resolve_no_test_calls_OK',
        'resolve_passthrough_OK_WITH_WARNING',
        'resolve_no_test_calls_OK_WITH_WARNING',
        'resolve_passthrough_HEADER_CORRUPT',
        'resolve_no_test_calls_HEADER_CORRUPT',
        'resolve_passthrough_MISSING_VOLUME',
        'resolve_no_test_calls_MISSING_VOLUME',
        'resolve_passthrough_NOT_ARCHIVE',
        'resolve_no_test_calls_NOT_ARCHIVE',
        'resolve_passthrough_TRUNCATED',
        'resolve_no_test_calls_TRUNCATED',
        'resolve_passthrough_DATA_CORRUPT',
        'resolve_no_test_calls_DATA_CORRUPT',
        'resolve_passthrough_UNSUPPORTED_METHOD',
        'resolve_no_test_calls_UNSUPPORTED_METHOD',
        'resolve_passthrough_CANCELLED',
        'resolve_no_test_calls_CANCELLED',
        'resolve_passthrough_IO_ERROR',
        'resolve_no_test_calls_IO_ERROR',
        'resolve_passthrough_UNKNOWN_ERROR',
        'resolve_no_test_calls_UNKNOWN_ERROR',
        'resolve_need_password_success_status',
        'resolve_need_password_sets_password_used',
        'resolve_need_password_tried_multiple',
        'resolve_log_hides_password_value',
        'resolve_log_hides_failed_password_value',
        'resolve_log_uses_redacted_placeholder',
        'resolve_wrong_password_path_ok',
        'resolve_wrong_password_path_password_used',
        'resolve_stops_on_non_password_status',
        'resolve_non_password_no_password_used',
        'resolve_does_not_try_remaining_after_header_corrupt',
        'probe_classifies_wrong_password_over_headers',
        'probe_stage_name',
        'probe_cmd_list_slt',
        'probe_cmd_bso1',
        'probe_cmd_bse1',
        'probe_cmd_bsp0',
        'probe_cmd_utf8',
        'test_classifies_ok',
        'test_stage_name',
        'test_sets_password_used_on_ok',
        'test_cmd_uses_t',
        'test_cmd_includes_dash_p',
        'test_log_redacts_password',
        'resolve_dialog_cancel_returns_cancelled',
        'resolve_dialog_use_ok',
        'resolve_dialog_use_password_used',
        'resolve_dialog_use_does_not_remember',
        'resolve_dialog_save_ok',
        'resolve_dialog_save_password_used',
        'resolve_dialog_save_calls_remember',
        'dialog_label_use_once',
        'dialog_label_use_and_save',
        'dialog_label_cancel',
        'dialog_edit_password_style'
    )

    foreach ($name in $cases) {
        It "behavior $name PASS" {
            $script:PwMap.ContainsKey($name) | Should Be $true
            $script:PwMap[$name] | Should Be 'PASS'
        }
    }
}
```

**Fragment exporter contract:** The PowerShell above defines the host seams. When implementing Step 3, keep `Export-PasswordPreflightFragment` so that:
1. It slices `SmartZip.ahk` from `` `n    ProbeArchive(`` through `` `n    RunCmdCapture(``
2. It embeds those product methods inside `class PasswordPreflightHost`
3. It then **redefines** only harness seams (`FormatPassword` ← `clipText`, `TestArchive` ← `scriptedTest` map, `ShowPasswordDialog` ← `dialogOverride`, `RememberPassword` ← call counter + product save logic). `BuildPasswordCandidates` must remain the sliced product method and obtains deterministic clipboard text through product `GetClipboardText()`.
4. Product `ProbeArchive` / `ResolveArchivePassword` / `ShowPasswordDialog` label strings remain from the slice (dialog labels assert against fragment text)

The final single-class assignment shown last in the script block is the exported harness host; the preceding assignments are overwritten construction stages and must never be written to `PasswordPreflight.Fragment.ahk`.

- [ ] **Step 2: Run focused tests and confirm RED**

Run:

```powershell
$staticFocused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName 'PasswordPreflightSafety' -PassThru
"STATIC_FOCUSED Passed=$($staticFocused.PassedCount) Failed=$($staticFocused.FailedCount) Total=$($staticFocused.TotalCount)"

$beh = Invoke-Pester -Script .\tests\PasswordPreflight.Tests.ps1 -PassThru
"BEH Passed=$($beh.PassedCount) Failed=$($beh.FailedCount) Total=$($beh.TotalCount)"
```

Expected RED:
- `PasswordPreflightSafety` → Its fail because slices are empty / `#Include lib\ArchiveDiagnostics.ahk` missing / `ProbeArchive` absent (`TotalCount=14`, `FailedCount` ≥ 1)
- `PasswordPreflightBehavior` fails exporting fragment (`Password preflight methods not found`) or harness `fragment_missing` / case map empty
- Do **not** implement until RED is recorded

- [ ] **Step 3: Implement preflight + password resolution in `SmartZip.ahk`**

**3a. Include pure diagnostics** — insert immediately before `class SmartZip`:

```ahk
#Include lib\ArchiveDiagnostics.ahk
```

**3b. Insert methods** immediately after `IsArchive`’s closing `}` and **before** Task 3’s `RunCmdCapture` (so order is `IsArchive` → password/preflight methods → `RunCmdCapture` → `RunCmd`):

```ahk
    ProbeArchive(path) {
        cmd := this.7z ' l -slt -bso1 -bse1 -bsp0 -sccUTF-8 "' path '"'
        if this.cmdLog
            this.testLog .= '`n#####`n' RedactDiagnostic(cmd) '`n'
        cap := this.RunCmdCapture(cmd, "UTF-8")
        return Classify7zResult("probe", cap.exitCode, cap.output, path)
    }

    TestArchive(path, password := "") {
        cmd := this.7z ' t -bso1 -bse1 -bsp0 -sccUTF-8 -p"' password '" "' path '"'
        if this.cmdLog
            this.testLog .= '`n#####`n' RedactDiagnostic(cmd) '`n'
        cap := this.RunCmdCapture(cmd, "UTF-8")
        result := Classify7zResult("test", cap.exitCode, cap.output, path)
        if (result.status = ArchiveStatus.OK || result.status = ArchiveStatus.OK_WITH_WARNING)
            result.passwordUsed := password
        return result
    }

    BuildPasswordCandidates(path) {
        out := []
        seen := Map()
        add(p) {
            if (p = "")
                return
            key := (p = "") ? "__EMPTY__" : String(p)
            if seen.Has(key)
                return
            seen[key] := true
            out.Push(p)
        }
        if (ini.lastPass != "")
            add(ini.lastPass)
        clip := this.FormatPassword(this.GetClipboardText())
        if (clip != "")
            add(clip)
        if (this.dynamicPassSort || this.autoAddPass) {
            arr := []
            if this.HasProp("dynamicPassArr") {
                for item in this.dynamicPassArr {
                    if (item is Array)
                        arr.Push([item[1], item[2]])
                    else
                        arr.Push([item, 0])
                }
            }
            ; sort copy by usage count desc; do not reorder this.dynamicPassArr here (PasswordSort still owns persistence)
            i := 0
            while (++i <= arr.Length) {
                j := 0
                while (++j <= arr.Length - i) {
                    if arr[j][2] < arr[j + 1][2] {
                        tmp := arr[j]
                        arr[j] := arr[j + 1]
                        arr[j + 1] := tmp
                    }
                }
            }
            for item in arr
                add(item[1])
        } else if this.HasProp("password") {
            for p in this.password
                add(p)
        }
        if this.addDir2Pass {
            SplitPath(path, , &dir)
            parent := RegExReplace(dir, ".+\\")
            if (parent != "")
                add(parent)
        }
        return out
    }

    ResolveArchivePassword(path, probeResult) {
        st := probeResult.status
        if (st != ArchiveStatus.NEED_PASSWORD && st != ArchiveStatus.WRONG_PASSWORD)
            return probeResult

        emptyTry := this.TestArchive(path, "")
        if (emptyTry.status = ArchiveStatus.OK || emptyTry.status = ArchiveStatus.OK_WITH_WARNING)
            return emptyTry
        if (emptyTry.status != ArchiveStatus.NEED_PASSWORD && emptyTry.status != ArchiveStatus.WRONG_PASSWORD)
            return emptyTry

        for pwd in this.BuildPasswordCandidates(path) {
            r := this.TestArchive(path, pwd)
            if (r.status = ArchiveStatus.OK || r.status = ArchiveStatus.OK_WITH_WARNING)
                return r
            if (r.status = ArchiveStatus.CANCELLED)
                return r
            if (r.status != ArchiveStatus.NEED_PASSWORD && r.status != ArchiveStatus.WRONG_PASSWORD)
                return r	; non-password status: stop iterating
        }

        dlg := this.ShowPasswordDialog(path)
        if (dlg.action = "cancel" || dlg.password = "")
            return ArchiveResult(ArchiveStatus.CANCELLED, "password", -1, path, "")

        r := this.TestArchive(path, dlg.password)
        if (r.status = ArchiveStatus.OK || r.status = ArchiveStatus.OK_WITH_WARNING) {
            if (dlg.action = "save")
                this.RememberPassword(dlg.password)
            ; "本次使用" does not persist
            return r
        }
        if (r.status = ArchiveStatus.NEED_PASSWORD || r.status = ArchiveStatus.WRONG_PASSWORD)
            return r  ; submitted-but-wrong stays diagnosable; only explicit cancel is CANCELLED
        return r
    }

    ShowPasswordDialog(path) {
        result := { action: "cancel", password: "" }
        SplitPath(path, &name)
        g := Gui("+AlwaysOnTop -MinimizeBox", "SmartZip 需要密码")
        g.AddText("w280", "文件: " name)
        g.AddText("w280", "请输入密码:")
        edit := g.AddEdit("w280 Password")
        btnRow := g.AddButton("w90 Default", "本次使用")
        btnSave := g.AddButton("x+8 w90", "使用并保存")
        btnCancel := g.AddButton("x+8 w90", "取消")
        btnRow.OnEvent("Click", (*) => (result.action := "use", result.password := edit.Value, g.Destroy()))
        btnSave.OnEvent("Click", (*) => (result.action := "save", result.password := edit.Value, g.Destroy()))
        btnCancel.OnEvent("Click", (*) => (result.action := "cancel", result.password := "", g.Destroy()))
        g.OnEvent("Close", (*) => (result.action := "cancel", result.password := "", g.Destroy()))
        g.Show("AutoSize Center")
        WinWaitClose(g.Hwnd)
        return result
    }

    RememberPassword(password) {
        if !password
            return password
        if ini.lastPass != password
            ini.Write(password, "lastPass", "temp")
        if this.dynamicPassSort || this.autoAddPass {
            if !this.HasProp("passwordMap")
                this.passwordMap := Map()
            if !this.HasProp("dynamicPassArr")
                this.dynamicPassArr := []
            if !this.passwordMap.Has(password) {
                this.dynamicPassArr.Push([password, 0])
                this.passwordMap[password] := this.dynamicPassArr.Length
                if this.autoAddPass
                    ini.Write(password, this.passwordMap.Count, "password")
            } else
                this.dynamicPassArr[this.passwordMap[password]][2]++
        }
        return password
    }

    FormatPassword(str) => StrLen(str) < 100 ? Trim(RegExReplace(str, "(\R*)")) : ""

    GetClipboardText() => this.HasOwnProp("clipText") ? this.clipText : A_Clipboard
```

**3c. Rewrite `zipx(path)` preflight only** (nested inside `Unzip`). Replace the block that currently:

- builds `pass := ""` / `this.continue := false`
- loops `for i in this.password` with first-iteration `RunCmd(..., CheckEncrypted)` and subsequent `CheckCMD` tests
- branches into `Run7z` on success or interactive `Run7z` without pass

with the following structure (keep `TrackPass` / old GUI 7zG password scrape **removed** from the auto path; keep `IsSuccess` / `Run7z` extract call shape for Task 5):

At the start of each outer `Unzip` call execute `if !loopPath this.processedVolumeFirst := Map()`; nested calls inherit the current map so a volume group is processed once per user operation.

```ahk
        zipx(path)
        {
            if this.logLevel
                this.log .= '`n#####`n' path '`n'

            pass := ""
            this.continue := false
            this.error := true

            SplitPath(path, &selectedName, &selectedDir)
            siblingNames := []
            loop files selectedDir "\*.*", "F"
                siblingNames.Push(A_LoopFileName)
            volume := DetectVolumeGroup(path, siblingNames)
            if volume.isVolume {
                key := StrLower(volume.firstPath)
                if !this.HasOwnProp("processedVolumeFirst")
                    this.processedVolumeFirst := Map()
                if this.processedVolumeFirst.Has(key) {
                    this.error := false  ; intentional duplicate member skip, not an extraction failure
                    return
                }
                if (volume.missingVolumes.Length || !FileExist(volume.firstPath)) {
                    missing := ArchiveResult(ArchiveStatus.MISSING_VOLUME, "probe", 2, path)
                    missing.volumeFirst := volume.firstPath
                    missing.missingVolumes := volume.missingVolumes
                    return missing
                }
                this.processedVolumeFirst[key] := true
                path := volume.firstPath
            }

            probe := this.ProbeArchive(path)
            if volume.isVolume
                probe.volumeFirst := volume.firstPath
            if this.logLevel
                this.Loging("probe status=" probe.status " exit=" probe.exitCode, A_LineNumber, 4)

            resolved := this.ResolveArchivePassword(path, probe)
            if this.logLevel
                this.Loging("resolve status=" resolved.status " exit=" resolved.exitCode, A_LineNumber, 4)

            ; Non-success preflight: never delete source; skip extract (Task 5 owns partial dirs)
            if (resolved.status != ArchiveStatus.OK && resolved.status != ArchiveStatus.OK_WITH_WARNING) {
                this.error := true
                if (resolved.status = ArchiveStatus.CANCELLED)
                    this.exitCode := 255
                return
            }

            this.error := false
            if (resolved.passwordUsed != "")
                pass := ' -p"' resolved.passwordUsed '"'

            ; OK_WITH_WARNING from probe/test still extracts; mayDeleteSource remains false on result
            ; (Task 5 enforces mayDeleteSource at finalize — do not delete here on warning)
            this.Run7z(hideBool, 'x', path, '" -aou -o' tmpDir pass this.excludeArgs this.codePage, hideBool || this.guiShow, () => IsSuccess(), A_LineNumber)

            if IsSuccess()
            {
                if volume.isVolume
                    return
                ; Warning status must not handle source even if IsSuccess still size-based (Task 5 removes size gate).
                if (resolved.status = ArchiveStatus.OK_WITH_WARNING)
                    return
                ; Interim Task 4 behavior is Recycle Bin only for every source archive.
                ; Task 5 replaces this whole block with the clean-success state machine.
                if loopPath
                    this.RecycleItem(path, A_LineNumber, false)
                else if this.delSource || (pass && this.delWhenHasPass)
                    this.RecycleItem(path, A_LineNumber, false)
            }
        }
```

Hard constraints for this step:
- Delete / stop using nested `CheckEncrypted` as the Unzip entry path (static test forbids `CheckEncrypted` inside `UnzipBody`)
- Remove nested `TrackPass` timer path from the no-password GUI fallback for this entry (password UI is `ShowPasswordDialog` only)
- Nested `AddPass` may remain unused or be reduced to calling `this.RememberPassword`; end-of-`Unzip` `PasswordSort` / `autoRemovePass` **must remain** unchanged
- Nested `FormatPassword` can be removed if all call sites use `this.FormatPassword` (Init currently calls bare `FormatPassword` — change Init password seed to `this.FormatPassword(A_Clipboard)` **or** keep a thin global/local alias; preferred: in `Unzip` password seed line use `this.FormatPassword(A_Clipboard)`)
- Do **not** edit `RunCmdCapture`, `RunCmd`, `CheckCMD` map tables, `Run7z`, `Gui`, `ButtonPause`, `Close(*)`, or `IsSuccess` size heuristic body in this task
- Do **not** log `resolved.passwordUsed` or any candidate string

**3d. Init clipboard seed** — where Unzip currently has:

```ahk
this.password := ["", ini.lastPass, FormatPassword(A_Clipboard)]
```

change to:

```ahk
this.password := ["", ini.lastPass, this.FormatPassword(A_Clipboard)]
```

- [ ] **Step 4: Run focused GREEN, full static suite, diagnostics, capture, and password suites**

Run:

```powershell
$staticFocused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName 'PasswordPreflightSafety' -PassThru
"STATIC_FOCUSED Passed=$($staticFocused.PassedCount) Failed=$($staticFocused.FailedCount) Total=$($staticFocused.TotalCount)"
if ($staticFocused.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=14, FailedCount=0

$static = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
"STATIC Passed=$($static.PassedCount) Failed=$($static.FailedCount) Total=$($static.TotalCount)"
if ($static.PassedCount -ne 96 -or $static.FailedCount -ne 0) { exit 1 }
# Expected: 82 (Tasks 0–3) + 14 PasswordPreflightSafety = 96

$beh = Invoke-Pester -Script .\tests\PasswordPreflight.Tests.ps1 -PassThru
"PW_BEH Passed=$($beh.PassedCount) Failed=$($beh.FailedCount) Total=$($beh.TotalCount)"
if ($beh.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=70 (1 harness-exit + 69 named cases), FailedCount=0

$cap = Invoke-Pester -Script .\tests\RunCmdCapture.Tests.ps1 -PassThru
"CAP Passed=$($cap.PassedCount) Failed=$($cap.FailedCount) Total=$($cap.TotalCount)"
if ($cap.PassedCount -ne 15 -or $cap.FailedCount -ne 0) { exit 1 }

$diag = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
"DIAG Passed=$($diag.PassedCount) Failed=$($diag.FailedCount) Total=$($diag.TotalCount)"
if ($diag.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=140, FailedCount=0 (Tasks 1–2 unchanged)
```

Expected GREEN gates (all required):
- static focused `14/14`
- full static `Passed=96 Failed=0 Total=96`
- PasswordPreflight behavior `Passed=70 Failed=0 Total=70`
- RunCmdCapture behavior `Passed=15 Failed=0 Total=15`
- ArchiveDiagnostics `Passed=140 Failed=0 Total=140`

- [ ] **Step 5: `git diff --check` and focused commit**

Run:

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1 `
    tests/PasswordPreflight.Harness.ahk tests/PasswordPreflight.Tests.ps1
if (Test-Path .\tests\PasswordPreflight.Fragment.ahk) {
    git status --porcelain -- tests/PasswordPreflight.Fragment.ahk
    # Ensure fragment is untracked or gitignored; do not git add it
}
git diff --check --cached
git diff --cached --stat
git commit -m "feat: probe archives and resolve passwords with full-output classification"
```

Expected: no whitespace errors; commit contains `SmartZip.ahk` + the three test files listed; no fragment commit; no `Run7z` / exact-PID / pause hunks except unavoidable context; no `lib/ArchiveDiagnostics.ahk` classifier changes.

Verify explicitly:

```powershell
git show --stat --oneline HEAD
git show HEAD -- SmartZip.ahk | Select-String -Pattern '^\+\s*ProbeArchive|^\+\s*TestArchive|^\+\s*BuildPasswordCandidates|^\+\s*ResolveArchivePassword|^\+\s*ShowPasswordDialog|^\-\s*.*CheckEncrypted|^\+\s*#Include lib\\ArchiveDiagnostics|^\-\s*.*exactPid|^\+\s*.*exactPid|^\-\s*.*ButtonPause|^\+\s*.*ButtonPause'
```

Expected: additions for preflight/password API + include; removal of Unzip `CheckEncrypted` entry path; zero pause/exactPid churn.

- [ ] **Step 6: Independent read-only review gate**

Dispatch a fresh read-only reviewer against this task’s commit with design §4–5, §9, and Canonical Interfaces. The reviewer must verify:

- `ProbeArchive` / `TestArchive` use Task 3 `RunCmdCapture` + Task 1 `Classify7zResult` with stages `"probe"` / `"test"` and full stdout+stderr classification (no early `ProcessClose` on keyword matchers in these paths)
- command flags include `-bso1 -bse1 -bsp0 -sccUTF-8`; probe uses `l -slt`; test uses `t` and `-p"..."`
- `BuildPasswordCandidates` order is lastPass → clipboard → saved dynamic order → optional parent with stable dedupe; empty is excluded from the list and `ResolveArchivePassword` calls `TestArchive(path, "")` exactly once before iterating it
- `ResolveArchivePassword` does **not** iterate candidates for any non-password status (`HEADER_CORRUPT`, `MISSING_VOLUME`, etc.)
- SmartZip password dialog Edit is masked; buttons are exactly `本次使用` / `使用并保存` / `取消`
- `本次使用` does not persist; `使用并保存` calls `RememberPassword` preserving dynamic sort/count hooks; batch `PasswordSort` / `autoRemovePass` still present at end of `Unzip`
- passwords never appear in `testLog` / `Loging` output (only `RedactDiagnostic` / `-p***`)
- `passwordUsed` is memory-only on success paths
- static `96/96`, password behavior `70/70`, capture `15/15`, diagnostics `140/140`
- `IsSuccess` size heuristic may still exist (Task 5) but preflight no longer uses early-kill `CheckEncrypted`

Require:

```text
Critical=0
Important=0
```

If either count is non-zero: fix only Task 4 files (`SmartZip.ahk` preflight/password regions + password tests/static Its), re-run Step 4–5, re-review until both are zero. Task 4 is incomplete until this gate passes.

### Task 5: Clean-Success Gate, Partial Output, and Source Lifecycle

**Files:**
- Modify: `SmartZip.ahk` — add class methods `ExtractArchiveToTemp`, `FinalizeExtraction`, `WriteDiagnostic` immediately after Task 4 password methods / before `RunCmdCapture`; rewrite nested `zipx` extract+source block to call them; **delete** nested `IsSuccess` body (and every `() => IsSuccess()` / `if IsSuccess()` call site inside `Unzip`/`zipx`); do **not** authorize success or source handling via folder-size ratio or `this.succesSpercent` / `ini.successPercent`
- Create: `tests/ExtractionLifecycle.Harness.ahk` — executable decision-table harness (no 7zG UI; uses injectable doubles + real `Classify7zResult` / `RedactDiagnostic`)
- Create: `tests/ExtractionLifecycle.Tests.ps1` — Pester 3.4 wrapper
- Modify: `tests/SmartZip.Static.Tests.ps1` — append `Describe 'ExtractionLifecycleSafety'` (existing **96** Its from Tasks 0–4 must remain green)
- Do not modify: `lib/ArchiveDiagnostics.ahk` classifier/volume bodies, `RunCmdCapture` body, `Run7z` / `Gui` / exact-PID / pause / force-end, settings UI migration / `successPercent` deprecation copy (Task 6), diagnostic **window** (Task 7)

**Interfaces:**
- Consumes:
  - Task 1: `ArchiveStatus`, `ArchiveResult`, `Classify7zResult`, `RedactDiagnostic`
  - Task 3: `RunCmdCapture`
  - Task 4: `resolved` from `ResolveArchivePassword` (`status`, `passwordUsed`); preflight already refused non-`OK`/`OK_WITH_WARNING`
  - Existing: `Run7z` (7zG extract UX), `MoveItem`, `RecycleItem`, `PathDupl`, `this.delSource`, `this.delWhenHasPass`, `this.excludeArgs`, `this.codePage`, `this.7z`, `this.7zG`, `this.cmdLog`/`testLog`/`Loging`
- Produces (Canonical Interfaces):
  - `SmartZip.ExtractArchiveToTemp(path, password, tempDir) => ArchiveResult`
    - stage always `"extract"`
    - launches existing `Run7z(..., 'x', path, '" -aou -o' tempDir pass this.excludeArgs this.codePage, ...)` so 7zG progress/pause stay intact
    - **never** calls size/`successPercent` success gates
    - `exitCode = 0` → `Classify7zResult("extract", 0, diagnosticOutput, path)` (diagnosticOutput may be `""` when 7zG left no text; empty + exit 0 ⇒ `OK`)
    - `exitCode = 255` → `ArchiveResult(ArchiveStatus.CANCELLED, "extract", 255, path)`
    - other non-zero → console re-test for classifiable text: `RunCmdCapture(this.7z ' t -bso1 -bse1 -bsp0 -sccUTF-8 -p"' password '" "' path '"')` then `Classify7zResult("extract", this.exitCode, cap.output, path)` (keep original extract exit on the result; do not treat console-test exit as extract success)
    - sets `result.tempOutputDir := tempDir`; `result.passwordUsed := password` (memory only); `isCleanSuccess`/`mayDeleteSource` true only when `status = OK` (library defaults)
  - `SmartZip.FinalizeExtraction(path, result, tempDir, targetDir, mayDeleteSource) => ArchiveResult`
    - `tempHasOutput` := tempDir exists and contains ≥1 file/folder entry (non-recursive existence check is enough; product may use existing `loop files`)
    - **Clean success** (`result.status = ArchiveStatus.OK` and `result.exitCode = 0`): leave `tempDir` for the existing post-`zipx` single/multi-file `MoveItem`/`AfterUnzip` path. If top-level `mayDeleteSource` is true and `!volume.isVolume`, source handling is `RecycleItem(path, …, false)` (Recycle Bin only). A nested source is handled by the caller only after its own clean `OK`, also with `delete := false`; nested archives have already been moved into the formal output tree and must never be treated as disposable TEMP. `part` remains a legacy skip hint and must never be the sole volume-deletion guard.
    - **`OK_WITH_WARNING`**: leave/move usable output the same way as success (temp kept for post-`zipx` movers); **always** preserve source (ignore `mayDeleteSource`); never volume-delete
    - **Failure with output** (`status` not OK/OK_WITH_WARNING and `tempHasOutput`): `SplitPath(path,,,,, &nameNoExt)`; `partial := this.PathDupl(targetDir "\" nameNoExt "_解压不完整_" FormatTime(, "yyyyMMdd-HHmmss"), 1)`; `DirMove(tempDir, partial)`; `result.partialOutputDir := partial`; call `WriteDiagnostic(result)` which creates UTF-8 `partial\SmartZip-诊断.txt` via `RedactDiagnostic` only
    - **Failure without output**: if `DirExist(tempDir)` and empty → `RecycleItem(tempDir, …, true)` (or `DirDelete`); never touch source
    - **CANCELLED / any non-clean status**: never source-handle; never delete volume members
    - Returns the (possibly updated) `result`
  - `SmartZip.WriteDiagnostic(result) => String` — builds timestamp/SmartZip version/7-Zip version/status/stage/exitCode/missingVolumes/warningLines/errorLines/archive basename plus at most a 4096-character raw-output excerpt, runs `RedactDiagnostic`, writes `SmartZip-诊断.txt` when `partialOutputDir` set, returns redacted text (no password, no `-p` secrets, no clipboard)
  - `zipx` source-handling rules (caller of Finalize):
    - `mayDeleteSource := !volume.isVolume && (resolved.status = ArchiveStatus.OK) && (this.delSource || (resolved.passwordUsed != "" && this.delWhenHasPass))` for top-level only; force `false` on warning or nested runs. `.part01.rar`, `.part10.rar`, `.rar`+`.r00`, and numeric split sets must all remain non-deletable regardless of legacy `IsPart`.
    - Permanent deletion is limited to SmartZip-created empty/abandoned `tempDir` paths. No call shaped as `RecycleItem(path, …, true)` is allowed for a source archive, top-level or nested.
  - **Deleted authorization path:** nested `IsSuccess` must not exist; no `folderSize / this.currentSize` / `succesSpercent` / `successPercent` comparison may grant success or trigger source recycle

- [ ] **Step 1: Write failing static tests and harness/wrapper**

Before appending the 12 lifecycle `It` blocks, update in place the existing static test `Unzip still consumes excludeArgs on both extraction paths`: after extraction moves into `ExtractArchiveToTemp`, assert `$script:ExtractArchiveToTempBody` contains the `Run7z('x', … this.excludeArgs …)` call and assert `$script:UnzipBody` calls `ExtractArchiveToTemp`. Keep it as one existing `It`; do not continue requiring two inline `Run7z` calls inside `UnzipBody`.

Append to `tests/SmartZip.Static.Tests.ps1` (after `Describe 'PasswordPreflightSafety'`) exactly:

```powershell
$script:ExtractArchiveToTempBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    ExtractArchiveToTemp(" -EndMarker "`n    FinalizeExtraction("
$script:FinalizeExtractionBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    FinalizeExtraction(" -EndMarker "`n    WriteDiagnostic("
$script:WriteDiagnosticBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    WriteDiagnostic(" -EndMarker "`n    RunCmdCapture("

Describe 'ExtractionLifecycleSafety' {

    It 'ExtractArchiveToTemp FinalizeExtraction WriteDiagnostic methods exist in order' {
        [string]::IsNullOrEmpty($script:ExtractArchiveToTempBody) | Should Be $false
        [string]::IsNullOrEmpty($script:FinalizeExtractionBody) | Should Be $false
        [string]::IsNullOrEmpty($script:WriteDiagnosticBody) | Should Be $false
        $e = $script:SmartZipSource.IndexOf('ExtractArchiveToTemp(')
        $f = $script:SmartZipSource.IndexOf('FinalizeExtraction(')
        $w = $script:SmartZipSource.IndexOf('WriteDiagnostic(')
        ($e -ge 0 -and $f -gt $e -and $w -gt $f) | Should Be $true
    }

    It 'ExtractArchiveToTemp uses Run7z extract and Classify7zResult stage extract' {
        $script:ExtractArchiveToTempBody | Should Match 'Run7z\s*\('
        $script:ExtractArchiveToTempBody | Should Match "['`"]x['`"]"
        $ok = Test-Regex -Text $script:ExtractArchiveToTempBody -Pattern `
            'Classify7zResult\s*\(\s*["'']extract["'']'
        $ok | Should Be $true
    }

    It 'ExtractArchiveToTemp reclassifies non-zero extract via console test capture' {
        $ok = Test-Regex -Text $script:ExtractArchiveToTempBody -Pattern `
            'RunCmdCapture\s*\('
        $ok | Should Be $true
        $script:ExtractArchiveToTempBody | Should Match '\bt\b'
        $script:ExtractArchiveToTempBody | Should Match '255'
    }

    It 'no IsSuccess size or successPercent authorization remains' {
        $script:UnzipBody | Should Not Match 'IsSuccess\s*\('
        $script:SmartZipSource | Should Not Match '(?s)IsSuccess\s*\(\s*\)\s*\{[^}]*succesSpercent'
        $script:ExtractArchiveToTempBody | Should Not Match 'succesSpercent|successPercent|GetFolder\s*\(\s*tmpDir\s*\)\s*\.Size|folderSize\s*/\s*this\.currentSize'
        $script:FinalizeExtractionBody | Should Not Match 'succesSpercent|successPercent|folderSize\s*/\s*this\.currentSize'
    }

    It 'FinalizeExtraction encodes partial dir name 解压不完整 and diagnostic file' {
        $script:FinalizeExtractionBody | Should Match '解压不完整'
        $script:FinalizeExtractionBody | Should Match 'yyyyMMdd-HHmmss'
        $script:FinalizeExtractionBody | Should Match 'PathDupl\s*\('
        $script:FinalizeExtractionBody | Should Match 'DirMove\s*\('
        $ok = Test-Regex -Text $script:FinalizeExtractionBody -Pattern 'WriteDiagnostic\s*\('
        $ok | Should Be $true
        $script:WriteDiagnosticBody | Should Match 'SmartZip-诊断\.txt'
        $script:WriteDiagnosticBody | Should Match 'RedactDiagnostic\s*\('
    }

    It 'FinalizeExtraction preserves source on warning and never permanently deletes a source path' {
        $script:FinalizeExtractionBody | Should Match 'OK_WITH_WARNING'
        $script:FinalizeExtractionBody | Should Match 'mayDeleteSource'
        $script:FinalizeExtractionBody | Should Match 'RecycleItem\s*\('
        # No source archive path may force permanent delete (delete:=true).
        $ok = Test-Regex -Text $script:FinalizeExtractionBody -Pattern `
            'RecycleItem\s*\(\s*path\s*,\s*[^,]+,\s*true\s*\)'
        $ok | Should Be $false
        $script:FinalizeExtractionBody | Should Match 'FileRecycle|delete\s*:=\s*false|RecycleItem\s*\(\s*path\s*,'
        # Permanent cleanup remains allowed only for the SmartZip-created tempDir.
        $script:FinalizeExtractionBody | Should Match 'RecycleItem\s*\(\s*tempDir\s*,[^\n]*true'
    }

    It 'zipx calls ExtractArchiveToTemp and FinalizeExtraction' {
        $ok = Test-Regex -Text $script:UnzipBody -Pattern 'ExtractArchiveToTemp\s*\('
        $ok2 = Test-Regex -Text $script:UnzipBody -Pattern 'FinalizeExtraction\s*\('
        $ok3 = Test-Regex -Text $script:UnzipBody -Pattern 'TestArchive\s*\('
        $ok4 = Test-Regex -Text $script:UnzipBody -Pattern 'forceTest\s*:=\s*this\.test\s*\|\|\s*mayHandleSource\s*\|\|\s*nestedMayRecycle'
        $ok5 = Test-Regex -Text $script:UnzipBody -Pattern '!\s*volume\.isVolume'
        ($ok -and $ok2 -and $ok3 -and $ok4 -and $ok5) | Should Be $true
        $script:UnzipBody | Should Match 'nestedMayRecycle\s*&&\s*extractResult\.isCleanSuccess'
        $script:UnzipBody | Should Not Match 'RecycleItem\s*\(\s*path\s*,[^\n]*true'
    }

    It 'Run7z still launches 7zG and exactPid reset unchanged' {
        $script:Run7zBody | Should Match '7zG'
        $script:Run7zBody | Should Match 'exactPid'
        $script:Run7zBody | Should Match 'this\.query\s*:='
    }

    It 'WriteDiagnostic never logs raw password material' {
        $script:WriteDiagnosticBody | Should Not Match 'passwordUsed'
        $script:WriteDiagnosticBody | Should Match 'RedactDiagnostic'
        $script:WriteDiagnosticBody | Should Match '7-Zip|sevenZipVersion'
        $script:WriteDiagnosticBody | Should Match '4096'
    }

    It 'volume and cancel paths do not authorize source handling in FinalizeExtraction' {
        # mayDeleteSource must gate any path RecycleItem; CANCELLED must not force delete
        $script:FinalizeExtractionBody | Should Match 'mayDeleteSource'
        $script:FinalizeExtractionBody | Should Not Match 'RecycleItem\s*\(\s*path\s*,[^\n]*CANCELLED'
    }

    It 'partial diagnostic name and PathDupl used' {
        $script:FinalizeExtractionBody | Should Match 'PathDupl\s*\('
        $script:FinalizeExtractionBody | Should Match 'DirMove|MoveItem'
    }

    It 'successPercent assignment may still load but must not gate extract success' {
        # Field may remain until Task 6 deprecates UI; must not appear in extract/finalize decision
        $script:ExtractArchiveToTempBody | Should Not Match 'successPercent|succesSpercent'
        $script:FinalizeExtractionBody | Should Not Match 'successPercent|succesSpercent'
    }
}
```

Create `tests/ExtractionLifecycle.Harness.ahk` with exactly:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\..\lib\ArchiveDiagnostics.ahk

outPath := A_Args.Length >= 1 ? A_Args[1] : A_Temp "\ExtractionLifecycle.out.txt"
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

; Pure finalize decision double — mirrors product rules without 7zG / SmartZip instance
FinalizeDecision(path, result, tempDir, targetDir, mayDeleteSource, tempHasOutput, isNested := false, isVolumeMember := false) {
    out := {
        status: result.status,
        exitCode: result.exitCode,
        sourceAction: "none",      ; none | recycle | recycle_nested
        tempAction: "keep",        ; keep | partial | remove_empty
        partialName: "",
        diagnostic: "",
        isCleanSuccess: (result.status = ArchiveStatus.OK && result.exitCode = 0)
    }
    if (result.status = ArchiveStatus.OK && result.exitCode = 0) {
        out.tempAction := "keep"
        if (isVolumeMember)
            out.sourceAction := "none"
        else if (isNested && out.isCleanSuccess)
            out.sourceAction := "recycle_nested"
        else if (!isNested && mayDeleteSource && out.isCleanSuccess)
            out.sourceAction := "recycle"
        else
            out.sourceAction := "none"
        return out
    }
    if (result.status = ArchiveStatus.OK_WITH_WARNING) {
        out.tempAction := "keep"
        out.sourceAction := "none"  ; always preserve
        out.isCleanSuccess := false
        return out
    }
    ; failure / cancel
    if (tempHasOutput) {
        SplitPath(path, , , , &nameNoExt)
        out.tempAction := "partial"
        out.partialName := nameNoExt "_解压不完整_" FormatTime(, "yyyyMMdd-HHmmss")
        raw := "status=" result.status "`nstage=" result.stage "`nexitCode=" result.exitCode
            . "`narchive=" path "`nerrors="
        for e in result.errorLines
            raw .= e "`n"
        out.diagnostic := RedactDiagnostic(raw)
        out.sourceAction := "none"
        return out
    }
    out.tempAction := "remove_empty"
    out.sourceAction := "none"
    return out
}

; 1) Clean OK + mayDeleteSource → recycle source, keep temp
r1 := ArchiveResult(ArchiveStatus.OK, "extract", 0, "D:\\a\\pack.zip")
d1 := FinalizeDecision("D:\\a\\pack.zip", r1, "D:\\tmp\\t1", "D:\\out", true, true, false, false)
AssertEq(d1.sourceAction, "recycle", "ok_top_maydelete_recycles")
AssertEq(d1.tempAction, "keep", "ok_keeps_temp_for_move")
AssertEq(d1.isCleanSuccess, true, "ok_is_clean_success")

; 2) OK but mayDeleteSource false → preserve source
d2 := FinalizeDecision("D:\\a\\pack.zip", r1, "D:\\tmp\\t1", "D:\\out", false, true, false, false)
AssertEq(d2.sourceAction, "none", "ok_without_maydelete_preserves")

; 3) OK_WITH_WARNING always preserves source even if mayDeleteSource true
r3 := ArchiveResult(ArchiveStatus.OK_WITH_WARNING, "extract", 0, "D:\\a\\pack.zip")
d3 := FinalizeDecision("D:\\a\\pack.zip", r3, "D:\\tmp\\t1", "D:\\out", true, true, false, false)
AssertEq(d3.sourceAction, "none", "warn_always_preserves_source")
AssertEq(d3.tempAction, "keep", "warn_moves_usable_output_keep_temp")
AssertEq(d3.isCleanSuccess, false, "warn_not_clean_success")

; 4) Executable regression: exit 2, ratio would be >90%, CRC → DATA_CORRUPT, source remains
;    (size/ratio must NOT flip this to success)
r4 := Classify7zResult("extract", 2, "ERROR: CRC Failed in encrypted file`nData Error", "D:\\a\\big.7z")
AssertEq(r4.status, ArchiveStatus.DATA_CORRUPT, "exit2_crc_is_data_corrupt")
AssertEq(r4.isCleanSuccess, false, "exit2_not_clean_success")
; Simulate temp filled to >90% of source — still failure
d4 := FinalizeDecision("D:\\a\\big.7z", r4, "D:\\tmp\\fat", "D:\\out", true, true, false, false)
AssertEq(d4.sourceAction, "none", "exit2_ratio_ignored_source_remains")
AssertEq(d4.tempAction, "partial", "exit2_with_output_goes_partial")
AssertTrue(InStr(d4.partialName, "_解压不完整_") > 0, "exit2_partial_name_has_marker")
AssertTrue(InStr(d4.diagnostic, "DATA_CORRUPT") > 0 || InStr(d4.diagnostic, "status=") > 0, "exit2_diagnostic_written_concept")

; 5) Failure empty temp → remove empty only
r5 := ArchiveResult(ArchiveStatus.HEADER_CORRUPT, "extract", 2, "D:\\a\\bad.zip")
d5 := FinalizeDecision("D:\\a\\bad.zip", r5, "D:\\tmp\\empty", "D:\\out", true, false, false, false)
AssertEq(d5.tempAction, "remove_empty", "fail_empty_removes_temp_only")
AssertEq(d5.sourceAction, "none", "fail_empty_preserves_source")

; 6) CANCELLED never source-handles
r6 := ArchiveResult(ArchiveStatus.CANCELLED, "extract", 255, "D:\\a\\pack.zip")
d6 := FinalizeDecision("D:\\a\\pack.zip", r6, "D:\\tmp\\c", "D:\\out", true, false, false, false)
AssertEq(d6.sourceAction, "none", "cancel_never_source_handle")

; 7) Every supported split family stays non-deletable even on OK + mayDelete
d7a := FinalizeDecision("D:\\a\\v.part01.rar", r1, "D:\\tmp\\t1", "D:\\out", true, true, false, true)
d7b := FinalizeDecision("D:\\a\\v.r00", r1, "D:\\tmp\\t1", "D:\\out", true, true, false, true)
AssertTrue(d7a.sourceAction = "none" && d7b.sourceAction = "none", "volume_never_source_handle")

; 8) Nested clean OK → Recycle Bin only; source may already be in formal output
d8 := FinalizeDecision("D:\\out\\nest\\inner.zip", r1, "D:\\tmp\\n", "D:\\out", true, true, true, false)
AssertEq(d8.sourceAction, "recycle_nested", "nested_ok_recycles_not_permanent")

; 9) Nested warning → no nested source handling
d9 := FinalizeDecision("D:\\tmp\\nest\\inner.zip", r3, "D:\\tmp\\n", "D:\\tmp\\n", true, true, true, false)
AssertEq(d9.sourceAction, "none", "nested_warn_preserves")

; 10) Redaction strips -p secrets in diagnostic path
secretRaw := "cmd: 7z t -p`"SuperSecret`"`nstatus=DATA_CORRUPT"
red := RedactDiagnostic(secretRaw)
AssertTrue(InStr(red, "SuperSecret") = 0, "diagnostic_redacts_password")
AssertTrue(InStr(red, "-p***") > 0 || InStr(red, "***") > 0, "diagnostic_has_redact_marker")

; 11) Clean success requires exit 0 — OK status with nonzero exit is not clean for source
r11 := ArchiveResult(ArchiveStatus.OK, "extract", 2, "D:\\a\\pack.zip")  ; inconsistent; product should not emit
d11 := FinalizeDecision("D:\\a\\pack.zip", r11, "D:\\tmp\\t", "D:\\out", true, true, false, false)
AssertEq(d11.isCleanSuccess, false, "nonzero_exit_not_clean_even_if_ok_status")
AssertEq(d11.sourceAction, "none", "nonzero_exit_no_recycle")

; 12) Partial name uses archive basename not full path secrets-only check
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
```

The `FinalizeDecision` table is an oracle, not the product-under-test. In `tests/ExtractionLifecycle.Tests.ps1`, implement `Export-ExtractionLifecycleProductHarness`: slice `ExtractArchiveToTemp` through the end of `WriteDiagnostic` from `SmartZip.ahk`, embed those exact methods in a TEMP host with injectable `Run7z`, `RunCmdCapture`, `RecycleItem`, `PathDupl`, `DirMove`/`MoveItem`, version, and filesystem doubles, and run the same named cases through the product fragment. The exporter must throw when any start/end marker or required method is absent, write only below `%TEMP%`, and return the generated `.ahk` path. It must not copy `FinalizeDecision` into the product host. Each Pester `It` below passes only when both the oracle case and the corresponding product-fragment case emit `PASS`. This preserves the exact `26`-test wrapper count while ensuring GREEN cannot occur before the production methods exist.

Create `tests/ExtractionLifecycle.Tests.ps1` with exactly:

```powershell
#requires -Version 5.0
$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:HarnessPath = Join-Path $PSScriptRoot 'ExtractionLifecycle.Harness.ahk'
$script:AhkExe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'

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
    $p = Start-Process -FilePath $script:AhkExe -ArgumentList @('/ErrorStdOut', $HarnessPath, $outFile) `
        -Wait -PassThru -NoNewWindow
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
```

- [ ] **Step 2: Run focused tests and confirm RED**

```powershell
$staticFocused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName 'ExtractionLifecycleSafety' -PassThru
"STATIC_FOCUSED Passed=$($staticFocused.PassedCount) Failed=$($staticFocused.FailedCount) Total=$($staticFocused.TotalCount)"

$beh = Invoke-Pester -Script .\tests\ExtractionLifecycle.Tests.ps1 -PassThru
"BEH Passed=$($beh.PassedCount) Failed=$($beh.FailedCount) Total=$($beh.TotalCount)"
```

Expected RED:
- static focused: methods missing / `IsSuccess` still present → **Failed ≥ 1**, Total=**12**
- behavior: harness can PASS decision-table cases that only need `lib/ArchiveDiagnostics.ahk` (already on disk from Task 1); if harness file missing, wrapper fails to start. Prefer observing static RED on product wiring before implementation.
- Do **not** implement product methods until static RED is recorded

- [ ] **Step 3: Minimal product implementation**

**3a. Insert methods** on `SmartZip` immediately before `RunCmdCapture` (after Task 4 `FormatPassword`):

```ahk
    ExtractArchiveToTemp(path, password, tempDir) {
        pass := ""
        if (password != "")
            pass := ' -p"' password '"'
        hideBool := false
        try hideBool := FileGetSize(path) / 1024 / 1024 < this.hideRunSize
        catch
            hideBool := false

        this.Run7z(hideBool, 'x', path, '" -aou -o' tempDir pass this.excludeArgs this.codePage,
            hideBool || this.guiShow, true, A_LineNumber)

        result := ""
        if (this.exitCode = 0) {
            result := Classify7zResult("extract", 0, "", path)
        } else if (this.exitCode = 255) {
            result := ArchiveResult(ArchiveStatus.CANCELLED, "extract", 255, path)
        } else {
            cmd := this.7z ' t -bso1 -bse1 -bsp0 -sccUTF-8 -p"' password '" "' path '"'
            cap := this.RunCmdCapture(cmd, "UTF-8")
            if this.cmdLog
                this.testLog .= '`n#####`n' RedactDiagnostic(cmd) '`n'
            result := Classify7zResult("extract", this.exitCode, cap.output, path)
            result.exitCode := this.exitCode
        }
        result.tempOutputDir := tempDir
        if (result.status = ArchiveStatus.OK || result.status = ArchiveStatus.OK_WITH_WARNING)
            result.passwordUsed := password
        result.isCleanSuccess := (result.status = ArchiveStatus.OK && result.exitCode = 0)
        result.mayDeleteSource := result.isCleanSuccess
        return result
    }

    FinalizeExtraction(path, result, tempDir, targetDir, mayDeleteSource) {
        tempHasOutput := false
        if DirExist(tempDir) {
            loop files tempDir "\*.*", "DF" {
                tempHasOutput := true
                break
            }
        }

        if (result.status = ArchiveStatus.OK && result.exitCode = 0) {
            ; keep tempDir for existing post-zipx MoveItem / AfterUnzip
            if (mayDeleteSource && result.isCleanSuccess)
                this.RecycleItem(path, A_LineNumber)  ; Recycle Bin only (delete=false)
            return result
        }

        if (result.status = ArchiveStatus.OK_WITH_WARNING) {
            ; usable output stays in tempDir for movers; never source-handle
            return result
        }

        if (tempHasOutput) {
            SplitPath(path, , , , &nameNoExt)
            stamp := FormatTime(, "yyyyMMdd-HHmmss")
            partial := this.PathDupl(targetDir "\" nameNoExt "_解压不完整_" stamp, 1)
            try DirMove(tempDir, partial)
            catch {
                try this.MoveItem(tempDir, partial, 1, A_LineNumber)
            }
            result.partialOutputDir := partial
            this.WriteDiagnostic(result)
            return result
        }

        if DirExist(tempDir)
            this.RecycleItem(tempDir, A_LineNumber, true)
        return result
    }

    WriteDiagnostic(result) {
        baseName := result.archivePath
        SplitPath(result.archivePath, &baseName)
        text := "SmartZip diagnostic`r`n"
            . "smartZipVersion=" MainVersion " " edition " (" buildVersion ")`r`n"
            . "sevenZipVersion=" (this.HasOwnProp("sevenZipVersion") ? this.sevenZipVersion : "unknown") "`r`n"
            . "status=" result.status "`r`n"
            . "stage=" result.stage "`r`n"
            . "exitCode=" result.exitCode "`r`n"
            . "archive=" baseName "`r`n"
        if (result.missingVolumes.Length) {
            text .= "missingVolumes="
            for v in result.missingVolumes
                text .= v ","
            text .= "`r`n"
        }
        for w in result.warningLines
            text .= "warning: " w "`r`n"
        for e in result.errorLines
            text .= "error: " e "`r`n"
        if (result.output != "")
            text .= "output:`r`n" SubStr(result.output, 1, 4096) "`r`n"
        text := RedactDiagnostic(text)
        if (result.partialOutputDir != "" && DirExist(result.partialOutputDir)) {
            diagPath := result.partialOutputDir "\SmartZip-诊断.txt"
            try FileDelete(diagPath)
            FileAppend(text, diagPath, "UTF-8")
        }
        return text
    }
```

**3b. Replace `zipx` extract + source block** (everything after successful preflight sets `pass` / `this.error := false`) with:

```ahk
            ; test=0 still forces a full integrity test before configured source handling
            mayHandleSource := (!loopPath) && !volume.isVolume
                && (this.delSource || (resolved.passwordUsed != "" && this.delWhenHasPass))
            nestedMayRecycle := loopPath && !volume.isVolume
                && (resolved.status = ArchiveStatus.OK)
            forceTest := this.test || mayHandleSource || nestedMayRecycle
            if (forceTest) {
                tr := this.TestArchive(path, resolved.passwordUsed)
                if (tr.status = ArchiveStatus.OK_WITH_WARNING) {
                    mayHandleSource := false
                    nestedMayRecycle := false
                } else if (tr.status != ArchiveStatus.OK) {
                    this.error := true
                    if (tr.status = ArchiveStatus.CANCELLED)
                        this.exitCode := 255
                    return
                }
            }

            extractResult := this.ExtractArchiveToTemp(path, resolved.passwordUsed, tmpDir)

            ; mayDeleteSource: all required stages OK only (probe/test already OK; extract must be OK)
            mayDel := false
            if (resolved.status = ArchiveStatus.OK
                && extractResult.status = ArchiveStatus.OK
                && extractResult.exitCode = 0
                && !volume.isVolume) {
                if (loopPath)
                    mayDel := false  ; nested handled below
                else if mayHandleSource
                    mayDel := true
            }

            extractResult := this.FinalizeExtraction(path, extractResult, tmpDir, A_WorkingDir, mayDel)

            ; Nested archive may already be in formal output: Recycle Bin only, never permanent delete
            if (nestedMayRecycle && extractResult.isCleanSuccess && !volume.isVolume && FileExist(path))
                this.RecycleItem(path, A_LineNumber, false)
```

Hard constraints:
- Delete nested `IsSuccess` entirely; delete both legacy `if IsSuccess()` source branches and the interactive `TrackPass` path if Task 4 already removed it
- Do not call `RecycleItem(path, …)` on `OK_WITH_WARNING`, failure, cancel, or any `DetectVolumeGroup(...).isVolume` set; do not rely on legacy `part != -1` alone
- Never call `RecycleItem(path, …, true)` for any source archive. Top-level and nested clean-success source handling uses Recycle Bin (`delete := false`) only; permanent cleanup is limited to SmartZip-created `tempDir`.
- Do not use `folderSize` / `succesSpercent` anywhere in this path
- Do not edit `Run7z` body, GUI pause, or `lib/ArchiveDiagnostics.ahk`
- Do not show diagnostic **window** (Task 7); only write `SmartZip-诊断.txt` on partial
- Leave post-`zipx` `AfterUnzip` / single-multi `MoveItem` loop unchanged for OK / OK_WITH_WARNING (temp still present); failure partial must remove/rename temp so empty-temp continue still works

- [ ] **Step 4: Run focused GREEN + full regression**

```powershell
$staticFocused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName 'ExtractionLifecycleSafety' -PassThru
"STATIC_FOCUSED Passed=$($staticFocused.PassedCount) Failed=$($staticFocused.FailedCount) Total=$($staticFocused.TotalCount)"
if ($staticFocused.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=12, FailedCount=0

$static = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
"STATIC Passed=$($static.PassedCount) Failed=$($static.FailedCount) Total=$($static.TotalCount)"
if ($static.PassedCount -ne 108 -or $static.FailedCount -ne 0) { exit 1 }
# Expected: 96 (Tasks 0–4) + 12 ExtractionLifecycleSafety = 108

$beh = Invoke-Pester -Script .\tests\ExtractionLifecycle.Tests.ps1 -PassThru
"LIFE_BEH Passed=$($beh.PassedCount) Failed=$($beh.FailedCount) Total=$($beh.TotalCount)"
if ($beh.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=26 (1 harness-exit + 25 named cases), FailedCount=0

$pw = Invoke-Pester -Script .\tests\PasswordPreflight.Tests.ps1 -PassThru
"PW Passed=$($pw.PassedCount) Failed=$($pw.FailedCount) Total=$($pw.TotalCount)"
if ($pw.PassedCount -ne 70 -or $pw.FailedCount -ne 0) { exit 1 }

$cap = Invoke-Pester -Script .\tests\RunCmdCapture.Tests.ps1 -PassThru
"CAP Passed=$($cap.PassedCount) Failed=$($cap.FailedCount) Total=$($cap.TotalCount)"
if ($cap.PassedCount -ne 15 -or $cap.FailedCount -ne 0) { exit 1 }

$diag = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
"DIAG Passed=$($diag.PassedCount) Failed=$($diag.FailedCount) Total=$($diag.TotalCount)"
if ($diag.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=140, FailedCount=0
```

Expected GREEN gates (all required):
- static focused `12/12`
- full static `Passed=108 Failed=0 Total=108`
- ExtractionLifecycle behavior `Passed=26 Failed=0 Total=26`
- PasswordPreflight `Passed=70 Failed=0 Total=70`
- RunCmdCapture `Passed=15 Failed=0 Total=15`
- ArchiveDiagnostics `Passed=140 Failed=0 Total=140`

- [ ] **Step 5: `git diff --check` and focused commit**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1 `
    tests/ExtractionLifecycle.Harness.ahk tests/ExtractionLifecycle.Tests.ps1
git diff --check --cached
git diff --cached --stat
git commit -m "feat: gate extract success without size heuristic and isolate partial output"
```

Expected: no whitespace errors; commit contains only the four files above; no `lib/ArchiveDiagnostics.ahk` classifier churn; no GUI/exactPid rewrites except unavoidable context.

Verify:

```powershell
git show --stat --oneline HEAD
git show HEAD -- SmartZip.ahk | Select-String -Pattern '^\+\s*ExtractArchiveToTemp|^\+\s*FinalizeExtraction|^\+\s*WriteDiagnostic|^\-\s*.*IsSuccess|^\-\s*.*succesSpercent|^\+\s*.*解压不完整|^\-\s*.*exactPid|^\+\s*.*exactPid|^\-\s*.*ButtonPause|^\+\s*.*ButtonPause'
```

Expected: additions for extract/finalize/diagnostic file; removal of `IsSuccess` size gate; zero pause/exactPid product changes.

- [ ] **Step 6: Independent read-only review gate**

Dispatch a fresh read-only reviewer against this task’s commit with design §5–6 and Canonical Interfaces. The reviewer must verify:

- clean success only when extract `exitCode = 0` and status `OK` (required preflight stages already `OK`); `successPercent`/output-size never authorizes success or source handling
- `OK_WITH_WARNING` keeps/moves usable output and **always** preserves source
- failure+output → `<name>_解压不完整_<yyyyMMdd-HHmmss>` + redacted `SmartZip-诊断.txt`; failure empty → remove empty TEMP only
- executable regression intent: exit 2 + CRC/`DATA_CORRUPT` + large output still preserves source (no size override)
- top-level source: Recycle Bin only on clean success when `mayDeleteSource`; warning/failure/cancel never source-handle; volume members never deleted
- nested source handling only after nested clean success, through Recycle Bin (`delete := false`); no source archive is permanently deleted
- static `108/108`, lifecycle `26/26`, password `70/70`, capture `15/15`, diagnostics `140/140`
- `Run7z` 7zG/exact-PID/pause unchanged; no Task 7 diagnostic window

Require:

```text
Critical=0
Important=0
```

If either count is non-zero: fix only Task 5 files (`SmartZip.ahk` extract/finalize/zipx regions + lifecycle tests/static Its), re-run Step 4–5, re-review until both are zero. Task 5 is incomplete until this gate passes.

### Task 6: Strict Nesting, Settings Migration, and Deprecated Size Heuristic

**Files:**
- Modify: `SmartZip.ahk` — rewrite `IsArchive` empty-ext + keep exact/`extExp` as **candidate hints only**; add class method `IsNestedArchiveCandidate(path, ext)` (immediately after `IsArchive`); rewrite nested `UnZipNesting` to candidate-gate + `DetectVolumeGroup` + mandatory `ProbeArchive` before nested `Unzip`, and **remove** legacy time/size/`!exitCode` nested source delete (Task 5 `zipx` owns nested clean-OK Recycle-Bin handling); verify and retain Task 5's `TestArchive` gate where `test=1` always tests and `test=0` still forces `TestArchive` whenever this run may handle source; stop reading `ini.successPercent` / `this.succesSpercent` in `Unzip`; remove settings `GuiUpDownEdit("successPercent", "判断解压成功百分比", …)`; add one script-level idempotent `MigrateDeprecatedExtExp` that removes only case-sensitive exact `extExp` values `zi`, `7`, `z` and preserves `ZI`, `^\d+$`, plus every other custom rule; keep `successPercent` in `ini.map` and in new-INI defaults; keep `test` load/`GuiCheckBox("test", …)`
- Modify: `tests/SmartZip.Static.Tests.ps1` — **update in place** `IsArchiveExt` empty-extension It from true→false (and retarget `IsArchiveBody` end marker to `` `n    ProbeArchive(`` when present, else keep existing); append `Describe 'NestingProbeAndMigrationSafety'` after `Describe 'ExtractionLifecycleSafety'`
- Create: `tests/NestingMigration.Harness.ahk` — pure decision/migration harness (uses `DetectVolumeGroup` + `ArchiveStatus` from `lib/ArchiveDiagnostics.ahk`; no 7zG)
- Create: `tests/NestingMigration.Tests.ps1` — Pester 3.4 wrapper
- Do not modify: `lib/ArchiveDiagnostics.ahk` classifier/volume bodies, `RunCmdCapture` body, `Run7z` / `Gui` pause / exact-PID / force-end, `ExtractArchiveToTemp` / `FinalizeExtraction` / `WriteDiagnostic` success rules (Task 5), diagnostic **window** / rotating log (Task 7), edition/`buildVersion`/Ahk2Exe ProductVersion display (Task 9), `README.md`/`ini.md` prose (Task 9)

**Interfaces:**
- Consumes:
  - Task 1–2: `ArchiveStatus`, `ArchiveResult`, `DetectVolumeGroup(path, siblingNames)`, `Classify7zResult`, `RedactDiagnostic`
  - Task 3–4: `RunCmdCapture`, `ProbeArchive`, `TestArchive`, `ResolveArchivePassword`
  - Task 5: `ExtractArchiveToTemp`, `FinalizeExtraction`, nested clean-OK Recycle-Bin path in `zipx` (`loopPath && extractResult.isCleanSuccess && !volume.isVolume`, `delete := false`)
  - Existing: `this.ext` (Map), `this.extExp` (Array), `this.nesting` / `this.nestingMuilt`, `this.test`, `this.delSource`, `this.delWhenHasPass`, `this.partSkip`, `ini` Read/Write/Delete/ReadLoop, settings `GuiCheckBox` / `GuiUpDownEdit` / `GuiComboBox`
- Produces / hard rules (design §8 + §12):
  - `SmartZip.IsArchive(ext) => Boolean`
    - `ext := StrLower(ext)`
    - **empty extension → `false`** (no longer auto-archive)
    - exact: `this.ext.Has(ext)` → `true` (candidate hint)
    - else each `this.extExp` regex `ext ~= "i)" i` → `true` (candidate hint only; never authorizes extract alone)
    - else `false`
  - `SmartZip.IsNestedArchiveCandidate(path, ext) => Boolean`
    - `true` if `IsArchive(ext)`
    - else build sibling file-name list from `path`’s directory and `DetectVolumeGroup(path, siblingNames).isVolume` → `true`
    - else `false`
    - **Custom regex / exact ext / volume pattern only nominate candidates**; nested extract path **must** call `ProbeArchive` before `Unzip`/`zipx` extract work
  - Top-level user-selected paths in `Unzip`/`zipx` **already** always `ProbeArchive` (Task 4) — do not add extension veto on top-level
  - `UnZipNesting(path, ext)`:
    1. if `!IsNestedArchiveCandidate(path, ext)` → return
    2. volume: if `DetectVolumeGroup(…).isVolume` and not first (or `partSkip` non-first semantics already handled by caller) → do not delete any volume; non-first may return without nested re-entry when appropriate
    3. `probe := this.ProbeArchive(path)`; if status is definitive non-archive / hard fail that should not recurse (`NOT_ARCHIVE`, `UNSUPPORTED_METHOD`, `HEADER_CORRUPT`, `TRUNCATED`, `DATA_CORRUPT`, `IO_ERROR`, `UNKNOWN_ERROR`, `MISSING_VOLUME`, `CANCELLED`) → return without nested `Unzip`
    4. allow continue into nested `Unzip(path)` when probe is `OK`, `OK_WITH_WARNING`, `NEED_PASSWORD`, or `WRONG_PASSWORD` (password path owned by Task 4 `ResolveArchivePassword` inside nested `zipx`)
    5. **do not** handle nested source here on time/size/`!exitCode`; nested source goes to the Recycle Bin only via Task 5 clean-`OK` path; **never** on warning/failure; **volumes never deleted**
  - `zipx` pre-extract test gate (after `resolved` is `OK` or `OK_WITH_WARNING`, before `ExtractArchiveToTemp`):
    - `mayHandleSource := (!loopPath) && !volume.isVolume && (this.delSource || (resolved.passwordUsed != "" && this.delWhenHasPass))`
    - `nestedMayRecycle := loopPath && !volume.isVolume && resolved.status = ArchiveStatus.OK`
    - `forceTest := this.test || mayHandleSource || nestedMayRecycle`  ; **`test=0` still forces `TestArchive` before any top-level or nested source handling**
    - if `forceTest`: `tr := this.TestArchive(path, resolved.passwordUsed)`; on `OK_WITH_WARNING` continue extract but force both `mayHandleSource := false` and `nestedMayRecycle := false` for this run; on any other non-`OK` → do not extract, preserve source; on `OK` continue
    - if `!forceTest`: extract may proceed without extra full test (probe/password already done)
  - Settings / INI:
    - **keep** `successPercent` key in `ini.map` and new-install `ini.setWrite("successPercent", 90)` — **stop reading** it (`Unzip` must not assign `this.succesSpercent := ini.successPercent`; no other runtime read)
    - **remove** settings control labeled `判断解压成功百分比` (`GuiUpDownEdit("successPercent", …)`)
    - **keep** `test` key, `this.test := ini.test`, and `GuiCheckBox("test", …)`
    - migration removes **only** case-sensitive exact `extExp` entry values equal to lowercase `zi`, `7`, or `z` (`==`, not substring or case-insensitive `=`); **preserve** `ZI`, `^\d+$`, and all other custom rules; renumber remaining `extExp` indices contiguously; **do not** rewrite unrelated INI sections/keys (passwords, `zipDir`, nesting, delete, menus, etc. stay byte/logically unchanged)
    - new-install defaults: still write `^\d+$` as first `extExp`; **do not** write `zi`/`7`/`z` as defaults anymore

- [ ] **Step 1: Write failing static tests + harness/wrapper; patch empty-ext static It**

**1a.** In `tests/SmartZip.Static.Tests.ps1`, update `IsArchiveBody` slice end marker to stop before password methods when present:

```powershell
$script:IsArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    IsArchive(ext)" -EndMarker "`n    IsNestedArchiveCandidate("
if ([string]::IsNullOrEmpty($script:IsArchiveBody)) {
    $script:IsArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    IsArchive(ext)" -EndMarker "`n    ProbeArchive("
}
if ([string]::IsNullOrEmpty($script:IsArchiveBody)) {
    $script:IsArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    IsArchive(ext)" -EndMarker "`n    RunCmdCapture("
}
if ([string]::IsNullOrEmpty($script:IsArchiveBody)) {
    $script:IsArchiveBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    IsArchive(ext)" -EndMarker "`n    RunCmd("
}
```

Replace the existing empty-extension It **exactly** (same Describe `IsArchiveExt`, same position) with:

```powershell
    It 'returns false when extension is empty' {
        $ok = Test-Regex -Text $script:IsArchiveBody -Pattern `
            '(?s)if\s*!ext\s+return\s+false'
        $ok | Should Be $true
        $bad = Test-Regex -Text $script:IsArchiveBody -Pattern `
            '(?s)if\s*!ext\s+return\s+true'
        $bad | Should Be $false
    }
```

**1b.** Append after `Describe 'ExtractionLifecycleSafety'` exactly:

```powershell
$script:IsNestedArchiveCandidateBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`n    IsNestedArchiveCandidate(" -EndMarker "`n    ProbeArchive("
if ([string]::IsNullOrEmpty($script:IsNestedArchiveCandidateBody)) {
    $script:IsNestedArchiveCandidateBody = Get-SourceSlice -Source $script:SmartZipSource `
        -StartMarker "`n    IsNestedArchiveCandidate(" -EndMarker "`n    RunCmdCapture("
}
$script:UnZipNestingBody = ""
if ($script:UnzipBody -match '(?s)(UnZipNesting\s*\([^\)]*\)\s*\{.*?\n        \})') {
    $script:UnZipNestingBody = $matches[1]
}
$script:IniCreateBody = ""
if ($script:SmartZipSource -match '(?s)(IniCreate\s*\(\s*\)\s*\{.*\n\})') {
    $script:IniCreateBody = $matches[1]
}
$script:MigrateDeprecatedExtExpBody = Get-SourceSlice -Source $script:SmartZipSource `
    -StartMarker "`nMigrateDeprecatedExtExp()" -EndMarker "`nIniCreate()"
$script:SettingsGuiRegion = ""
# Settings live in Set() / settings GUI block; use whole source for control assertions
$script:SettingsGuiRegion = $script:SmartZipSource

Describe 'NestingProbeAndMigrationSafety' {

    It 'IsNestedArchiveCandidate method exists after IsArchive' {
        [string]::IsNullOrEmpty($script:IsNestedArchiveCandidateBody) | Should Be $false
        $a = $script:SmartZipSource.IndexOf("`n    IsArchive(ext)")
        $c = $script:SmartZipSource.IndexOf("`n    IsNestedArchiveCandidate(")
        ($a -ge 0 -and $c -gt $a) | Should Be $true
    }

    It 'IsArchive empty extension returns false not true' {
        $script:IsArchiveBody | Should Match '(?s)if\s*!ext\s+return\s+false'
        $script:IsArchiveBody | Should Not Match '(?s)if\s*!ext\s+return\s+true'
    }

    It 'IsArchive still uses exact ext map and extExp regex only as hints' {
        $script:IsArchiveBody | Should Match 'this\.ext\.Has\(\s*ext\s*\)'
        $script:IsArchiveBody | Should Match 'this\.extExp'
        $script:IsArchiveBody | Should Match 'ext\s*~='
    }

    It 'IsNestedArchiveCandidate uses IsArchive and DetectVolumeGroup' {
        $b = $script:IsNestedArchiveCandidateBody
        $b | Should Match 'IsArchive\s*\('
        $b | Should Match 'DetectVolumeGroup\s*\('
    }

    It 'UnZipNesting gates on candidate then ProbeArchive before nested Unzip' {
        $b = $script:UnZipNestingBody
        [string]::IsNullOrEmpty($b) | Should Be $false
        ($b -match 'IsNestedArchiveCandidate\s*\(|IsArchive\s*\(') | Should Be $true
        $b | Should Match 'ProbeArchive\s*\('
        $b | Should Match 'Unzip\s*\('
        # ProbeArchive must appear before nested Unzip call in the function body
        $p = $b.IndexOf('ProbeArchive')
        $u = $b.LastIndexOf('Unzip(')
        ($p -ge 0 -and $u -gt $p) | Should Be $true
    }

    It 'UnZipNesting does not legacy-delete on time size or bare exitCode success' {
        $b = $script:UnZipNestingBody
        $b | Should Not Match 'FileGetTime\s*\(\s*path\s*\)\s*,\s*sizeSave\s*:=\s*FileGetSize'
        $b | Should Not Match 'FileGetTime\s*\(\s*path\s*\)\s*=\s*timeSave'
        $b | Should Not Match '(?s)if\s*!this\.exitCode\s*&&\s*part\s*='
    }

    It 'UnZipNesting volume path never RecycleItem deletes volumes' {
        $b = $script:UnZipNestingBody
        # Must consult DetectVolumeGroup or explicit volume guard; must not RecycleItem volume members
        ($b -match 'DetectVolumeGroup\s*\(|isVolume|part\s*=') | Should Be $true
        # No unconditional RecycleItem(path) after nested unzip without OK/isCleanSuccess gate in this helper
        $bad = Test-Regex -Text $b -Pattern 'RecycleItem\s*\(\s*path\s*,\s*A_LineNumber\s*\)\s*$'
        # UnZipNesting itself performs no source RecycleItem (Task 5 zipx owns clean-OK recycle).
        $b | Should Not Match 'RecycleItem\s*\(\s*path'
    }

    It 'zipx forces TestArchive before top-level or nested source handling even if test is 0' {
        $u = $script:UnzipBody
        $u | Should Match 'TestArchive\s*\('
        $u | Should Match 'this\.test'
        $u | Should Match 'delSource|delWhenHasPass'
        $u | Should Match 'nestedMayRecycle'
        # must not skip test solely because test flag is false when delete is enabled
        ($u -match 'forceTest|this\.test\s*\|\||mayHandleSource|mayDel') | Should Be $true
    }

    It 'Unzip no longer assigns succesSpercent from ini.successPercent' {
        $script:UnzipBody | Should Not Match 'succesSpercent\s*:=\s*ini\.successPercent'
        $script:UnzipBody | Should Not Match 'this\.succesSpercent\s*:=\s*ini\.successPercent'
    }

    It 'successPercent key remains in ini map and new-install default still written' {
        $script:SmartZipSource | Should Match 'successPercent\s*:'
        $script:IniCreateBody | Should Match 'setWrite\s*\(\s*"successPercent"'
    }

    It 'settings UI removes 判断解压成功百分比 control but keeps test checkbox' {
        $script:SettingsGuiRegion | Should Not Match '判断解压成功百分比'
        $script:SettingsGuiRegion | Should Not Match 'GuiUpDownEdit\s*\(\s*"successPercent"'
        $script:SettingsGuiRegion | Should Match 'GuiCheckBox\s*\(\s*"test"'
    }

    It 'migration removes only exact extExp values zi 7 z and preserves digit regex default' {
        $b = $script:IniCreateBody
        $m = $script:MigrateDeprecatedExtExpBody
        [string]::IsNullOrEmpty($b) | Should Be $false
        [string]::IsNullOrEmpty($m) | Should Be $false
        # Must still seed ^\d+$ for new installs
        $b | Should Match '\\\^\\d\+\$|"\^\\d\+\$"'
        # Must not seed broad zi/7/z as new defaults
        $b | Should Not Match 'Write\s*\(\s*"zi"\s*,\s*2\s*,\s*"extExp"\s*\)'
        $b | Should Not Match 'Write\s*\(\s*"7"\s*,\s*3\s*,\s*"extExp"\s*\)'
        $b | Should Not Match 'Write\s*\(\s*"z"\s*,\s*4\s*,\s*"extExp"\s*\)'
        # IniCreate invokes the script-level migration; its body filters exact tokens.
        $b | Should Match 'MigrateDeprecatedExtExp\s*\('
        $m | Should Match 'var\s*==\s*"zi"'
        $m | Should Match 'var\s*==\s*"7"'
        $m | Should Match 'var\s*==\s*"z"'
    }

    It 'migration does not rewrite unrelated INI sections wholesale' {
        $b = $script:MigrateDeprecatedExtExpBody
        # Forbid wiping entire password/ext sections blindly; migration should target extExp indices only
        $b | Should Not Match 'IniDelete\s*\(\s*this\.path\s*,\s*"password"\s*\)'
        $b | Should Not Match 'FileDelete\s*\(\s*ini\.path\s*\)'
        $b | Should Match 'extExp'
    }

    It 'nested clean OK source recycle remains only in zipx lifecycle and is never permanent' {
        $u = $script:UnzipBody
        $u | Should Match 'loopPath'
        $u | Should Match 'isCleanSuccess|ArchiveStatus\.OK'
        # Warning must not authorize nested handling; source paths never use delete:=true.
        $u | Should Match 'OK_WITH_WARNING'
        $u | Should Match 'nestedMayRecycle\s*:=\s*false'
        $u | Should Not Match 'RecycleItem\s*\(\s*path\s*,[^\n]*true'
    }
}
```

**1c.** Create `tests/NestingMigration.Harness.ahk` with exactly:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\..\lib\ArchiveDiagnostics.ahk

outPath := A_Args.Length >= 1 ? A_Args[1] : A_Temp "\NestingMigration.out.txt"
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
AssertFalse(cond, name) => AssertEq(cond ? "1" : "0", "0", name)

; Mirrors product IsArchive (Task 6)
IsArchiveExt(ext, extMap, extExp) {
    ext := StrLower(ext)
    if !ext
        return false
    if extMap.Has(ext)
        return true
    for i in extExp
        if ext ~= "i)" i
            return true
    return false
}

IsNestedArchiveCandidate(path, ext, extMap, extExp, siblingNames) {
    if IsArchiveExt(ext, extMap, extExp)
        return true
    g := DetectVolumeGroup(path, siblingNames)
    return g.isVolume
}

; Migration: remove only case-sensitive exact lowercase zi / 7 / z
MigrateDeprecatedExtExp(rules) {
    out := []
    for r in rules {
        if (r == "zi" || r == "7" || r == "z")
            continue
        out.Push(r)
    }
    return out
}

; Nested source action (product: Task 5 zipx + Task 6 guards)
NestedSourceAction(status, isNested, isVolumeMember) {
    if (!isNested || isVolumeMember)
        return "none"
    if (status = ArchiveStatus.OK)
        return "recycle_nested"
    return "none"
}

; test=0 still forces TestArchive before source handling
ShouldForceTestArchive(testFlag, mayHandleSource, nestedMayRecycle := false) {
    return (testFlag ? true : false) || (mayHandleSource ? true : false)
        || (nestedMayRecycle ? true : false)
}

ShouldEnterNestedAfterProbe(status) {
    return status = ArchiveStatus.OK
        || status = ArchiveStatus.OK_WITH_WARNING
        || status = ArchiveStatus.NEED_PASSWORD
        || status = ArchiveStatus.WRONG_PASSWORD
}

extMap := Map("zip", true, "7z", true, "rar", true, "001", true)
extExp := ["^\d+$", "zi", "7", "z", "ZI", "custom$"]

; 1) empty extension is not archive / not auto candidate
AssertFalse(IsArchiveExt("", extMap, extExp), "empty_ext_not_archive")
AssertFalse(IsNestedArchiveCandidate("C:\\t\\file", "", extMap, extExp, ["file"]), "empty_ext_not_candidate")

; 2) exact configured extension is candidate hint
AssertTrue(IsArchiveExt("zip", extMap, extExp), "exact_zip_is_candidate")
AssertTrue(IsArchiveExt("7Z", extMap, extExp), "exact_7z_casefold_candidate")

; 3) custom regex is candidate hint only (still just nomination)
AssertTrue(IsArchiveExt("123", extMap, extExp), "digit_regex_candidate")
AssertTrue(IsArchiveExt("mycustom", extMap, ["custom$"]), "custom_regex_candidate")
AssertFalse(IsArchiveExt("nope", extMap, ["custom$"]), "custom_regex_non_match")

; 4) volume pattern is candidate even when ext not in map
sibs := ["pack.7z.001", "pack.7z.002"]
AssertTrue(IsNestedArchiveCandidate("C:\\v\\pack.7z.001", "001", Map(), [], sibs), "volume_pattern_candidate")
g := DetectVolumeGroup("C:\\v\\pack.7z.001", sibs)
AssertTrue(g.isVolume, "volume_detect_is_volume")
AssertTrue(g.selectedIsFirst, "volume_detect_first")

; 5) migration removes only zi, 7, z
migrated := MigrateDeprecatedExtExp(extExp)
AssertEq(migrated.Length, 3, "migrate_count_three_kept")
AssertEq(migrated[1], "^\d+$", "migrate_keeps_digit_regex")
AssertTrue(migrated[2] == "ZI" && migrated[3] == "custom$", "migrate_keeps_other_custom")
for r in migrated {
    AssertFalse(r == "zi", "migrate_no_zi")
    AssertFalse(r == "7", "migrate_no_7")
    AssertFalse(r == "z", "migrate_no_z")
}

; 6) migration preserves order of non-matching rules and leaves unrelated alone
onlyCustom := MigrateDeprecatedExtExp(["foo", "zi", "bar", "7", "z", "baz"])
AssertEq(onlyCustom.Length, 3, "migrate_preserves_three_customs")
AssertEq(onlyCustom[1], "foo", "migrate_order_foo")
AssertEq(onlyCustom[2], "bar", "migrate_order_bar")
AssertEq(onlyCustom[3], "baz", "migrate_order_baz")

; 7) nested source recycle only for nested OK; never permanent, warn/fail, or volumes
AssertEq(NestedSourceAction(ArchiveStatus.OK, true, false), "recycle_nested", "nested_ok_recycles")
AssertEq(NestedSourceAction(ArchiveStatus.OK_WITH_WARNING, true, false), "none", "nested_warn_preserves")
AssertEq(NestedSourceAction(ArchiveStatus.DATA_CORRUPT, true, false), "none", "nested_fail_preserves")
AssertEq(NestedSourceAction(ArchiveStatus.OK, true, true), "none", "nested_volume_never_deletes")
AssertEq(NestedSourceAction(ArchiveStatus.OK, false, false), "none", "top_level_not_nested_delete_here")

; 8) test flag vs source-handling force
AssertTrue(ShouldForceTestArchive(1, false), "test1_always_forces_test")
AssertTrue(ShouldForceTestArchive(0, true), "test0_forces_test_before_source_handle")
AssertTrue(ShouldForceTestArchive(0, false, true)
    && !ShouldForceTestArchive(0, false, false), "test0_nested_forces_and_nohandle_skips")

; 9) Candidate hint is not authority: product fragment must additionally prove call order.
AssertTrue(ShouldEnterNestedAfterProbe(ArchiveStatus.OK)
    && ShouldEnterNestedAfterProbe(ArchiveStatus.NEED_PASSWORD)
    && !ShouldEnterNestedAfterProbe(ArchiveStatus.NOT_ARCHIVE)
    && !ShouldEnterNestedAfterProbe(ArchiveStatus.HEADER_CORRUPT),
    "nested_requires_probe_stage_before_extract")

summary := "SUMMARY passed=" passCount " failed=" failCount
lines.Push(summary)
text := ""
for line in lines
    text .= line "`r`n"
try FileDelete(outPath)
FileAppend(text, outPath, "UTF-8")
ExitApp(failCount > 0 ? 1 : 0)
```

**1d.** Create `tests/NestingMigration.Tests.ps1` with exactly:

```powershell
#requires -Version 5.0
$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:HarnessPath = Join-Path $PSScriptRoot 'NestingMigration.Harness.ahk'
$script:AhkExe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'

function Export-NestingMigrationProductHarness {
    # Required implementation contract (no oracle fallback):
    # - Slice exact product IsArchive + IsNestedArchiveCandidate methods,
    #   exact UnZipNesting helper, script-level MigrateDeprecatedExtExp, and
    #   the zipx block from mayHandleSource through FinalizeExtraction.
    # - Throw unless each region occurs exactly once.
    # - Generate a TEMP host with INI/probe/volume/recycle spies and the same
    #   29 named keys; never copy IsArchiveExt, NestedSourceAction,
    #   ShouldForceTestArchive, or ShouldEnterNestedAfterProbe from the oracle.
    # - For nested_requires_probe_stage_before_extract, the product host spy
    #   must record call order ["candidate","probe","unzip"] for OK and
    #   ["candidate","probe"] for NOT_ARCHIVE, with no unzip call.
    $productHarness = New-NestingMigrationProductHost `
        -SmartZipPath (Join-Path $script:RepoRoot 'SmartZip.ahk') `
        -OutputRoot (Join-Path $env:TEMP ("SmartZip-Nesting-Product-{0}" -f ([guid]::NewGuid().ToString('N'))))
    if (-not (Test-Path -LiteralPath $productHarness)) { throw 'product nesting harness was not generated' }
    return $productHarness
}

function Invoke-NestingMigrationHarness([string]$HarnessPath, [string]$Label) {
    $outFile = Join-Path $env:TEMP ("NestingMigration.{0}.{1}.out.txt" -f $Label,([guid]::NewGuid().ToString('N')))
    $p = Start-Process -FilePath $script:AhkExe -ArgumentList @('/ErrorStdOut', $HarnessPath, $outFile) `
        -Wait -PassThru -NoNewWindow
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
    return [pscustomobject]@{ ExitCode = $p.ExitCode; Map = $map }
}

Describe 'NestingMigrationBehavior' {
    BeforeAll {
        $script:OracleRun = Invoke-NestingMigrationHarness $script:HarnessPath 'oracle'
        $script:ProductHarnessPath = Export-NestingMigrationProductHarness
        $script:ProductRun = Invoke-NestingMigrationHarness $script:ProductHarnessPath 'product'
    }

    It 'oracle and product harnesses exit 0' {
        $script:OracleRun.ExitCode | Should Be 0
        $script:ProductRun.ExitCode | Should Be 0
    }

    $cases = @(
        'empty_ext_not_archive',
        'empty_ext_not_candidate',
        'exact_zip_is_candidate',
        'exact_7z_casefold_candidate',
        'digit_regex_candidate',
        'custom_regex_candidate',
        'custom_regex_non_match',
        'volume_pattern_candidate',
        'volume_detect_is_volume',
        'volume_detect_first',
        'migrate_count_three_kept',
        'migrate_keeps_digit_regex',
        'migrate_keeps_other_custom',
        'migrate_no_zi',
        'migrate_no_7',
        'migrate_no_z',
        'migrate_preserves_three_customs',
        'migrate_order_foo',
        'migrate_order_bar',
        'migrate_order_baz',
        'nested_ok_recycles',
        'nested_warn_preserves',
        'nested_fail_preserves',
        'nested_volume_never_deletes',
        'top_level_not_nested_delete_here',
        'test1_always_forces_test',
        'test0_forces_test_before_source_handle',
        'test0_nested_forces_and_nohandle_skips',
        'nested_requires_probe_stage_before_extract'
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
```

- [ ] **Step 2: Run focused tests and confirm RED**

```powershell
$staticFocused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName @('NestingProbeAndMigrationSafety','IsArchiveExt') -PassThru
"STATIC_FOCUSED Passed=$($staticFocused.PassedCount) Failed=$($staticFocused.FailedCount) Total=$($staticFocused.TotalCount)"

$beh = Invoke-Pester -Script .\tests\NestingMigration.Tests.ps1 -PassThru
"BEH Passed=$($beh.PassedCount) Failed=$($beh.FailedCount) Total=$($beh.TotalCount)"
```

Expected RED:
- `IsArchiveExt` empty-extension It fails while product still has `return true` (or slice missing `return false`)
- `NestingProbeAndMigrationSafety` → methods/migration/UI wiring missing → **Failed ≥ 1**, Total=**14**
- NestingMigration harness may already PASS pure decision cases once files exist (uses only `lib/ArchiveDiagnostics.ahk`); if harness missing, wrapper fails. Prefer recording static RED on product wiring before implementation.
- Do **not** implement product changes until static RED is recorded

- [ ] **Step 3: Minimal product implementation**

**3a. Replace `IsArchive` and insert `IsNestedArchiveCandidate` immediately after it** (before `ProbeArchive`):

```ahk
    IsArchive(ext)
    {
        ext := StrLower(ext)

        if !ext
            return false

        if this.ext.Has(ext)
            return true

        for i in this.extExp
            if ext ~= "i)" i
                return true

        return false
    }

    IsNestedArchiveCandidate(path, ext)
    {
        if this.IsArchive(ext)
            return true

        SplitPath(path, &name, &dir)
        siblingNames := []
        if DirExist(dir) {
            loop files dir "\*.*", "F"
                siblingNames.Push(A_LoopFileName)
        }
        g := DetectVolumeGroup(path, siblingNames)
        return g.isVolume
    }
```

**3b. Replace nested `UnZipNesting` body** (inside `Unzip`) with:

```ahk
        UnZipNesting(path, ext)
        {
            if !this.IsNestedArchiveCandidate(path, ext)
                return

            SplitPath(path, &name, &dir)
            siblingNames := []
            if DirExist(dir) {
                loop files dir "\*.*", "F"
                    siblingNames.Push(A_LoopFileName)
            }
            vol := DetectVolumeGroup(path, siblingNames)
            if (vol.isVolume && !vol.selectedIsFirst)
                return  ; never re-enter non-first volumes; volumes never deleted here

            probe := this.ProbeArchive(path)
            switch probe.status
            {
                case ArchiveStatus.OK, ArchiveStatus.OK_WITH_WARNING
                    , ArchiveStatus.NEED_PASSWORD, ArchiveStatus.WRONG_PASSWORD:
                {
                    ; real/possible archive → nested Unzip (password + extract owned by zipx)
                }
                default:
                    return  ; candidate hint only; ProbeArchive rejected nested extract
            }

            this.exitCode := -1
            this.Unzip(path)
            this.Loging("解压嵌套 <--> " path, A_LineNumber)
            ; Nested source recycle only after nested clean OK — Task 5 zipx.
            ; Never handle it here on warning/failure/volume, and never permanently delete a source.
        }
```

**3c. Verify Task 5's forced-test gate in `zipx`**, after password resolve accepts `OK` / `OK_WITH_WARNING` and before `ExtractArchiveToTemp`. The product must already contain this exact logic; do not insert a second copy:

```ahk
            ; Full test: test=1 always; test=0 still forces TestArchive before source handling
            mayHandleSource := (!loopPath) && !volume.isVolume
                && (this.delSource || (resolved.passwordUsed != "" && this.delWhenHasPass))
            nestedMayRecycle := loopPath && !volume.isVolume
                && (resolved.status = ArchiveStatus.OK)
            forceTest := this.test || mayHandleSource || nestedMayRecycle
            if (forceTest) {
                tr := this.TestArchive(path, resolved.passwordUsed)
                if (tr.status = ArchiveStatus.OK_WITH_WARNING) {
                    mayHandleSource := false
                    nestedMayRecycle := false
                } else if (tr.status != ArchiveStatus.OK) {
                    this.error := true
                    if (tr.status = ArchiveStatus.CANCELLED)
                        this.exitCode := 255
                    return
                }
            }

            extractResult := this.ExtractArchiveToTemp(path, resolved.passwordUsed, tmpDir)

            mayDel := false
            if (resolved.status = ArchiveStatus.OK
                && extractResult.status = ArchiveStatus.OK
                && extractResult.exitCode = 0
                && !volume.isVolume
                && mayHandleSource) {
                if (loopPath)
                    mayDel := false
                else if (this.delSource || (resolved.passwordUsed != "" && this.delWhenHasPass))
                    mayDel := true
            }

            extractResult := this.FinalizeExtraction(path, extractResult, tmpDir, A_WorkingDir, mayDel)

            if (nestedMayRecycle && extractResult.isCleanSuccess && !volume.isVolume && FileExist(path))
                this.RecycleItem(path, A_LineNumber, false)
```

If Task 5 already inserted an equivalent extract block, **merge** only the `forceTest` / `TestArchive` / `mayHandleSource` gating — do not duplicate `ExtractArchiveToTemp` / `FinalizeExtraction`.

**3d. Stop reading `successPercent` in `Unzip` init** — delete this line only:

```ahk
            this.succesSpercent := ini.successPercent
```

Do **not** remove `successPercent` from `ini.map` or from new-install writes.

**3e. Remove settings control** — delete the single settings line:

```ahk
    GuiUpDownEdit("successPercent", "判断解压成功百分比", ini.successPercent, 100, "部分文件可能解压后大小会小于源文件`n只要解压到一定百分比就判断解压成功", "xs")
```

Keep surrounding `hideRunSize` / log buttons / `GuiCheckBox("test", …)` unchanged.

**3f. `IniCreate` migration + new defaults** — replace the new-install `extExp` seed block:

```ahk
        ini.Write("^\d+$", 1, "extExp")
        ini.Write("zi", 2)
        ini.Write("7", 3)
        ini.Write("z", 4)
```

with:

```ahk
        ini.Write("^\d+$", 1, "extExp")
```

Define exactly one script-level `MigrateDeprecatedExtExp` immediately before `IniCreate`, using the implementation below. Call it once inside `IniCreate` immediately before the final `if VersionsCompare(buildVersion) ini.setWrite("version", buildVersion)` block. Do not also define a nested copy.

```ahk
MigrateDeprecatedExtExp()
{
    kept := []
    idx := 0
    loop
    {
        if !(var := ini.Read(A_Index, , "extExp"))
            break
        idx := A_Index
        if (var == "zi" || var == "7" || var == "z")
            continue
        kept.Push(var)
    }
    if !idx
        return
    hadDeprecated := false
    loop idx
    {
        var := ini.Read(A_Index, , "extExp")
        if (var == "zi" || var == "7" || var == "z") {
            hadDeprecated := true
            break
        }
    }
    if !hadDeprecated
        return
    loop idx
        ini.Delete("extExp", A_Index)
    for i, rule in kept
        ini.Write(rule, i, "extExp")
}
```

and call `MigrateDeprecatedExtExp()` at the end of `IniCreate` (always; idempotent). **Do not** delete or rewrite `password`, `set`, `menu`, `7z`, or other sections. **Do not** remove the `successPercent` key from existing INIs.

Hard constraints:
- Empty extension must not be treated as archive
- Nested candidate = exact ext **or** supported volume **or** custom `extExp` regex; then **must** `ProbeArchive` before nested extract
- Nested source recycle only for nested clean `OK` (Task 5 `zipx`, `delete := false`); never on warning/failure; volumes never handled; source archives are never permanently deleted
- Migration case-sensitive exact-match only on lowercase `zi` / `7` / `z`; preserve `ZI`
- Keep `successPercent` key; stop reading; remove UI label `判断解压成功百分比`
- Keep `test`; `test=0` still forces `TestArchive` when source handling is possible
- Preserve all other INI values byte/logically unchanged
- Do not edit `Run7z` / GUI pause / exact-PID / classifier library / Task 7 diagnostics window

- [ ] **Step 4: Run focused GREEN + full regression**

```powershell
$staticFocused = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 `
    -TestName @('NestingProbeAndMigrationSafety','IsArchiveExt') -PassThru
"STATIC_FOCUSED Passed=$($staticFocused.PassedCount) Failed=$($staticFocused.FailedCount) Total=$($staticFocused.TotalCount)"
if ($staticFocused.FailedCount -ne 0) { exit 1 }
# Expected: NestingProbeAndMigrationSafety TotalCount=14 FailedCount=0;
#           IsArchiveExt empty-ext It green (suite still 7 Its inside IsArchiveExt)

$static = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
"STATIC Passed=$($static.PassedCount) Failed=$($static.FailedCount) Total=$($static.TotalCount)"
if ($static.PassedCount -ne 122 -or $static.FailedCount -ne 0) { exit 1 }
# Expected: 108 (Tasks 0–5) + 14 NestingProbeAndMigrationSafety = 122
# (IsArchiveExt empty It updated in place — no net add/remove)

$beh = Invoke-Pester -Script .\tests\NestingMigration.Tests.ps1 -PassThru
"NEST_BEH Passed=$($beh.PassedCount) Failed=$($beh.FailedCount) Total=$($beh.TotalCount)"
if ($beh.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=30 (1 harness-exit + 29 named cases), FailedCount=0

$life = Invoke-Pester -Script .\tests\ExtractionLifecycle.Tests.ps1 -PassThru
"LIFE_BEH Passed=$($life.PassedCount) Failed=$($life.FailedCount) Total=$($life.TotalCount)"
if ($life.PassedCount -ne 26 -or $life.FailedCount -ne 0) { exit 1 }

$pw = Invoke-Pester -Script .\tests\PasswordPreflight.Tests.ps1 -PassThru
"PW Passed=$($pw.PassedCount) Failed=$($pw.FailedCount) Total=$($pw.TotalCount)"
if ($pw.PassedCount -ne 70 -or $pw.FailedCount -ne 0) { exit 1 }

$cap = Invoke-Pester -Script .\tests\RunCmdCapture.Tests.ps1 -PassThru
"CAP Passed=$($cap.PassedCount) Failed=$($cap.FailedCount) Total=$($cap.TotalCount)"
if ($cap.PassedCount -ne 15 -or $cap.FailedCount -ne 0) { exit 1 }

$diag = Invoke-Pester -Script .\tests\ArchiveDiagnostics.Tests.ps1 -PassThru
"DIAG Passed=$($diag.PassedCount) Failed=$($diag.FailedCount) Total=$($diag.TotalCount)"
if ($diag.FailedCount -ne 0) { exit 1 }
# Expected: TotalCount=140, FailedCount=0
```

Expected GREEN gates (all required):
- static focused `NestingProbeAndMigrationSafety` **14/14** + `IsArchiveExt` green
- full static `Passed=122 Failed=0 Total=122`
- NestingMigration behavior `Passed=30 Failed=0 Total=30`
- ExtractionLifecycle behavior `Passed=26 Failed=0 Total=26`
- PasswordPreflight `Passed=70 Failed=0 Total=70`
- RunCmdCapture `Passed=15 Failed=0 Total=15`
- ArchiveDiagnostics `Passed=140 Failed=0 Total=140`

- [ ] **Step 5: `git diff --check` and focused commit**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1 `
    tests/NestingMigration.Harness.ahk tests/NestingMigration.Tests.ps1
git diff --check --cached
git diff --cached --stat
git commit -m "feat: strict nested probe candidates and deprecate successPercent heuristic"
```

Expected: no whitespace errors; commit contains only the four paths above; no classifier/volume library churn; no GUI pause/exactPid rewrites; no Task 7 diagnostic window; no edition/buildVersion display bump (Task 9).

Verify:

```powershell
git show --stat --oneline HEAD
git show HEAD -- SmartZip.ahk | Select-String -Pattern '^\+\s*IsNestedArchiveCandidate|^\+\s*MigrateDeprecatedExtExp|^\-\s*.*return true|^\+\s*.*return false|^\-\s*.*succesSpercent|^\-\s*.*判断解压成功百分比|^\+\s*.*ProbeArchive|^\+\s*.*forceTest|^\-\s*.*Write\s*\(\s*"zi"|^\-\s*.*exactPid|^\+\s*.*exactPid|^\-\s*.*ButtonPause|^\+\s*.*ButtonPause'
```

Expected: empty-ext false; nested candidate + ProbeArchive; migration strips `zi`/`7`/`z` defaults; successPercent UI/read removed; TestArchive force gate; zero pause/exactPid product changes.

- [ ] **Step 6: Independent read-only review gate**

Dispatch a fresh read-only reviewer against this task’s commit with design §8, §12, and Canonical Interfaces. The reviewer must verify:

- nested candidates = exact ext **or** supported volume via `DetectVolumeGroup` **or** custom `extExp` regex as **hint only**, then **must** `ProbeArchive` before nested extraction
- empty extension is **not** automatically archive (`IsArchive` → false)
- nested source handling only for nested clean `OK`, and only through Recycle Bin; never on warning/failure; source archives are never permanently deleted; volumes are never handled
- migration removes only case-sensitive exact lowercase `extExp` values `zi`, `7`, `z`; preserves `ZI`, `^\d+$`, and all other custom rules; no unrelated INI rewrite
- `successPercent` key kept; runtime no longer reads it; settings control `判断解压成功百分比` removed
- `test` kept; `test=0` still forces `TestArchive` before source handling when `mayHandleSource`
- static `122/122`, nesting behavior `30/30`, lifecycle `26/26`, password `70/70`, capture `15/15`, diagnostics `140/140`
- Task 5 success/partial/Recycle-Bin rules unchanged; no Task 7 window; no Kirs.2 metadata bump yet

Require:

```text
Critical=0
Important=0
```

If either count is non-zero: fix only Task 6 files (`SmartZip.ahk` nesting/settings/migration/`zipx` test-gate regions + nesting tests/static Its), re-run Step 4–5, re-review until both are zero. Task 6 is incomplete until this gate passes.

### Task 7: Diagnostic Window, Batch Summary, and Redacted Rotating Log

**Files:**

- Modify: `SmartZip.ahk`
- Modify: `tests/SmartZip.Static.Tests.ps1`
- Create: `tests/DiagnosticUI.Harness.ahk`
- Create: `tests/DiagnosticUI.Tests.ps1`

**Interfaces:** keep `ShowDiagnostic(result, isBatch := false)` and `WriteDiagnostic(result)` exactly. Add private `SmartZip` methods `DiagnosticTitle`, `DiagnosticReason`, `DiagnosticRecommendation`, `DiagnosticButtons`, `FormatDiagnosticCopy`, `FormatDiagnosticLogEntry`, `RecordBatchDiagnostic`, `ShowBatchDiagnosticSummary`, `AppendRotatingDiagnosticLog`, and `RotateDiagnosticLogIfNeeded`. Do not move GUI or file I/O into pure `lib/ArchiveDiagnostics.ahk`.

- [ ] **Step 1: Add failing static and behavior tests**

In `tests/SmartZip.Static.Tests.ps1`, add `Describe 'DiagnosticUISafety'` with exactly 16 `It` blocks asserting:

1. `WriteDiagnostic` precedes `ShowDiagnostic`, which precedes `RunCmdCapture`.
2. Both required public signatures are unchanged.
3. failure and warning Chinese titles exist.
4. all six labels exist: `打开部分文件目录`, `重新输入密码`, `定位首卷`, `使用 7-Zip 打开`, `复制脱敏诊断信息`, `关闭`.
5. partial-directory action is conditional on a non-empty existing `partialOutputDir`.
6. password retry is limited to `NEED_PASSWORD`/`WRONG_PASSWORD`.
7. locate-first-volume is limited to `MISSING_VOLUME`.
8. batch mode is selected by existing `this.muilt`; only `!loopPath && this.muilt` resets the four buckets and only the outer `Unzip` exit calls one `ShowBatchDiagnosticSummary()`.
9. batch buckets are `success`, `warning`, `failure`, `skipped`.
10. `OK` and `CANCELLED` create neither a diagnostic popup nor a rotating-log entry.
11. warning/failure paths call `WriteDiagnostic`.
12. log names are exactly `SmartZip-diagnostics.log`, `.1`, `.2`.
13. rotation threshold is exactly `1048576` and the writer uses UTF-8.
14. copied diagnostics call `RedactDiagnostic(..., false)`; local log calls it with full paths permitted.
15. `passwordUsed` and clipboard contents are absent from diagnostic composition.
16. every legacy command-log append is wrapped in `RedactDiagnostic`.

Create `tests/DiagnosticUI.Harness.ahk` as a headless adapter around the production formatting/bucketing/rotation helpers. It accepts one command (`reason`, `buttons`, `batch`, `rotate`, `copy`, `log`, `partial`) plus JSON input, writes JSON to stdout, and redirects all GUI/run/clipboard operations to injectable no-op spies. Create `tests/DiagnosticUI.Tests.ps1` with exactly 36 assertions:

- 13 status reason/recommendation mappings (every canonical status);
- 2 title mappings;
- 6 conditional-button cases;
- 4 batch bucket/one-summary cases;
- 2 combined `OK`/`CANCELLED` silence and warning logging cases;
- 3 rotation/max-three-files cases;
- 4 redaction/full-path-vs-basename cases;
- 1 no-password-or-clipboard-leak case;
- 1 partial `SmartZip-诊断.txt` UTF-8 case.

Use these exact 36 case keys so the wrapper count is auditable:

```text
reason_OK, reason_OK_WITH_WARNING, reason_NEED_PASSWORD, reason_WRONG_PASSWORD,
reason_MISSING_VOLUME, reason_NOT_ARCHIVE, reason_UNSUPPORTED_METHOD,
reason_HEADER_CORRUPT, reason_TRUNCATED, reason_DATA_CORRUPT, reason_CANCELLED,
reason_IO_ERROR, reason_UNKNOWN_ERROR,
title_warning, title_failure,
button_partial, button_retry_password, button_locate_first, button_open_7zip,
button_copy_redacted, button_close,
batch_success, batch_warning, batch_failure, batch_skipped_one_summary,
silence_ok_and_cancelled, log_warning,
rotate_at_1mib, rotate_shift_1_to_2, rotate_max_three,
redact_dash_p, copy_basename_only, copy_omits_full_path, log_allows_full_path,
no_password_or_clipboard_leak, partial_utf8_diagnostic
```

Run RED:

```powershell
$redStatic = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($redStatic.TotalCount -ne 138 -or $redStatic.FailedCount -lt 1) {
    throw "expected static RED with 138 discovered and >=1 failure; got Total=$($redStatic.TotalCount) Failed=$($redStatic.FailedCount)"
}
$redUi = Invoke-Pester -Script .\tests\DiagnosticUI.Tests.ps1 -PassThru
if ($redUi.TotalCount -ne 36 -or $redUi.FailedCount -lt 1) {
    throw "expected UI RED with 36 discovered and >=1 failure; got Total=$($redUi.TotalCount) Failed=$($redUi.FailedCount)"
}
```

Expected: static total is 138 with at least one of the 16 new tests failing; behavior suite fails because the helpers/harness are not implemented. Existing baselines remain static `122/122`, nesting `30/30`, lifecycle `26/26`, password `70/70`, capture `15/15`, diagnostics `140/140`.

- [ ] **Step 2: Implement the diagnostic model and state-specific actions**

Before inserting helpers, retarget Task 5's static slice so `$script:WriteDiagnosticBody` ends at `` `n    ShowDiagnostic(`` instead of `` `n    RunCmdCapture(``; add `$script:ShowDiagnosticBody` from `` `n    ShowDiagnostic(`` to `` `n    RunCmdCapture(``. Then insert the helpers after `WriteDiagnostic` and before `RunCmdCapture`. Use this exact behavior table:

| Status | Title | Actions beyond copy/close |
|---|---|---|
| `OK` | none | none |
| `OK_WITH_WARNING` | `SmartZip 解压警告` | use 7-Zip |
| `NEED_PASSWORD`, `WRONG_PASSWORD` | `SmartZip 未完成解压` | retry password; use 7-Zip |
| `MISSING_VOLUME` | `SmartZip 未完成解压` | locate first volume; use 7-Zip |
| `HEADER_CORRUPT`, `TRUNCATED`, `DATA_CORRUPT` | `SmartZip 未完成解压` | open partial directory when present; use 7-Zip |
| `NOT_ARCHIVE`, `UNSUPPORTED_METHOD`, `IO_ERROR`, `UNKNOWN_ERROR` | `SmartZip 未完成解压` | use 7-Zip; open partial directory when present |
| `CANCELLED` | none | none |

Pin the 13 behavior keys to this exact reason/recommendation table; the production fragment and expected JSON must compare exact strings rather than co-inventing free text:

| Status | Reason | Recommendation |
|---|---|---|
| `OK` | `解压成功` | `无需操作。` |
| `OK_WITH_WARNING` | `解压完成，但 7-Zip 返回警告。` | `请检查输出文件，并使用 7-Zip 复核压缩包。` |
| `NEED_PASSWORD` | `压缩包需要密码。` | `请重新输入正确密码后再试。` |
| `WRONG_PASSWORD` | `密码错误。` | `请检查密码并重新输入。` |
| `MISSING_VOLUME` | `分卷不完整，或未从首卷开始。` | `请补齐全部分卷并从首卷重新解压。` |
| `NOT_ARCHIVE` | `文件不是可识别的压缩包。` | `请确认文件类型或使用 7-Zip 打开检查。` |
| `UNSUPPORTED_METHOD` | `当前 7-Zip 不支持此压缩方法。` | `请更新 7-Zip，或使用创建该压缩包的工具。` |
| `HEADER_CORRUPT` | `压缩包文件头损坏。` | `请重新获取完整源文件，并使用 7-Zip 测试。` |
| `TRUNCATED` | `压缩包数据被截断。` | `请重新下载或复制完整文件后再试。` |
| `DATA_CORRUPT` | `CRC 或数据校验失败。` | `请检查“不完整”目录中的可用文件，并重新获取源包。` |
| `CANCELLED` | `操作已取消。` | `无需操作。` |
| `IO_ERROR` | `读取或写入文件失败。` | `请检查磁盘空间、文件占用和目录权限。` |
| `UNKNOWN_ERROR` | `7-Zip 返回未识别错误。` | `请复制脱敏诊断信息，并使用 7-Zip 进一步检查。` |

The reason/recommendation map must cover all 13 statuses. `ShowDiagnostic(result, true)` only calls `RecordBatchDiagnostic(result)` and returns. `ShowDiagnostic(result, false)` returns silently for `OK` and `CANCELLED`; otherwise it opens one modeless AHK v2 `Gui` with archive basename, reason, recommendation, “源包已保留”, optional partial path, and only applicable buttons. Password retry calls the Task 4 password-resolution entry point for that archive; locate-first opens/selects `result.volumeFirst` or the archive directory; use-7-Zip invokes the configured 7-Zip GUI/open command with a quoted archive path.

Use the existing `this.muilt` operation flag as the exact batch selector:

```ahk
isBatch := this.muilt
if (!loopPath && isBatch)
    this.batchDiagnostic := {success: [], warning: [], failure: [], skipped: []}
```

After every terminal/finalized archive path call `ShowDiagnostic(result, isBatch)`. Non-first volume members intentionally skipped by grouping set `result.batchBucket := "skipped"` before that call; `RecordBatchDiagnostic` honors the explicit bucket and otherwise maps `OK→success`, `OK_WITH_WARNING→warning`, `CANCELLED→skipped`, and all remaining statuses→failure. At the outer `Unzip` exit only, execute `if (!loopPath && isBatch) this.ShowBatchDiagnosticSummary()` exactly once; recursive `Unzip(path)` calls never reset or summarize the inherited batch. Password and first-volume interaction may still appear during processing; ordinary result dialogs may not.

`tests/DiagnosticUI.Harness.ahk` must not carry a hand-copied second implementation. In the Pester wrapper, implement `Export-DiagnosticUIProductFragment`: slice the exact production methods starting at `WriteDiagnostic(` (not `DiagnosticTitle(`) through the line before `RunCmdCapture(`, place them in a TEMP `SmartZip` host, and inject spies for GUI, run/open, clipboard write, file existence, UTF-8 append, move/delete, and clock. The exporter throws unless `WriteDiagnostic`, `DiagnosticTitle`, `DiagnosticReason`, `DiagnosticRecommendation`, `ShowDiagnostic`, `AppendRotatingDiagnosticLog`, and `RotateDiagnosticLogIfNeeded` each occur exactly once. The committed harness only parses the command/JSON and calls this generated product host; the wrapper runs all 36 keys above and compares the spy JSON to the expected table. The `partial_utf8_diagnostic`, `log_warning`, all three `rotate_*`, and redaction keys must invoke product `WriteDiagnostic` and its real sink helpers—no shadow writer/oracle is allowed. GREEN therefore requires the production fragment, including partial-file writing, rotating log append, `ShowDiagnostic(result, isBatch := false)`, `RecordBatchDiagnostic`, single-summary outer-call behavior, rotation, and redaction.

- [ ] **Step 3: Extend diagnostics without weakening Task 5**

Keep Task 5's partial-output `SmartZip-诊断.txt`. `WriteDiagnostic(result)` must build only from stable `ArchiveResult` properties other than `passwordUsed`, redact once before any sink, overwrite the partial-directory diagnostic in UTF-8 when applicable, append to the rotating log only for `OK_WITH_WARNING` or hard failure statuses (not `OK` and not `CANCELLED`), and return the redacted string.

Use this exact rotation algorithm:

```ahk
RotateDiagnosticLogIfNeeded(logPath) {
    if !FileExist(logPath) || FileGetSize(logPath) < 1048576
        return
    if FileExist(logPath ".2")
        FileDelete(logPath ".2")
    if FileExist(logPath ".1")
        FileMove(logPath ".1", logPath ".2", 1)
    FileMove(logPath, logPath ".1", 1)
}

AppendRotatingDiagnosticLog(text) {
    logPath := A_ScriptDir "\SmartZip-diagnostics.log"
    this.RotateDiagnosticLogIfNeeded(logPath)
    FileAppend(text "`r`n", logPath, "UTF-8")
}
```

The local log entry includes timestamp, SmartZip version when available, cached 7-Zip version or `unknown`, `stage`, `status`, `exitCode`, full archive path, missing-volume list, warning/error lines, and bounded raw-output excerpt. `FormatDiagnosticCopy` uses `RedactDiagnostic(text, false)` so copied text contains only the archive basename. Never read `A_Clipboard` while composing diagnostics. Wrap every old `cmdLog`/`testLog` command append in `RedactDiagnostic` so `-p...` becomes `-p***`.

- [ ] **Step 4: Run focused and complete GREEN verification**

```powershell
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=138; 'DiagnosticUI.Tests.ps1'=36
  'NestingMigration.Tests.ps1'=30; 'ExtractionLifecycle.Tests.ps1'=26
  'PasswordPreflight.Tests.ps1'=70; 'RunCmdCapture.Tests.ps1'=15
  'ArchiveDiagnostics.Tests.ps1'=140
}
foreach ($item in $expected.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }
```

Expected exact totals: static `138/138`, diagnostic UI `36/36`, focused volume `68/68` within diagnostics, nesting `30/30`, lifecycle `26/26`, password `70/70`, capture `15/15`, diagnostics `140/140`; no whitespace errors. Manually exercise one warning, one wrong-password retry, one missing-volume selection, one partial-directory button, and a three-item batch; observe one batch summary and no password in UI/log/clipboard.

- [ ] **Step 5: Commit and independent review**

```powershell
git add -- SmartZip.ahk tests/SmartZip.Static.Tests.ps1 tests/DiagnosticUI.Harness.ahk tests/DiagnosticUI.Tests.ps1
git diff --check --cached
git commit -m "feat: add redacted extraction diagnostics"
```

Dispatch a fresh read-only reviewer. Require `Critical=0`, `Important=0` for: state/button matrix, one-summary batch behavior, warning/failure-only logs, exactly three 1 MiB UTF-8 log files, basename-only copy, full-path local log, password redaction including legacy logs, and no regression to Task 5 source/partial rules. Fix and re-run Step 4 until clear.

### Task 8: Deterministic Real-7-Zip Integration and Lifecycle Regression Suite

**Files:**

- Modify: `SmartZip.ahk` (optional test-hook callback checks only; production default remains inactive)
- Create: `tests/New-ExtractionReliabilityFixtures.ps1`
- Create: `tests/Real7Zip.Integration.Tests.ps1`
- Create: `tests/Invoke-CompiledSmartZipScenario.ps1`
- Create: `tests/IntegrationTestHook.ahk`
- Create: `tests/Invoke-ProductionSmartZipSmoke.ps1`
- Create: `tests/ProductionSmokeUI.ahk`
- Modify: `tests/README.md`

This task uses `C:\Tool\7-Zip-Zstandard\7z.exe`, but every archive, INI, output, log, compiled test executable, and downloaded artifact stays below one unique directory created with `Join-Path $env:TEMP ("SmartZip-Kirs2-" + [guid]::NewGuid().ToString("N"))`. It must never read or write `C:\Tool\SmartZip`.

- [ ] **Step 1: Write the deterministic fixture generator**

`New-ExtractionReliabilityFixtures.ps1` takes mandatory `-Root` and optional `-SevenZip` (default above), and fails unless **both** the executable exists **and** process environment variable `SMARTZIP_FIXTURE_PASSWORD` is non-empty. It returns a JSON manifest. Set `$ErrorActionPreference='Stop'`; create fixed binary payloads with seeded `System.Random(20260720)` and fixed UTF-8 text. Invoke 7-Zip through `System.Diagnostics.ProcessStartInfo` with `UseShellExecute=$false`, redirected stdout/stderr, explicit argument list, and the process-only password that is never printed. `Real7Zip.Integration.Tests.ps1` creates unique correct and guaranteed-wrong values in `BeforeAll`, sets `SMARTZIP_FIXTURE_PASSWORD` and `SMARTZIP_FIXTURE_WRONG_PASSWORD` only for child processes, scans outputs for both, and clears both in `AfterAll`.

Generate these exact fixture keys:

| Key | Construction | Expected terminal status |
|---|---|---|
| `valid` | two files, normal `.7z` | `OK` |
| `encryptedHeader` | `-mhe=on -p<process-only fixture password>` | `NEED_PASSWORD`; correct candidate → `OK` |
| `wrongPassword` | same archive, wrong supplied candidate only | `WRONG_PASSWORD` |
| `damagedHeader` | copy-mode 7z; flip one byte in the next-header region | `HEADER_CORRUPT` |
| `truncated` | remove final 128 bytes | `TRUNCATED` |
| `crcPartial` | copy-mode two-file 7z; flip a data-stream byte so extraction writes over 90% but exits 2 | `DATA_CORRUPT` |
| `splitComplete` | `-v64k`; all volumes present | selected first volume → `OK` |
| `splitMissing` | delete one middle volume from a copied set | `MISSING_VOLUME` |
| `splitNonFirst` | point manifest at `.7z.002` | normalized to first volume and processed once |
| `trailingWarning` | append fixed 16 bytes to valid archive | `OK_WITH_WARNING` |
| `fake7z` | UTF-8 text named `.7z` | `NOT_ARCHIVE` |
| `plainNoExtension` | UTF-8 ordinary file without extension | `NOT_ARCHIVE` |
| `extensionlessArchive` | copy valid archive without extension | `OK` after strict probe |
| `passwordCancel` | encrypted-header fixture with test dialog callback returning cancel | `CANCELLED` |

For corruption, search the generated archive rather than hard-code an offset. The generator must retry a bounded set of candidate offsets, run `7z t`, and accept only an offset whose normalized output matches the target class. For `crcPartial`, also extract into a probe directory and assert `0.90 < extractedBytes/sourceBytes < 1.0` and exit code `2`; otherwise fail fixture generation. Store no plaintext password in the manifest; store its SHA-256 and inject the actual value only inside the test process.

- [ ] **Step 2: Add the compiled-SmartZip isolated scenario runner**

`Invoke-CompiledSmartZipScenario.ps1` takes `-SmartZipExe`, `-FixtureManifest`, `-Scenario`, `-Root`, `-DelSource 0|1`, and `-PasswordMode none|correctSaved|wrongDialog|dialogCancel`. It creates a per-scenario `app`, `source`, `target`, and `temp` directory; copies only the compiled EXE into `app`; writes a disposable lifecycle-test `SmartZip.ini` as UTF-16LE with BOM containing:

```ini
[set]
zipDir=C:\Tool\7-Zip-Zstandard
nesting=1
nestingMuilt=1
partSkip=1
delSource=1
targetDir=__SCENARIO_TARGET__
test=1
logLevel=0
cmdLog=1
successPercent=90

[ext]
1=zip
2=rar
3=7z
4=001

[extExp]
1=^\d+$
```

Replace only `__SCENARIO_TARGET__` with the scenario path. Before running, assert through the same INI reader used by the app that `zipDir`, `delSource`, and `test` loaded from `[set]`, and that `IsArchive("7z")` is true after numeric `[ext]` loading.

Copy the scenario source into its own source directory, run the compiled EXE with the repository's existing command-line/shell verb used by integration tests, cap execution at 120 seconds, and capture exit code, redacted result JSON, stdout/stderr, source inventory, target inventory, partial directories, and all diagnostic/log text. Capture the launched SmartZip PID and recursively track child PIDs through `Win32_Process.ParentProcessId`; in a `finally` block, stop only still-running members of that captured tree. After cleanup, throw unless zero `SmartZip`/`7z`/`7zG` processes have `ExecutablePath` or `CommandLine` below the scenario root. Include `LeakedProcessCount=0` in the runner result but do not add an integration `It`; every existing scenario fails through the runner invariant if it leaks. `Real7Zip.Integration.Tests.ps1` repeats the same root-scoped zero-process assertion in `AfterAll` before deleting the TEMP root. The hook-aware runner accepts `-DelSource 0|1`: lifecycle deletion scenarios use `1` only on disposable TEMP copies and preservation scenarios use `0`. The exact production artifact is tested separately by the hook-free smoke pair below.

Use an optional compile-time include, not a runtime environment backdoor:

```ahk
; in SmartZip.ahk, adjacent to the diagnostics include
#Include *i tests\IntegrationTestHook.ahk
```

`tests/IntegrationTestHook.ahk` defines three callback variables consumed only through guarded `IsSet(...)` checks in `SmartZip.ahk`: one serializes a redacted final result, one suppresses GUI/run/clipboard actions, and `SmartZipTest_PasswordDialog(path)` supplies a deterministic `{ action, password }` only in the TEMP integration build. Immediately at the top of product `ShowPasswordDialog(path)`, add:

```ahk
        if IsSet(SmartZipTest_PasswordDialog)
            return SmartZipTest_PasswordDialog(path)
```

The scenario runner maps password modes exactly:

| Scenario/mode | Disposable setup | Dialog callback | Expected |
|---|---|---|---|
| `encryptedHeader` / `correctSaved` | `[password]` key `1` receives `SMARTZIP_FIXTURE_PASSWORD` | must not be called | `OK` |
| `wrongPassword` / `wrongDialog` | no correct saved password; hook reads `SMARTZIP_FIXTURE_WRONG_PASSWORD` with `EnvGet` | `{ action: "use", password: wrongValue }` once | `WRONG_PASSWORD` |
| `passwordCancel` / `dialogCancel` | no saved candidate | `{ action: "cancel", password: "" }` once | `CANCELLED` |
| every other scenario / `none` | no password entry | callback throws if called | fixture table status |

`correctSaved` must prove the normal candidate path without using the dialog hook. `wrongDialog` must prove a submitted wrong password remains `WRONG_PASSWORD`; only `dialogCancel` may become `CANCELLED`. The wrong/correct values exist only in the test process/environment and disposable INI, never in arguments or reports. The serializer must omit `passwordUsed`, redact `output`/warning/error fields, and include the marker `SMARTZIP_TEST_RESULT_V1`. Task 8 compiles from a TEMP source tree that includes `tests\IntegrationTestHook.ahk`; Task 10 compiles from a clean TEMP staging tree containing `SmartZip.ahk`, `lib`, and `ico.ico` but no `tests` directory, so the optional include is absent. Production code follows the normal GUI path when all three callbacks are unset.

Also create the hook-free production smoke pair used by Task 10:

- `ProductionSmokeUI.ahk` takes `SmartZipExe`, `WorkingDirectory`, `ArchivePath`, `TimeoutSeconds`, and `ResultPath`. It launches the exact EXE with the normal `x "<archive>"` verb, records only PID/window-title/button observations, closes only windows owned by that launched PID whose title is `SmartZip 解压警告` or `SmartZip 未完成解压` by clicking `关闭`, waits for the launched process to exit, and fails on timeout. It never includes `IntegrationTestHook.ahk`, reads clipboard, types a password, or serializes an `ArchiveResult`.
- `Invoke-ProductionSmartZipSmoke.ps1` takes mandatory `-SmartZipExe`, `-FixtureManifest`, `-Root`, and `-AhkExe`; optional `-SevenZip` defaults to `C:\Tool\7-Zip-Zstandard\7z.exe`, and it requires the same non-empty process environment variable. It copies the EXE into a unique per-scenario `app` directory, writes the same UTF-16LE BOM INI schema above with `delSource=0`, and runs exactly `valid`, `crcPartial`, `splitMissing`, and `encryptedHeader`. The encrypted scenario puts the process-only fixture password in its disposable `[password]` INI entry and deletes that INI in `finally`; the password is never an argument, console line, report field, or log.
- The runner returns one PowerShell object/JSON report built only from observable filesystem/log/UI-driver evidence: `Passed`, per-scenario exit/timeout, source/target inventories, partial-directory count, diagnostic filenames, redaction checks, and leaked-process count. It must assert: valid and encrypted payloads exist; every source remains because `delSource=0`; CRC creates exactly one `*_解压不完整_yyyyMMdd-HHmmss` directory containing `SmartZip-诊断.txt` and never contaminates the normal target; missing-volume members all remain and normal output is absent; plaintext fixture password and raw `-p...` are absent from every `SmartZip-diagnostics.log*`, command log, partial diagnostic, and driver report; and no newly launched SmartZip/7z/7zG process whose executable/command line points below the smoke root remains. A `finally` block closes only PIDs launched by the driver and removes the disposable password INI.
- This smoke pair is production-path automation, not a replacement classifier: it contains no status oracle, optional callback, result marker, or product-source include. The existing integration secrecy `It` also asserts that both files contain no `SMARTZIP_TEST_RESULT_V1`, `IntegrationTestHook`, or production-result JSON callback; do not add a 27th `It`.

- [ ] **Step 3: Add 26 failing integration assertions**

`Real7Zip.Integration.Tests.ps1` builds a TEMP-only test executable, generates fixtures once in `BeforeAll`, deletes the root in `AfterAll`, and skips with an explicit reason only when 7-Zip or the trusted compiler is absent. Add exactly 26 `It` blocks:

- 14 fixture/scenario terminal-status assertions matching the table; every non-`OK` assertion also verifies source still exists, all volume members still exist, and no permanent delete occurred;
- 4 lifecycle assertions: valid clean success uses Recycle Bin only for its disposable single source when deletion is enabled; warning preserves source; CRC partial preserves source; header/truncated preserve source;
- 2 volume assertions: all complete members preserved even on success; missing/non-first sets are processed once and every member is preserved;
- 2 partial-output assertions: CRC output is moved to exactly one `*_解压不完整_yyyyMMdd-HHmmss` directory; no failed extraction contaminates the normal target;
- 2 old-heuristic regressions: CRC fixture really exceeds 90%; it is still not `OK` and `mayDeleteSource=false`;
- 2 secrecy assertions: password absent from every captured UI/result/log/cmdLog stream; copied diagnostics contain basename but not full source path.

Run RED:

```powershell
$red = Invoke-Pester -Script .\tests\Real7Zip.Integration.Tests.ps1 -PassThru
if ($red.TotalCount -ne 26 -or $red.FailedCount -lt 1) {
    throw "expected integration RED with 26 discovered and >=1 failure; got Total=$($red.TotalCount) Failed=$($red.FailedCount)"
}
```

Expected: `26` discovered and at least one failure before the production/test hook is wired; the fixture generator itself must complete and prove the CRC ratio precondition.

- [ ] **Step 4: Wire only the test-mode seam and make the suite GREEN**

Add only the three optional callback checks and test hook described in Step 2. It must call the same production `ProbeArchive`, `TestArchive`, password resolution, extraction, finalization, volume grouping, diagnostic, and cleanup code; no duplicate classifier or fake success path is allowed. The password callback replaces only the modal input operation and returns the same `{ action, password }` shape as the real dialog; it must not bypass `ResolveArchivePassword` or `TestArchive`. Use per-scenario INI and TEMP paths; do not special-case fixture filenames. Add an integration assertion that the result JSON contains no plaintext fixture password/wrong token, no `passwordUsed` property, and no raw `-p...` command.

Run:

```powershell
$expected = [ordered]@{
  'Real7Zip.Integration.Tests.ps1'=26; 'SmartZip.Static.Tests.ps1'=138
  'DiagnosticUI.Tests.ps1'=36; 'NestingMigration.Tests.ps1'=30
  'ExtractionLifecycle.Tests.ps1'=26; 'PasswordPreflight.Tests.ps1'=70
  'RunCmdCapture.Tests.ps1'=15; 'ArchiveDiagnostics.Tests.ps1'=140
}
foreach ($item in $expected.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }
```

Expected exact totals: integration `26/26`, static `138/138`, UI `36/36`, focused volume `68/68` within diagnostics, nesting `30/30`, lifecycle `26/26`, password `70/70`, capture `15/15`, diagnostics `140/140`. The suite must contain a static guard rejecting literal `C:\Tool\SmartZip` references in its runner/generator code and must never enumerate, read, or write that deployed directory.

- [ ] **Step 5: Document, commit, and independently review**

Document prerequisites, TEMP isolation, 120-second timeout, fixture meanings, and the test-only build seam in `tests/README.md`.

```powershell
git add -- SmartZip.ahk tests/New-ExtractionReliabilityFixtures.ps1 tests/Real7Zip.Integration.Tests.ps1 tests/Invoke-CompiledSmartZipScenario.ps1 tests/IntegrationTestHook.ahk tests/Invoke-ProductionSmartZipSmoke.ps1 tests/ProductionSmokeUI.ahk tests/README.md
git diff --check --cached
git commit -m "test: add real 7-Zip reliability regressions"
```

Require a fresh reviewer to report `Critical=0`, `Important=0` for determinism, no deployed-directory access, genuine >90% CRC reproduction, all non-clean source preservation, volume preservation, isolated partial output, password secrecy, and use of production state-machine paths. Fix and rerun all suites until clear.

### Task 9: Kirs.2 Metadata, Documentation, and Whole-Branch Verification

**Files:**

- Modify: `SmartZip.ahk`
- Modify: `README.md`
- Modify: `ini.md`
- Modify: `tests/SmartZip.Static.Tests.ps1`
- Modify: `tests/README.md`

- [ ] **Step 1: Add 12 failing metadata/About/documentation assertions**

Append `Describe 'Kirs2MetadataAndDocs'` with exactly 12 `It` blocks using these exact titles and assertions:

1. `Kirs2 file version remains 3.6` → `;@Ahk2Exe-SetFileVersion 3.6`
2. `Kirs2 product version is 22` → `;@Ahk2Exe-SetProductVersion 22`
3. `Kirs2 buildVersion is 22` → `buildVersion := 22`
4. `Kirs2 edition is Kirs.2` → `edition := "Kirs.2"`
5. `Kirs2 About keeps version edition build expression` → About expression still renders `app MainVersion edition (buildVersion)`.
6. `Kirs2 rendered About identity is exact` → rendered expectation is `SmartZip 3.6 Kirs.2 (22)`.
7. `Kirs2 About keeps removed rows absent` → About source contains none of `支持作者`, `建议反馈`, `论坛反馈`.
8. `Kirs2 README names safety pipeline` → README names Kirs.2 and the safety-first extraction pipeline.
9. `Kirs2 README documents volume preservation` → README explains first-volume normalization and preservation.
10. `Kirs2 ini docs deprecate successPercent` → `ini.md` labels `successPercent` retained/deprecated and not read by runtime.
11. `Kirs2 docs explain recovery and redaction` → docs describe diagnostic/partial-output recovery and password redaction.
12. `Kirs2 docs name engine without replacing Kirs1` → docs name current engine path and do not claim Kirs.1 was replaced.

Before appending them, update in place the three separate existing `VersionBanner` Its and their titles: `edition is Kirs.2`, `buildVersion is 22`, and `Ahk2Exe product version is 22`. Keep them as three existing Its; do not merge or add one. Rename the existing `AboutSection` title `shows SmartZip 3.6 Kirs.1 build 21` to `shows SmartZip 3.6 Kirs.2 build 22` while retaining its version/edition/build expression assertion. No other existing `It` title/body changes in this step.

Run:

```powershell
$red = Invoke-Pester -Script .\tests\SmartZip.Static.Tests.ps1 -PassThru
if ($red.TotalCount -ne 150 -or $red.FailedCount -lt 3) {
    throw "expected metadata RED with 150 discovered and at least 3 failures; got Passed=$($red.PassedCount) Failed=$($red.FailedCount) Total=$($red.TotalCount)"
}
$requiredRed = @('edition is Kirs.2','buildVersion is 22','Ahk2Exe product version is 22')
$allowedRed = $requiredRed + @(
  'Kirs2 file version remains 3.6','Kirs2 product version is 22',
  'Kirs2 buildVersion is 22','Kirs2 edition is Kirs.2',
  'Kirs2 About keeps version edition build expression','Kirs2 rendered About identity is exact',
  'Kirs2 About keeps removed rows absent','Kirs2 README names safety pipeline',
  'Kirs2 README documents volume preservation','Kirs2 ini docs deprecate successPercent',
  'Kirs2 docs explain recovery and redaction','Kirs2 docs name engine without replacing Kirs1'
)
$failedNames = @($red.TestResult | Where-Object Result -eq 'Failed' | ForEach-Object Name)
$missingRequiredRed = @($requiredRed | Where-Object { $failedNames -notcontains $_ })
$unexpectedRed = @($failedNames | Where-Object { $allowedRed -notcontains $_ })
if ($missingRequiredRed -or $unexpectedRed) {
    throw "bad RED set; missing=[$($missingRequiredRed -join ',')] unexpected=[$($unexpectedRed -join ',')]"
}
```

Expected: total `150`; the three retargeted metadata tests are definitely RED; some of the 12 new guards may already pass on Kirs.1 (for example FileVersion 3.6, retained About expression, or already-removed rows), so no impossible exact failure count is asserted. Every failure must be in the explicit allow-list, proving the other 135 pre-existing tests remain green.

- [ ] **Step 2: Update metadata and About display only**

Apply these exact source replacements:

```ahk
;@Ahk2Exe-SetFileVersion 3.6
;@Ahk2Exe-SetProductVersion 22
buildVersion := 22
edition := "Kirs.2"
```

Keep `MainVersion` at `3.6`. Keep the About row:

```ahk
set.AddText("", app " " MainVersion " " edition " (" buildVersion ")")
```

so it displays `SmartZip 3.6 Kirs.2 (22)`. Do not reintroduce the previously removed support-author, suggestion-feedback, or forum-feedback controls, labels, URLs, variables, or callbacks.

- [ ] **Step 3: Update user documentation**

In `README.md`, add a concise `3.6 Kirs.2` section covering:

- list → test → extract-to-isolated-temp → finalize state flow;
- only clean `OK` may allow configured source handling;
- warnings and every failure preserve source;
- partial results go to `<archive>_解压不完整_<yyyyMMdd-HHmmss>`;
- split archives are normalized to the first volume and members are never auto-deleted;
- header corruption, truncation, CRC/data corruption, wrong password, missing volume, unsupported method, and non-archive are distinct diagnostics;
- diagnostic buttons and one-summary batch behavior;
- log location/rotation and password redaction;
- current tested engine `C:\Tool\7-Zip-Zstandard\7z.exe`;
- recovery guidance: obtain a complete source/volume set, retry password, open in 7-Zip, inspect partial output, copy redacted diagnostics.

In `ini.md`, preserve the `successPercent` row but change its description to:

```text
兼容保留（Kirs.2 已弃用，运行时不读取；不再通过大小百分比判断解压成功）
```

Document `test=0` semantics: optional user test is off, but SmartZip still performs integrity testing before any configured source recycle. Explain that legacy case-sensitive exact lowercase `extExp` defaults `zi`, `7`, `z` are migrated away while `ZI`, `^\d+$`, and custom expressions remain probe hints rather than proof.

Update `tests/README.md` with the command order and exact counts from Step 4.

- [ ] **Step 4: Run whole-branch verification and trace the approved design**

```powershell
$expected = [ordered]@{
  'SmartZip.Static.Tests.ps1'=150; 'ArchiveDiagnostics.Tests.ps1'=140
  'RunCmdCapture.Tests.ps1'=15; 'PasswordPreflight.Tests.ps1'=70
  'ExtractionLifecycle.Tests.ps1'=26; 'NestingMigration.Tests.ps1'=30
  'DiagnosticUI.Tests.ps1'=36; 'Real7Zip.Integration.Tests.ps1'=26
}
foreach ($item in $expected.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }
```

Expected exact totals: static `150/150`, diagnostics `140/140` (including focused volume `68/68`), capture `15/15`, password/workflow `70/70`, lifecycle `26/26`, nesting `30/30`, UI `36/36`, real integration `26/26`.

Complete a line-by-line checklist against design sections 1–13 and 15:

1. version/release scope;
2. evidence/root cause;
3. pure status model;
4. classifier priority;
5. full capture;
6. list/test/extract/finalize pipeline;
7. clean-success source gate;
8. volume grouping/preservation;
9. strict nesting/migration;
10. password order/prompt;
11. diagnostics/batch/log;
12. deprecated size heuristic;
13. deterministic integration fixtures;
14. compatibility/non-goals.

For each row record the implementation task, production symbol, and passing test file. No row may be `N/A`. Record design §14 build/deploy/release separately as `Deferred to Task 10` with its exact future gates; Task 10's final deployment report replaces that entry with tool hashes, smoke results, backup/deployed hashes, and Release evidence. Do not claim passing deployment evidence during Task 9.

- [ ] **Step 5: Commit and independent whole-branch review**

```powershell
git add -- SmartZip.ahk README.md ini.md tests/SmartZip.Static.Tests.ps1 tests/README.md
git diff --check --cached
git commit -m "docs: prepare SmartZip 3.6 Kirs.2"
```

Dispatch an independent read-only reviewer with the spec, all Task 1–9 commits, and the exact test output. Require:

```text
Critical=0
Important=0
TraceabilityMissing=0
```

The reviewer must additionally confirm Kirs.1 tag/release is untouched, Kirs.2 metadata is internally consistent, removed About rows remain absent, docs match actual safety behavior, and no password appears in repository diffs or test logs. Fix, rerun the full command block, and repeat review until clear.

### Task 10: Build, Smoke-Test, Deploy, and Publish v3.6-kirs.2

**Outputs:**

- Build: `%TEMP%\smartzip-kirs2-build-<stamp>\SmartZip.exe`
- Deploy: `C:\Tool\SmartZip\SmartZip.exe`
- Backup: `C:\Tool\SmartZip\SmartZip.exe.bak-<stamp>`
- Branch: `codex/kirs2-extraction-reliability`
- Tag/Release: `v3.6-kirs.2`
- Release asset: `SmartZip.exe`

Every stop condition below is mandatory. Do not deploy, push, tag, or publish after a failed command.

- [ ] **Step 1: Freeze Kirs.1 evidence and verify the final source/toolchain**

```powershell
$ErrorActionPreference = 'Stop'
$repo = 'kirsartx/SmartZip'
$oldTag = (git ls-remote origin refs/tags/v3.6-kirs.1).Split()[0]
$oldRelease = gh release view v3.6-kirs.1 --repo $repo --json tagName,targetCommitish,url,assets | ConvertFrom-Json
$oldReleaseJson = $oldRelease | ConvertTo-Json -Depth 8 -Compress

$suites = [ordered]@{
  'SmartZip.Static.Tests.ps1'=150; 'ArchiveDiagnostics.Tests.ps1'=140
  'RunCmdCapture.Tests.ps1'=15; 'PasswordPreflight.Tests.ps1'=70
  'ExtractionLifecycle.Tests.ps1'=26
  'NestingMigration.Tests.ps1'=30; 'DiagnosticUI.Tests.ps1'=36
  'Real7Zip.Integration.Tests.ps1'=26
}
foreach ($item in $suites.GetEnumerator()) {
    $r = Invoke-Pester -Script (Join-Path '.\tests' $item.Key) -PassThru
    if ($r.FailedCount -ne 0 -or $r.PassedCount -ne $item.Value) {
        throw "$($item.Key): expected $($item.Value)/0, got $($r.PassedCount)/$($r.FailedCount)"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }

$sevenZip = 'C:\Tool\7-Zip-Zstandard\7z.exe'
if (-not (Test-Path $sevenZip)) { throw '7-Zip executable missing' }
& $sevenZip i | Select-Object -First 5

$ahkBase = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'
$ahkCompiler = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\Ahk2Exe1.1.37.02a2\Ahk2Exe.exe'
$expectedBase = 'A2A54B8ABC476D7671D4DE0771BB54BF5F2373D79FF6871D0BA6A62C3B88AE00'
$expectedCompiler = 'E54A599B19BAA5C1688849BBAE7A9CF049EEFCCD4F704C67941B40DA13A625B2'
if ((Get-FileHash $ahkBase -Algorithm SHA256).Hash -ne $expectedBase) { throw 'AutoHotkey base hash mismatch' }
if ((Get-FileHash $ahkCompiler -Algorithm SHA256).Hash -ne $expectedCompiler) { throw 'Ahk2Exe hash mismatch' }
```

Expected: every exact suite count passes; engine identifies the tested current 7-Zip Zstandard build; both trusted hashes match. Record `$oldTag` and `$oldReleaseJson`; they are immutable comparison evidence.

- [ ] **Step 2: Commit final implementation on the intended branch**

Before implementation begins, the execution session must create/switch to `codex/kirs2-extraction-reliability`. At this point confirm every Task 1–9 commit is present and only intended files differ.

```powershell
git status --short --branch
git diff --check
git log --oneline --decorate -12
git add -- SmartZip.ahk lib tests README.md ini.md
git diff --check --cached
git diff --cached --stat
git commit -m "feat: release SmartZip 3.6 Kirs.2"
if (git status --porcelain) { throw 'worktree is not clean after final commit' }
$releaseCommit = git rev-parse HEAD
```

If earlier task commits already contain all implementation, omit an empty final commit. Never stage `.superpowers`, TEMP fixtures, credentials, deployed files, backups, or unrelated user changes.

- [ ] **Step 3: Compile the exact reviewed commit in TEMP**

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$buildDir = Join-Path $env:TEMP "smartzip-kirs2-build-$stamp"
$buildSource = Join-Path $buildDir 'src'
New-Item -ItemType Directory -Path $buildSource,(Join-Path $buildSource 'lib') | Out-Null
Copy-Item .\SmartZip.ahk (Join-Path $buildSource 'SmartZip.ahk')
Copy-Item .\ico.ico (Join-Path $buildSource 'ico.ico')
Copy-Item .\lib\*.ahk (Join-Path $buildSource 'lib')
if (Test-Path (Join-Path $buildSource 'tests')) { throw 'production staging must not contain test hooks' }
$builtExe = Join-Path $buildDir 'SmartZip.exe'
$source = Join-Path $buildSource 'SmartZip.ahk'
$compile = Start-Process -FilePath $ahkCompiler `
  -ArgumentList @('/in',$source,'/out',$builtExe,'/base',$ahkBase) `
  -WorkingDirectory $buildSource -WindowStyle Hidden -Wait -PassThru
if ($compile.ExitCode -ne 0 -or -not (Test-Path $builtExe) -or (Get-Item $builtExe).Length -eq 0) {
    throw 'compile failed'
}
$version = [Diagnostics.FileVersionInfo]::GetVersionInfo($builtExe)
if ($version.FileVersion -notmatch '^3\.6(\.0\.0)?$') { throw "unexpected FileVersion $($version.FileVersion)" }
if ($version.ProductVersion -notmatch '^22(\.0\.0)?$') { throw "unexpected ProductVersion $($version.ProductVersion)" }
$builtHash = (Get-FileHash $builtExe -Algorithm SHA256).Hash
$version | Select-Object FileVersion,ProductVersion,ProductName
"BUILT_SHA256=$builtHash"
$exeBytes = [IO.File]::ReadAllBytes($builtExe)
$exeText = [Text.Encoding]::Unicode.GetString($exeBytes) + [Text.Encoding]::UTF8.GetString($exeBytes)
if ($exeText.Contains('SMARTZIP_TEST_RESULT_V1')) { throw 'test hook leaked into production artifact' }
```

- [ ] **Step 4: Smoke-test the exact artifact in isolated TEMP**

Do not use the hook-aware Task 8 result serializer against `$builtExe`: the production artifact must not contain that hook. Task 8's full fixture matrix has already passed against the same reviewed source through the test-only optional include. For the exact production artifact, run the Task 8 production smoke driver, which observes only files, logs, process lifetime, and normal UI. Its JSON is an external smoke report—not product result serialization.

```powershell
$smokeRoot = Join-Path $env:TEMP "smartzip-kirs2-smoke-$stamp"
$fixtureRoot = Join-Path $smokeRoot 'fixtures'
$manifestPath = Join-Path $smokeRoot 'fixtures.json'
$artifactSmokeRoot = Join-Path $smokeRoot 'built-artifact'
New-Item -ItemType Directory -Path $smokeRoot,$fixtureRoot,$artifactSmokeRoot | Out-Null

$fixturePassword = "K2-$([guid]::NewGuid().ToString('N'))!"
$env:SMARTZIP_FIXTURE_PASSWORD = $fixturePassword
try {
    $manifestJson = (& .\tests\New-ExtractionReliabilityFixtures.ps1 `
        -Root $fixtureRoot -SevenZip $sevenZip | Out-String).Trim()
    [IO.File]::WriteAllText($manifestPath, $manifestJson, [Text.UTF8Encoding]::new($false))

    $reportJson = (& .\tests\Invoke-ProductionSmartZipSmoke.ps1 `
        -SmartZipExe $builtExe -FixtureManifest $manifestPath `
        -Root $artifactSmokeRoot -AhkExe $ahkBase -SevenZip $sevenZip | Out-String).Trim()
    if ($reportJson -match [regex]::Escape($fixturePassword)) {
        throw 'fixture password leaked into production smoke report'
    }
    $artifactSmoke = $reportJson | ConvertFrom-Json
    if (-not $artifactSmoke.Passed -or $artifactSmoke.LeakedProcessCount -ne 0) {
        throw "production artifact smoke failed: $reportJson"
    }
    foreach ($name in 'valid','crcPartial','splitMissing','encryptedHeader') {
        if (-not ($artifactSmoke.Scenarios.PSObject.Properties.Name -contains $name)) {
            throw "production smoke omitted scenario: $name"
        }
    }
} finally {
    Remove-Item Env:SMARTZIP_FIXTURE_PASSWORD -ErrorAction SilentlyContinue
}
```

Required report evidence: valid and encrypted payloads exist; CRC source is preserved, exactly one isolated partial directory and its UTF-8 diagnostic exist, and the ordinary target is uncontaminated; all missing-volume members remain; every source remains with `delSource=0`; all diagnostic/command/driver text passes password and raw-`-p` secrecy checks; no smoke-owned SmartZip/7z/7zG process remains.

Also run simple CLI creation/extraction:

```powershell
$cliRoot = Join-Path $smokeRoot 'simple-cli'
$smokeBin = Join-Path $cliRoot 'bin'
$smokeWork = Join-Path $cliRoot 'work'
New-Item -ItemType Directory -Path $smokeBin,$smokeWork | Out-Null
Copy-Item $builtExe (Join-Path $smokeBin 'SmartZip.exe')
$smokeIni = Join-Path $smokeBin 'SmartZip.ini'
$ini = @"
[set]
zipDir=C:\Tool\7-Zip-Zstandard
nesting=1
nestingMuilt=1
partSkip=1
delSource=0
targetDir=$smokeWork
test=1
logLevel=0
cmdLog=1
successPercent=90

[ext]
1=zip
2=rar
3=7z
4=001

[extExp]
1=^\d+$
"@
[IO.File]::WriteAllText($smokeIni, $ini, [Text.UnicodeEncoding]::new($false, $true))
$smokeExe = Join-Path $smokeBin 'SmartZip.exe'
$payload = Join-Path $smokeWork 'payload.txt'
[IO.File]::WriteAllText($payload, 'SmartZip 3.6 Kirs.2 smoke', [Text.UTF8Encoding]::new($false))
& $sevenZip a -t7z (Join-Path $smokeWork 'payload.7z') $payload
if ($LASTEXITCODE -ne 0) { throw 'fixture archive creation failed' }
Remove-Item -LiteralPath $payload
$x = Start-Process $smokeExe -ArgumentList @('x',(Join-Path $smokeWork 'payload.7z')) `
  -WorkingDirectory $smokeBin -Wait -PassThru
if ($x.ExitCode -ne 0 -or -not (Test-Path $payload)) { throw 'compiled extraction smoke failed' }
```

Run the full Step 1 test loop again after smoke. Any failure stops before deployment.

- [ ] **Step 5: Back up and deploy only the tested EXE**

```powershell
$deployDir = 'C:\Tool\SmartZip'
$deployExe = Join-Path $deployDir 'SmartZip.exe'
$backupExe = Join-Path $deployDir "SmartZip.exe.bak-$stamp"
$iniPath = Join-Path $deployDir 'SmartZip.ini'
$contextPath = Join-Path $deployDir 'Contextmenu.exe'
$iniHashBefore = (Get-FileHash $iniPath -Algorithm SHA256).Hash
$contextHashBefore = (Get-FileHash $contextPath -Algorithm SHA256).Hash

$running = Get-Process SmartZip,Contextmenu,7z,7zG,7zFM -ErrorAction SilentlyContinue
if ($running) { throw "close running archive processes before deployment: $($running.Name -join ', ')" }
Copy-Item $deployExe $backupExe
Copy-Item $builtExe $deployExe -Force

$deployedHash = (Get-FileHash $deployExe -Algorithm SHA256).Hash
$iniHashAfter = (Get-FileHash $iniPath -Algorithm SHA256).Hash
$contextHashAfter = (Get-FileHash $contextPath -Algorithm SHA256).Hash
if ($deployedHash -ne $builtHash -or $iniHashAfter -ne $iniHashBefore -or
    $contextHashAfter -ne $contextHashBefore) {
    Copy-Item $backupExe $deployExe -Force
    throw 'deployment verification failed; backup restored'
}
```

Run the same four-scenario observable smoke against the deployed EXE bytes, still from copied fixtures and a disposable app/INI below TEMP. Never execute against or overwrite the real `SmartZip.ini` or `Contextmenu.exe`:

```powershell
$deployedSmokeRoot = Join-Path $smokeRoot 'deployed-artifact'
New-Item -ItemType Directory -Path $deployedSmokeRoot | Out-Null
$env:SMARTZIP_FIXTURE_PASSWORD = $fixturePassword
try {
    $deployedReportJson = (& .\tests\Invoke-ProductionSmartZipSmoke.ps1 `
        -SmartZipExe $deployExe -FixtureManifest $manifestPath `
        -Root $deployedSmokeRoot -AhkExe $ahkBase -SevenZip $sevenZip | Out-String).Trim()
    if ($deployedReportJson -match [regex]::Escape($fixturePassword)) {
        throw 'fixture password leaked into deployed smoke report'
    }
    $deployedSmoke = $deployedReportJson | ConvertFrom-Json
    if (-not $deployedSmoke.Passed -or $deployedSmoke.LeakedProcessCount -ne 0) {
        throw "deployed smoke failed: $deployedReportJson"
    }
} catch {
    Copy-Item $backupExe $deployExe -Force
    $restoredHash = (Get-FileHash $deployExe -Algorithm SHA256).Hash
    $backupHash = (Get-FileHash $backupExe -Algorithm SHA256).Hash
    if ($restoredHash -ne $backupHash) { throw 'deployed smoke failed and rollback hash mismatch' }
    throw
} finally {
    Remove-Item Env:SMARTZIP_FIXTURE_PASSWORD -ErrorAction SilentlyContinue
}
```

- [ ] **Step 6: Push, review, and merge the branch**

```powershell
git push -u origin codex/kirs2-extraction-reliability
gh pr create --repo $repo --base main --head codex/kirs2-extraction-reliability `
  --title 'SmartZip 3.6 Kirs.2 extraction reliability' `
  --body 'Safety-first extraction state machine, volume handling, diagnostics, and deterministic real-7-Zip regressions.'
$checks = gh pr checks --repo $repo 2>&1
$checksExit = $LASTEXITCODE
if ($checksExit -ne 0 -and ($checks -join "`n") -notmatch '(?i)no checks') {
    throw "unable to read PR checks: $($checks -join "`n")"
}
if (($checks -join "`n") -notmatch '(?i)no checks') {
    gh pr checks --repo $repo --watch
    if ($LASTEXITCODE -ne 0) { throw 'PR checks failed' }
} else {
    'NO_GITHUB_CHECKS_CONFIGURED'
}
```

Require all configured checks plus a final independent reviewer result `Critical=0`, `Important=0`; when GitHub explicitly reports no configured checks, record `NO_GITHUB_CHECKS_CONFIGURED` and do not treat that message as a failed build. Then merge with the repository's allowed merge method, update local `main`, and set:

```powershell
git switch main
git pull --ff-only origin main
$releaseCommit = git rev-parse HEAD
if (git status --porcelain) { throw 'main not clean' }
```

If direct pushing is the repository's established approved workflow and no PR is used, still push only after the same review/check gates and verify `origin/main == $releaseCommit`.

- [ ] **Step 7: Create a new immutable Kirs.2 tag and Release**

Do not move, delete, edit, or replace `v3.6-kirs.1`.

```powershell
$existingTag = git ls-remote origin refs/tags/v3.6-kirs.2 2>$null
if ($LASTEXITCODE -ne 0) { throw 'failed to query remote tag state' }
if ($existingTag) { throw 'v3.6-kirs.2 already exists' }
git tag -a v3.6-kirs.2 $releaseCommit -m 'SmartZip 3.6 Kirs.2'
git push origin refs/tags/v3.6-kirs.2

$notes = @"
## SmartZip 3.6 Kirs.2 (22)

- 使用 list → test → 临时目录解压 → finalize 的安全状态机
- 仅完全成功允许按配置处理源包；警告和失败始终保留源包
- 区分密码、缺卷、头损坏、截断、CRC/数据损坏、不支持格式等错误
- 失败的部分结果隔离到“_解压不完整_时间”目录
- 分卷统一从首卷处理，所有分卷均不会自动删除
- 新增脱敏诊断窗口、批量汇总及最多 3 个 1 MiB 轮转日志
- 使用 7-Zip Zstandard 当前本机版本完成确定性回归测试

Pester：静态 150、诊断（含分卷）140、命令捕获 15、密码 70、生命周期 26、嵌套 30、诊断界面 36、真实集成 26，全部通过。

SmartZip.exe SHA-256: $builtHash

升级时只替换 SmartZip.exe；请保留 SmartZip.ini 与 Contextmenu.exe。
"@
gh release create v3.6-kirs.2 $builtExe --repo $repo `
  --title 'SmartZip 3.6 Kirs.2' --notes $notes --latest
```

- [ ] **Step 8: Download and verify published/deployed/old-release evidence**

```powershell
$downloadDir = Join-Path $env:TEMP "smartzip-kirs2-release-check-$stamp"
New-Item -ItemType Directory -Path $downloadDir | Out-Null
gh release download v3.6-kirs.2 --repo $repo --pattern 'SmartZip.exe' --dir $downloadDir
$downloaded = Join-Path $downloadDir 'SmartZip.exe'
$downloadedHash = (Get-FileHash $downloaded -Algorithm SHA256).Hash
if ($downloadedHash -ne $builtHash) { throw 'downloaded release hash mismatch' }
if ((Get-FileHash $deployExe -Algorithm SHA256).Hash -ne $builtHash) { throw 'deployed hash mismatch' }

$newRelease = gh release view v3.6-kirs.2 --repo $repo `
  --json tagName,name,isDraft,isPrerelease,targetCommitish,url,assets | ConvertFrom-Json
if ($newRelease.tagName -ne 'v3.6-kirs.2' -or $newRelease.isDraft -or $newRelease.isPrerelease) {
    throw 'release metadata mismatch'
}
if ((git ls-remote origin refs/tags/v3.6-kirs.1).Split()[0] -ne $oldTag) {
    throw 'v3.6-kirs.1 tag changed'
}
$oldReleaseAfter = gh release view v3.6-kirs.1 --repo $repo --json tagName,targetCommitish,url,assets |
  ConvertFrom-Json | ConvertTo-Json -Depth 8 -Compress
if ($oldReleaseAfter -ne $oldReleaseJson) { throw 'v3.6-kirs.1 release changed' }
```

Final report must record release URL, commit, branch/PR, exact test totals, tool hashes, engine version, built/deployed/downloaded identical SHA-256, backup path/hash, unchanged INI and Contextmenu hashes, and unchanged Kirs.1 evidence. Finish with `git status --short --branch`; repository must be clean.

Rollback boundary: deployment can be restored from `$backupExe`. If tagging succeeds but Release creation/verification fails, do not retag or mutate Kirs.1; leave the Kirs.2 tag pointing at the reviewed commit, correct the Release asset/metadata, and re-verify hashes.

## Plan Self-Review

This review checks the plan itself; it does not claim that future implementation tests, builds, deployment, or publication have already run.

### Scope traceability

| Approved design section | Implemented by plan task(s) | Verification gate |
|---|---|---|
| §1–2 problem, scope, non-goals | Global Constraints; Tasks 1, 5, 8–10 | whole-branch reviewer and release evidence |
| §3 module boundary/result object | Task 1; Canonical Interfaces | diagnostics harness + static API tests |
| §4 statuses/classification priority | Task 1 | diagnostics focused `72/72` (3 file checks + 1 harness-exit + 68 named classifier/redaction cases), later full `140/140` including volume coverage |
| §5 state machine | Tasks 3–6 | capture 15, password 70, lifecycle 26, nesting 30 |
| §6 partial output | Task 5 | lifecycle + real CRC-partial fixture |
| §7 volumes | Tasks 2, 6, 8 | volume 68 + complete/missing/non-first integration fixtures |
| §8 strict nesting | Task 6 | nesting/migration 30 |
| §9 password experience | Task 4 | password/workflow 70 + secrecy integration assertions |
| §10 diagnostic window | Task 7 | UI behavior 36 + 16 static additions |
| §11 logging/redaction | Tasks 1, 7, 8 | redaction cases, rotation cases, no-secret integration scan |
| §12 settings/migration | Task 6 and Task 9 docs | static + nesting/migration behavior |
| §13 tests | Tasks 1–9 | exact cumulative suite table below |
| §14 build/deploy/release | Task 10 | trusted hashes, isolated smoke, backup, three-way artifact hash, immutable Kirs.1 comparison |
| §15 acceptance | Tasks 9–10 | traceability reviewer, all suites, deployment/release report |

### Canonical interface audit

- All status spellings match the 13-value canonical list.
- `ArchiveResult` constructor and stable property list are introduced once in Task 1 and consumed without alternate result types.
- `Classify7zResult`, `DetectVolumeGroup`, and `RedactDiagnostic` remain pure compile-time-library functions.
- `RunCmdCapture`, `ProbeArchive`, `TestArchive`, `BuildPasswordCandidates`, `ResolveArchivePassword`, `ExtractArchiveToTemp`, `FinalizeExtraction`, `ShowDiagnostic`, and `WriteDiagnostic` retain the exact canonical names and argument order.
- UI, process, filesystem, INI, and log effects stay in `SmartZip.ahk`; `lib/ArchiveDiagnostics.ahk` remains GUI/I/O-free.
- Task 4's exporter writes only its final single-class harness assignment; intermediate construction strings are overwritten and cannot reach the generated fragment.

### Test-count audit

| End of task | Static | New focused behavior | Preserved behavior suites |
|---|---:|---:|---|
| baseline | 69 | — | — |
| Task 1 | 69 | diagnostics 72 | — |
| Task 2 | 69 | volume 68; diagnostics cumulative 140 | — |
| Task 3 | 82 | capture 15 | diagnostics 140; volume 68 |
| Task 4 | 96 | password 70 | capture 15; diagnostics 140; focused volume 68 |
| Task 5 | 108 | lifecycle 26 | password 70; capture 15; diagnostics 140; focused volume 68 |
| Task 6 | 122 | nesting 30 | lifecycle 26; password 70; capture 15; diagnostics 140; focused volume 68 |
| Task 7 | 138 | diagnostic UI 36 | all preceding suites unchanged |
| Task 8 | 138 | real integration 26 | all preceding suites unchanged |
| Task 9/final | 150 | metadata/docs are 12 new static cases | diagnostics 140 (volume subset 68); capture 15; password 70; lifecycle 26; nesting 30; UI 36; integration 26 |

The count chain is arithmetic-consistent: `69 + 13 + 14 + 12 + 14 + 16 + 12 = 150`.

### Safety and publication audit

- The old `successPercent=90` regression is reproduced with a >90% partial CRC extraction, but no runtime path may read that value to declare success.
- Only clean exit/status plus all required clean stages can set `isCleanSuccess`/`mayDeleteSource`; warning/failure/cancel always preserve source.
- Top-level and nested clean-success source handling is Recycle Bin only; permanent deletion is limited to SmartZip-created TEMP cleanup; volume members are never auto-deleted.
- Every real integration scenario runs under a unique TEMP root with a generated safe INI; `C:\Tool\SmartZip` is outside test scope.
- The hook-free production smoke runs valid, CRC-partial, missing-volume, and encrypted fixtures against both built and deployed EXE bytes, asserts only observable files/logs/UI/process state, and fails before publication on any secret or leaked process.
- Deployment captures pre-hashes, creates a timestamped EXE backup, replaces only the EXE, checks INI/Contextmenu hashes, and restores on failure.
- Publication creates new `v3.6-kirs.2`; it records and rechecks Kirs.1 tag and Release evidence rather than moving or editing them.
- Built, deployed, and freshly downloaded Release EXEs must have one identical SHA-256.
- Passwords are excluded from result serialization, diagnostics, legacy command logs, clipboard-derived reports, release notes, and test output.

### Plan hygiene audit

- Exactly 10 ordered tasks are present; each has files, RED, implementation, GREEN, focused commit, and independent review/deployment gates appropriate to its risk.
- All remaining implementation work is expressed as checkboxes; no product-code claim is marked complete.
- No agent fill marker, unfinished-work token, vague “same as above” instruction, or implementation placeholder remains.
- Markdown fences are balanced, referenced repository paths are explicit, and temporary/deployed paths are absolute where safety matters.
- Scratch generators created during plan drafting are not part of the worktree or commit.
- Before committing this plan, run the final mechanical checks below and require no output from the searches:

```powershell
$plan = 'docs\superpowers\plans\2026-07-20-smartzip-kirs2-extraction-reliability.md'
$text = Get-Content $plan -Raw
if (([regex]::Matches($text, '(?m)^```')).Count % 2) { throw 'unbalanced Markdown fences' }
if (([regex]::Matches($text, '(?m)^### Task ')).Count -ne 10) { throw 'task count mismatch' }
$forbidden = @('GROK' + '_FILL', 'T' + 'BD', 'TO' + 'DO', 'FIX' + 'ME',
  'PLACE' + 'HOLDER', 'similar' + ' to', 'handle' + ' errors') -join '|'
rg -n $forbidden $plan
git diff --check
git status --short --branch
```

The implementation session must still use `superpowers:subagent-driven-development`, one fresh implementer per task, a separate spec-compliance reviewer, and a separate code-quality reviewer. No task advances while either reviewer reports Critical or Important findings.
