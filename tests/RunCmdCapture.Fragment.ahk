#Requires AutoHotkey v2.0

class RunCmdCaptureHost {
    CMDPID := 0

    RunCmdCapture(CmdLine, Codepage := "UTF-8") {
        cancelled := false
        exitCode := -1
        sOutput := ""

        DllCall("CreatePipe", "PtrP", &hPipeR := 0, "PtrP", &hPipeW := 0, "Ptr", 0, "Int", 0)
        , DllCall("SetHandleInformation", "Ptr", hPipeW, "Int", 1, "Int", 1)
        , DllCall("SetNamedPipeHandleState", "Ptr", hPipeR, "UIntP", &PIPE_NOWAIT := 1, "Ptr", 0, "Ptr", 0)

        , P8 := (A_PtrSize = 8)
        , SI := Buffer(P8 ? 104 : 68, 0)
        , NumPut("UInt", P8 ? 104 : 68, SI)
        , NumPut("UInt", STARTF_USESTDHANDLES := 0x100, SI, P8 ? 60 : 44)
        , NumPut("Ptr", hPipeW, SI, P8 ? 88 : 60)	; hStdOutput
        , NumPut("Ptr", hPipeW, SI, P8 ? 96 : 64)	; hStdError
        , PI := Buffer(P8 ? 24 : 16, 0)

        if !DllCall("CreateProcess", "Ptr", 0, "Str", CmdLine, "Ptr", 0, "Int", 0, "Int", True
            , "Int", 0x08000000 | DllCall("GetPriorityClass", "Ptr", -1, "UInt"), "Int", 0
            , "Ptr", 0, "Ptr", SI.ptr, "Ptr", PI.ptr) {
            DllCall("CloseHandle", "Ptr", hPipeW)
            DllCall("CloseHandle", "Ptr", hPipeR)
            return { exitCode: -1, output: "", cancelled: false }
        }

        DllCall("CloseHandle", "Ptr", hPipeW)
        hProcess := NumGet(PI, 0, "Ptr")
        hThread := NumGet(PI, A_PtrSize, "Ptr")
        this.CMDPID := NumGet(PI, P8 ? 16 : 8, "UInt")

        enc := Codepage
        if (enc = "UTF-8" || enc = "utf-8")
            enc := "UTF-8"
        File := FileOpen(hPipeR, "h", enc)

        ; Read until the process exits; never ProcessClose on output content.
        loop {
            still := DllCall("PeekNamedPipe", "Ptr", hPipeR, "Ptr", 0, "Int", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0)
            while !File.AtEOF {
                chunk := File.Read(4096)
                if (chunk != "")
                    sOutput .= chunk
                else
                    break
            }
            if !DllCall("WaitForSingleObject", "Ptr", hProcess, "UInt", 15) {
                ; drain remaining bytes after exit
                while !File.AtEOF {
                    chunk := File.Read(4096)
                    if (chunk != "")
                        sOutput .= chunk
                    else
                        break
                }
                break
            }
            if !still && !DllCall("WaitForSingleObject", "Ptr", hProcess, "UInt", 0) {
                break
            }
        }

        if !DllCall("GetExitCodeProcess", "Ptr", hProcess, "UIntP", &ec := 0)
            exitCode := -1
        else
            exitCode := Integer(ec)

        DllCall("CloseHandle", "Ptr", hProcess)
        DllCall("CloseHandle", "Ptr", hThread)
        DllCall("CloseHandle", "Ptr", hPipeR)
        this.CMDPID := 0

        cancelled := (exitCode = 255)
        return { exitCode: exitCode, output: sOutput, cancelled: cancelled }
    }

    ;https://www.autohotkey.com/boards/viewtopic.php?t=93944
}
