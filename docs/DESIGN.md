# Standup — Design

This document describes **what** Standup does and **how** it is built. The sequencing of the work lives in [PLAN.md](PLAN.md).

## 1. Product summary

Standup is a macOS menu bar app that reminds you to get up and move every _N_ minutes during your work hours. It skips reminders when the screen is locked, can be muted, and goes quiet when you're in a Microsoft Teams call.

### Feature list (v1)

| Area | Behavior |
|---|---|
| Menu bar | Icon in the top-right menu bar. No Dock icon (`LSUIElement`). The menu shows status, mute options, Settings…, and Quit. |
| Launch at login | Registers itself as a login item, so it starts after every restart. Can be turned off in Settings. |
| Schedule | Reminder interval in minutes. Active weekdays. Work hours (start–end, same day). |
| Alert styles | **Corner toast**: a small card at the top-right that hides itself after 10 s, with an optional sound. It's Standup's own window, not a macOS notification (see §7). **Pop-up**: floating window and a looping sound that you click to clear. |
| Mute | 30 min, 1 hour, 2 hours, until tomorrow, until a custom date and time, or until unmuted. Mute survives app restarts. |
| Screen lock | No alerts while locked or asleep. The countdown starts fresh on unlock or wake. |
| Teams calls | When a reminder comes due during a call, **nothing is shown**, because it could appear in a screen share. The menu bar shows the call state, and you get **one normal alert after the call ends** (optional). |

### Explicitly out of scope (per discussion)
Idle-based timer reset, snooze, stretch suggestions, streaks and stats, global hotkey, and break-for-a-break flows. Don't add these without asking.

## 2. Tech stack and decisions

| Decision | Choice | Why |
|---|---|---|
| Language/UI | Swift 6 (strict concurrency), SwiftUI plus a little AppKit | Native, small, energy-efficient. Every needed API is first-party. |
| Min macOS | 15.0 | CoreAudio process objects need 14.2+. 15.0 adds the SwiftUI window options `.restorationBehavior(.disabled)` and `.defaultLaunchBehavior(.suppressed)`, so Settings never reopens on its own at login (raised in M4). The dev machine runs macOS 27.2. |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (≥ 2.48) from `project.yml`, with `syncedFolder` sources | `.xcodeproj` files are hard to edit by hand and by agents. `project.yml` is small and reviewable. Synced folders mean adding a file needs no project edits. The `.xcodeproj` is generated and git-ignored. |
| Build driver | `Makefile` wrapping `xcodegen` and `xcodebuild` | Gives one command each for build, test, run, install, and uninstall. |
| Tests | Swift Testing (`import Testing`) in a unit-test target | All scheduling and decision logic is pure and runs on an injected clock. |
| Signing | Ad-hoc (`CODE_SIGN_IDENTITY = "-"`), no sandbox, no hardened runtime | Personal use on one Mac. No Apple Developer account needed. Locally built apps aren't quarantined, so Gatekeeper doesn't block them. |
| Dependencies | None (no SwiftPM packages) | Keeps the build simple. |
| Persistence | `UserDefaults`, a single Codable `AppSettings` value plus `muteUntil` | Small and local. Survives reinstalls because it's keyed by bundle ID. |
| Logging | `os.Logger`, subsystem = bundle ID | Viewable with `log stream`. See the README troubleshooting section. |

**Bundle ID:** `dev.standup.Standup`. Change it in `project.yml` **before the first install** if you want something else. Changing it later orphans saved settings and the login item.

## 3. Architecture

