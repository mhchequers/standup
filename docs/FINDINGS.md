# M2 Findings: platform checks on the target Mac

These are results from validating the risky assumptions (DESIGN §10) on the company MacBook (macOS 27.2.1, Xcode 27.2, Teams `com.microsoft.teams2` 26304.1206.5384.1209).

Status legend: ⏳ not run · ✅ as expected · ⚠️ works with caveats · ❌ assumption wrong

---

## Test A — Teams call mic detection ✅

**How to run (solo call, about 10 min):**
1. In Terminal, from the repo: `swift scripts/mic-probe.swift`. Leave it running. It prints whenever mic usage changes.
2. **Baseline:** with Teams open and no call, wait about 10 s.
3. In Teams: **Calendar → Meet now → Start meeting**. Join with the mic **on** and the camera **off**. Wait about 20 s.
4. **Mute** in Teams and wait about 20 s. **Unmute.**
5. Turn the **camera on** and wait about 20 s. Turn it off.
6. **Share your screen** and wait about 20 s. Stop sharing.
7. **Leave** the meeting and wait about 70 s.
8. Optional: **Teams → Settings → Devices → Make a test call** while the probe is still running.
9. Optional: open any other app that uses the mic (e.g., QuickTime → New Audio Recording, without recording) to see a non-Teams entry.
10. Ctrl-C the probe and paste the full output to Claude.

**Questions this answers:**
| # | Question | Result |
|---|---|---|
| A1 | Which bundle ID(s) show `INPUT` during the call? (expected: `com.microsoft.teams2*` and/or `com.microsoft.vcxpc`) | |
| A2 | Does the input stay running while **muted**? | |
| A3 | Any change with camera on or screen sharing? | |
| A4 | How long after leaving does the input stop? | |
| A5 | With Teams open and **no call**: nothing using input? | |
| A6 | Does a non-Teams mic app show its own bundle ID (not Teams)? | |

### Run 1 (2026-11-25 15:06, Meet now, solo)
The probe started after joining. Exact step timing wasn't recorded.
```
[15:06:12] INPUT pid=3483 com.microsoft.teams2.modulehost   (31 procs)
[15:07:41] same, 32 procs
[15:08:03] mic: 0                       ← presumably muted
[15:08:57] INPUT ...teams2.modulehost   ← presumably unmuted
[15:09:29] mic: 0                       ← muted again or left
[15:09:41] 28 procs (4 audio processes deregistered)  ← probably left meeting
```
**Observations:**
- A1: the mic is held by **`com.microsoft.teams2.modulehost`** ("Microsoft Teams ModuleHost"). `com.microsoft.vcxpc` didn't appear.
- A2 (tentative ❌, overturned by run 2): the input dropped for 54 s mid-call. Step timing wasn't recorded, so this was probably camera or screen-share toggling, not mute.
- The default-input `kAudioDevicePropertyDeviceIsRunningSomewhere` stayed **false** throughout, even while ModuleHost was capturing. The §5 device-level fallback is **not viable**.
- The CoreAudio process count dropped by 4 about 12 s after the last mic activity. Teams likely registers call-specific audio processes, and their presence or output activity may mark the call better than the mic does.
- With no call, `--once` shows no Microsoft processes registered at all.

The probe was extended to also show OUTPUT and idle-but-registered Microsoft processes, plus typed step markers. See run 2.

### Run 2 (2026-11-25 15:12, Meet now, solo, with typed markers)
```
15:12:07  Teams open, no call: helper OUTPUT briefly (UI sound), then all Teams procs idle
15:12:16  MARK idle
15:12:46  ModuleHost INPUT             ← pre-join screen opened (mic preview)
15:12:48  ModuleHost INPUT + OUTPUT
15:12:50  MARK prejoin
15:13:06  + helper OUTPUT (join sound)
15:13:13  MARK joined
15:13:16  ModuleHost INPUT + OUTPUT
15:13:41  MARK muted                   ← no change for 74 s
15:14:55  MARK unmuted                 ← no change
15:15:19  ModuleHost idle; helper OUTPUT (leave sound)
15:15:22  MARK left
15:15:31  all Teams procs idle
15:16:40  Chrome helper OUTPUT         ← browser audio, bundle com.google.Chrome.helper
```
**Answers:**
| # | Question | Result |
|---|---|---|
| A1 | Bundle ID during call | `com.microsoft.teams2.modulehost`, with both INPUT and OUTPUT for the whole call. `com.microsoft.vcxpc` never appeared. |
| A2 | Input while muted? | ✅ **Stays running** (74 s muted, no change) |
| A3 | Camera or screen share | Not isolated. Run 1's 54 s input gap was likely one of these. That's covered by the 60 s end grace and the OUTPUT signal (see conclusions). |
| A4 | Stop after leaving | Within about 3 s (the probe polls every 2 s) |
| A5 | Teams open, no call | Teams processes are **registered but idle**. Only short helper OUTPUT blips for UI sounds. Registration alone does **not** mean a call. |
| A6 | Non-Teams app | Chrome audio showed under `com.google.Chrome.helper`. No confusion with Teams. |

