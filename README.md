# Standup

A small macOS menu bar app that reminds you to get up, stretch, and take a quick break while you work at a computer all day.

> **Version 1.0.** Built for personal use on one Mac: it's built locally and ad-hoc signed, with no Apple Developer account needed. The build history is in [docs/PLAN.md](docs/PLAN.md).

## Features
- Lives in the menu bar (no Dock icon) and starts automatically when you log in
- A reminder every _N_ minutes, only on the days and hours you choose
- Two alert styles:
  - **Corner toast**: a small card at the top-right that hides itself after 10 seconds, with an optional sound
  - **Pop-up**: a floating window with a looping sound that you click **Done** to clear
- Mute for 30 min, 1 hour, 2 hours, until tomorrow, until a custom time, or until you unmute
- No reminders while your screen is locked or the Mac is asleep. The timer starts fresh when you come back.
- **Microsoft Teams aware:** during a call nothing pops up, so nothing appears in a screen share. You get one reminder after the call ends.

## Requirements
- macOS 15 or later (developed on macOS 27)
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
1. Standup registers itself to open at login, and macOS may show a "Background item added" or "Login item added" notice. That's expected. You can turn it off in **Settings → General → Launch at login**.
2. Open **Settings…** from the menu and set your interval, days, work hours, and alert style.

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
Every 5 seconds, Standup checks which apps are using the microphone or speaker, using a macOS audio API that needs no special permission. If Microsoft Teams' call process holds either one for about 10 seconds, you're treated as in a call. This still works while you're muted. The call counts as over about 60 seconds after Teams lets go. Nothing is recorded or listened to. You can turn this off in Settings.

## Troubleshooting
- **No reminders appear:** check the menu's status line. It says why: muted, outside work hours, or in a Teams call. **Settings → Alerts → Show test alert** shows one immediately.
- **Doesn't start after a reboot:** check that **Settings → General → Launch at login** is on, and that Standup is allowed under System Settings → General → Login Items & Extensions.
- **"Launch at login" is greyed out:** you're running a Debug build (`make run`). Only the copy in `/Applications` can launch at login, so run `make install`.
- **A Teams call wasn't detected:** check the log's `meeting` lines (command below), or run `swift scripts/mic-probe.swift` during a call to see which processes hold the mic.
- **"Standup can't be opened" warning:** this only happens if the app was copied from somewhere else, such as downloaded. Run `xattr -dr com.apple.quarantine /Applications/Standup.app`.
- **Logs:** `/usr/bin/log stream --info --predicate 'subsystem == "dev.standup.Standup"'`. Use the full path, because in zsh `log` is a different, built-in command.
- **Teams detection diagnostics:** `swift scripts/mic-probe.swift` lists which apps are using the mic right now

## Development
```sh
make project   # generate Standup.xcodeproj from project.yml (git-ignored)
make build     # Debug build into ./build.noindex (".noindex" keeps Spotlight from listing build copies)
make test      # run unit tests
make coverage  # tests + StandupCore line coverage
make run       # build Debug and launch it
make clean
```
Open in Xcode with `make project && open Standup.xcodeproj`. Source files live in synced folders, so adding a file needs no project edits. The app icon is generated by `swift scripts/make-icon.swift`; re-run it after changing the icon's colors.

### Debug builds (for testing)
`make run` builds and launches the **Debug** build instead of the installed app. Only one copy runs at a time, so it quits the installed one first. Debug builds differ in two ways:
- **1-minute minimum interval.** Release builds allow 5–240 minutes. This lets you watch reminders, mute expiry, and after-call alerts without waiting.
- **Debug menu** in the menu bar menu: **Simulate call start / end**, to test Teams-call behavior without joining a call.

Debug and installed builds share the **same saved settings** (same app ID). A 1-minute interval set in Debug also applies to the installed app. To test safely:
```sh
defaults export dev.standup.Standup ~/standup-settings-backup.plist   # back up
make run                                                              # test with the Debug build
# ...test...
pkill -x Standup                                                      # quit the Debug build
defaults import dev.standup.Standup ~/standup-settings-backup.plist   # restore settings
make install                                                          # back to the installed app
```
Useful while testing: `/usr/bin/log stream --info --predicate 'subsystem == "dev.standup.Standup"'` shows every alert (`effect: …`), lock/unlock (`screen`), and Teams signal change (`meeting`).

- [docs/DESIGN.md](docs/DESIGN.md): architecture, exact reminder rules, Teams detection, decisions
- [docs/PLAN.md](docs/PLAN.md): milestone-by-milestone build plan with commit points

## License
Apache 2.0. See [LICENSE](LICENSE).