```
Standup/          App target (AppKit/SwiftUI/CoreAudio allowed)
  App/            StandupApp.swift (scenes), AppModel.swift (thin @MainActor @Observable wrapper: timer + effects around ReminderController),
                  SingleInstance.swift (a second running copy exits at launch, preventing double reminders)
StandupCore/      Framework target: pure logic, Foundation only, 100% unit tested
    AppSettings.swift        Codable settings + defaults + validation
    Schedule.swift          "is now inside work hours?", "when does the next window start?"
    Mute.swift              mute presets → muteUntil Date
    ReminderEngine.swift    the state machine (events in → effects out)
    MeetingDebouncer.swift  raw mic samples → debounced inMeeting on/off
    TeamsCallSignal.swift   the verified "is Teams in a call" rule over AudioProcessSample values (§5)
    StatusText.swift        menu status line strings
    ScreenAwayTracker.swift combines the away signals (§6)
    LoginItemPolicy.swift   when to auto-register; installed-location check (§9)
    MeetingDetector.swift   TeamsCallSignal + MeetingDebouncer: one poll of the detection pipeline (§5)
    ReminderController.swift engine + SettingsStore + clock + status/icon: all app wiring that doesn't need AppKit (tested)
    Clock.swift             protocol Clock { var now: Date }, SystemClock (the engine takes `at:` instead of a clock)
    SettingsStore.swift     UserDefaults load/save (Foundation only, so it lives here)
Standup/
  Services/       Thin adapters to the OS — each behind a protocol so AppModel can be tested with fakes
    ScreenStateMonitor.swift   lock / sleep / display-sleep / screensaver / session switches → ScreenAwayTracker
    MicUsageProbe.swift        CoreAudio process-object reads (who is using the mic)
    MeetingMonitor.swift       polls MicUsageProbe every 5 s (only while detection is on) → MeetingDetector
    ToastController.swift      corner toast + shared FloatingPanel (non-activating, all Spaces)
    PopupAlertController.swift floating NSPanel + looping sound
    SoundPlayer.swift          NSSound wrapper, system sound list
    LoginItemManager.swift     SMAppService.mainApp; first-launch auto-register; --unregister-login-item
  UI/
    MenuContent.swift       the MenuBarExtra menu
    SettingsView.swift      settings window
    CustomMuteView.swift    "Mute until…" picker window
    PopupView.swift         content of the pop-up alert
  Resources/      Assets.xcassets (AppIcon). Info.plist is generated from INFOPLIST_KEY_* build settings in project.yml.
StandupTests/     Swift Testing tests; links only StandupCore, so the app never launches during tests
scripts/          mic-probe.swift (diagnostic), make-icon.swift (generates AppIcon.appiconset)
```

**Data flow:** OS monitors → `AppModel` turns OS signals into `ReminderEngine.Event`s → `engine.handle(event, at: now)` returns `[Effect]` → `AppModel` performs the effects (show toast, show or dismiss pop-up, play or stop sound). A tick (every 5 s) drives time-based events. The menu observes the engine, which is a value type stored on the `@Observable` `AppModel`, so there's no explicit refresh effect.

The engine has no knowledge of AppKit, and every call passes the time explicitly, so every rule in §4 is unit tested with fixed dates.

## 4. Reminder engine: behavior spec

This is the source of truth for timing behavior. Tests in `StandupTests/ReminderEngineTests.swift` should map one-to-one to these rules.

### Inputs
- `settings`: interval, days, work hours, alert style, meeting options
- `now` from the injected clock
- `screenAway: Bool`: locked, asleep, displays asleep, or user session inactive
- `inMeeting: Bool`: already debounced (§5). Always false if meeting detection is off.
- `muteUntil: Date?`
- `popupShowing: Bool`

### Derived
- `inWorkHours(now)`: weekday ∈ activeDays **and** start ≤ time-of-day < end, using `Calendar.current`.
- `muted(now)`: `muteUntil != nil && now < muteUntil`. An expired mute clears itself.
- **eligible** = `inWorkHours && !muted && !screenAway`

### Countdown state: `dueAt: Date?`
1. **Becoming eligible** (any ineligible → eligible transition, including app launch, unlock, wake, unmute, or the work window opening): `dueAt = now + interval`.
   - Example: interval 30, hours 9:00–17:00, Mac unlocked at 8:50 → first reminder at 9:30.
