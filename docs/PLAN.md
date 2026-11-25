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

- [ ] `brew install xcodegen` (need ≥ 2.48). Record the version in Notes.
- [ ] `project.yml`:
  - `Standup` app target and `StandupTests` unit-test target, both with `type: syncedFolder` sources
  - deployment target macOS 14.2, Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY = complete`
  - Info.plist properties: `LSUIElement = YES`, `CFBundleDisplayName = Standup`, `LSApplicationCategoryType = public.app-category.healthcare-fitness`, version `0.1.0`
  - signing: `CODE_SIGN_IDENTITY = "-"`, `CODE_SIGN_STYLE = Manual`, no team, `ENABLE_HARDENED_RUNTIME = NO`, no sandbox entitlements
  - bundle ID `dev.standup.Standup` (DESIGN §2)
- [ ] Folder skeleton per DESIGN §3, with `StandupApp.swift` containing a `MenuBarExtra` (SF Symbol `figure.stand`) that has a single **Quit Standup** item
- [ ] One placeholder Swift Testing test, so `make test` exercises the pipeline
- [ ] `Makefile` targets:
  - `project`: `xcodegen generate`
  - `build`: Debug build into `./build` (`-derivedDataPath build`)
  - `test`: `xcodebuild test -scheme Standup -destination 'platform=macOS'`
  - `run`: Debug build, then `open` the built app (quits any running copy first)
  - `install`: Release build, quit the running app, `ditto` to `/Applications/Standup.app`, open it
  - `uninstall`: run `--unregister-login-item` (once M8 exists), quit, remove the app, optionally `defaults delete dev.standup.Standup` (`make uninstall PURGE=1`)
  - `clean`: remove `build/` and the generated `.xcodeproj`
- [ ] `.gitignore`: `build/`, `*.xcodeproj/`, `xcuserdata/`, `.DS_Store`, `DerivedData/`

**Verify:** `make test` passes. `make install` puts Standup in `/Applications` with the icon in the menu bar and **no Dock icon**. Quit works. Opening from Finder or Spotlight works with no Gatekeeper warning.

⏸ **Commit point:** `chore: scaffold Standup menu bar app with XcodeGen and Makefile`

---

## M2 — Platform spikes (validate risks before building on them)
Goal: confirm the platform assumptions in DESIGN §10 on **this company Mac**. Record results in `docs/FINDINGS.md`. **Needs the user for one real Teams call.**

- [ ] `scripts/mic-probe.swift`: a standalone script (`swift scripts/mic-probe.swift`) that prints, every 2 s, each CoreAudio process object with `IsRunningInput == 1`: PID, bundle ID, and process name. Also print default-input-device `IsRunningSomewhere`.
- [ ] Run the probe **during a real Teams call** with the user: unmuted, muted, camera on/off, screen sharing, and the 60 s after leaving. Record exactly which bundle IDs appear, and whether muting keeps the stream running.
- [ ] Run it while **not** in a call with Teams open (expect nothing), and while using another mic app (expect a non-Teams ID).
- [ ] Throwaway code in the app: request notification permission and post a test banner. Install with `make install` and confirm MDM allows it.
- [ ] Throwaway code in the app: `SMAppService.mainApp.register()` from `/Applications`. Check its status, confirm it appears in System Settings → Login Items, and reboot once to confirm it launches.
- [ ] Throwaway code in the app: a menu item that opens a `Window` scene via `openWindow` plus activation. Confirm it comes to the front over other apps.
- [ ] Update DESIGN §5, §9, and §10 if anything differs. Remove the throwaway code, or keep it if it's already the right shape.

**Verify:** `docs/FINDINGS.md` answers each item. Any changed decisions are reflected in DESIGN.md.

⏸ **Commit point:** `spike: validate Teams mic detection, notifications, login item on target Mac`

---

## M3 — Core logic (pure Swift, fully tested)
Goal: all scheduling and decision logic implemented and tested, with no UI yet.

- [ ] `Clock` protocol, `SystemClock`, and a `FakeClock` (tests only)
- [ ] `Settings`: Codable, defaults from DESIGN §8, `validated()` (clamp interval, require end > start, at least one day; fall back to defaults otherwise)
- [ ] `Schedule`: `isInWorkHours(_ date:)`, `nextWindowStart(after:)` (for "resumes Mon 9:00 AM")
- [ ] `Mute`: presets `.minutes(30)`, `.hours(1)`, `.hours(2)`, `.untilTomorrow` (next local midnight), `.until(Date)`, `.indefinitely` (`Date.distantFuture`) → `muteUntil`. Expiry check.
- [ ] `ReminderEngine`: events → effects exactly per DESIGN §4 rules 1–11, plus a `status` value for the menu line
- [ ] `MeetingDebouncer`: 10 s on, 60 s off (DESIGN §5)
- [ ] `SettingsStore`: `UserDefaults` load/save of `Settings` and `muteUntil`, with an injectable `UserDefaults(suiteName:)` for tests
- [ ] Tests: one or more per DESIGN §4 rule, schedule edge cases (exactly at start/end, weekend, DST day), each mute preset, debouncer thresholds, and settings validation and round-trip

**Verify:** `make test` is green, and the test names map to DESIGN §4 rule numbers.

⏸ **Commit point:** `feat(core): reminder engine, schedule, mute, meeting debouncer with tests`

---

## M4 — Menu and Settings UI
Goal: everything configurable, with the menu reflecting state. No alerts yet.

- [ ] `AppModel` (`@MainActor @Observable`): owns the engine, store, and services, and runs the 5 s tick via `Task` + `Task.sleep`
- [ ] `MenuContent`: status line (DESIGN §4 "Menu status line"); **Mute ▸** with 30 min / 1 hour / 2 hours / Until tomorrow / Until… / Until I unmute; **Unmute** (only when muted); **Settings…**; **Quit Standup**
- [ ] Menu bar icon reflects state: normal `figure.stand`, muted `bell.slash`, in a call `phone.fill`, outside hours or paused uses the normal icon dimmed. Final symbols are picked during build.
- [ ] `SettingsView`, with sections for Schedule (interval stepper, weekday toggles, start/end time pickers), Alerts (style, sound picker plus Preview, which is wired in M5), Meetings (two toggles, wired in M7), and General (launch at login, wired in M8; app version)
- [ ] Settings window: `Window` scene, `openWindow` + activation-policy dance (DESIGN §8)
- [ ] `CustomMuteView` (DESIGN §8)
- [ ] Changes persist immediately and survive relaunch

**Verify:** `make run`. Change every setting, quit, relaunch, and confirm they persisted. Mute presets show the correct "Muted until …". The status line counts down as the menu is reopened.

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

**Verify** (with the user, real Teams call, 1–2 min interval): exactly one silent banner during the call (and hidden when screen sharing), a normal alert about 60 s after leaving, and none if the toggle is off. A muted call still counts. Opening Teams without a call does nothing.

⏸ **Commit point:** `feat: detect Teams calls and defer reminders`

---

## M8 — Launch at login and install polish
- [ ] `LoginItemManager` (DESIGN §9): register on first launch from `/Applications`; Settings toggle with live status; `.requiresApproval` button; Debug builds disabled with an explanation
- [ ] `--unregister-login-item` launch argument; `make uninstall` uses it
- [ ] App icon (`Assets.xcassets/AppIcon`). A simple generated icon is fine (optional `scripts/make-icon.swift` rendering an SF Symbol).
- [ ] `make install` re-run is a clean upgrade (quits the old version, keeps settings)
- [ ] README: finalize install, update, uninstall, and troubleshooting against reality
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
- Device-listener gating of mic polling (energy optimization)
- A custom in-app toast if notifications are blocked by MDM
- A Homebrew-style or DMG release if it's ever shared with coworkers (needs a Developer ID and notarization)
