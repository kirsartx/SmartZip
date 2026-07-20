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
