#Requires AutoHotkey v2.0
#NoTrayIcon
; Dismisses windows belonging to ONE 7-Zip front-end process that the test itself launched.
; Args: 1 = pid, 2 = mode (dismiss|cancel), 3 = marker file, 4 = deadline in ms.
;
; WinExist reports only the top-most match, and 7-Zip keeps its progress dialog open
; underneath the box that follows, so the driver walks the top-level Z-order outward from the
; window it found and keeps the windows owned by that pid. Nothing outside the pid is looked
; at, so a 7-Zip window the user opened is never touched.
;
; Messages are posted rather than sent: a sent BM_CLICK blocks this thread on these dialogs,
; which is what made an earlier driver hang.
targetPid := Integer(A_Args[1])
mode := A_Args[2]
marker := A_Args[3]
deadline := A_TickCount + Integer(A_Args[4])
WM_CLOSE := 0x0010
BM_CLICK := 0x00F5
GW_HWNDNEXT := 2
GW_HWNDPREV := 3
; A cancel delivered at 0 percent proves nothing, so wait for bytes to be moving.
cancelAfterMs := 150
cancelStepMs := 300
IsSeen := false
FirstSeen := 0
LastCancelAt := 0
; Button ordinals to try, in the order the measurement suggests.
CancelOrder := [2, 3, 1]
CancelIndex := 1
Witness := ""
Handled := Map()

Post(hwnd, msg, wParam := 0, lParam := 0) {
    return DllCall("PostMessageW", "Ptr", hwnd, "UInt", msg, "Uptr", wParam, "Uptr", lParam, "Int")
}
Neighbour(hwnd, dir) => DllCall("user32\GetWindow", "Ptr", hwnd, "UInt", dir, "Ptr")

Owns(hwnd) {
    global targetPid
    pid := 0
    DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &pid, "UInt")
    return pid = targetPid
}

TitleOf(hwnd) {
    ttl := Buffer(512, 0)
    DllCall("GetWindowTextW", "Ptr", hwnd, "Ptr", ttl.Ptr, "Int", 512, "Int")
    return StrGet(ttl.Ptr)
}

ClassOf(hwnd) {
    cls := Buffer(128, 0)
    DllCall("GetClassNameW", "Ptr", hwnd, "Ptr", cls.Ptr, "Int", 128, "Int")
    return StrGet(cls.Ptr)
}

IsTargetWindow(hwnd) {
    ; GetParent reports the owner for a dialog, so it must not exclude anything: 7-Zip's own
    ; message box is owned by its progress dialog. The walk only follows top-level neighbours,
    ; so controls cannot leak in here.
    return Owns(hwnd) && DllCall("IsWindowVisible", "Ptr", hwnd, "Int")
}

; Walks outward in both Z-order directions so every window of the pid is seen, not just the
; one WinExist happens to return.
CollectSide(fromHwnd, dir, sink) {
    walk := Neighbour(fromHwnd, dir)
    steps := 0
    while (walk && steps < 2000) {
        steps++
        if IsTargetWindow(walk)
            sink.Push({hwnd: walk, title: TitleOf(walk), class: ClassOf(walk)})
        walk := Neighbour(walk, dir)
    }
}

ListWindows(fromHwnd) {
    list := []
    if IsTargetWindow(fromHwnd)
        list.Push({hwnd: fromHwnd, title: TitleOf(fromHwnd), class: ClassOf(fromHwnd)})
    CollectSide(fromHwnd, GW_HWNDPREV, list)
    CollectSide(fromHwnd, GW_HWNDNEXT, list)
    return list
}

; Asks a running dialog to stop by pressing its buttons in turn, recording which one was
; pressed. Measured on 7-Zip 26.02 ZS: Escape, WM_COMMAND/IDCANCEL, WM_CLOSE and the default
; control (id 2) leave a running extraction untouched, and the first button (id 444) only
; pauses it, so the second button is tried first and the rest follow. The marker says which
; control was pressed, so a change in the front-end shows up as evidence rather than a guess.
CancelRun(hwnd) {
    global CancelIndex, CancelOrder
    ord := CancelOrder[CancelIndex]
    CancelIndex := Mod(CancelIndex, CancelOrder.Length) + 1
    ch := 0
    try ch := ControlGetHwnd("Button" ord, "ahk_id " hwnd)
    if ch {
        Post(ch, BM_CLICK)
        return "button" ord "(id" DllCall("GetDlgCtrlID", "Ptr", ch, "Int") ") "
    }
    Post(hwnd, WM_CLOSE)
    return "wmclose "
}

; Presses the dialog's default control, or closes the window when it has none.
ClickOrClose(hwnd) {
    ack := DllCall("GetDlgItem", "Ptr", hwnd, "UInt", 2, "Ptr")
    if ack {
        Post(ack, BM_CLICK)
        return "click-id2"
    }
    Post(hwnd, WM_CLOSE)
    return "wmclose"
}

try {
    Loop {
        if (A_TickCount > deadline)
            break
        if !ProcessExist(targetPid)
            break
        top := WinExist("ahk_pid " targetPid)
        if !top {
            Sleep 20
            continue
        }
        if !IsSeen {
            IsSeen := true
            FirstSeen := A_TickCount
        }
        found := ListWindows(top)
        for w in found {
            if (mode = "cancel") {
                ; Asks the running dialog to cancel with its own default control, repeatedly.
                ; Measured on 7-Zip 26.02 ZS: Escape, WM_COMMAND/IDCANCEL and WM_CLOSE leave
                ; the run untouched, while two owner-drawn buttons with empty labels (control
                ; ids 444 and 446) only pause it, so this records the interrupt request and the
                ; suite asserts on what was left on disk rather than on a gesture claim.
                if (A_TickCount - FirstSeen < cancelAfterMs
                        || A_TickCount - LastCancelAt < cancelStepMs)
                    continue
                LastCancelAt := A_TickCount
                Witness := Witness . "cancel:" CancelRun(w.hwnd) " "
            } else {
                ; 7-Zip acknowledges the run from the dialog that showed the progress, so press
                ; that dialog's default control. Clicks repeat each pass because the box only
                ; appears at the end of the run, and a click on a disabled button is ignored.
                acted := ClickOrClose(w.hwnd)
                if (Witness = "")
                    Witness := acted " " w.class " [" w.title "] "
            }
        }
        if (Witness = "" && found.Length) {
            ; Nothing actionable yet: keep the first observation so a failure explains itself
            ; instead of leaving the extraction to time out with no evidence at all.
            w0 := found[1]
            Witness := "watch " w0.class " [" w0.title "] windows=" found.Length " "
        }
        Sleep 20
    }
} catch as failure {
    ; A driver that dies silently would leave the extraction hanging with no explanation, so
    ; the reason travels back through the marker file.
    Witness := "ERROR " failure.Message " line " failure.Line
}
FileAppend((IsSeen ? "1" : "0") "|" Witness "|", marker, "UTF-8")
ExitApp(IsSeen ? 0 : 1)
