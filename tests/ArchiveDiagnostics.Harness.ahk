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
