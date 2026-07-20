#requires -Version 5.0
$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:HarnessSrc = Join-Path $PSScriptRoot 'DiagnosticUI.Harness.ahk'
$script:AhkExe = 'C:\Users\Kirs\AppData\Local\Temp\smartzip-36-ahk-toolchain\AutoHotkey_2.0.26\AutoHotkey64.exe'

$script:CaseKeys = @(
    'reason_OK', 'reason_OK_WITH_WARNING', 'reason_NEED_PASSWORD', 'reason_WRONG_PASSWORD',
    'reason_MISSING_VOLUME', 'reason_NOT_ARCHIVE', 'reason_UNSUPPORTED_METHOD',
    'reason_HEADER_CORRUPT', 'reason_TRUNCATED', 'reason_DATA_CORRUPT', 'reason_CANCELLED',
    'reason_IO_ERROR', 'reason_UNKNOWN_ERROR',
    'title_warning', 'title_failure',
    'button_partial', 'button_retry_password', 'button_locate_first', 'button_open_7zip',
    'button_copy_redacted', 'button_close',
    'batch_success', 'batch_warning', 'batch_failure', 'batch_skipped_one_summary',
    'silence_ok_and_cancelled', 'log_warning',
    'rotate_at_1mib', 'rotate_shift_1_to_2', 'rotate_max_three',
    'redact_dash_p', 'copy_basename_only', 'copy_omits_full_path', 'log_allows_full_path',
    'no_password_or_clipboard_leak', 'partial_utf8_diagnostic'
)

$script:ReasonTable = [ordered]@{
    OK                 = @('解压成功', '无需操作。')
    OK_WITH_WARNING    = @('解压完成，但 7-Zip 返回警告。', '请检查输出文件，并使用 7-Zip 复核压缩包。')
    NEED_PASSWORD      = @('压缩包需要密码。', '请重新输入正确密码后再试。')
    WRONG_PASSWORD     = @('密码错误。', '请检查密码并重新输入。')
    MISSING_VOLUME     = @('分卷不完整，或未从首卷开始。', '请补齐全部分卷并从首卷重新解压。')
    NOT_ARCHIVE        = @('文件不是可识别的压缩包。', '请确认文件类型或使用 7-Zip 打开检查。')
    UNSUPPORTED_METHOD = @('当前 7-Zip 不支持此压缩方法。', '请更新 7-Zip，或使用创建该压缩包的工具。')
    HEADER_CORRUPT     = @('压缩包文件头损坏。', '请重新获取完整源文件，并使用 7-Zip 测试。')
    TRUNCATED          = @('压缩包数据被截断。', '请重新下载或复制完整文件后再试。')
    DATA_CORRUPT       = @('CRC 或数据校验失败。', '请检查“不完整”目录中的可用文件，并重新获取源包。')
    CANCELLED          = @('操作已取消。', '无需操作。')
    IO_ERROR           = @('读取或写入文件失败。', '请检查磁盘空间、文件占用和目录权限。')
    UNKNOWN_ERROR      = @('7-Zip 返回未识别错误。', '请复制脱敏诊断信息，并使用 7-Zip 进一步检查。')
}

function Get-SmartZipSourceText([string]$SmartZipPath) {
    $raw = Get-Content -LiteralPath $SmartZipPath -Raw -Encoding UTF8
    if ($raw -notmatch 'WriteDiagnostic|class SmartZip') {
        $raw = Get-Content -LiteralPath $SmartZipPath -Raw
    }
    return $raw
}

function Get-SourceSlice {
    param([string]$Source, [string]$StartMarker, [string]$EndMarker)
    $start = $Source.IndexOf($StartMarker)
    if ($start -lt 0) { return $null }
    $end = $Source.IndexOf($EndMarker, $start + $StartMarker.Length)
    if ($end -lt 0) { return $Source.Substring($start) }
    return $Source.Substring($start, $end - $start)
}

function Assert-ExactlyOneOccurrence([string]$Text, [string]$Name, [string]$Pattern) {
    $matches = [regex]::Matches($Text, $Pattern)
    if ($matches.Count -ne 1) {
        throw "expected exactly one $Name occurrence, found $($matches.Count)"
    }
}

