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
; AHK v2 RegExReplace(Haystack, Needle, Replacement, &OutputVarCount, Limit).
; Limit is the 5th parameter — passing it 4th (as in brief draft) hangs/throws under ErrorStdOut.
occCount := 0
RegExReplace(joined, "last-ok", "X", &occCount)
AssertEq(occCount, 1, "cand_last_ok_once")
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
