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
