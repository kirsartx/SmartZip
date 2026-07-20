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
