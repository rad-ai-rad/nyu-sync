# NYU Synchronization

Starts at Windows user sign-in and combines the existing Epic-to-Visage file sync with login watchers for Citrix/Epic, PowerScribe 360, and Visage.

Updated September 19, 2026. The installed app and this guide live in `C:\Users\vg518\NYU Synchronization`.

## Daily use

1. Sign into Windows; NYU Synchronization starts automatically. Open clinical apps yourself or use the Start / Focus controls. Monitoring runs in the signed-in desktop session, not before Windows login.
2. Left-click the tray icon once to open the **NYU Synchronization** Tk menu, styled in dark purple with NYU-inspired accents. It shows application and file-sync status. Escape or the close button dismisses it.
3. Close the settings window when finished so login monitoring resumes. Already authenticated applications stay open.

After changing your NYU password, update the shared stored password here once for all three applications. The watcher uses it when an application next needs to log in.

## Username and password

Click the tray icon, then **Username and password**, or choose **Username and Password** from the right-click menu. The Windows account shown at the top owns the encrypted record; **NYU username** is the shared login for all three applications.

Enter a **New password** and click **Save** to update the stored credentials. This does not change the password on NYU's servers. Leave the password blank to retain it; a username change requires a password. Close the settings window to resume login monitoring. File sync continues while editing.

The record uses Windows DPAPI **CurrentUser** encryption in `%USERPROFILE%\NYU Synchronization\State\credentials.dpapi`, outside Dropbox. Its directory on this workstation is restricted to the current Windows user, SYSTEM, and Administrators. This dedicated location avoids packaged-app redirection of Local AppData so Windows startup and interactive launches use the same files.

DPAPI protects the stored record from other ordinary Windows accounts. It does not isolate credentials from software running as the same Windows user or from a compromised account. Decrypted credentials exist briefly in process memory for login. Updates are encrypted and validated before replacing the previous encrypted record. No plaintext credential files or command-line secrets are created.

The existing encrypted Epic record was migrated. The running app no longer reads `nyy`; use the editor for future updates. Existing AutoHotkey files were not modified. Other computers or Windows accounts require their own local credential setup. Do not synchronize the local credential directory.

## Controls

- **Epic Secure Chat** brings the single Epic production window forward and opens Secure Chat. It identifies the three cyan toolbar buttons from a fresh capture, clicks the middle speech bubble, and checks for the Secure Chat heading. It allows one additional click if an open menu absorbed the first. It does not create a conversation, select a patient, or send a message. An unrecognized layout leaves Epic in front with a manual-navigation notice.
- **Epic â†” Visage file sync** immediately saves the enabled setting; the supervisor stops or starts the file-transfer process on its next check (normally within three seconds). Disabled sync stays disabled across restarts.
- Enable or disable each application independently.
- **Start / Focus — Epic, PowerScribe, Visage** brings an existing window forward (restoring it if minimized), or launches the app when it is not running. Repeated launch clicks are limited while the app starts. Closed applications are never reopened by the watchers.
- **Pause Login Watchers** pauses logins while file sync continues.
- **Retry Logins** permits one new attempt per application. Saving credentials also resets attempt limits.
- **Restart file sync** (**Restart Sync** in the right-click menu) restarts the transfer process if file sync is enabled.
- **Exit synchronization** (**Exit** in the right-click menu) stops the supervisor and file sync, not the clinical applications.

Checkbox changes save immediately. Login watchers pause while the Tk menu or credential editor is open; file sync continues unless its own checkbox is off. Right-click retains the native tray menu. The Tk panel uses the local Python/Tk runtime; an alternate `pythonw.exe` can be configured under `[Paths] Python` in the local `watcher.ini`.

## Verified targets

| Application | Login identification | Positive authentication signal |
| --- | --- | --- |
| Citrix / Epic | Epic production process and Hyperspace login labels; fresh foreground capture and unchanged geometry | Hyperspace with Log Out in the top toolbar |
| PowerScribe 360 | Configured executable; exact username, password, and login UI Automation controls | Visible Explorer workspace and toolbar |
| Visage | Configured executable; exact login controls; server `visage.nyumc.org` | Visage CDC worklist title and worklist controls |

