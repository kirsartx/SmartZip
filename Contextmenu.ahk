#SingleInstance Ignore
#NoTrayIcon
SetWorkingDir(A_ScriptDir)

if A_Args.Length < 1
    ExitApp

cmd := A_Args[1]
argFiles := []

; Registry "%1" only passes the first selected file; collect what we have.
loop A_Args.Length - 1
    argFiles.Push(A_Args[A_Index + 1])

; Try clipboard to capture the FULL selection (multi-file) from Explorer.
; Send ^c copies all currently selected files, overwriting stale clipboard content.
ClipSaved := ClipboardAll()
A_Clipboard := ""
Send("^c")
clipOK := ClipWait(1)
clipText := A_Clipboard
A_Clipboard := ClipSaved

if clipOK && clipText {
    clipFiles := []
    for line in StrSplit(clipText, "`r`n") {
        line := Trim(line)
        if line != ""
            clipFiles.Push(line)
    }
    ; Prefer clipboard only when it has more files than registry args (multi-select).
    ; Single-file: keep the reliable %1 path to avoid stale clipboard races.
    if clipFiles.Length > argFiles.Length
        argFiles := clipFiles
}

if argFiles.Length {
    args := cmd
    for f in argFiles
        args .= ' "' f '"'
} else {
    ToolTip("未复制到路径,请重试")
    Sleep(1500)
    ExitApp
}

if FileExist("SmartZip.ahk")
    RunWait("SmartZip.ahk " args)
else if FileExist("SmartZip.exe")
    RunWait("SmartZip.exe " args)
else
    MsgBox("主脚本不存在")