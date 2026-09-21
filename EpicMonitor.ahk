#Requires AutoHotkey v2.0

#Include EpicCredentials.ahk
; Credentials are encrypted with Windows DPAPI in the local user profile.
; Machine-local retry state survives launcher restarts and is never synced.
EpicMonitorStart() {
    global EW
    localDir := A_ScriptDir "\State"
    DirCreate(localDir)
    EW := {paused: false, hwnd: 0, pid: 0, probeAt: 0, nextProbe: 0,
        launchAt: A_TickCount, launched: false, activated: false,
        result: localDir "\probe-" DllCall("GetCurrentProcessId") ".txt",
        state: localDir "\watcher.ini", status: "Starting"}
    try EpicEnsureCredentials()
    catch
        EpicStatus("Set credentials in NYU Sync")
    SetTimer(EpicWatchTick, 2000)
    EpicWatchTick()
}

EpicStatus(message) {
    global EW
    if EW.status != message
        IniWrite(message, EW.state, "Watcher", "Status")
    EW.status := message
    A_IconTip := "NYU Sync`nEpic: " message
}

EpicRetry(*) {
    global EW
    IniWrite(0, EW.state, "Login", "Attempted")
    EW.nextProbe := 0
    EW.activated := false
    EpicStatus("Login retry enabled")
}

EpicMonitorStop() {
    global EW
    if !IsSet(EW)
        return
    SetTimer(EpicWatchTick, 0)
    if EW.pid && ProcessExist(EW.pid)
        try ProcessClose(EW.pid)
    try FileDelete(EW.result)
}

EpicWindow() {
    matches := []
    for hwnd in WinGetList() {
        try {
            name := StrLower(WinGetProcessName(hwnd))
            title := WinGetTitle(hwnd)
            if (name = "wfica32.exe" && RegExMatch(title, "i)^Epic - Prod(?: - Citrix Workspace)?$"))
                || (name = "hyperspace.exe" && InStr(title, "Hyperspace") && InStr(title, "PRD"))
                matches.Push(hwnd)
        }
    }
    return matches.Length = 1 ? matches[1] : 0
}

EpicDesktopReady() {
    desktop := DllCall("OpenInputDesktop", "UInt", 0, "Int", false, "UInt", 0x0100, "Ptr")
    if !desktop
        return false
    ready := DllCall("SwitchDesktop", "Ptr", desktop)
    DllCall("CloseDesktop", "Ptr", desktop)
    return ready
}

EpicWatchTick(*) {
    global EW
    try {
        if EW.paused || NYUInputPaused() || !EpicDesktopReady() || !NYUIdleReady() {
            if EW.pid && ProcessExist(EW.pid)
                try ProcessClose(EW.pid)
            EW.pid := 0
            try FileDelete(EW.result)
            return
        }
        if IniRead(EW.state, "Settings", "epic", "1") != "1" {
            EpicStatus("Disabled")
            return
        }
        hwnd := EpicWindow()
        if !hwnd {
            EpicStatus("Not running; use Start / Focus")
            return
        }
        if EW.hwnd != hwnd {
            EW.hwnd := hwnd
            EW.activated := false
            EW.nextProbe := 0
        }
        if WinGetMinMax(hwnd) != 1 {
            if !NYUIdleReady()
                return
            WinMaximize(hwnd)
            EW.nextProbe := A_TickCount + 3000
            return
        }
        if !EW.activated && NYUIdleReady() {
            WinActivate(hwnd)
            EW.activated := true
            EW.nextProbe := A_TickCount + 3000
            return
        }
        if EW.pid {
            if ProcessExist(EW.pid) {
                if A_TickCount - EW.probeAt > 20000 {
                    ProcessClose(EW.pid)
                    EW.pid := 0
                    EpicStatus("Recognition unavailable; waiting")
                }
                return
            }
            EW.pid := 0
            if FileExist(EW.result) {
                result := Trim(FileRead(EW.result))
                FileDelete(EW.result)
                if EW.probeHwnd = hwnd
                    EpicHandleResult(hwnd, result)
            }
        }
        if A_TickCount < EW.nextProbe
            return
        EW.nextProbe := A_TickCount + 15000
        EW.probeAt := A_TickCount
        EW.probeHwnd := hwnd
        EW.probeForeground := !!WinActive(hwnd)
        ps := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
        Run('"' ps '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'
            A_ScriptDir '\EpicLoginProbe.ps1" -WindowHandle ' hwnd ' -OutputPath "' EW.result '"',
            A_ScriptDir, "Hide", &probePID)
        EW.pid := probePID
    } catch {
        EpicStatus("Waiting; watcher will check again")
    }
}

EpicHandleResult(hwnd, result) {
    global EW
    if result = "authenticated" {
        if IniRead(EW.state, "Login", "Attempted", 0)
            IniWrite(0, EW.state, "Login", "Attempted")
        EpicStatus("Authenticated")
        return
    }
    if result = "attention" {
        EpicStatus("Login needs attention; use Retry Epic Login when ready")
        return
    }
    fields := StrSplit(result, ",")
    if fields[1] != "login" || fields.Length != 9 {
        EpicStatus("Running; login not detected")
        return
    }
    if IniRead(EW.state, "Login", "Attempted", 0) {
        EpicStatus("Automatic login already attempted; use Retry Epic Login")
        return
    }
    if !NYUIdleReady()
        return
    if !WinActive(hwnd) {
        WinActivate(hwnd)
        EW.nextProbe := A_TickCount + 3000
        return ; Always capture again after activation, never type from an occluded image.
    }
    if !EW.probeForeground {
        EW.nextProbe := A_TickCount + 3000
        return
    }
    WinGetPos(&left, &top, &width, &height, hwnd)
    if left != Integer(fields[2]) || top != Integer(fields[3]) || EpicWindow() != hwnd
        || width != Integer(fields[8]) || height != Integer(fields[9])
        return
    try credentials := EpicReadCredentials()
    catch {
        EpicStatus("Set credentials in NYU Sync")
        return
    }
    if !NYUIdleReady() || NYUInputPaused() || !WinActive(hwnd)
        return
    ; Persist before sending: failures or a restarted watcher must not cause a lockout loop.
    IniWrite(1, EW.state, "Login", "Attempted")
    CoordMode("Mouse", "Window")
    Click(Integer(fields[4]), Integer(fields[5]))
    Sleep(200)
    if !WinActive(hwnd) || !EpicDesktopReady() || !NYUIdleReady() || NYUInputPaused()
        return
    SendEvent("^a")
    SendText(credentials.user)
    if !WinActive(hwnd) || !NYUIdleReady() || NYUInputPaused()
        return
    SendEvent("{Tab}")
    Sleep(200)
    if !WinActive(hwnd) || !NYUIdleReady() || NYUInputPaused()
        return
    SendEvent("^a")
    SendText(credentials.password)
    credentials.password := ""
    Sleep(200)
    if !WinActive(hwnd) || !NYUIdleReady() || NYUInputPaused()
        return
    Click(Integer(fields[6]), Integer(fields[7]))
    EpicStatus("Login submitted; checking")
    EW.nextProbe := A_TickCount + 10000
}

EpicCheckCredentials() {
    EpicEnsureCredentials()
    credentials := EpicReadCredentials()
    if !credentials.user || !credentials.password
        ExitApp(2)
}