2. **Becoming ineligible**: `dueAt = nil`. The countdown is discarded, not paused. "Hybrid clock time" means the clock runs on wall time but restarts after you were away.
3. **Interval changed in settings**: `dueAt = now + newInterval`.
4. **Tick** with `eligible && now ≥ dueAt`:
   - **In a meeting:** show nothing. Set `pendingAfterCall = true` and `dueAt = now + interval`. A long call still produces exactly one alert, after it ends (rule 6). (Changed in M5: originally a silent macOS banner. See §7.)
   - **Not in a meeting:** fire an alert in the configured style.
     - Corner toast: show the toast and play the sound once if one is set. `dueAt = now + interval`.
     - Pop-up: show the pop-up. `dueAt = nil` until it's dismissed.
5. **Pop-up dismissed** (click): `dueAt = now + interval`.
6. **Meeting ended** (debounced): if `pendingAfterCall && remindAfterCall && eligible`, fire a normal alert as in 4. Then clear `pendingAfterCall`.
7. **Meeting started while the pop-up is showing:** stop the sound and keep the window.
8. **Screen away while the pop-up is showing:** dismiss the pop-up with no follow-up. Rule 2 applies, and on return rule 1 starts a fresh countdown.
9. **Muted while the pop-up is showing:** dismiss it.
10. **Pop-up sound:** replay every ~1.2 s until dismissed (was 4 s; tuned with the user in M5), for at most **2 minutes**. After that the window stays up but goes silent. This avoids blaring at an empty desk when you walked away without locking.
11. **Work hours end while the pop-up is showing:** leave it. It still needs a click.

### Effects
`showToast(silent: Bool)`, `showPopup`, `dismissPopup`, `stopPopupSound`. `silent` is true when the sound is None. Rule 10's timing is handled by the app's pop-up controller, using `PopupSoundTiming` constants from Core. The toast's 10 s visibility comes from `ToastTiming`.

### Menu status line (derived)
- `Next break in 23 min` / `Next break in less than a minute`
- `Break time!` (pop-up waiting for Done)
- `In a Teams call — will remind after` (or just `In a Teams call` when "Remind after call ends" is off)
- `Muted until 3:30 PM` / `Muted until tomorrow 9:00 AM` / `Muted until tomorrow` (midnight) / `Muted`
- `Outside work hours — resumes Mon 9:00 AM`
- `Paused — screen locked` (rarely visible, but correct)

## 5. Teams call detection

### Approach
- **Signal:** CoreAudio *process objects*, available on macOS 14.2+. Read `kAudioHardwarePropertyProcessObjectList` on `kAudioObjectSystemObject`. For each process object read `kAudioProcessPropertyIsRunningInput`, `kAudioProcessPropertyBundleID`, and `kAudioProcessPropertyPID`.
- **No permission prompt:** this is a property read, not audio capture, so no microphone TCC permission is needed.
- **Teams call signal** (verified in M2, see FINDINGS.md): Teams is "active" when either holds:
  - a `com.microsoft.teams2.modulehost` process has `IsRunningInput` **or** `IsRunningOutput`, or
  - any `com.microsoft.teams*` process has `IsRunningInput`.

  Output from `com.microsoft.teams2.helper` is **ignored**, because it's UI sounds such as the join/leave chimes. Our own PID is excluded. The match rules live in one constant so they're easy to adjust.
