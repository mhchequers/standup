# Standup — Implementation Plan

This file is the end-to-end build sequence. Each milestone ends in a working, committable state and is marked **⏸ Commit point**. Behavior details live in [DESIGN.md](DESIGN.md), and this file links to them by section (e.g., "DESIGN §4").

**Workflow per milestone**
1. Build the tasks.
2. Run `make test`, plus `make run` or `make install` for any manual checks listed.
3. Tick the checkboxes in this file and note any deviations under that milestone's **Notes**.
4. Commit (suggested message given). The user commits, or asks Claude to.

Ordering rationale: validate the risky platform assumptions early (M1–M2). Build the pure logic with tests before the UI (M3). Reach a usable MVP fast (M5). Then layer on lock handling, Teams detection, and polish.

---

## M0 — Planning docs ✅
- [x] `docs/DESIGN.md`, `docs/PLAN.md`, README rewrite, `CLAUDE.md`

⏸ **Commit point:** `docs: add design, plan, and README`

---

## M1 — Project scaffold and install pipeline
Goal: an empty menu bar app that builds, tests, and installs to `/Applications` with one command.

- [x] `brew install xcodegen` (need ≥ 2.48). Record the version in Notes.
- [x] `project.yml`:
  - `Standup` app target and `StandupTests` unit-test target, both with `type: syncedFolder` sources
  - deployment target macOS 14.2, Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY = complete`
  - Info.plist properties: `LSUIElement = YES`, `CFBundleDisplayName = Standup`, `LSApplicationCategoryType = public.app-category.healthcare-fitness`, version `0.1.0`
  - signing: `CODE_SIGN_IDENTITY = "-"`, `CODE_SIGN_STYLE = Manual`, no team, `ENABLE_HARDENED_RUNTIME = NO`, no sandbox entitlements
  - bundle ID `dev.standup.Standup` (DESIGN §2)
- [x] Folder skeleton per DESIGN §3, with `StandupApp.swift` containing a `MenuBarExtra` (SF Symbol `figure.stand`) that has a single **Quit Standup** item
- [x] One placeholder Swift Testing test, so `make test` exercises the pipeline
- [x] `Makefile` targets:
  - `project`: `xcodegen generate`
  - `build`: Debug build into `./build` (`-derivedDataPath build`)
  - `test`: `xcodebuild test -scheme Standup -destination 'platform=macOS'`
  - `run`: Debug build, then `open` the built app (quits any running copy first)
  - `install`: Release build, quit the running app, `ditto` to `/Applications/Standup.app`, open it
  - `uninstall`: run `--unregister-login-item` (once M8 exists), quit, remove the app, optionally `defaults delete dev.standup.Standup` (`make uninstall PURGE=1`)
  - `clean`: remove `build/` and the generated `.xcodeproj`
- [x] `.gitignore`: `build/`, `*.xcodeproj/`, `xcuserdata/`, `.DS_Store`, `DerivedData/`

**Verify:** `make test` passes. `make install` puts Standup in `/Applications` with the icon in the menu bar and **no Dock icon**. Quit works. Opening from Finder or Spotlight works with no Gatekeeper warning.

**Notes:**
- XcodeGen 2.48.0. The default project format works with Xcode 27.2.
- Prerequisite found: Xcode's first-launch components were missing. Fixed with `sudo xcodebuild -runFirstLaunch` (added to README requirements).
- Deviation: pure logic is a separate **`StandupCore` framework target** (top-level `StandupCore/` folder) instead of `Standup/Core/`. Tests link only the framework, so `make test` never launches the menu bar app, and the no-AppKit rule is enforced by target boundaries. DESIGN §3 has been updated.
- Info.plist is generated from `INFOPLIST_KEY_*` build settings (`GENERATE_INFOPLIST_FILE`), so there's no plist file in a synced folder.
- The destination is pinned to `platform=macOS,arch=arm64`, which silences xcodebuild's multiple-destination warning. Builds are arm64-only, which is fine for this Mac.
- `make uninstall` doesn't call `--unregister-login-item` yet (M8).
- Found during user check: Spotlight showed 3 copies (installed plus the Debug and Release build products), and each could run at once. Fixed in two ways. The build dir is now **`build.noindex`**, which Spotlight skips. **`SingleInstance.enforce()`** at launch makes a second copy with the same bundle ID exit immediately (DESIGN §3).
- Verified: tests pass. Installed and running from `/Applications`, `LSUIElement = true`, ad-hoc signed, not quarantined. `make run`, `make uninstall`, and reinstall all work.

⏸ **Commit point:** `chore: scaffold Standup menu bar app with XcodeGen and Makefile`

---

## M2 — Platform spikes (validate risks before building on them)
Goal: confirm the platform assumptions in DESIGN §10 on **this company Mac**. Record results in `docs/FINDINGS.md`. **Needs the user for one real Teams call.**

- [x] `scripts/mic-probe.swift`: a standalone script (`swift scripts/mic-probe.swift`) that prints, every 2 s, each CoreAudio process object with `IsRunningInput == 1`: PID, bundle ID, and process name. Also print default-input-device `IsRunningSomewhere`.
- [x] Run the probe **during a real Teams call** with the user: unmuted, muted, camera on/off, screen sharing, and the 60 s after leaving. Record exactly which bundle IDs appear, and whether muting keeps the stream running.
- [x] Run it while **not** in a call with Teams open (expect nothing), and while using another mic app (expect a non-Teams ID).
- [x] Throwaway code in the app: request notification permission and post a test banner. Install with `make install` and confirm MDM allows it.
- [x] Throwaway code in the app: `SMAppService.mainApp.register()` from `/Applications`. Check its status, confirm it appears in System Settings → Login Items, and reboot once to confirm it launches.
- [x] Throwaway code in the app: a menu item that opens a `Window` scene via `openWindow` plus activation. Confirm it comes to the front over other apps.
- [x] Update DESIGN §5, §9, and §10 if anything differs. Remove the throwaway code, or keep it if it's already the right shape.

**Verify:** `docs/FINDINGS.md` answers each item. Any changed decisions are reflected in DESIGN.md.

**Notes** (details in [FINDINGS.md](FINDINGS.md)):
- Teams capture is done by **`com.microsoft.teams2.modulehost`** (INPUT + OUTPUT for the whole call, **including while muted**). `vcxpc` isn't involved. DESIGN §5 signal rules were updated, and ModuleHost OUTPUT now counts too.
- `kAudioDevicePropertyDeviceIsRunningSomewhere` is unreliable, so the device-level fallback and device-listener optimization were dropped.
- Notifications, `SMAppService` login item (survives restart), and window activation all work with ad-hoc signing on the company Mac. No fallbacks are needed.
- Windows must stay `.accessory` and just call `NSApp.activate()`. Switching to `.regular` leaves a Dock recents entry.
- The probe was extended with OUTPUT, idle Microsoft processes, and typed step markers.
- Spike code (`Standup/App/Spike.swift`) was removed. Side effects persist on this Mac and are harmless: notification permission granted, login item registered (M8 takes it over).
- Carried to M7: re-verify with a real multi-person call, including camera and screen-share toggles.

⏸ **Commit point:** `spike: validate Teams mic detection, notifications, login item on target Mac`

---

## M3 — Core logic (pure Swift, fully tested)
Goal: all scheduling and decision logic implemented and tested, with no UI yet.

- [x] `Clock` protocol, `SystemClock`, and a `FakeClock` (tests only)
- [x] `AppSettings`: Codable, defaults from DESIGN §8, `validated()` (clamp interval, require end > start, at least one day; fall back to defaults otherwise)
- [x] `Schedule`: `isInWorkHours(_ date:)`, `nextWindowStart(after:)` (for "resumes Mon 9:00 AM")
- [x] `Mute`: presets `.minutes(30)`, `.hours(1)`, `.hours(2)`, `.untilTomorrow` (next local midnight), `.until(Date)`, `.indefinitely` (`Date.distantFuture`) → `muteUntil`. Expiry check.
- [x] `ReminderEngine`: events → effects exactly per DESIGN §4 rules 1–11, plus a `status` value for the menu line
- [x] `MeetingDebouncer`: 10 s on, 60 s off (DESIGN §5)
- [x] `SettingsStore`: `UserDefaults` load/save of `AppSettings` and `muteUntil`, with an injectable `UserDefaults(suiteName:)` for tests
- [x] Tests: one or more per DESIGN §4 rule, schedule edge cases (exactly at start/end, weekend, DST day), each mute preset, debouncer thresholds, and settings validation and round-trip

**Verify:** `make test` is green, and the test names map to DESIGN §4 rule numbers.

**Notes:**
- 88 tests in 10 suites, all passing, with about 99.7% line coverage of StandupCore (`make coverage`, added). A mutation check (breaking "one banner per call") made the matching test fail as expected.
- The user delegated test-coverage review to Claude. Mapping each requirement to tests found 8 cross-feature gaps (persisted mute at launch, day/interval changes while away or with the pop-up up, mute during a call, call during the pop-up, full-day count, status priority). They're covered in `ReminderEngineScenarioTests`. The map lives in DESIGN §12.
- Deviation: no `FakeClock`. `ReminderEngine.handle(_:at:)` takes the time explicitly, which keeps the engine a pure value type and makes tests simpler. `Clock`/`SystemClock` stay for `AppModel`.
- Added to Core, beyond the original list: **`TeamsCallSignal`** (the M2 detection rule, tested against FINDINGS run-2 cases) and **`StatusText`** (menu strings, with tests). Both are pure, so they belong here rather than in M7 or M4.
- `stateChanged` effect dropped. The UI observes the engine directly.
- Rule 10 (pop-up sound cap) is presentation, so it lives in M5's pop-up controller. Core provides `PopupSoundTiming` (4 s repeat, 120 s cap).
- `AppSettings` decoding tolerates missing keys (older saved versions), and settings are stored under `settings.v1`.
- Sound "None" is allowed for both styles. DESIGN §8 was updated.

⏸ **Commit point:** `feat(core): reminder engine, schedule, mute, meeting debouncer with tests`

---

## M4 — Menu and Settings UI
Goal: everything configurable, with the menu reflecting state. No alerts yet.

- [x] `AppModel` (`@MainActor @Observable`): owns the engine, store, and services, and runs the 5 s tick via `Task` + `Task.sleep`
- [x] `MenuContent`: status line (DESIGN §4 "Menu status line"); **Mute ▸** with 30 min / 1 hour / 2 hours / Until tomorrow / Until… / Until I unmute; **Unmute** (only when muted); **Settings…**; **Quit Standup**
- [x] Menu bar icon reflects state: normal `figure.stand`, muted `bell.slash`, in a call `phone.fill`, outside hours or paused uses the normal icon dimmed. Final symbols are picked during build.
- [x] `SettingsView`, with sections for Schedule (interval stepper, weekday toggles, start/end time pickers), Alerts (style, sound picker plus Preview, which is wired in M5), Meetings (two toggles, wired in M7), and General (launch at login, wired in M8; app version)
- [x] Settings window: `Window` scene, `openWindow` + `NSApp.activate()`, staying `.accessory` (DESIGN §8, FINDINGS D4)
- [x] `CustomMuteView` (DESIGN §8)
- [x] Changes persist immediately and survive relaunch

**Verify:** `make run`. Change every setting, quit, relaunch, and confirm they persisted. Mute presets show the correct "Muted until …". The status line counts down as the menu is reopened.

**Notes:**
- Core type `Settings` was renamed to **`AppSettings`**, because it clashed with SwiftUI's `Settings` scene.
- Min macOS raised to **15.0** for `.restorationBehavior(.disabled)` and `.defaultLaunchBehavior(.suppressed)`, so windows never reopen by themselves.
- Deviation: the wiring (persistence sync, mute expiry, status line, icon) lives in a new Core **`ReminderController`** with 10 tests. `AppModel` is now just a timer plus an effect performer. 98 tests total.
- Pulled forward from M5: a minimal `SoundPlayer` (lists `/System/Library/Sounds`, plays once), because the Settings sound picker and **Preview** need it. Looping and the cap stay in M5.
- **Launch at login is not in Settings yet** (M8). General shows the version only.
- M4 placeholder: a due pop-up is logged and instantly treated as dismissed, so the countdown keeps cycling. Removed in M5.
- Icons: normal `figure.stand`, muted `bell.slash`, in call `phone.fill`. No dimming outside hours, because the status line says it.
- Interval: type a value, or use the stepper (steps of 5). Out-of-range values are clamped on save. The last active day can't be switched off. Invalid hours (end ≤ start) show a red note and aren't saved until fixed.

⏸ **Commit point:** `feat(ui): menu bar menu, settings window, mute options`

---

## M5 — Alerts (MVP: usable daily from here)
Goal: reminders actually fire.

- [ ] `SoundPlayer`: list `/System/Library/Sounds`, play, stop, and loop with the 2-minute cap (DESIGN §4 rule 10)
- [ ] `BannerNotifier`: authorization request; single replaceable notification; silent posting with sound via `SoundPlayer`; denied-state hint in the menu
- [ ] `PopupAlertController` + `PopupView`: non-activating floating `NSPanel`, all Spaces, **Done** dismisses it, `sharingType = .none` best-effort (DESIGN §7)
- [ ] Wire engine effects to these, and wire Preview buttons in Settings
- [ ] Debug-only: allow a 1-minute interval for quick testing

**Verify:** with a 1-min interval in Debug, confirm that banner style shows a banner plus sound (and a silent one when sound is None). Pop-up style shows a window with a looping sound, Done clears it, and the next reminder comes one interval after Done. Mute stops alerts. Outside work hours gives no alerts. Then `make install` and use it for real.

⏸ **Commit point:** `feat(alerts): banner and pop-up alerts with sounds` (tag `v0.1.0` if desired)

---

## M6 — Screen lock and sleep awareness
- [ ] `ScreenStateMonitor` (DESIGN §6) with initial state at launch
- [ ] Feed `screenAway` into the engine (rules 1, 2, 8)
- [ ] Unit tests for the engine paths, already covered in M3. Add any gaps found.

**Verify:** start a countdown, lock (⌃⌘Q) for longer than the interval, and unlock. There should be no alert on unlock, and the status shows a full fresh interval. With the pop-up showing, locking dismisses it. Sleep and wake behave the same way.

⏸ **Commit point:** `feat: pause reminders while screen is locked or asleep`

---

## M7 — Teams call detection
- [ ] `MicUsageProbe`: CoreAudio process-object reads with a long-lived in-process client, own PID excluded, and the prefix list from M2 findings (DESIGN §5)
- [ ] `MeetingMonitor`: 5 s poll → `MeetingDebouncer` → engine `meetingStarted` / `meetingEnded`. Respects the "Detect Teams calls" toggle.
- [ ] Engine rules 4 (meeting branch), 6, and 7 wired. Silent banner copy: "Time for a break — we'll remind you after your call."
- [ ] Menu status "In a Teams call — will remind after" and the call icon
- [ ] "Remind after call ends" toggle wired
- [ ] Optional: a Debug-only menu item "Simulate call start/end" for testing without Teams
- [ ] Debug logging of the raw Teams signal (per poll) to check for gaps over 60 s during a real multi-person call with camera and screen-share toggles (FINDINGS conclusion 8)

**Verify** (with the user, real Teams call, 1–2 min interval): exactly one silent banner during the call (and hidden when screen sharing), a normal alert about 60 s after leaving, and none if the toggle is off. A muted call still counts. Opening Teams without a call does nothing.

⏸ **Commit point:** `feat: detect Teams calls and defer reminders`

---

## M8 — Launch at login and install polish
- [ ] `LoginItemManager` (DESIGN §9): register on first launch from `/Applications`; Settings toggle with live status; `.requiresApproval` button; Debug builds disabled with an explanation
- [ ] `--unregister-login-item` launch argument; `make uninstall` uses it
- [ ] App icon (`Assets.xcassets/AppIcon`). A simple generated icon is fine (optional `scripts/make-icon.swift` rendering an SF Symbol).
- [ ] `make install` re-run is a clean upgrade (quits the old version, keeps settings)
- [ ] README: finalize install, update, uninstall, and troubleshooting against reality
- [ ] Refresh `CLAUDE.md`: switch from "next milestone" to a maintenance workflow, and add gotchas learned during the build (e.g., M2 findings)
- [ ] Bump the version to `1.0.0`

**Verify:** fresh `make install`, reboot, and Standup is in the menu bar. Toggle launch at login off, reboot, and it's not running. `make uninstall` leaves no login item behind (System Settings → Login Items).

⏸ **Commit point:** `feat: launch at login, app icon, install/uninstall polish` (tag `v1.0.0`)

---

## M9 — Dogfood week
- [ ] Use it for real for about a week. Log annoyances in this section.
- [ ] Fix bugs and tune defaults (interval, debounce timings, sound cap).

⏸ **Commit point(s):** per fix.

---

## Backlog (not committed to; ask before doing)
- A bundled or custom jingle sound file (user-chosen file)
- Detecting other call apps (Zoom, Meet in Chrome). The prefix list makes this easy.
- A custom in-app toast if notifications are blocked by MDM
- A Homebrew-style or DMG release if it's ever shared with coworkers (needs a Developer ID and notarization)