function Export-DiagnosticUIProductFragment {
    param(
        [Parameter(Mandatory = $true)][string]$SmartZipPath,
        [Parameter(Mandatory = $true)][string]$OutputRoot
    )
    if (-not (Test-Path -LiteralPath $SmartZipPath)) {
        throw "SmartZip.ahk not found: $SmartZipPath"
    }
    $src = Get-SmartZipSourceText $SmartZipPath
    $body = Get-SourceSlice -Source $src -StartMarker "`n    WriteDiagnostic(" -EndMarker "`n    RunCmdCapture("
    if ([string]::IsNullOrEmpty($body)) {
        throw 'diagnostic product slice missing (WriteDiagnostic..RunCmdCapture)'
    }
    $method = $body.TrimStart("`r", "`n")
    $script:ProductFragmentReady = $true
    foreach ($name in @(
            'WriteDiagnostic', 'DiagnosticTitle', 'DiagnosticReason', 'DiagnosticRecommendation',
            'ShowDiagnostic', 'AppendRotatingDiagnosticLog', 'RotateDiagnosticLogIfNeeded'
        )) {
        $matches = [regex]::Matches($method, '(?m)^    ' + [regex]::Escape($name) + '\s*\(')
        if ($matches.Count -ne 1) {
            $script:ProductFragmentReady = $false
            break
        }
    }
    if (-not $script:ProductFragmentReady) {
        # RED-friendly stub host so 36 cases are discovered and fail assertions.
        $stub = @'
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib\ArchiveDiagnostics.ahk
EscapeJson(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    return s
}
RunDiagnosticUICommand(cmd, jsonText, caseKey := "") {
    return '{"key":"' caseKey '","ok":false,"error":"product fragment incomplete","reason":"","recommendation":"","title":"","buttons":[],"showGui":false,"logAppends":0,"rotated":false,"has1":false,"hasOnlyThree":false,"fileCount":0,"exists":false,"leakedPasswordUsed":true,"leakedClipboard":true,"copy":"","log":"","write":"","logText":"","content":"","summaryCalls":0,"guiCalls":0,"buckets":{"success":[],"warning":[],"failure":[],"skipped":[]}}'
}
'@
        if (-not (Test-Path -LiteralPath $OutputRoot)) {
            New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
        }
        $libDir = Join-Path $OutputRoot 'lib'
        New-Item -ItemType Directory -Path $libDir -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'lib\ArchiveDiagnostics.ahk') `
            -Destination (Join-Path $libDir 'ArchiveDiagnostics.ahk') -Force
        $outAhk = Join-Path $OutputRoot 'DiagnosticUI.Product.ahk'
        [System.IO.File]::WriteAllText($outAhk, $stub, [System.Text.UTF8Encoding]::new($true))
        return $outAhk
    }

    if (-not (Test-Path -LiteralPath $OutputRoot)) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    }
    $libDir = Join-Path $OutputRoot 'lib'
    New-Item -ItemType Directory -Path $libDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'lib\ArchiveDiagnostics.ahk') `
        -Destination (Join-Path $libDir 'ArchiveDiagnostics.ahk') -Force

    $outAhk = Join-Path $OutputRoot 'DiagnosticUI.Product.ahk'
    $header = @'
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib\ArchiveDiagnostics.ahk

global MainVersion := "3.6"
global edition := "Kirs.1"
global buildVersion := 21

EscapeJson(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return s
}

JsonGet(text, key, default := "") {
    ; Minimal JSON string/number/bool extractor for flat and nested test inputs.
    pat := '"' key '"\s*:\s*"([^"]*)"'
    if RegExMatch(text, pat, &m)
        return m[1]
    pat2 := '"' key '"\s*:\s*(true|false|null|-?\d+)'
    if RegExMatch(text, pat2, &m2)
        return m2[1]
    return default
}

JsonGetBool(text, key, default := false) {
    v := JsonGet(text, key, default ? "true" : "false")
    return (v = "true" || v = "1")
}

JsonUnescape(s) {
    ; Protect \\ first so real Windows paths (e.g. ...\Temp\...) are not
    ; corrupted when \t/\n/\r escapes are applied after collapsing backslashes.
    s := StrReplace(s, "\\", Chr(1))
    s := StrReplace(s, '\"', '"')
    s := StrReplace(s, "\r", "`r")
    s := StrReplace(s, "\n", "`n")
    s := StrReplace(s, "\t", "`t")
    s := StrReplace(s, Chr(1), "\")
    return s
}

class DiagnosticUIHost {
    7z := "7z.exe"
    7zG := "7zG.exe"
    sevenZipVersion := "23.01"
    muilt := false
    batchDiagnostic := { success: [], warning: [], failure: [], skipped: [] }
    diagHeadless := true
    lastDiagnosticUi := ""
    summaryCalls := 0
    guiCalls := 0
    runCalls := []
    clipboardWrites := []
    clipboardReads := 0
    fileAppends := []
    fileMoves := []
    fileDeletes := []
    workRoot := ""
    scriptDirOverride := ""

    ScriptDir() {
        if (this.scriptDirOverride != "")
            return this.scriptDirOverride
        return A_ScriptDir
    }

    ResetSpies() {
        this.lastDiagnosticUi := ""
        this.summaryCalls := 0
        this.guiCalls := 0
        this.runCalls := []
        this.clipboardWrites := []
        this.clipboardReads := 0
        this.fileAppends := []
        this.fileMoves := []
        this.fileDeletes := []
        this.batchDiagnostic := { success: [], warning: [], failure: [], skipped: [] }
    }

    DiagnosticOpenPath(path) {
        this.runCalls.Push({ kind: "open", path: path })
    }

    DiagnosticRun7zip(path) {
        this.runCalls.Push({ kind: "7zip", path: path })
        if !this.diagHeadless
            Run('"' this.7zG '" "' path '"')
    }

    DiagnosticSetClipboard(text) {
        this.clipboardWrites.Push(text)
        if !this.diagHeadless
            A_Clipboard := text
    }

    DiagnosticShowGui(title, archiveName, reason, recommendation, partialPath, buttons) {
        this.guiCalls++
        this.lastDiagnosticUi := {
            title: title,
            archiveName: archiveName,
            reason: reason,
            recommendation: recommendation,
            partialPath: partialPath,
            buttons: buttons,
            sourceKept: true
        }
        if this.diagHeadless
            return
        ; Production path uses real Gui when not headless — not exercised in this host.
    }

    ResolveArchivePassword(path, probeResult := "") {
        this.runCalls.Push({ kind: "retry_password", path: path })
        return probeResult
    }

'@

    $footer = @'

    ; --- spy-friendly wrappers over file sinks used by product rotation helpers ---
    DiagFileExist(path) {
        return FileExist(path)
    }
    DiagFileGetSize(path) {
        return FileGetSize(path)
    }
    DiagFileDelete(path) {
        this.fileDeletes.Push(path)
        if FileExist(path)
            FileDelete(path)
    }
    DiagFileMove(from, to, overwrite := 0) {
        this.fileMoves.Push({ from: from, to: to, overwrite: overwrite })
        FileMove(from, to, overwrite)
    }
    DiagFileAppend(text, path, enc := "UTF-8") {
        this.fileAppends.Push({ path: path, encoding: enc, text: text })
        FileAppend(text, path, enc)
    }
}

; Patch product Rotate/Append/WriteDiagnostic file ops to use host spy wrappers when present.
; Product code uses FileExist/FileGetSize/FileAppend/FileMove/FileDelete globals; for real-file
; rotation tests we keep real FS and record via wrapping product methods below if needed.

host := DiagnosticUIHost()

MakeResult(status, archivePath := "D:\\data\\folder\\pack.7z", extra := "") {
    r := ArchiveResult(status, "extract", 2, archivePath, "")
    if (status = ArchiveStatus.OK || status = ArchiveStatus.OK_WITH_WARNING)
        r.exitCode := 0
    if (status = ArchiveStatus.CANCELLED)
        r.exitCode := 255
    if (extra != "") {
        if RegExMatch(extra, '"partialOutputDir"\s*:\s*"([^"]*)"', &m)
            r.partialOutputDir := JsonUnescape(m[1])
        if RegExMatch(extra, '"volumeFirst"\s*:\s*"([^"]*)"', &m2)
            r.volumeFirst := JsonUnescape(m2[1])
        if RegExMatch(extra, '"output"\s*:\s*"((?:\\.|[^"\\])*)"', &m3)
            r.output := JsonUnescape(m3[1])
        if RegExMatch(extra, '"stage"\s*:\s*"([^"]*)"', &m4)
            r.stage := m4[1]
        if RegExMatch(extra, '"exitCode"\s*:\s*(-?\d+)', &m5)
            r.exitCode := Integer(m5[1])
        if RegExMatch(extra, '"batchBucket"\s*:\s*"([^"]*)"', &m6)
            r.batchBucket := m6[1]
        if RegExMatch(extra, '"passwordUsed"\s*:\s*"([^"]*)"', &m7)
            r.passwordUsed := m7[1]
        if InStr(extra, '"warningLines"')
            r.warningLines.Push("There are data after the end of archive")
        if InStr(extra, '"errorLines"')
            r.errorLines.Push("ERROR: CRC Failed")
    }
    return r
}

ButtonsToJson(arr) {
    s := "["
    for i, b in arr {
        if (i > 1)
            s .= ","
        s .= '"' EscapeJson(b) '"'
    }
    s .= "]"
    return s
}

ArrayNamesJson(arr) {
    s := "["
    for i, item in arr {
        if (i > 1)
            s .= ","
        name := item
        if (item is Object) {
            if item.HasOwnProp("archivePath")
                name := item.archivePath
            else if item.HasOwnProp("status")
                name := item.status
        }
        SplitPath(name, &leaf)
        if (leaf != "")
            name := leaf
        s .= '"' EscapeJson(String(name)) '"'
    }
    s .= "]"
    return s
}

RunDiagnosticUICommand(cmd, jsonText, caseKey := "") {
    global host
    host.ResetSpies()
    if (host.workRoot = "")
        host.workRoot := A_ScriptDir "\work"
    try DirCreate(host.workRoot)
    host.scriptDirOverride := host.workRoot

    if (cmd = "reason") {
        status := JsonGet(jsonText, "status", "OK")
        r := MakeResult(status)
        reason := host.DiagnosticReason(r)
        rec := host.DiagnosticRecommendation(r)
        return '{"key":"' caseKey '","status":"' status '","reason":"' EscapeJson(reason) '","recommendation":"' EscapeJson(rec) '"}'
    }

    if (cmd = "buttons" || cmd = "title") {
        status := JsonGet(jsonText, "status", "DATA_CORRUPT")
        arch := JsonUnescape(JsonGet(jsonText, "archivePath", "D:\\data\\folder\\pack.7z"))
        r := MakeResult(status, arch, jsonText)
        partial := r.partialOutputDir
        if (partial != "" && JsonGetBool(jsonText, "partialExists", true)) {
            try DirCreate(partial)
        }
        title := host.DiagnosticTitle(r)
        buttons := host.DiagnosticButtons(r)
        host.ShowDiagnostic(r, false)
        showGui := host.guiCalls > 0
        bn := ""
        if (r.archivePath != "")
            SplitPath(r.archivePath, &bn)
        return '{"key":"' caseKey '","status":"' status '","title":"' EscapeJson(title) '","buttons":' ButtonsToJson(buttons)
            . ',"showGui":' (showGui ? "true" : "false") ',"basename":"' EscapeJson(bn) '","sourceKeptLabel":"源包已保留"}'
    }

    if (cmd = "batch") {
        host.muilt := true
        host.batchDiagnostic := { success: [], warning: [], failure: [], skipped: [] }
        ; Fixed multi-result batch for bucket assertions
        specs := [
            { status: ArchiveStatus.OK, path: "a.zip" },
            { status: ArchiveStatus.OK_WITH_WARNING, path: "b.zip" },
            { status: ArchiveStatus.DATA_CORRUPT, path: "c.zip" },
            { status: ArchiveStatus.CANCELLED, path: "d.zip" },
            { status: ArchiveStatus.OK, path: "e.part02.rar", bucket: "skipped" }
        ]
        for s in specs {
            r := MakeResult(s.status, s.path)
            if s.HasOwnProp("bucket")
                r.batchBucket := s.bucket
            host.ShowDiagnostic(r, true)
        }
        if JsonGetBool(jsonText, "callSummary", true)
            host.ShowBatchDiagnosticSummary()
        return '{"key":"' caseKey '"'
            . ',"buckets":{"success":' ArrayNamesJson(host.batchDiagnostic.success)
            . ',"warning":' ArrayNamesJson(host.batchDiagnostic.warning)
            . ',"failure":' ArrayNamesJson(host.batchDiagnostic.failure)
            . ',"skipped":' ArrayNamesJson(host.batchDiagnostic.skipped) '}'
            . ',"summaryCalls":' host.summaryCalls ',"guiCalls":' host.guiCalls '}'
    }

    if (cmd = "log" || cmd = "silence") {
        ; silence_ok_and_cancelled runs both OK and CANCELLED
        if (InStr(caseKey, "silence") || JsonGet(jsonText, "mode", "") = "silence") {
            r1 := MakeResult(ArchiveStatus.OK, "D:\\x\\a.zip")
            r1.stage := "extract"
            r1.exitCode := 0
            host.ShowDiagnostic(r1, false)
            t1 := host.WriteDiagnostic(r1)
            g1 := host.guiCalls
            a1 := host.fileAppends.Length
            host.ResetSpies()
            host.scriptDirOverride := host.workRoot
            r2 := MakeResult(ArchiveStatus.CANCELLED, "D:\\x\\b.zip")
            r2.stage := "extract"
            r2.exitCode := 255
            host.ShowDiagnostic(r2, false)
            t2 := host.WriteDiagnostic(r2)
            g2 := host.guiCalls
            a2 := host.fileAppends.Length
            logPath := host.workRoot "\SmartZip-diagnostics.log"
            logExists := FileExist(logPath) ? true : false
            return '{"key":"' caseKey '","showGui":' ((g1 + g2) > 0 ? "true" : "false")
                . ',"logAppends":' (a1 + a2) ',"logExists":' (logExists ? "true" : "false") '}'
        }
        status := JsonGet(jsonText, "status", "OK_WITH_WARNING")
        arch := JsonUnescape(JsonGet(jsonText, "archivePath", "D:\\x\\a.zip"))
        r := MakeResult(status, arch, jsonText)
        if (status = ArchiveStatus.OK_WITH_WARNING)
            r.warningLines := ["There are data after the end of archive"]
        text := host.WriteDiagnostic(r)
        host.ShowDiagnostic(r, false)
        logPath := host.workRoot "\SmartZip-diagnostics.log"
        logText := FileExist(logPath) ? FileRead(logPath, "UTF-8") : ""
        return '{"key":"' caseKey '","showGui":' (host.guiCalls > 0 ? "true" : "false")
            . ',"logAppends":' host.fileAppends.Length
            . ',"logText":"' EscapeJson(logText) '","diagnostic":"' EscapeJson(text) '"}'
    }

    if (cmd = "rotate") {
        logPath := host.workRoot "\SmartZip-diagnostics.log"
        try {
            if FileExist(logPath)
                FileDelete(logPath)
            if FileExist(logPath ".1")
                FileDelete(logPath ".1")
            if FileExist(logPath ".2")
                FileDelete(logPath ".2")
        } catch {
        }
        mode := caseKey
        if (mode = "rotate_at_1mib" || InStr(jsonText, "1048576")) {
            ; Create exactly 1 MiB log so next append rotates
            f := FileOpen(logPath, "w", "UTF-8")
            pad := ""
            while (StrLen(pad) < 1024)
                pad .= "x"
            ; write until >= 1048576 bytes
            while (f.Length < 1048576)
                f.Write(pad)
            f.Close()
            sz := FileGetSize(logPath)
            host.AppendRotatingDiagnosticLog("entry-after-1mib")
            has1 := FileExist(logPath ".1") ? true : false
            has2 := FileExist(logPath ".2") ? true : false
            has0 := FileExist(logPath) ? true : false
            newText := has0 ? FileRead(logPath, "UTF-8") : ""
            return '{"key":"' caseKey '","sizeBefore":' sz ',"hasLog":' (has0 ? "true" : "false")
                . ',"has1":' (has1 ? "true" : "false") ',"has2":' (has2 ? "true" : "false")
                . ',"newText":"' EscapeJson(newText) '","rotated":' (has1 ? "true" : "false") '}'
        }
        if (mode = "rotate_shift_1_to_2") {
            FileAppend("old-current`r`n", logPath, "UTF-8")
            ; force size threshold
            f := FileOpen(logPath, "a", "UTF-8")
            pad := ""
            while (StrLen(pad) < 1024)
                pad .= "y"
            while (f.Length < 1048576)
                f.Write(pad)
            f.Close()
            FileAppend("old-one`r`n", logPath ".1", "UTF-8")
            host.AppendRotatingDiagnosticLog("entry-shift")
            t1 := FileExist(logPath ".1") ? FileRead(logPath ".1", "UTF-8") : ""
            t2 := FileExist(logPath ".2") ? FileRead(logPath ".2", "UTF-8") : ""
            t0 := FileExist(logPath) ? FileRead(logPath, "UTF-8") : ""
            return '{"key":"' caseKey '","log0":"' EscapeJson(t0) '","log1":"' EscapeJson(t1) '","log2":"' EscapeJson(t2) '"}'
        }
        if (mode = "rotate_max_three") {
            FileAppend("c0`r`n", logPath, "UTF-8")
            f := FileOpen(logPath, "a", "UTF-8")
            pad := ""
            while (StrLen(pad) < 1024)
                pad .= "z"
            while (f.Length < 1048576)
                f.Write(pad)
            f.Close()
            FileAppend("c1`r`n", logPath ".1", "UTF-8")
            FileAppend("c2`r`n", logPath ".2", "UTF-8")
            host.AppendRotatingDiagnosticLog("entry-max3")
            names := []
            if FileExist(logPath)
                names.Push("SmartZip-diagnostics.log")
            if FileExist(logPath ".1")
                names.Push("SmartZip-diagnostics.log.1")
            if FileExist(logPath ".2")
                names.Push("SmartZip-diagnostics.log.2")
            ; count only these three basenames
            count := names.Length
            t2 := FileExist(logPath ".2") ? FileRead(logPath ".2", "UTF-8") : ""
            return '{"key":"' caseKey '","fileCount":' count ',"hasOnlyThree":' (count <= 3 ? "true" : "false")
                . ',"log2":"' EscapeJson(t2) '"}'
        }
        return '{"key":"' caseKey '","error":"unknown rotate mode"}'
    }

    if (cmd = "copy" || cmd = "redact") {
        arch := JsonUnescape(JsonGet(jsonText, "archivePath", "D:\\data\\folder\\pack.7z"))
        status := JsonGet(jsonText, "status", "DATA_CORRUPT")
        output := JsonUnescape(JsonGet(jsonText, "output", '7z t -p"SuperSecret" "D:\\data\\folder\\pack.7z"'))
        r := MakeResult(status, arch)
        r.output := output
        r.errorLines := ["CRC Failed"]
        copyText := host.FormatDiagnosticCopy(r)
        logText := host.FormatDiagnosticLogEntry(r)
        wd := host.WriteDiagnostic(r)
        return '{"key":"' caseKey '","copy":"' EscapeJson(copyText) '","log":"' EscapeJson(logText)
            . '","write":"' EscapeJson(wd) '"}'
    }

    if (cmd = "leak" || cmd = "no_password_or_clipboard_leak") {
        arch := "D:\\data\\folder\\pack.7z"
        r := MakeResult(ArchiveStatus.DATA_CORRUPT, arch)
        r.passwordUsed := "SecretPass"
        r.output := 'cmd -p"SecretPass" file'
        copyText := host.FormatDiagnosticCopy(r)
        logText := host.FormatDiagnosticLogEntry(r)
        wd := host.WriteDiagnostic(r)
        host.ShowDiagnostic(r, false)
        all := copyText "`n" logText "`n" wd
        if host.lastDiagnosticUi != "" {
            all .= "`n" host.lastDiagnosticUi.title "`n" host.lastDiagnosticUi.reason
        }
        for c in host.clipboardWrites
            all .= "`n" c
        leakedPw := InStr(all, "SecretPass") > 0
        leakedClip := InStr(all, "ClipSecret") > 0
        return '{"key":"' caseKey '","leakedPasswordUsed":' (leakedPw ? "true" : "false")
            . ',"leakedClipboard":' (leakedClip ? "true" : "false")
            . ',"clipboardReads":' host.clipboardReads
            . ',"allText":"' EscapeJson(all) '"}'
    }

    if (cmd = "partial") {
        partial := host.workRoot "\pack_partial"
        try {
            if DirExist(partial)
                DirDelete(partial, 1)
        } catch {
        }
        DirCreate(partial)
        r := MakeResult(ArchiveStatus.DATA_CORRUPT, "D:\\data\\folder\\pack.7z")
        r.partialOutputDir := partial
        r.errorLines := ["CRC Failed"]
        r.output := "ERROR: CRC Failed"
        text := host.WriteDiagnostic(r)
        diagPath := partial "\SmartZip-诊断.txt"
        exists := FileExist(diagPath) ? true : false
        content := exists ? FileRead(diagPath, "UTF-8") : ""
        ; UTF-8 check: file should contain status and Chinese marker path name policy
        return '{"key":"' caseKey '","exists":' (exists ? "true" : "false")
            . ',"content":"' EscapeJson(content) '","returned":"' EscapeJson(text) '"}'
    }

    return '{"key":"' caseKey '","error":"unknown command","cmd":"' EscapeJson(cmd) '"}'
}
'@

    # Insert product methods into the host class (before the spy wrappers footer section).
    # $header ends inside class; $method is product methods; then close class with footer start.
    # Rebuild carefully: header opens class, product methods, then footer adds wrappers + closes class + dispatch.
    $full = $header + "`r`n" + $method + "`r`n" + $footer
    [System.IO.File]::WriteAllText($outAhk, $full, [System.Text.UTF8Encoding]::new($true))
    return $outAhk
}

function Invoke-DiagnosticUICase {
    param(
        [string]$Command,
        [string]$CaseKey,
        [string]$Json,
        [string]$StageDir
    )
    $jsonPath = Join-Path $StageDir ($CaseKey + '.json')
    $outPath = Join-Path $StageDir ($CaseKey + '.out.json')
    [System.IO.File]::WriteAllText($jsonPath, $Json, [System.Text.UTF8Encoding]::new($true))
    if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }
    $harness = Join-Path $StageDir 'DiagnosticUI.Harness.ahk'
    $p = Start-Process -FilePath $script:AhkExe -ArgumentList @($harness, $Command, $jsonPath, $outPath, $CaseKey) `
        -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0 -and -not (Test-Path -LiteralPath $outPath)) {
        throw "AHK harness failed for $CaseKey exit=$($p.ExitCode)"
    }
    if (-not (Test-Path -LiteralPath $outPath)) {
        throw "No output for $CaseKey"
    }
    return Get-Content -LiteralPath $outPath -Raw -Encoding UTF8
}

function Get-JsonField([string]$Json, [string]$Name) {
    if ($Json -match ('"' + [regex]::Escape($Name) + '"\s*:\s*"((?:\\.|[^"\\])*)"')) {
        $s = $Matches[1]
        $s = $s -replace '\\n', "`n" -replace '\\r', "`r" -replace '\\t', "`t" -replace '\\"', '"' -replace '\\\\', '\'
        return $s
    }
    if ($Json -match ('"' + [regex]::Escape($Name) + '"\s*:\s*(true|false|null|-?\d+)')) {
        return $Matches[1]
    }
    return $null
}