- **Muted in Teams:** verified in M2 that the input stream keeps running while muted, and ModuleHost output runs for the whole call. The pre-join screen counts as a call because the mic preview is live.
- **Polling:** every 5 s, **in-process**, with one long-lived CoreAudio client. **Never spawn a subprocess per poll.** One project polled by spawning a helper every 3 s, and after about an hour macOS power management broke ([yogurt#143](https://github.com/FrigadeHQ/yogurt/issues/143)). Polling is chosen over property listeners because listeners on `IsRunningInput` have been reported not to fire on recent macOS. **Don't use `kAudioDevicePropertyDeviceIsRunningSomewhere`**: in M2 it read false while Teams was capturing.
- **Debounce** (`MeetingDebouncer`, pure, tested):
  - **start:** Teams input is active for ≥ 10 s continuously. This ignores device-test blips.
  - **Logging:** detection on/off, raw signal transitions (with the active Teams processes), and call started/ended are logged at **notice** level (category `meeting`), so they're kept on disk for days and calls can be reviewed later. Other categories use info level, which is memory-only.
  - **end:** Teams is inactive for ≥ 60 s continuously. This ignores quick hiccups and rejoins. M2 saw a 54 s mid-call input gap, likely from a camera or screen-share toggle.
- **No device-level fallback:** M2 showed the device property is unreliable. If process objects ever stop working, revisit the design rather than guessing.

### Why not the alternatives
- **Microsoft Graph presence API:** needs an Azure AD app registration and tenant admin consent on a company account.
- **Teams window titles:** need Accessibility or Screen Recording permission and break whenever Teams changes its UI.
- **Camera-in-use:** misses audio-only calls.

### Why nothing is shown during calls
Our own floating windows (toast and pop-up) **can't** be reliably hidden from screen share, because `NSWindow.sharingType = .none` is ignored by ScreenCaptureKit on macOS 15.4+. The original plan used a silent macOS banner, since macOS hides those during screen sharing. M5 dropped macOS notifications (see §7), so during a call Standup shows nothing and only updates the menu bar. We still set `sharingType = .none` on both windows as a best effort.

## 6. Screen lock and sleep detection

`screenAway` is true if any of these hold:
- `DistributedNotificationCenter`: `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked`
- `NSWorkspace`: `willSleepNotification` / `didWakeNotification`
- `NSWorkspace`: `screensDidSleepNotification` / `screensDidWakeNotification`
- `NSWorkspace`: `sessionDidResignActiveNotification` / `sessionDidBecomeActiveNotification` (fast user switching)
- `DistributedNotificationCenter`: `com.apple.screensaver.didstart` / `didstop` (added in M6: a running screensaver means you're away)

Each signal is tracked separately in Core's `ScreenAwayTracker` (tested), and you're away while any is active. So waking from sleep with the lock screen still up stays "away" until you unlock. On wake, the monitor also re-reads the real lock state in case a lock notification was missed.

The initial state at launch comes from `CGSessionCopyCurrentDictionary()` (key `CGSSessionScreenIsLocked`). After wake, the tick also re-evaluates against the wall clock, so a late timer never causes a burst of alerts.

## 7. Alerts

### Corner toast (style `banner` in saved settings)
- Standup's own borderless, non-activating `FloatingPanel` at the **top-right** of the screen the mouse is on, just under the menu bar. It's on all Spaces and over full-screen apps, and doesn't steal focus.
- Shows "Time to stand up / Stretch, walk around, grab some water." It fades out after **10 s** (`ToastTiming.visibleDuration`), and clicking it hides it sooner. A new toast replaces any visible one.
- Plays the chosen sound **once** via `SoundPlayer` (none if the sound is None).
- **Why not macOS notifications (`UNUserNotificationCenter`)?** M5 found that an ad-hoc-signed app's notification approval is tied to the exact build (designated requirement = `cdhash`). Every rebuild becomes "not allowed for this application" with no new prompt. Fixing that needs a stable signing identity (self-signed certificate or Apple ID team). The user chose our own window instead, so there's no permission and no signing setup. Trade-off: it isn't hidden during screen sharing, which is why nothing is shown during calls (§5).

### Pop-up
- A non-activating `NSPanel` at `.floating` level, centered near the top of the main screen. It appears on all Spaces (`canJoinAllSpaces`, `fullScreenAuxiliary`) and doesn't steal keyboard focus from your work.
- It contains a short message ("Time to stand up / Stretch, walk around, grab some water.") and a **Done** button. Clicking Done dismisses it, and so does pressing Return once you've clicked into it.
- Sound: the chosen sound loops per §4 rule 10.

### Sounds
The picker lists `/System/Library/Sounds/*.aiff` (Glass, Hero, Ping, Submarine, …) by name via `NSSound(named:)`, plus **None**. A **Preview** button sits next to the picker. A bundled or custom jingle file is a possible later addition (see PLAN backlog).

## 8. Settings

| Setting | Default | Notes |
|---|---|---|
| Interval (min) | 30 | 5–240. Debug builds allow 1 (see README "Debug builds"). |
| Active days | Mon–Fri | |
| Work hours | 9:00–17:00 | end must be > start (no overnight) |
| Alert style | Pop-up | Corner toast / Pop-up |
| Sound | Glass | any system sound, or None (both styles) |
| Detect Teams calls | On | |
| Remind after call ends | On | |
| Launch at login | On | Reflects `SMAppService.mainApp.status` live. Not stored in `UserDefaults`. |

**Settings window:** a SwiftUI `Window` scene with id `settings`, opened from the menu with `openWindow(id:)`. Open it with `openWindow(id:)` followed by `NSApp.activate()`, and **keep the `.accessory` activation policy**. M2 found that switching to `.regular` leaves the app in the Dock's recent-apps section, while plain `activate()` brings the window to the front with focus and no Dock icon (FINDINGS Test D). `SettingsLink` from a `MenuBarExtra` is known not to bring the window forward. If this still misbehaves, the fallback is the hidden-window `openSettings` technique ([steipete](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items/)).

**Custom mute window:** a small `Window` with a date-and-time `DatePicker` (default: now + 90 min, must be in the future) and **Mute** / **Cancel** buttons.

## 9. Launch at login

- `SMAppService.mainApp.register()` / `.unregister()`. Status is read from `.status`. On `.requiresApproval`, a button calls `SMAppService.openSystemSettingsLoginItems()`.
- **It only registers when running from `/Applications/Standup.app`.** Debug builds run from DerivedData, and registering those creates a duplicate login item per build path. That's a known issue with unsigned or ad-hoc builds. In Debug builds the toggle is disabled and says why.
- On first launch from `/Applications` it registers automatically, matching the default of On. This happens **once**: the flag `loginItem.autoRegisterAttempted` is set, so if you later turn it off, it stays off. An existing registration (e.g., from M2) is adopted. macOS may show a "login item added" notice, which is expected.
- `make uninstall` runs `--unregister-login-item`, clears that flag (so a reinstall registers again), and unregisters the app from LaunchServices. `make install` also unregisters the repo's build products from LaunchServices, so macOS only knows the installed copy. Verified in M8: after uninstall, `sfltool dumpbtm` shows the item `disabled`; after reinstall, `enabled`.
- The `--unregister-login-item` launch argument unregisters and exits. `make uninstall` uses it.
- **Fallback** if `SMAppService` misbehaves with ad-hoc signing on the company Mac: sign with a free Apple ID "Personal Team" in Xcode, or have `make install` write a `~/Library/LaunchAgents/dev.standup.Standup.plist` with `RunAtLoad`.

## 10. Risks (validated in Milestone 2)

| Risk | Check | Mitigation |
|---|---|---|
| Teams' mic use shows under an unexpected bundle ID | ✅ M2: `com.microsoft.teams2.modulehost` | Signal rules in §5 |
| Company MDM blocks notifications for unknown apps | ✅ M2: not blocked. M5: macOS notifications dropped anyway (ad-hoc signing breaks approval on every rebuild) | Own toast window (§7) |
| Login item blocked or managed by MDM | ✅ M2: works, survives restart | — |
| XcodeGen output incompatible with Xcode 27.2 | `make project && make build` | Try `options.projectFileFormat: xcproj` (XcodeGen 2.48, experimental), or commit a hand-made project |
| Settings window doesn't come to the front | ✅ M2: `openWindow` + `activate()` works | — |

## 11. References and prior art
- sigstop: "How sigstop knows you are on a call, with zero permissions" — https://dev.to/mohamedelshesheny/how-sigstop-knows-you-are-on-a-call-with-zero-permissions-1kfj
- CoreAudio process objects — https://macnotetaker.com/blog/which-app-is-using-mic-coreaudio-process-objects
- Polling pitfall — https://github.com/FrigadeHQ/yogurt/issues/143
- Settings from menu bar apps — https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items/
- `sharingType` ignored by ScreenCaptureKit — https://developer.apple.com/forums/thread/792152
- Ad-hoc login item duplicates — https://github.com/sindresorhus/LaunchAtLogin/issues/100
- XcodeGen ProjectSpec — https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md
- Similar apps to borrow UI ideas from: Nook, Twenty, StandLock, Give Me A Break

## 12. Requirement → test map

`StandupCore` line coverage is about 99.6% (`make coverage`, as of v1.0.0). This table maps each user-facing requirement to the tests that prove it. App-level behavior (real toast and pop-up windows, sounds, CoreAudio, lock notifications) is verified manually per PLAN milestone.

| Requirement | Tests |
|---|---|
| Remind every N minutes | `rule4_bannerRepeatsEveryInterval`, `fullWorkdayProducesExpectedReminders`, `rule1_*` |
| Interval configurable (and clamped) | `rule3_*`, `intervalChangedWhileAwayAppliesOnReturn`, `intervalChangeWhilePopupShowingWaitsForDone`, `AppSettingsTests.intervalIsClamped` |
| Active days and work hours | `ScheduleTests.*` (including DST), `rule2_noAlertsOutsideWorkHours`, `enablingTodayStartsCountdown`, `rule3_shrinkingHoursMakesIneligible` |
| Hybrid clock: away restarts the countdown | `rule2_lockDiscardsCountdownAndUnlockGivesFullInterval`, `rule2_startedLockedStaysQuiet`, `rule8_*`, `ScreenAwayTrackerTests.*` (lock, sleep, wake-while-locked, display sleep, screensaver, user switch) |
| Corner toast style (sound / silent) | `rule4_bannerWithSound`, `rule4_bannerWithoutSoundIsSilent` |
| Pop-up style, click to clear | `rule4_popupWaitsForDone`, `rule5_*`, `rule11_*` |
| Mute presets and custom | `MuteTests.*`, `rule2_noAlertsWhileMuted`, `rule1_unmute*`, `rule1_expiredMute*`, `rule9_*` |
| Mute survives restart | `SettingsStoreTests.muteUntilRoundTripAndClear`, `persistedMute*`, `ReminderControllerTests.muteSurvivesRestartAndShowsInMenu`, `unmuteClearsSavedMute`, `expiredMuteIsClearedFromStorage` |
| Settings persist | `SettingsStoreTests.*`, `AppSettingsTests.roundTrips*`, `missingKeysDecodeToDefaults`, `ReminderControllerTests.settingsSurviveRestart`, `applyClampsBeforeSaving` |
| Teams detection rule | `TeamsCallSignalTests.*` (cases from FINDINGS run 2) |
| Call start/end timing | `MeetingDebouncerTests.*` (including the 54 s gap from FINDINGS run 1), `MeetingDetectorTests.*` (full pipeline replayed against FINDINGS run 2) |
| Nothing on screen during a call | `rule4_inMeetingShowsNothingOnScreen`, `rule4_longCallStillGivesOnlyOneAlertAfter`, `rule6_eachCallDefersIndependently` |
| Reminder after call | `rule6_*`, `mutingDuringCallCancelsAfterCallReminder` |
| Detection / after-call toggles | `rule4_detectionOffIgnoresMeetings`, `rule6_noAlertWhenToggleOff`, `rule6_turningDetectionOffDropsDeferredReminder` |
| Launch at login (installed copy only, once) | `LoginItemPolicyTests.*` (manual: restart check in PLAN M8) |
| Never two reminders at once | `rule4_popupWaitsForDone`, `callDuringPopupNeverDoublesUp`, `rule7_*` |
| Menu status text and icon | `StatusTextTests.*`, `statusReflectsState`, `statusPriority`, `ReminderControllerTests.statusLineCountsDownWithClock`, `callShowsCallIcon` |
