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

; --- Eligible encrypted CRC enters password resolution; generic corrupt above still passes through ---
host.ResetPasswordState()
probeEnc := ArchiveResult(ArchiveStatus.DATA_CORRUPT, "extract", 2, "C:\\enc.7z", "ERROR: CRC Failed in encrypted file`n")
probeEnc.encryptionEvidence := true
probeEnc.passwordRetryEligible := true
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.DATA_CORRUPT, "test", 2, "C:\\enc.7z", "ERROR: CRC Failed in encrypted file`n"),
    "right-enc", ArchiveResult(ArchiveStatus.OK, "test", 0, "C:\\enc.7z", "Everything is Ok`n")
)
host.password := ["right-enc"]
host.dialogOverride := { action: "cancel", password: "" }
host.muilt := false
rEnc := host.ResolveArchivePassword("C:\\enc.7z", probeEnc)
AssertEq(rEnc.status, ArchiveStatus.OK, "resolve_eligible_data_corrupt_accepts_password")
AssertTrue(host.testCalls > 0, "resolve_eligible_data_corrupt_runs_tests")

; Eligible encrypted CRC that remains ambiguous must not be relabeled as a password failure.
probeEnc2 := ArchiveResult(ArchiveStatus.DATA_CORRUPT, "extract", 2, "C:\\enc2.7z", "ERROR: CRC Failed in encrypted file`n")
probeEnc2.encryptionEvidence := true
probeEnc2.passwordRetryEligible := true
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.DATA_CORRUPT, "test", 2, "C:\\enc2.7z", "ERROR: CRC Failed in encrypted file`n"),
    "nope", ArchiveResult(ArchiveStatus.DATA_CORRUPT, "test", 2, "C:\\enc2.7z", "ERROR: CRC Failed in encrypted file`n")
)
host.password := ["nope"]
host.dialogOverride := { action: "cancel", password: "" }
rEnc2 := host.ResolveArchivePassword("C:\\enc2.7z", probeEnc2)
AssertEq(rEnc2.status, ArchiveStatus.DATA_CORRUPT, "resolve_eligible_cancel_keeps_data_corrupt")

; Batch: never opens dialog even for NEED_PASSWORD after candidates fail.
host.muilt := true
host.dialogCalls := 0
probeNeedBatch := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 2, "C:\\b.7z", "Enter password (will not be echoed):`n")
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\b.7z", "ERROR: Wrong password?`n")
)
host.password := []
host.dialogOverride := { action: "use", password: "should-not-run" }
rBatch := host.ResolveArchivePassword("C:\\b.7z", probeNeedBatch)
AssertTrue(rBatch.status = ArchiveStatus.NEED_PASSWORD || rBatch.status = ArchiveStatus.WRONG_PASSWORD, "batch_resolve_no_success_without_candidates")
AssertEq(host.dialogCalls, 0, "batch_resolve_never_opens_password_dialog")
host.muilt := false

; Recovery-session evidence must survive empty/candidate DATA_CORRUPT results.
host.ResetPasswordState()
host.muilt := true
batchSecret := "BatchAmbiguousSecret-9f31"
probeNeedEvidence := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 2,
    "C:\\batch-evidence.7z", "Enter password (will not be echoed):`n")
probeNeedEvidence.encryptionEvidence := true
host.scriptedTest := Map(
    "", ArchiveResult(ArchiveStatus.DATA_CORRUPT, "test", 2,
        "C:\\batch-evidence.7z", "ERROR: Data Error`n"),
    batchSecret, ArchiveResult(ArchiveStatus.DATA_CORRUPT, "test", 2,
        "C:\\batch-evidence.7z", "ERROR: Data Error`n")
)
host.password := [batchSecret]
host.dialogOverride := { action: "use", password: "should-not-run" }
rBatchCorrupt := host.ResolveArchivePassword("C:\\batch-evidence.7z", probeNeedEvidence)
AssertEq(rBatchCorrupt.status, ArchiveStatus.DATA_CORRUPT, "resolve_batch_corrupt_keeps_status")
AssertTrue(rBatchCorrupt.encryptionEvidence, "resolve_batch_corrupt_keeps_encryption_evidence")
AssertTrue(rBatchCorrupt.passwordRetryEligible, "resolve_batch_corrupt_keeps_retry_eligibility")
AssertEq(host.dialogCalls, 0, "resolve_batch_corrupt_never_opens_dialog")
AssertFalse(InStr(host.testLog, batchSecret) > 0, "resolve_ambiguous_log_hides_candidate")
AssertTrue(InStr(host.testLog, "-p***") > 0, "resolve_ambiguous_log_uses_redacted_placeholder")