function Test-JsonHasButton([string]$Json, [string]$Label) {
    return $Json -match [regex]::Escape('"' + $Label + '"')
}

Describe 'DiagnosticUI' {
    BeforeAll {
        if (-not (Test-Path -LiteralPath $script:AhkExe)) {
            throw "AutoHotkey not found: $script:AhkExe"
        }
        $script:StageDir = Join-Path $env:TEMP ('SmartZip-DiagUI-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:StageDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:StageDir 'work') -Force | Out-Null
        Copy-Item -LiteralPath $script:HarnessSrc -Destination (Join-Path $script:StageDir 'DiagnosticUI.Harness.ahk') -Force
        $script:ProductPath = Export-DiagnosticUIProductFragment `
            -SmartZipPath (Join-Path $script:RepoRoot 'SmartZip.ahk') `
            -OutputRoot $script:StageDir
    }

    AfterAll {
        if ($script:StageDir -and (Test-Path -LiteralPath $script:StageDir)) {
            try { Remove-Item -LiteralPath $script:StageDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    # --- 13 reason mappings ---
    foreach ($status in @($script:ReasonTable.Keys)) {
        $key = 'reason_' + $status
        It $key {
            $json = '{"status":"' + $status + '"}'
            $out = Invoke-DiagnosticUICase -Command 'reason' -CaseKey $key -Json $json -StageDir $script:StageDir
            $expected = $script:ReasonTable[$status]
            (Get-JsonField $out 'reason') | Should Be $expected[0]
            (Get-JsonField $out 'recommendation') | Should Be $expected[1]
        }
    }

    It 'title_warning' {
        $out = Invoke-DiagnosticUICase -Command 'title' -CaseKey 'title_warning' `
            -Json '{"status":"OK_WITH_WARNING","archivePath":"D:\\data\\a.zip"}' -StageDir $script:StageDir
        (Get-JsonField $out 'title') | Should Be 'SmartZip 解压警告'
        (Get-JsonField $out 'showGui') | Should Be 'true'
    }

    It 'title_failure' {
        $out = Invoke-DiagnosticUICase -Command 'title' -CaseKey 'title_failure' `
            -Json '{"status":"DATA_CORRUPT","archivePath":"D:\\data\\a.zip"}' -StageDir $script:StageDir
        (Get-JsonField $out 'title') | Should Be 'SmartZip 未完成解压'
        (Get-JsonField $out 'showGui') | Should Be 'true'
    }

    It 'button_partial' {
        $partial = (Join-Path $script:StageDir 'work\pack_partial_dir') -replace '\\', '\\'
        $out = Invoke-DiagnosticUICase -Command 'buttons' -CaseKey 'button_partial' `
            -Json ('{"status":"DATA_CORRUPT","archivePath":"D:\\data\\pack.7z","partialOutputDir":"' + $partial + '","partialExists":true}') `
            -StageDir $script:StageDir
        (Test-JsonHasButton $out '打开部分文件目录') | Should Be $true
        (Test-JsonHasButton $out '使用 7-Zip 打开') | Should Be $true
        (Test-JsonHasButton $out '复制脱敏诊断信息') | Should Be $true
        (Test-JsonHasButton $out '关闭') | Should Be $true
        (Get-JsonField $out 'showGui') | Should Be 'true'
    }

    It 'button_retry_password' {
        $out = Invoke-DiagnosticUICase -Command 'buttons' -CaseKey 'button_retry_password' `
            -Json '{"status":"WRONG_PASSWORD","archivePath":"D:\\data\\secret.7z","partialOutputDir":"","partialExists":false}' `
            -StageDir $script:StageDir
        (Test-JsonHasButton $out '重新输入密码') | Should Be $true
        (Test-JsonHasButton $out '使用 7-Zip 打开') | Should Be $true
        (Test-JsonHasButton $out '定位首卷') | Should Be $false
        (Get-JsonField $out 'showGui') | Should Be 'true'
    }

    It 'button_locate_first' {
        $out = Invoke-DiagnosticUICase -Command 'buttons' -CaseKey 'button_locate_first' `
            -Json '{"status":"MISSING_VOLUME","archivePath":"D:\\data\\v.part01.rar","volumeFirst":"D:\\data\\v.part01.rar"}' `
            -StageDir $script:StageDir
        (Test-JsonHasButton $out '定位首卷') | Should Be $true
        (Test-JsonHasButton $out '使用 7-Zip 打开') | Should Be $true
        (Test-JsonHasButton $out '重新输入密码') | Should Be $false
        (Get-JsonField $out 'showGui') | Should Be 'true'
    }

    It 'button_open_7zip' {
        $out = Invoke-DiagnosticUICase -Command 'buttons' -CaseKey 'button_open_7zip' `
            -Json '{"status":"OK_WITH_WARNING","archivePath":"D:\\data\\a.zip"}' -StageDir $script:StageDir
        (Test-JsonHasButton $out '使用 7-Zip 打开') | Should Be $true
        (Get-JsonField $out 'showGui') | Should Be 'true'
    }

    It 'button_copy_redacted' {
        $out = Invoke-DiagnosticUICase -Command 'buttons' -CaseKey 'button_copy_redacted' `
            -Json '{"status":"IO_ERROR","archivePath":"D:\\data\\a.zip"}' -StageDir $script:StageDir
        (Test-JsonHasButton $out '复制脱敏诊断信息') | Should Be $true
    }

    It 'button_close' {
        $out = Invoke-DiagnosticUICase -Command 'buttons' -CaseKey 'button_close' `
            -Json '{"status":"UNKNOWN_ERROR","archivePath":"D:\\data\\a.zip"}' -StageDir $script:StageDir
        (Test-JsonHasButton $out '关闭') | Should Be $true
    }

    It 'batch_success' {
        $out = Invoke-DiagnosticUICase -Command 'batch' -CaseKey 'batch_success' `
            -Json '{"callSummary":true}' -StageDir $script:StageDir
        ($out -match '"success":\[[^\]]*"a\.zip"') | Should Be $true
    }

    It 'batch_warning' {
        $out = Invoke-DiagnosticUICase -Command 'batch' -CaseKey 'batch_warning' `
            -Json '{"callSummary":true}' -StageDir $script:StageDir
        ($out -match '"warning":\[[^\]]*"b\.zip"') | Should Be $true
    }

    It 'batch_failure' {
        $out = Invoke-DiagnosticUICase -Command 'batch' -CaseKey 'batch_failure' `
            -Json '{"callSummary":true}' -StageDir $script:StageDir
        ($out -match '"failure":\[[^\]]*"c\.zip"') | Should Be $true
    }

    It 'batch_skipped_one_summary' {
        $out = Invoke-DiagnosticUICase -Command 'batch' -CaseKey 'batch_skipped_one_summary' `
            -Json '{"callSummary":true}' -StageDir $script:StageDir
        ($out -match '"skipped":\[[^\]]*"d\.zip"') | Should Be $true
        ($out -match 'e\.part02\.rar') | Should Be $true
        (Get-JsonField $out 'summaryCalls') | Should Be '1'
        (Get-JsonField $out 'guiCalls') | Should Be '0'
    }

    It 'silence_ok_and_cancelled' {
        $out = Invoke-DiagnosticUICase -Command 'silence' -CaseKey 'silence_ok_and_cancelled' `
            -Json '{"mode":"silence"}' -StageDir $script:StageDir
        (Get-JsonField $out 'showGui') | Should Be 'false'
        (Get-JsonField $out 'logAppends') | Should Be '0'
    }

    It 'log_warning' {
        $out = Invoke-DiagnosticUICase -Command 'log' -CaseKey 'log_warning' `
            -Json '{"status":"OK_WITH_WARNING","archivePath":"D:\\x\\a.zip","stage":"extract","exitCode":0,"warningLines":["warn"]}' `
            -StageDir $script:StageDir
        (Get-JsonField $out 'showGui') | Should Be 'true'
        $logText = Get-JsonField $out 'logText'
        ($logText -match 'OK_WITH_WARNING') | Should Be $true
        ([int](Get-JsonField $out 'logAppends') -ge 1 -or ($logText -and $logText.Length -gt 0)) | Should Be $true
    }

    It 'rotate_at_1mib' {
        $out = Invoke-DiagnosticUICase -Command 'rotate' -CaseKey 'rotate_at_1mib' `
            -Json '{"threshold":1048576}' -StageDir $script:StageDir
        (Get-JsonField $out 'rotated') | Should Be 'true'
        (Get-JsonField $out 'has1') | Should Be 'true'
        $newText = Get-JsonField $out 'newText'
        ($newText -match 'entry-after-1mib') | Should Be $true
    }

    It 'rotate_shift_1_to_2' {
        $out = Invoke-DiagnosticUICase -Command 'rotate' -CaseKey 'rotate_shift_1_to_2' `
            -Json '{}' -StageDir $script:StageDir
        $log2 = Get-JsonField $out 'log2'
        ($log2 -match 'old-one') | Should Be $true
        $log0 = Get-JsonField $out 'log0'
        ($log0 -match 'entry-shift') | Should Be $true
    }

    It 'rotate_max_three' {
        $out = Invoke-DiagnosticUICase -Command 'rotate' -CaseKey 'rotate_max_three' `
            -Json '{}' -StageDir $script:StageDir
        (Get-JsonField $out 'hasOnlyThree') | Should Be 'true'
        ([int](Get-JsonField $out 'fileCount')) | Should Be 3
    }

    It 'redact_dash_p' {
        $out = Invoke-DiagnosticUICase -Command 'copy' -CaseKey 'redact_dash_p' `
            -Json '{"archivePath":"D:\\data\\folder\\pack.7z","status":"DATA_CORRUPT","output":"7z t -p\"SuperSecret\" \"D:\\data\\folder\\pack.7z\""}' `
            -StageDir $script:StageDir
        $copy = Get-JsonField $out 'copy'
        $write = Get-JsonField $out 'write'
        $all = $copy + $write
        ($all -match '-p\*\*\*') | Should Be $true
        ($all -match 'SuperSecret') | Should Be $false
    }

    It 'copy_basename_only' {
        $out = Invoke-DiagnosticUICase -Command 'copy' -CaseKey 'copy_basename_only' `
            -Json '{"archivePath":"D:\\data\\folder\\pack.7z","status":"DATA_CORRUPT","output":"x"}' `
            -StageDir $script:StageDir
        $copy = Get-JsonField $out 'copy'
        ($copy -match 'pack\.7z') | Should Be $true
        ($copy -match 'D:\\data\\folder\\') | Should Be $false
    }

    It 'copy_omits_full_path' {
        $out = Invoke-DiagnosticUICase -Command 'copy' -CaseKey 'copy_omits_full_path' `
            -Json '{"archivePath":"D:\\data\\folder\\pack.7z","status":"DATA_CORRUPT","output":"x"}' `
            -StageDir $script:StageDir
        $copy = Get-JsonField $out 'copy'
        ($copy -match 'D:\\data\\folder\\pack\.7z') | Should Be $false
        ($copy -match 'pack\.7z') | Should Be $true
    }

    It 'log_allows_full_path' {
        $out = Invoke-DiagnosticUICase -Command 'copy' -CaseKey 'log_allows_full_path' `
            -Json '{"archivePath":"D:\\data\\folder\\pack.7z","status":"DATA_CORRUPT","output":"7z t -p\"SuperSecret\" file"}' `
            -StageDir $script:StageDir
        $log = Get-JsonField $out 'log'
        ($log -match 'D:\\data\\folder\\pack\.7z' -or $log -match 'D:/data/folder/pack\.7z') | Should Be $true
        ($log -match 'SuperSecret') | Should Be $false
    }

    It 'no_password_or_clipboard_leak' {
        $out = Invoke-DiagnosticUICase -Command 'leak' -CaseKey 'no_password_or_clipboard_leak' `
            -Json '{"passwordUsed":"SecretPass"}' -StageDir $script:StageDir
        (Get-JsonField $out 'leakedPasswordUsed') | Should Be 'false'
        (Get-JsonField $out 'leakedClipboard') | Should Be 'false'
    }

    It 'partial_utf8_diagnostic' {
        $out = Invoke-DiagnosticUICase -Command 'partial' -CaseKey 'partial_utf8_diagnostic' `
            -Json '{}' -StageDir $script:StageDir
        (Get-JsonField $out 'exists') | Should Be 'true'
        $content = Get-JsonField $out 'content'
        ($content -match 'DATA_CORRUPT') | Should Be $true
        ($content -match 'status=') | Should Be $true
    }
}
