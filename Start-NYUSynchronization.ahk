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

A_IconTip := "NYU Synchronization"

if FileExist(iconFile)
    try TraySetIcon(iconFile, 1)

A_TrayMenu.Delete()
A_TrayMenu.Add("NYU Synchronization", NYUMenu)
A_TrayMenu.Add()
A_TrayMenu.Add("Restart Sync", RestartSync)
A_TrayMenu.Add("Pause Login Watchers", NYUPause)
A_TrayMenu.Add("Retry Logins", NYURetry)
A_TrayMenu.Add("Username and Password", NYUSettings)
A_TrayMenu.Add("Open Folder", OpenFolder)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", ExitSync)
A_TrayMenu.Default := "NYU Synchronization"
A_TrayMenu.ClickCount := 1

OnExit(HandleExit)
StartSync()
EpicMonitorStart()
NYUStart()

NoAction(*) {
}

StartSync(*) {
    global batchFile, syncPID

    if IniRead(EnvGet("USERPROFILE") "\NYU Synchronization\State\watcher.ini", "Settings", "FileSync", "1") != "1"
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