Also: the device-level `runningSomewhere` flipped to true during pre-join and back to false after joining, while ModuleHost was still capturing. **It's unreliable, so don't use it.**

---

## Test B — Notification banners ✅
1. Click the Standup menu bar icon, then **1. Test notification banner**.
2. macOS asks to allow notifications. Click **Allow**.
3. Expect a banner: "Standup test banner". Reopen the menu; the line under item 1 shows the result.

| # | Question | Result |
|---|---|---|
| B1 | Was the permission prompt shown, and did Allow work? | Yes |
| B2 | Did the banner appear? | Yes. Works with ad-hoc signing on the company Mac. |
| B3 | Result text in the menu | |
| B4 | System Settings → Notifications → Standup: anything greyed out or managed by the organization? | |

---

## Test C — Launch at login ✅
1. Menu → **2. Register login item**. Reopen the menu and note the status (expected: `enabled`).
2. System Settings → General → **Login Items & Extensions**: is Standup listed under "Open at Login"?
3. **Restart the Mac.** After logging in, is Standup in the menu bar without you opening it?
4. Optional, to clean up: menu → **Unregister login item** (it gets re-registered for real in M8).

| # | Question | Result |
|---|---|---|
| C1 | Status after register | Registered without error |
| C2 | Listed in Login Items? Any "managed by your organization" note? | Listed. Not managed by the organization. |
| C3 | Auto-started after restart? | ✅ Yes. Standup started about a minute after boot (pid 1096) with no user action. `SMAppService.mainApp` works with ad-hoc signing on this Mac, so the LaunchAgent fallback isn't needed. |

---

## Test D — Window comes to the front ✅
1. Click on another app (e.g., your browser) so it's in front.
2. Standup menu → **3. Open test window**.

| # | Question | Result |
|---|---|---|
| D1 | Did "Standup test window" appear **in front** of other apps, with keyboard focus? | Yes (variant 3, switching to `.regular`) |
| D2 | After closing it, did any Standup Dock icon disappear again? | The policy returned to `.accessory` (verified via `NSRunningApplication.activationPolicy == 1`), but the icon stayed in the Dock's **recent apps** section. That's clutter the user dislikes. |
| D3 | When Standup launched, did the test window open by itself (unwanted)? | No. The `Window` scene doesn't auto-open. |
| D4 | Variant 4 (`NSApp.activate()` without switching to `.regular`): window in front with focus? No Dock icon at all? | ✅ In front, clickable right away, **no Dock icon**. **Decision: use this for Settings and Custom mute windows.** |

---

## Conclusions / design changes
1. **Teams call signal:** a `com.microsoft.teams2.modulehost` process with `IsRunningInput` **or** `IsRunningOutput`. Any other `com.microsoft.teams*` process with `IsRunningInput` also counts, in case Teams moves capture between processes. **Helper OUTPUT is ignored** because it's UI sounds, like the join/leave chime. `com.microsoft.vcxpc` is dropped from the match list.
2. The pre-join screen counts as a call because the mic preview is live. That's acceptable, since you're about to join.
3. **Keep the debounce** at 10 s on and 60 s off. That would have absorbed run 1's 54 s input gap, and the OUTPUT signal makes it more robust still.
4. **Drop the device-level fallback** (`kAudioDevicePropertyDeviceIsRunningSomewhere`) and the "gate polling on a device listener" optimization. That property doesn't track Teams capture.
5. **Notifications** work with ad-hoc signing and aren't blocked by MDM, so no custom toast is needed.
6. **Launch at login** via `SMAppService.mainApp` works with ad-hoc signing, including after a restart. The LaunchAgent fallback isn't needed.
7. **Windows:** `openWindow` + `NSApp.activate()` while staying `.accessory` brings the window to the front with focus and no Dock icon. Don't switch to `.regular`, because that leaves a Dock recents entry.
8. **Re-verify in M7:** a real multi-person call with camera and screen-share toggles, with Debug logging of the raw signal, to confirm there are no gaps longer than 60 s.
