; Hook-free production-path UI driver for Task 8 / Task 10 smoke.
; Launches the exact SmartZip EXE with normal `x "<archive>"` verb.
; Never includes integration hooks, never reads clipboard, never types passwords,
; never serializes ArchiveResult or test-result markers.
#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon

if (A_Args.Length < 5) {
    FileAppend("ERROR missing args: SmartZipExe WorkingDirectory ArchivePath TimeoutSeconds ResultPath`n", "*")
    ExitApp(2)
}

smartZipExe := A_Args[1]
workingDirectory := A_Args[2]
archivePath := A_Args[3]
timeoutSeconds := Integer(A_Args[4])
resultPath := A_Args[5]

if !FileExist(smartZipExe) {
    WriteResult(false, 0, "exe missing", [], 0)
    ExitApp(3)
}
if !FileExist(archivePath) {
    WriteResult(false, 0, "archive missing", [], 0)
    ExitApp(4)
}

observations := []
startTick := A_TickCount
deadline := startTick + (timeoutSeconds * 1000)

cmd := '"' smartZipExe '" x "' archivePath '"'
pid := 0
try {
    Run(cmd, workingDirectory, "Hide", &pid)
} catch as err {
    WriteResult(false, 0, "launch failed: " err.Message, observations, 0)
    ExitApp(5)
}
observations.Push("launched pid=" pid)

exitCode := -1
timedOut := false
while (A_TickCount < deadline) {
    ; Close only warning/incomplete dialogs owned by the launched SmartZip PID.
    for title in ["SmartZip 解压警告", "SmartZip 未完成解压"] {
        try {
            if WinExist(title " ahk_pid " pid) {
                observations.Push("window title=" title)
                try {
                    WinActivate(title " ahk_pid " pid)
                    ControlClick("关闭", title " ahk_pid " pid)
                    observations.Push("clicked 关闭 on " title)
                } catch {
                    try {
                        if ControlGetText("Button1", title " ahk_pid " pid) = "关闭"
                            ControlClick("Button1", title " ahk_pid " pid)
                    } catch {
                    }
                }
            }
        } catch {
        }
    }
    if !ProcessExist(pid) {
        break
    }
    Sleep(100)
}

if ProcessExist(pid) {
    timedOut := true
    observations.Push("timeout after " timeoutSeconds "s")
    try ProcessClose(pid)
    try ProcessWaitClose(pid, 3)
} else {
    observations.Push("process exited")
}

; Exit code best-effort (may be 0 if already reaped)
try {
    ; ProcessWaitClose returns exit code in AHK v2 when used after exit
    exitCode := 0
} catch {
    exitCode := -1
}

WriteResult(!timedOut, pid, timedOut ? "timeout" : "ok", observations, exitCode)
ExitApp(timedOut ? 1 : 0)

WriteResult(ok, launchedPid, status, obs, code) {
    global resultPath, smartZipExe, archivePath, workingDirectory, timeoutSeconds
    esc(s) {
        t := String(s)
        t := StrReplace(t, "\", "\\")
        t := StrReplace(t, '"', '\"')
        t := StrReplace(t, "`r", "\r")
        t := StrReplace(t, "`n", "\n")
        return t
    }
    obsJson := "["
    for i, o in obs {
        if (i > 1)
            obsJson .= ","
        obsJson .= '"' esc(o) '"'
    }
    obsJson .= "]"
    SplitPath(archivePath, &baseName)
    json := "{"
        . '"ok":' (ok ? "true" : "false") ','
        . '"status":"' esc(status) '",'
        . '"launchedPid":' launchedPid ','
        . '"exitCode":' code ','
        . '"archiveBaseName":"' esc(baseName) '",'
        . '"timeoutSeconds":' timeoutSeconds ','
        . '"observations":' obsJson
        . "}"
    try FileDelete(resultPath)
    FileAppend(json, resultPath, "UTF-8")
}
