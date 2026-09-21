#Requires AutoHotkey v2.0

NYUInitialize() {
    global NYU
    ; Track real user input so automated login keystrokes do not reset inactivity.
    InstallKeybdHook()
    InstallMouseHook()
    dir := A_ScriptDir "\State"
    DirCreate(dir)
    NYU := {dir: dir, state: dir "\watcher.ini", exe: A_ScriptDir "\NYUSynchronization.exe",
        pid: 0, observing: false, settingsPID: 0, menuPID: 0, scanAt: 0, nextScan: 0, healthAt: 0, chatBusy: false,
        generation: IniRead(dir "\watcher.ini", "Settings", "RetryGeneration", "")}
    ; Preserve the existing effective preference once, then use one persisted toggle.
    if IniRead(NYU.state, "Settings", "WatcherToggleMigrated", "0") != "1" {
        enabled := false
        for app in ["epic", "ps360", "visage"]
            enabled := enabled || IniRead(NYU.state, "Settings", app, "1") = "1"
        paused := IniRead(NYU.state, "Settings", "Paused", "0") = "1" || !enabled
        IniWrite(paused ? "1" : "0", NYU.state, "Settings", "Paused")
        IniWrite(IniRead(NYU.state, "Settings", "FileSync", "1"), NYU.state, "Settings", "FileSync")
        IniWrite("1", NYU.state, "Settings", "WatcherToggleMigrated")
    }
    IniWrite("", NYU.state, "Menu", "Command")
    if !FileExist(NYU.exe) {
        ps := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
        RunWait('"' ps '" -NoProfile -ExecutionPolicy Bypass -File "' A_ScriptDir '\Build-NYUSynchronization.ps1"', , "Hide")
    }
}

NYUStart() {
    global NYU
    if IniRead(NYU.state, "Settings", "Paused", "0") = "1"
        A_TrayMenu.Uncheck("Login Watchers (All)")
    else
        A_TrayMenu.Check("Login Watchers (All)")
    SetTimer(NYUTick, 3000)
    SetTimer(NYUCommands, 200)
}

NYUMenu(*) {
    global NYU
    if WinExist("NYU Sync ahk_exe pythonw.exe") {
        WinActivate()
        return
    }
    if NYU.menuPID && ProcessExist(NYU.menuPID)
        return
    python := IniRead(NYU.state, "Paths", "Python", EnvGet("USERPROFILE") "\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\pythonw.exe")
    if !FileExist(python) {
        MsgBox("Python with Tk is unavailable. Set Paths / Python in watcher.ini.", "NYU Sync")
        return
    }
    Run('"' python '" "' A_ScriptDir '\NYUTrayMenu.py"', , , &pid)
    NYU.menuPID := pid
}

NYUCommands(*) {
    global NYU
    command := IniRead(NYU.state, "Menu", "Command", "")
    if command = ""
        return
    IniWrite("", NYU.state, "Menu", "Command")
    switch command {
        case "settings": NYUSettings()
        case "retry": NYURetry()
        case "restart": RestartSync()
        case "chat": NYUSecureChat()
        case "open-epic": NYUStartFocus("epic")
        case "open-ps360": NYUStartFocus("ps360")
        case "open-visage": NYUStartFocus("visage")
        case "exit": ExitApp()
        case "changed":
            NYU.healthAt := 0
            if NYU.pid && ProcessExist(NYU.pid)
                try ProcessClose(NYU.pid)
            NYU.pid := 0
            if IniRead(NYU.state, "Settings", "Paused", "0") = "1"
                A_TrayMenu.Uncheck("Login Watchers (All)")
            else
                A_TrayMenu.Check("Login Watchers (All)")
    }
}