PowerScribe and Visage receive credentials through specific UI Automation controls. Epic retains OCR-based recognition because Citrix does not expose its remote controls reliably. Epic is maximized when needed. Login waits for an unlocked desktop and idle input.

Each app has a persisted one-attempt limit until positive authentication is observed. Failed or interrupted attempts need correction and **Retry Logins**. Credentials are not entered into unrecognized forms. MFA, password-change/expiration prompts, certificate prompts, and separate Citrix/browser identity-provider authentication require manual handling. Existing authenticated sessions are not logged out when credentials are updated.

The status **Running; authentication unverified** is intentionally distinct from Authenticated. Missing login fields alone do not prove success. The native worker has a supervisor timeout to bound stalled accessibility calls. Credential editing excludes native workers and pauses Epic input.

## File synchronization

The original `FileSynchronization.bat` behavior is preserved. The supervisor restarts its process if it stops and checks access to `Z:\Visage\Imaging\RisPACSXML\Out` and `C:\Visage\Imaging\RisPACSXML\Out`.

**Running; folders accessible** reports process and folder availability. It does not prove that a particular study or patient-context message transferred. No synthetic clinical messages are generated for testing. The existing mapped drive and network/VPN connection must be available.

## Implementation

- **NYU Synchronization.lnk** in Windows Startup launches the `Start-NYUSynchronization.ahk` entry point.
- `NYUSynchronization.ahk` supervises native login checks and file sync.
- `NYUTrayMenu.py` implements the dark Tk panel. It exchanges allowlisted commands and non-secret settings with the supervisor through Windows INI APIs; it does not read the credential record.
- `NYUSynchronization.cs` implements the password editor, PS360/Visage login checks, and encryption tests.
- `Build-NYUSynchronization.ps1` compiles the helper into the app folder and discovers installed app paths. Run it again after a PowerScribe ClickOnce update changes its installed path.
- `EpicMonitor.ahk`, `EpicCredentials.ahk`, and `EpicLoginProbe.ps1` retain Epic monitoring and use the shared credential record.
- `watcher.ini` stores non-secret preferences, paths, attempt limits, and short statuses alongside the encrypted record. Screenshots, recognized screen text, and patient transcripts are not saved by the watcher.

### Workstation locations

| Item | Location |
| --- | --- |
| App, source, icons, and documentation | `C:\Users\vg518\NYU Synchronization` |
| Encrypted credentials and watcher state | `C:\Users\vg518\NYU Synchronization\State` |
| Startup shortcut | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\NYU Synchronization.lnk` |
| Start Menu shortcut | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\NYU Synchronization.lnk` |
| AutoHotkey runtime | `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` |
| Python/Tk runtime | `%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\pythonw.exe` |
| Source-only backup destination | `C:\Users\vg518\Dropbox\Apps\Settings Backups` |

The startup and Start Menu shortcuts run `Start-NYUSynchronization.ahk` from the app folder and use `NYUSynchronization.ico`. Epic and Citrix launch shortcuts are stored in the app folder as `Launch-Epic.lnk` and `Launch-CitrixWorkspace.lnk`; neither runs at Windows sign-in.

Both shortcuts target the AutoHotkey runtime, pass the quoted full path to `Start-NYUSynchronization.ahk`, and use the app folder as their working directory. Open **NYU Synchronization** from the Start Menu to start it manually. Avoid starting the transfer batch or native helper separately: the launcher supervises them.

## Troubleshooting and maintenance

| Situation | Action |
| --- | --- |
| Login monitoring appears paused | Close the settings window and check **Pause Login Watchers** in the tray menu. |
| Login failed or was interrupted | Correct the stored credentials or finish the app's prompt, then choose **Retry Logins**. Repeated automatic attempts are deliberately limited. |
| Running; authentication unverified | Inspect the application. This status does not establish that login succeeded. |
| PowerScribe is loading its speaker profile | Allow profile loading to finish; authentication is confirmed when Explorer appears. |
| MFA, expired password, certificate, or unfamiliar prompt | Complete the prompt manually. Update the stored password if it changed. |
| Sync folders are unavailable | Restore the network/VPN and mapped drive, then inspect status again. **Restart Sync** is available if the transfer process needs restarting. |
| PowerScribe stopped being detected after an update | Rebuild the local helper to refresh the installed application path, using the steps below. |
| Credentials cannot be decrypted on another computer/account | Set up credentials locally under that Windows account. Do not copy the protected record as a portable login. |