; NEED_PASSWORD can carry encryption evidence before its retry-eligibility flag is set.
; If empty-password testing proves ambiguous DATA_CORRUPT, cancel returns that last
; eligible corruption result instead of erasing it as CANCELLED.
host.ResetPasswordState()
host.muilt := false
probeCancelEvidence := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 2,
    "C:\\cancel-evidence.7z", "Enter password (will not be echoed):`n")
probeCancelEvidence.encryptionEvidence := true
host.scriptedTest := Map(
    "", ArchiveResult(ArchiveStatus.DATA_CORRUPT, "test", 2,
        "C:\\cancel-evidence.7z", "ERROR: Data Error`n")
)
host.password := []
host.dialogOverride := { action: "cancel", password: "" }
rCancelCorrupt := host.ResolveArchivePassword("C:\\cancel-evidence.7z", probeCancelEvidence)
AssertEq(rCancelCorrupt.status, ArchiveStatus.DATA_CORRUPT, "resolve_cancel_after_corrupt_keeps_status")
AssertTrue(rCancelCorrupt.encryptionEvidence, "resolve_cancel_after_corrupt_keeps_encryption_evidence")
AssertTrue(rCancelCorrupt.passwordRetryEligible, "resolve_cancel_after_corrupt_keeps_retry_eligibility")
AssertEq(host.dialogCalls, 1, "resolve_cancel_after_corrupt_opens_dialog_once")

; Typed-password DATA_CORRUPT is part of the same recovery session and inherits evidence.
host.ResetPasswordState()
host.muilt := false
probeTypedEvidence := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 2,
    "C:\\typed-evidence.7z", "Enter password (will not be echoed):`n")
probeTypedEvidence.encryptionEvidence := true
host.scriptedTest := Map(
    "", ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2,
        "C:\\typed-evidence.7z", "ERROR: Wrong password?`n"),
    "typed-ambiguous", ArchiveResult(ArchiveStatus.DATA_CORRUPT, "test", 2,
        "C:\\typed-evidence.7z", "ERROR: Data Error`n")
)
host.password := []
host.dialogOverride := { action: "use", password: "typed-ambiguous" }
rTypedCorrupt := host.ResolveArchivePassword("C:\\typed-evidence.7z", probeTypedEvidence)
AssertEq(rTypedCorrupt.status, ArchiveStatus.DATA_CORRUPT, "resolve_typed_corrupt_keeps_status")
AssertTrue(rTypedCorrupt.encryptionEvidence, "resolve_typed_corrupt_keeps_encryption_evidence")
AssertTrue(rTypedCorrupt.passwordRetryEligible, "resolve_typed_corrupt_keeps_retry_eligibility")

; Controls: ordinary corruption never enters password UI; ordinary cancel is unchanged.
host.ResetPasswordState()
host.muilt := false
plainCorrupt := ArchiveResult(ArchiveStatus.DATA_CORRUPT, "probe", 2,
    "C:\\plain-crc.7z", "ERROR: CRC Failed`n")
host.ResolveArchivePassword("C:\\plain-crc.7z", plainCorrupt)
AssertEq(host.dialogCalls, 0, "resolve_plain_corrupt_never_opens_dialog")

host.ResetPasswordState()
host.muilt := false
plainNeed := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 2,
    "C:\\plain-cancel.7z", "Enter password (will not be echoed):`n")
