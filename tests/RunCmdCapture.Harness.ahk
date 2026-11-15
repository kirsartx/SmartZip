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

; Split UTF-8 codepoints across writes and pipe reads. Text-mode incremental
; reads can replace a leading byte before its continuation bytes arrive.
emitter := A_Temp "\SmartZip-Utf8Emitter-" DllCall("GetCurrentProcessId") ".ahk"
emitterText := "
(
#Requires AutoHotkey v2.0
#SingleInstance Off
h := DllCall("GetStdHandle", "Int", -11, "Ptr")
b := Buffer(1)
Loop 8 {
    for value in [0xE4, 0xB8, 0xAD] {
        NumPut("UChar", value, b)
        DllCall("WriteFile", "Ptr", h, "Ptr", b.Ptr, "UInt", 1, "UInt*", &written := 0, "Ptr", 0)
        Sleep 50
    }
}
ExitApp
)"
try FileDelete(emitter)
FileAppend(emitterText, emitter, "UTF-8")
expectedUtf8 := ""
Loop 8
    expectedUtf8 .= Chr(0x4E2D)
try {
    splitUtf8 := host.RunCmdCapture('"' A_AhkPath '" /ErrorStdOut "' emitter '"', "UTF-8")
    AssertTrue(splitUtf8.exitCode = 0 && splitUtf8.output == expectedUtf8, "capture_preserves_split_utf8")
} finally {
    FileDelete(emitter)
}

; A fast bulk writer exposes pipe backpressure without a wall-clock threshold.
bulkEmitter := A_Temp "\SmartZip-BulkEmitter-" DllCall("GetCurrentProcessId") ".ahk"
bulkText := "
(
#Requires AutoHotkey v2.0
#SingleInstance Off
h := DllCall("GetStdHandle", "Int", -11, "Ptr")
block := Buffer(4096, 65)
Loop 512 {
    if !DllCall("WriteFile", "Ptr", h, "Ptr", block.Ptr, "UInt", block.Size, "UInt*", &written := 0, "Ptr", 0)
        ExitApp(99)
}
FileAppend("TAIL", "**", "UTF-8-RAW")
ExitApp(7)
)"
FileAppend(bulkText, bulkEmitter, "UTF-8")
try {
    blockText := StrReplace(Format("{:4096}", ""), " ", "A")
    expectedBulk := ""
    Loop 512
        expectedBulk .= blockText
    host.captureReadCalls := 0
    bulk := host.RunCmdCapture('"' A_AhkPath '" /ErrorStdOut "' bulkEmitter '"', "UTF-8")
    AssertTrue(bulk.output == expectedBulk "TAIL", "capture_large_output_complete")
    AssertEq(bulk.exitCode, 7, "capture_large_exit_7")
    AssertTrue(host.captureReadCalls <= 128, "capture_large_read_efficiency")
} finally {
    FileDelete(bulkEmitter)
}

retryHost := RetryCaptureHost()
retryResult := retryHost.RunCmdCapture(cmd5)
AssertTrue(retryResult.exitCode = 0 && InStr(retryResult.output, "UTF8_OK"), "capture_retries_default_pipe")
failedHost := FailedCaptureHost()
failedResult := failedHost.RunCmdCapture(cmd5)
AssertTrue(failedResult.exitCode = -1 && failedResult.output = "" && !failedResult.cancelled
    && failedHost.CMDPID = 0, "capture_pipe_failure_returns_error")

summary := "SUMMARY passed=" passCount " failed=" failCount
lines.Push(summary)
text := ""
for line in lines
    text .= line "`r`n"
try FileDelete(outPath)
FileAppend(text, outPath, "UTF-8")
ExitApp(failCount > 0 ? 1 : 0)
