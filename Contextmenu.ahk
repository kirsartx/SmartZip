#SingleInstance Ignore
#NoTrayIcon
SetWorkingDir(A_ScriptDir)

if A_Args.Length >= 2
{
    ; Registry passes "%1" → paths come as A_Args[2..]
    args := A_Args[1]
    loop A_Args.Length - 1
        args .= ' "' A_Args[A_Index + 1] '"'
}
else if A_Args.Length = 1
{
    args := A_Args[1]
    ; Fallback for old registrations without "%1": get paths from clipboard
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    ClipWait(1)
    temp := A_Clipboard
    A_Clipboard := ClipSaved
    if temp
    {
        for i in StrSplit(temp, "`r`n")
            args .= ' "' i '"'
    } else
    {
        ToolTip("未复制到路径,请重试")
        Sleep(1500)
        ExitApp
    }
}
else
    ExitApp

if FileExist("SmartZip.ahk")
    RunWait("SmartZip.ahk " args)
else if FileExist("SmartZip.exe")
    RunWait("SmartZip.exe " args)
else
    MsgBox("主脚本不存在")
