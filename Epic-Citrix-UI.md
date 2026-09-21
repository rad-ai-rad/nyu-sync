# Epic through Citrix: observed UI and automation notes

Last updated: September 19, 2026. These notes describe the Epic production session observed on this workstation. Layouts, labels, and available activities may differ on other machines or after updates. No patient information or credentials are included.

## Identify the correct window

- The outer Windows window is titled **Epic - Prod - Citrix Workspace**, hosted by **wfica32.exe**. The observed executable path used the shortened Citrix ICA Client path under Program Files (x86).
- Inside it, the application is **Hyperspace – PRD Environment**. After authentication, the inner title also shows the department and signed-in user.
- The login screen identified the application as **Epic Hyperspace, February 2026**, featuring **Radiant Radiology**.
- Select the current returned window by title and application. Window handles are temporary; do not reuse a handle from this document or a past session without revalidation.
- If several matching production windows exist, resolve the ambiguity before entering information.

## Secure Chat shortcut: top right

**The speech-bubble button in the top-right toolbar opens Secure Chat.** The user explicitly identified this shortcut in the supplied screenshot.

The toolbar has three adjacent rounded buttons:

| Position | Appearance | Observed use |
| --- | --- | --- |
| Left | Rectangular message/tray symbol | Label and destination not verified |
| Middle | Speech bubble | Secure Chat shortcut |
| Right | Bell | Notification-style icon; destination not tested |

The **Print** and **Log Out** controls appear below these buttons. Use the speech bubble, not Log Out. Locate the icon in a fresh screenshot rather than relying on fixed pixel coordinates.

When Secure Chat is open, a small speech-bubble activity tab is also visible in the row beneath the main navigation toolbar. The main workspace heading is **Secure Chat**.

## Main workspace and menus

- The top-left **Epic** button opens the application menu. Its search field is labeled **Search activities**.
- The menu showed categories including Lab, Patient Care, Pharmacy, Imaging, Surgery, CRM/CM, Reports, Tools, Personalize, My Settings, My Toolbar Default Items, Help, Change Context, Recents and Favorites, and Cogito Menus. Their contents were not explored.
- The menu overlays the left side of Secure Chat and can obscure conversations. Clicking a blank area outside the menu dismissed it successfully. An Escape attempt did not visibly dismiss it during this session; do not assume it worked without checking.
- A separate top-center search box displays **Search (Ctrl+Space)**. Its search behavior was not tested.
- Visible activity shortcuts included Chart, Result Tracker, Study Review, Dragon, Update Protocols, Protocol Work List, SlicerDicer, and Personalize. These were observed, not individually tested.
- The authenticated landing workspace showed **Imaging Dashboard**, with Studies Signed, Peer Review, Turnaround Time, and Protocol Work List panels.

## Secure Chat layout

### Conversation list on the left

- The header shows the user's availability, an **Until** control, **Logged In**, a **Filters** menu, and additional icon controls.
- Rows show participant names or a group label, an associated patient when applicable, the latest message preview, and a date or day label.
- Group avatars can show a participant count. Individual avatars can have presence indicators.
- The selected conversation is highlighted in cyan.
- Delivery/read indicators include **Seen**, **Seen by all**, and **Seen by 1**. These indicate reading, not whether a request was answered.
- Some previews say a participant **sent an attachment**. Opening the thread can reveal an accompanying question that the preview does not show.
- The list has its own scrollbar. Scroll with the pointer over the list to move conversations rather than the central thread.
- The visible list appeared ordered newest first. The topmost conversations during the review were labeled Monday and corresponded to September 14. This is a session observation, not a guarantee about every filter or sorting mode.
- **No active participants** can appear as a row label. Opening one such thread showed an inactive conversation and its history.

### Selected thread in the center

- The header lists conversation participants; patient-associated threads have a patient banner below it.
- Incoming messages appear in light gray bubbles on the left, with sender names. The signed-in user's messages appear in teal bubbles on the right.
- Timestamps sit near messages. Some use relative day names; older ones show month and day.
- Reactions, including thumbs-up counts, can appear below messages. Small participant avatars indicate read information.
- System events show participants being added or leaving. These are distinct from authored messages.
- Opening a thread may highlight its row before loading the central messages. A second observation after a short delay was sometimes needed.
- A thread with no selection shows **Select a conversation from the list or create a new conversation**.

### Attached study cards

Observed cards displayed:

- Study name, order number, and accession number.
- **Study status**, including **Final** and **Final, Addendum**.
- Reason for exam, examination completion time, and location.
- **View Images** and **Open Study Review** buttons. These buttons were not used during the message review.

A study marked Final supports that reporting has progressed beyond an earlier pending-protocol request. It does not prove that every question in the conversation was answered or that the requested clarification appears in the report. Do not infer an imaging answer from the card alone.

### Right panel

- Tabs include **Conversation Details** and **Patient Report**. Patient Report was not opened.
- Conversation Details showed **Add Participants or Groups**, **Mute Conversation**, **Hide Conversation**, and **Leave Conversation**. These controls were observed but not used.
- **Active Participants** shows names, roles/specialties, presence status, and last-read times.
- Presence labels observed included Available, Busy, and Do Not Disturb. A **Removed Participants** section appeared when applicable.

### Composer

