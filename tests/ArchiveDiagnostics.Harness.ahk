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

_ArrayHas(arr, value) {
    for item in arr {
        if (item = value)
            return true
    }
    return false
}

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
    ; Contiguous range 01..10 with only 01 and 10 present → missing 02..09 exactly (not past 10)
    AssertEq(g.missingVolumes.Length, 8, "part10_rar_reports_gap_missing_count")
    AssertTrue(_ArrayHas(g.missingVolumes, "movie.part02.rar"), "part10_rar_missing_includes_part02")
    AssertTrue(_ArrayHas(g.missingVolumes, "movie.part09.rar"), "part10_rar_missing_includes_part09")
    AssertFalse(_ArrayHas(g.missingVolumes, "movie.part01.rar"), "part10_rar_missing_excludes_present_first")
    AssertFalse(_ArrayHas(g.missingVolumes, "movie.part10.rar"), "part10_rar_missing_excludes_selected")
    AssertFalse(_ArrayHas(g.missingVolumes, "movie.part11.rar"), "part10_rar_missing_excludes_part11")

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

    ; --- review-fix: absent selected path is not a member ---
    ; Select archive.7z.002 when only 001 is present among siblings → isVolume, first derived,
    ; members only the present sibling; selected 002 must not appear as a member.
    siblings := ["archive.7z.001"]
    g := DetectVolumeGroup(dir "\archive.7z.002", siblings)
    AssertTrue(g.isVolume, "absent_selected_is_volume")
    AssertEq(g.firstPath, dir "\archive.7z.001", "absent_selected_first_path")
    AssertEq(g.members.Length, 1, "absent_selected_member_count")
    AssertEq(g.members[1], dir "\archive.7z.001", "absent_selected_member_only_present")
    AssertFalse(_ArrayHas(g.members, dir "\archive.7z.002"), "absent_selected_not_member")
    AssertTrue(_ArrayHas(g.missingVolumes, "archive.7z.002"), "absent_selected_listed_missing")

    ; --- review-fix: firstPath preserves observed sibling casing ---
    siblings := ["Archive.7z.001", "archive.7z.002"]
    g := DetectVolumeGroup(dir "\archive.7z.002", siblings)
    AssertTrue(g.isVolume, "present_first_sibling_casing_is_volume")
    AssertEq(g.firstPath, dir "\Archive.7z.001", "present_first_sibling_casing")

    ; --- review-fix: .000 is not a valid volume index ---
    siblings := ["file.000"]
    g := DetectVolumeGroup(dir "\file.000", siblings)
    AssertFalse(g.isVolume, "numeric_000_not_volume")
    AssertEq(g.firstPath, "", "numeric_000_empty_first")
    AssertEq(g.members.Length, 0, "numeric_000_empty_members")
    AssertEq(g.missingVolumes.Length, 0, "numeric_000_empty_missing")
    AssertFalse(g.selectedIsFirst, "numeric_000_selected_not_first")

    siblings := ["file.7z.000"]
    g := DetectVolumeGroup(dir "\file.7z.000", siblings)
    AssertFalse(g.isVolume, "numeric_7z_000_not_volume")
    AssertEq(g.firstPath, "", "numeric_7z_000_empty_first")
    AssertEq(g.members.Length, 0, "numeric_7z_000_empty_members")
    AssertEq(g.missingVolumes.Length, 0, "numeric_7z_000_empty_missing")
    AssertFalse(g.selectedIsFirst, "numeric_7z_000_selected_not_first")

    ; --- review-fix: .part00.rar is not a volume ---
    siblings := ["name.part00.rar"]
    g := DetectVolumeGroup(dir "\name.part00.rar", siblings)
    AssertFalse(g.isVolume, "part00_not_volume")
    AssertEq(g.firstPath, "", "part00_empty_first")
    AssertEq(g.members.Length, 0, "part00_empty_members")
    AssertEq(g.missingVolumes.Length, 0, "part00_empty_missing")
    AssertFalse(g.selectedIsFirst, "part00_selected_not_first")

    ; --- review-fix: large suffix span (>4096) stays bounded; keep observed members; empty missing ---
    siblings := ["huge.7z.0001", "huge.7z.5000"]
    g := DetectVolumeGroup(dir "\huge.7z.0001", siblings)
    AssertTrue(g.isVolume, "large_suffix_is_volume")
    AssertEq(g.missingVolumes.Length, 0, "large_suffix_empty_missing")
    AssertEq(g.members.Length, 2, "large_suffix_retains_members")
    AssertTrue(_ArrayHas(g.members, dir "\huge.7z.0001"), "large_suffix_retains_001")
    AssertTrue(_ArrayHas(g.members, dir "\huge.7z.5000"), "large_suffix_retains_5000")

    ; --- review-fix: invalid sibling index 0 ignored (not treated as volume member) ---
    siblings := ["archive.7z.000", "archive.7z.001", "archive.7z.002"]
    g := DetectVolumeGroup(dir "\archive.7z.001", siblings)
    AssertTrue(g.isVolume, "invalid_sibling_zero_is_volume")
    AssertEq(g.members.Length, 2, "invalid_sibling_zero_ignored")
    AssertFalse(_ArrayHas(g.members, dir "\archive.7z.000"), "invalid_sibling_zero_not_member")
    AssertTrue(_ArrayHas(g.members, dir "\archive.7z.001"), "invalid_sibling_zero_keeps_001")
    AssertTrue(_ArrayHas(g.members, dir "\archive.7z.002"), "invalid_sibling_zero_keeps_002")

    ; --- review-fix: mixed numeric widths are separate groups ---
    siblings := ["mix.7z.001", "mix.7z.01"]
    g := DetectVolumeGroup(dir "\mix.7z.001", siblings)
    AssertTrue(g.isVolume, "mixed_numeric_width_is_volume")
    AssertEq(g.members.Length, 1, "mixed_numeric_width_member_count")
    AssertFalse(_ArrayHas(g.members, dir "\mix.7z.01"), "mixed_numeric_width_excludes_other_width")

    ; --- review-fix: mixed part widths are separate groups ---
    siblings := ["movie.part01.rar", "movie.part001.rar"]
    g := DetectVolumeGroup(dir "\movie.part01.rar", siblings)
    AssertTrue(g.isVolume, "mixed_part_width_is_volume")
    AssertEq(g.members.Length, 1, "mixed_part_width_member_count")
    AssertFalse(_ArrayHas(g.members, dir "\movie.part001.rar"), "mixed_part_width_excludes_other_width")

    ; --- review-fix: inclusive range above 4096 does not create missing names ---
    siblings := ["edge.0001", "edge.4097"]
    g := DetectVolumeGroup(dir "\edge.0001", siblings)
    AssertTrue(g.isVolume, "inclusive_bound_is_volume")
    AssertEq(g.missingVolumes.Length, 0, "inclusive_bound_empty_missing")
    AssertEq(g.members.Length, 2, "inclusive_bound_keeps_members")
    AssertTrue(_ArrayHas(g.members, dir "\edge.4097"), "inclusive_bound_keeps_last")
}

summary := "SUMMARY passed=" passCount " failed=" failCount
lines.Push(summary)
text := ""
for line in lines
    text .= line "`r`n"
try FileDelete(outPath)
FileAppend(text, outPath, "UTF-8")
ExitApp(failCount > 0 ? 1 : 0)