host.scriptedTest := Map(
    "", ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2,
        "C:\\plain-cancel.7z", "ERROR: Wrong password?`n")
)
host.password := []
host.dialogOverride := { action: "cancel", password: "" }
rPlainCancel := host.ResolveArchivePassword("C:\\plain-cancel.7z", plainNeed)
AssertEq(rPlainCancel.status, ArchiveStatus.CANCELLED, "resolve_plain_cancel_stays_cancelled")

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

; Content-encrypted readable-header ZIP/7z: probe exits 0 with Encrypted = + → NEED_PASSWORD
; so ResolveArchivePassword is entered (I2). Live 7-Zip ZS form.
host.ResetPasswordState()
host.scriptedCapture := { exitCode: 0, output: "Type = zip`nPath = payload.txt`nEncrypted = +`nMethod = AES-256 Store`n", cancelled: false }
prEnc := host.ProbeArchive("C:\\content-enc.zip")
AssertEq(prEnc.status, ArchiveStatus.NEED_PASSWORD, "probe_content_encrypted_plus_need_password")
AssertEq(prEnc.stage, "probe", "probe_content_encrypted_stage")
; Encrypted = - must not enter password path
host.scriptedCapture := { exitCode: 0, output: "Type = zip`nPath = payload.txt`nEncrypted = -`n", cancelled: false }
prPlain := host.ProbeArchive("C:\\plain.zip")
AssertEq(prPlain.status, ArchiveStatus.OK, "probe_encrypted_minus_ok")
host.testCalls := 0
gotPlain := host.ResolveArchivePassword("C:\\plain.zip", prPlain)
AssertEq(gotPlain.status, ArchiveStatus.OK, "resolve_skips_non_password_ok_probe")
AssertEq(host.testCalls, 0, "resolve_no_tests_for_plain_probe")
; NEED_PASSWORD from Encrypted = + must iterate candidates; correct saved password wins
host.ResetPasswordState()
host.lastPass := "right-content"
host.clipText := ""
host.dynamicPassSort := false
host.autoAddPass := false
host.addDir2Pass := false
host.password := ["", "right-content"]
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\content-enc.zip", "ERROR: Wrong password : payload.txt`n"),
    "right-content", ArchiveResult(ArchiveStatus.OK, "test", 0, "C:\\content-enc.zip", "Everything is Ok`n")
)
probeContent := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 0, "C:\\content-enc.zip", "Encrypted = +`n")
gotContent := host.ResolveArchivePassword("C:\\content-enc.zip", probeContent)
AssertEq(gotContent.status, ArchiveStatus.OK, "resolve_content_encrypted_correct_password_ok")
AssertEq(gotContent.passwordUsed, "right-content", "resolve_content_encrypted_sets_password_used")
; Wrong password on content-encrypted ZIP colon form stays WRONG_PASSWORD
host.ResetPasswordState()
host.lastPass := ""
host.clipText := ""
host.dynamicPassSort := false
host.autoAddPass := false
host.addDir2Pass := false
host.password := [""]
host.dialogOverride := { action: "use", password: "typed-wrong-zip" }
host.scriptedTest := Map(
    "" , ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\content-enc.zip", "ERROR: Wrong password : payload.txt`n"),
    "typed-wrong-zip", ArchiveResult(ArchiveStatus.WRONG_PASSWORD, "test", 2, "C:\\content-enc.zip", "ERROR: Wrong password : payload.txt`n")
)
probeContent2 := ArchiveResult(ArchiveStatus.NEED_PASSWORD, "probe", 0, "C:\\content-enc.zip", "Encrypted = +`n")
gotZipWrong := host.ResolveArchivePassword("C:\\content-enc.zip", probeContent2)
AssertEq(gotZipWrong.status, ArchiveStatus.WRONG_PASSWORD, "resolve_content_encrypted_wrong_password_colon")

; Restore clean capture path for TestArchive product classification assertions
host.ResetPasswordState()
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