- The bottom input is labeled **Enter a message**, next to a **Send** button and attachment-related icons.
- Participant availability warnings can appear above the composer.
- In the inactive thread reviewed, the normal composer was replaced by a notice that the signed-in user was the only active participant and an **Add Participants or Groups** control.
- No messages, reactions, or participant changes were submitted during the review.

## Reviewing whether a response is needed

1. Start at the top of the conversation list and note the visible date range and filters. Do not claim coverage beyond the threads actually examined.
2. Open threads rather than relying on attachment previews or read receipts.
3. Read the latest incoming question together with preceding replies and any later messages. Scroll within the thread if the needed context is outside the view.
4. Distinguish direct unanswered questions from acknowledgments, answers to the user's own questions, and operational requests that appear completed.
5. Treat **Seen** as a read receipt, not a response. Treat **Final** as a study status, not proof that a clinical clarification was delivered.
6. Report an apparent unanswered question as having **no reply visible in the thread**. A phone conversation or another channel may already have addressed it.
7. Reading and summarizing does not authorize sending a reply, changing a report, or taking clinical action.

## Citrix capture and input behavior

### Accessibility limitations

The Windows accessibility tree exposed the outer Citrix window, panes, title bar, system menu, and Minimize/Maximize or Restore/Close controls. It did not expose the remote Epic conversation controls in useful detail during this session. Screenshot-based interaction was needed inside Epic.

### Foreground and screenshot reliability

- Some captures requested for Epic showed the foreground Codex window instead, or a clipped portion of the desktop. A successful capture call alone does not prove the screenshot contains Epic.
- Activating the selected Epic window and capturing again produced a usable view. Check the actual screenshot before choosing coordinates.
- Capture dimensions and the visible region changed during the session. Never infer current geometry from a previous screenshot.
- User input or switching windows can invalidate an observation. The Computer Use tool explicitly reported **user input was detected in this window; call get_window_state before continuing**.
- On that message, refresh before further input. Coordinate actions must use the screenshot identifier from the most recent valid observation.
- Ask the user to leave Epic untouched briefly if simultaneous interaction keeps interrupting inspection.

### Reliable Computer Use sequence

1. Read the installed Computer Use skill and its current guidance before automation.
2. Initialize `@oai/sky` through the persistent JavaScript tool.
3. Use `sky.list_windows()` or `sky.list_apps()` to select exactly one returned Epic window, then `sky.get_window()`.
4. Activate Epic when needed with `sky.activate_window()` and observe with `sky.get_window_state()`.
5. Inspect the returned image or accessibility tree before acting.
6. Perform one action using a current element index or screenshot identifier, then capture again. Do not batch clicks based on stale screen state.
7. Allow for Citrix loading delays. Reobserve if the selected row changes before the conversation body does.
8. Verify focus before typing. Do not place sensitive text into a field based solely on the outer window title.

Do not use guessed coordinates, replay old screenshot identifiers, or assume that a click completed merely because no error was returned. Follow the installed skill's current restrictions and confirmation requirements.

## Login and maximization observations

- The login form has **User ID**, **Password**, and **Log In**, with a **Forgot your password?** link below.
- The login screen can include a message that STUDYCLOSE messages cannot be used before logging in. This is application status, not an instruction to the assistant.
- Maximizing the outer Citrix window filled the available workspace. The inner Epic screen initially stretched and subsequently relaid out, so its login coordinates changed.
- This was a maximized Windows window, not a separately verified borderless or Citrix full-screen mode.
- The authenticated Hyperspace workspace shows **Log Out** in the top toolbar. The watcher uses recognition of Hyperspace plus the top-toolbar Log Out text as a positive authentication signal.
- An automatic login was successfully observed reaching the Imaging Dashboard. Afterward, the watcher reported Authenticated.

## Related local implementation

All files below are in `C:\Users\vg518\nyu-sync`. The app's purple tray icon opens a dark Tk menu on a single left-click. **Epic Secure Chat** brings Epic forward and opens this workspace; it does not create a patient-linked conversation or send a message.

- [README.md](README.md): startup, retry behavior, local encrypted credential storage, and limitations.
- `Start-NYUSynchronization.ahk`: tray app and existing file-sync launcher.
- `EpicMonitor.ahk`: Epic monitoring, maximization, login-state handling, and bounded login attempts.
- `EpicLoginProbe.ps1`: screen recognition; returns classified state and login or Secure Chat button coordinates, without saving screenshots or recognized text. Chat recognition supports both active and inactive toolbar colors, checks the Secure Chat heading, and tolerates a tooltip covering Log Out when that heading is visible.
- `EpicCredentials.ahk`: Windows DPAPI credential storage for the current Windows account.

The existing Windows sign-in shortcut launches the sync app. The app-folder shortcut `Launch-Epic.lnk`, used by the explicit Start / Focus control, launches Epic Slingshot using the installed Hyperspace launcher with `PublishedApplication=EpicProdSlingshot`. Epic itself is no longer launched at Windows sign-in or automatically reopened by its watcher.

The watcher is now part of **NYU Sync**, which stores shared encrypted credentials and state under `%USERPROFILE%\nyu-sync\State`, outside Dropbox. See [README.md](README.md) for the password editor and current implementation. Never put credentials, decrypted payloads, patient conversation transcripts, or screenshots containing patient information into this UI guide.