NYUStartFocus(app) {
    global NYU
    static launched := Map()
    try {
        if app = "epic" {
            hwnd := EpicWindow()
            if !hwnd && WinExist("Epic - Prod ahk_exe wfica32.exe") {
                MsgBox("More than one Epic window is open. Select the session from the taskbar.", "NYU Sync")
                return
            }
            path := A_ScriptDir "\Launch-Epic.lnk"
            if !hwnd && ProcessExist("Hyperspace.exe") {
                MsgBox("Epic is already running or starting. Select its window from the taskbar.", "NYU Sync")
                return
            }
        } else {
            path := IniRead(NYU.state, "Paths", app, "")
            hwnd := path != "" ? WinExist("ahk_exe " path) : 0
            name := app = "ps360" ? "Nuance.PowerScribe360.exe" : "vsclient.exe"
            if !hwnd && ProcessExist(name) {
                MsgBox("The app is already running or starting, but no window is available yet.", "NYU Sync")
                return
            }
        }
        if hwnd {
            if WinGetMinMax(hwnd) = -1
                WinRestore(hwnd)
            WinActivate(hwnd)
            return
        }
        if launched.Has(app) && A_TickCount - launched[app] < 30000
            return
        if !FileExist(path) {
            MsgBox("The app launch path is unavailable. Rebuild NYU Sync to refresh installed paths.", "NYU Sync")
            return
        }
        Run('"' path '"')
        launched[app] := A_TickCount
    } catch {
        MsgBox("The app could not be opened. Check its installed path and try again.", "NYU Sync")
    }
}

NYUSecureChat() {
    global NYU
    if NYU.chatBusy
        return
    NYU.chatBusy := true
    try NYUOpenChat()
    finally NYU.chatBusy := false
}

NYUOpenChat() {
    global NYU
    hwnd := EpicWindow()
    if !hwnd {
        MsgBox("Open one Epic production window, then try again.", "NYU Sync")
        return
    }
    WinActivate("ahk_id " hwnd)
    if !WinWaitActive("ahk_id " hwnd, , 3)
        return
    Loop 3 {
    result := NYU.dir "\chat-probe.txt"
    try FileDelete(result)
    ps := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
    Run('"' ps '" -NoProfile -ExecutionPolicy Bypass -File "' A_ScriptDir '\EpicLoginProbe.ps1" -Chat -WindowHandle ' hwnd ' -OutputPath "' result '"', , "Hide", &pid)
    if ProcessWaitClose(pid, 15) {
        try ProcessClose(pid)
        return
    }
    answer := FileExist(result) ? FileRead(result) : "unknown"
    try FileDelete(result)
    if answer = "chat-open"
        return
    fields := StrSplit(answer, ",")
    if A_Index < 3 && fields.Length = 7 && fields[1] = "chat-target" && WinActive("ahk_id " hwnd) {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if x = fields[2] && y = fields[3] && w = fields[6] && h = fields[7] {
            CoordMode("Mouse", "Screen")
            Click(x + Integer(fields[4]), y + Integer(fields[5]))
            Sleep(1200)
            continue
        }
    }
    break
    }
    MsgBox("Epic is in front. The Secure Chat button could not be identified; use the speech bubble in the top-right toolbar.", "NYU Sync")
}

NYUIdleReady() {
    ; Ignore our own injected input during login; require one minute of physical inactivity.
    return A_TimeIdlePhysical >= 60000
}

NYUInputPaused() {
    global NYU
    return IniRead(NYU.state, "Settings", "Paused", "0") = "1"
        || NYU.chatBusy
        || (NYU.settingsPID && ProcessExist(NYU.settingsPID))
        || WinExist("NYU Sync ahk_exe NYUSynchronization.exe")
        || WinExist("NYU Sync ahk_exe pythonw.exe")
}

NYUSettings(*) {
    global NYU
    if NYU.settingsPID && ProcessExist(NYU.settingsPID) {
        try WinActivate("ahk_pid " NYU.settingsPID)
        return
    }
    ; Finish/stop the read-and-login worker before editing the shared credential store.
    if NYU.pid && ProcessExist(NYU.pid)
        try ProcessClose(NYU.pid)
    NYU.pid := 0
    Run('"' NYU.exe '" --settings', , , &pid)
    NYU.settingsPID := pid
}