To rebuild after an application update, choose **Exit** from the tray menu, run `Build-NYUSynchronization.ps1` from this folder in PowerShell, then launch **NYU Synchronization.lnk** from the Windows Startup folder. Exiting the supervisor leaves the clinical applications open. The build places the helper in the app folder and refreshes installed app paths.

Keep code and documentation backups separate from the machine-local protected directory. Never put plaintext passwords, the old `nyy` hotstring contents, or patient information into these documents or ordinary backups. Updating NYU Synchronization does not update or remove the original AutoHotkey credential hotstring.

## Validation â€” September 19, 2026

The shared credential record logged into PowerScribe and Visage. PowerScribe loaded its speech profile and reached Explorer; Visage reached its worklist. All three apps reported authenticated. File sync was running with both folders accessible.

The dark Tk panel was visually checked with all controls visible. Its file-sync checkbox stopped and resumed the batch process. The Secure Chat shortcut was exercised against the live Epic production window and opened Secure Chat from Imaging Dashboard. Active and inactive toolbar colors are supported; an open Secure Chat heading counts as success even when a tooltip covers Log Out. No messages were sent.

Encryption round trip, password/username replacement, corrupt-blob rejection, compatibility with the previous Epic record, and launcher checks passed. The password editor was visually inspected. The Windows Startup shortcut was updated; a reboot was not performed.

See [Epic-Citrix-UI.md](Epic-Citrix-UI.md) for Epic navigation notes.

## Installation layout

All active application files live in `C:\Users\vg518\NYU Synchronization`. `State` holds the DPAPI-encrypted credentials and machine-specific settings. The tray, Tk panel, settings executable, and Windows shortcuts share the purple synchronization icon. Windows startup points to this folder. AutoHotkey and Python/Tk remain separately installed runtimes. Source-only recovery snapshots are stored in `Apps/Settings Backups`; never copy `State` into ordinary backups or Dropbox.

The renamed launcher and encrypted credential format passed validation after consolidation. The helper was rebuilt with the themed icon, and its encryption self-test passed. Startup shortcut targets and icon paths were checked; no reboot was performed.

The Tk menu's new title-bar icon was visually verified. The launcher and transfer process were observed running from the consolidated folder; Epic, PowerScribe, and Visage reported **Authenticated**, and file sync reported **Running; folders accessible**. The menu was closed afterward to resume login monitoring.

Superseded app files and local credential copies were removed after migration checks. Unrelated clinical software installers were left in place. Recovery snapshots retain historical source versions; they are not active installations.

### Icon maintenance

`NYUSynchronization.ico` contains multiple resolutions for the tray, window title bars, executable, and shortcuts. `NYUSynchronization.png` is the large preview. If changing the icon, replace both assets, exit the supervisor, rebuild the native helper, and relaunch through the Start Menu shortcut. Keep the shortcut icon paths pointed at the app folder.

## Manual application launch

Automatic app launch/relaunch has been removed from both watcher implementations and settings interfaces. The login checkboxes control authentication monitoring for running apps only. Closing Epic, PowerScribe, or Visage leaves it closed. Windows Startup retains NYU Synchronization, while its dedicated Epic and Citrix launch shortcuts have been moved into the app folder. The existing Secure Chat shortcut requires an open Epic session. File synchronization retains its independent checkbox and startup behavior.


## One-minute inactivity gate — September 19, 2026

Automatic application checks, Epic activation/maximization, and login actions now wait for **60 seconds without keyboard or mouse activity**. Resuming input stops pending watcher work; login steps recheck inactivity before continuing. File synchronization continues independently in the background. Manual Start / Focus and Epic Secure Chat respond immediately. This replaces the previous three-second threshold that could bring Epic forward during short pauses. These are session/login checks, not a guarantee against server-enforced timeouts.

Validation for this change: native helper rebuilt successfully; AutoHotkey launcher check passed with physical keyboard/mouse hooks installed; one updated supervisor confirmed running. Startup still targets the consolidated launcher. No Windows reboot or deliberately induced clinical-session timeout was performed.
