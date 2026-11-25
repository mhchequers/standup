# Standup

A small macOS menu bar app that reminds you to get up, stretch, and take a quick break while you work at a computer all day.

> **Status: in development.** Features land milestone by milestone (see [docs/PLAN.md](docs/PLAN.md)). The install instructions below work from milestone M1 onward. Features listed here may not exist yet.

## Features
- Lives in the menu bar (no Dock icon) and starts automatically when you log in
- A reminder every _N_ minutes, only on the days and hours you choose
- Two alert styles:
  - **Banner**: a standard macOS notification, with an optional sound
  - **Pop-up**: a floating window with a looping sound that you click **Done** to clear
- Mute for 30 min, 1 hour, 2 hours, until tomorrow, until a custom time, or until you unmute
- No reminders while your screen is locked or the Mac is asleep. The timer starts fresh when you come back.
- **Microsoft Teams aware:** during a call you get one silent banner instead of a loud alert, then one normal reminder after the call ends

## Requirements
- macOS 14.2 or later (developed on macOS 27)
- Xcode (developed with Xcode 27.2) and its command line tools. If builds fail with "A required plugin failed to load", run `sudo xcodebuild -runFirstLaunch` once.
- [Homebrew](https://brew.sh) and XcodeGen: `brew install xcodegen`

## Install

Build it once and it installs into `/Applications` like any other app. You don't need to keep a terminal open or run it from the repo.

```sh
git clone <this repo> standup
cd standup
brew install xcodegen      # first time only
make install
```

`make install` builds a Release version, copies it to `/Applications/Standup.app`, and launches it. Look for the standing-figure icon in the top-right menu bar.

**First launch:**
1. macOS asks whether Standup may send notifications. Click **Allow**. This is needed for the Banner style and for the silent banner during calls.
2. Standup registers itself to open at login, and macOS shows a "Login item added" notice. That's expected. You can turn it off in **Settings → General**.
3. Open **Settings…** from the menu and set your interval, days, work hours, and alert style.

From then on you can open Standup from Spotlight, Launchpad, or Finder like any app, and it opens on its own after every restart.

### Update
```sh
cd standup
git pull
make install     # quits the old version, installs the new one, keeps your settings
```

### Uninstall
```sh
make uninstall           # removes the login item and /Applications/Standup.app
make uninstall PURGE=1   # ...and also deletes saved settings
```
Without the repo, you can do it manually: turn off **Launch at login** in Settings, quit Standup, and drag `/Applications/Standup.app` to the Trash.

## Using it
Click the menu bar icon to see:
- **Status**: e.g. "Next break in 23 min", "Muted until 3:30 PM", "In a Teams call — will remind after", "Outside work hours — resumes Mon 9:00 AM"
- **Mute ▸**: 30 min, 1 hour, 2 hours, until tomorrow, until… (pick a date and time), until I unmute
- **Unmute**
- **Settings…**: interval, active days, work hours, alert style and sound, Teams options, launch at login
- **Quit Standup**

### How timing works
The timer runs on the clock during your work hours. Locking the screen, sleeping the Mac, muting, or leaving work hours discards the countdown. You get a full fresh interval when you come back. With the Pop-up style, the next countdown starts when you click **Done**.

### How Teams detection works
Standup checks every few seconds which apps are using the microphone, using a macOS audio API that needs no special permission. If Microsoft Teams holds the mic for more than about 10 seconds, you're treated as in a call. The call counts as over about 60 seconds after Teams releases the mic. Nothing is recorded or listened to. You can turn this off in Settings.

## Troubleshooting
- **No banners appear:** check System Settings → Notifications → Standup. Also check whether a Focus mode is on. Banners are also hidden while you share your screen, which is intended.
- **Doesn't start after a reboot:** check System Settings → General → Login Items for Standup, and toggle **Launch at login** in Settings.
- **"Standup can't be opened" warning:** this only happens if the app was copied from somewhere else, such as downloaded. Run `xattr -dr com.apple.quarantine /Applications/Standup.app`.
- **Logs:** `log stream --predicate 'subsystem == "dev.standup.Standup"' --level debug`
- **Teams detection diagnostics:** `swift scripts/mic-probe.swift` lists which apps are using the mic right now

## Development
```sh
make project   # generate Standup.xcodeproj from project.yml (git-ignored)
make build     # Debug build into ./build.noindex (".noindex" keeps Spotlight from listing build copies)
make test      # run unit tests
make run       # build Debug and launch it
make clean
```
Open in Xcode with `make project && open Standup.xcodeproj`. Source files live in synced folders, so adding a file needs no project edits.

- [docs/DESIGN.md](docs/DESIGN.md): architecture, exact reminder rules, Teams detection, decisions
- [docs/PLAN.md](docs/PLAN.md): milestone-by-milestone build plan with commit points

## License
Apache 2.0. See [LICENSE](LICENSE).
