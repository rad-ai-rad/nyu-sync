#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
#Include EpicMonitor.ahk
#Include NYUSynchronization.ahk

NYUInitialize()

if A_Args.Length && A_Args[1] = "--check" {
    try EpicCheckCredentials()
    catch as err {
        FileAppend(err.Message " (line " err.Line ")`n", "*")
        ExitApp(1)
    }
    ExitApp()
}

batchFile := A_ScriptDir "\FileSynchronization.bat"
iconFile := A_ScriptDir "\NYUSynchronization.ico"
syncPID := 0

A_IconTip := "NYU Sync"

if FileExist(iconFile)
    try TraySetIcon(iconFile, 1)

A_TrayMenu.Delete()
A_TrayMenu.Add("NYU Sync", NYUMenu)
A_TrayMenu.Add()
A_TrayMenu.Add("Restart Sync", RestartSync)
A_TrayMenu.Add("Login Watchers (All)", NYUPause)
A_TrayMenu.Add("Retry Logins", NYURetry)
A_TrayMenu.Add("Username and Password", NYUSettings)
A_TrayMenu.Add("Open Folder", OpenFolder)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", ExitSync)
A_TrayMenu.Default := "NYU Sync"
A_TrayMenu.ClickCount := 2
OnMessage(0x404, NYUTrayClick)

OnExit(HandleExit)
StartSync()
EpicMonitorStart()
NYUStart()

; Delay the single click until Windows' double-click interval has elapsed.
; Consume left-click messages so the default tray action cannot run twice.
NYUTrayClick(wParam, lParam, *) {
    static ignoreRelease := false
    event := lParam & 0xFFFF
    switch event {
        case 0x201: ; WM_LBUTTONDOWN
            ignoreRelease := false
            return 0
        case 0x202: ; WM_LBUTTONUP
            if ignoreRelease
                ignoreRelease := false
            else
                SetTimer(NYUShowTrayMenu, -DllCall("GetDoubleClickTime", "UInt"))
            return 0
        case 0x203: ; WM_LBUTTONDBLCLK
            SetTimer(NYUShowTrayMenu, 0)
            ignoreRelease := true
            SetTimer(NYUMenu, -1)
            return 0
        case 0x204, 0x205: ; Let AutoHotkey handle the right-click menu.
            SetTimer(NYUShowTrayMenu, 0)
    }
}

NYUShowTrayMenu() {
    A_TrayMenu.Show()
}

NoAction(*) {
}

StartSync(*) {
    global batchFile, syncPID

    if IniRead(A_ScriptDir "\State\watcher.ini", "Settings", "FileSync", "1") != "1"
        return
    if syncPID && ProcessExist(syncPID)
        return
    if !FileExist(batchFile)
        return

    try Run('"' batchFile '"', A_ScriptDir, "Hide", &syncPID)
}

StopSync(*) {
    global syncPID

    if syncPID && ProcessExist(syncPID) {
        try RunWait(
            A_ComSpec " /D /C taskkill /PID " syncPID " /T /F >nul 2>&1",
            ,
            "Hide"
        )
    }

    syncPID := 0
}

RestartSync(*) {
    StopSync()
    StartSync()
}

OpenFolder(*) {
    try Run('explorer.exe "' A_ScriptDir '"')
}

ExitSync(*) {
    ExitApp()
}

HandleExit(*) {
    NYUStop()
    EpicMonitorStop()
    StopSync()
}