NYUPause(*) {
    global NYU
    paused := IniRead(NYU.state, "Settings", "Paused", "0") != "1"
    IniWrite(paused ? "1" : "0", NYU.state, "Settings", "Paused")
    if paused {
        A_TrayMenu.Uncheck("Login Watchers (All)")
        if NYU.pid && ProcessExist(NYU.pid)
            try ProcessClose(NYU.pid)
        NYU.pid := 0
        EpicStatus("Paused")
    } else {
        A_TrayMenu.Check("Login Watchers (All)")
        EpicStatus("Watching")
    }
}

NYURetry(*) {
    global NYU
    EpicRetry()
    for app in ["ps360", "visage"]
        IniWrite("0", NYU.state, app, "Attempted")
    NYU.nextScan := 0
}

NYUTick(*) {
    global NYU, EW, syncPID
    try {
        ; Keep file sync alive independently of login watcher pause.
        if A_TickCount >= NYU.healthAt {
            NYU.healthAt := A_TickCount + 30000
            if IniRead(NYU.state, "Settings", "FileSync", "1") != "1" {
                StopSync()
                IniWrite("Disabled", NYU.state, "Sync", "Status")
            } else {
            if !syncPID || !ProcessExist(syncPID)
                StartSync()
            health := syncPID && ProcessExist(syncPID) ? "Running" : "Stopped"
            if !DirExist("Z:\Visage\Imaging\RisPACSXML\Out")
                health .= "; remote folder unavailable"
            else if !DirExist("C:\Visage\Imaging\RisPACSXML\Out")
                health .= "; local folder unavailable"
            else
                health .= "; folders accessible"
            IniWrite(health, NYU.state, "Sync", "Status")
            }
        }
        NYUProcessStatus()
        observe := NYUInputPaused() || !NYUIdleReady()
        if observe && !NYU.observing {
            if NYU.pid && ProcessExist(NYU.pid)
                try ProcessClose(NYU.pid)
            NYU.pid := 0
        }
        generation := IniRead(NYU.state, "Settings", "RetryGeneration", "")
        if generation != NYU.generation {
            NYU.generation := generation
            EW.nextProbe := 0
            EW.activated := false
            NYU.nextScan := 0
        }
        if NYU.pid && ProcessExist(NYU.pid) {
            if A_TickCount - NYU.scanAt > 25000 {
                ProcessClose(NYU.pid)
                NYU.pid := 0
                for app in ["ps360", "visage"]
                    IniWrite("App response timed out; will check again", NYU.state, app, "Status")
            }
            return
        }
        if A_TickCount < NYU.nextScan || !EpicDesktopReady()
            return
        NYU.scanAt := A_TickCount
        NYU.nextScan := A_TickCount + 15000
        NYU.observing := observe
        Run('"' NYU.exe '" ' (observe ? "--observe" : "--scan"), , "Hide", &pid)
        NYU.pid := pid
    } catch {
        ; Do not write exception details or UI content to logs.
    }
}

NYUStop() {
    global NYU
    if !IsSet(NYU)
        return
    SetTimer(NYUTick, 0)
    SetTimer(NYUCommands, 0)
    if NYU.menuPID && ProcessExist(NYU.menuPID)
        try ProcessClose(NYU.menuPID)
    if NYU.pid && ProcessExist(NYU.pid)
        try ProcessClose(NYU.pid)
}

; Presence polling never activates windows or waits for user inactivity.
NYUProcessStatus() {
    global NYU
    static previous := Map()
    for app, name in Map("ps360", "Nuance.PowerScribe360.exe", "visage", "vsclient.exe") {
        pid := ProcessExist(name)
        if !pid
            IniWrite("Not running", NYU.state, app, "Status")
        else if !previous.Has(app) || previous[app] != pid
            IniWrite("Running; authentication unverified", NYU.state, app, "Status")
        previous[app] := pid
    }
}
