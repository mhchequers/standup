# CLAUDE.md

Standup is a native macOS menu bar break-reminder app (Swift 6 + SwiftUI, XcodeGen, no dependencies).

## Read first
- `docs/PLAN.md`: the build history (M0–M8 done) and **M9 dogfood log**. New work: record the request or bug under M9 (or the Backlog), update DESIGN first if behavior changes, implement with tests, then stop. **Before committing, tell the user what to check and wait for their approval**, then commit to `main` and push.
- `docs/FINDINGS.md`: facts verified on the real Mac (Teams processes, signing and notification limits). Check it before changing detection or alerts.
- `docs/DESIGN.md`: the source of truth for behavior. §4 is the reminder engine spec. If the implementation needs to differ, update DESIGN.md in the same change.

## Commands
`make project | build | test | coverage | run | install | uninstall | clean`. Always run `make test` before declaring a milestone done. The user relies on Claude for test coverage: when behavior changes, update the requirement→test map in DESIGN §12.

## Conventions
- `StandupCore/` (framework target) must stay pure: Foundation only, no AppKit, SwiftUI, CoreAudio, or UserNotifications. Pass time explicitly (`handle(_:at:)`) or via `Clock`. Everything there gets Swift Testing tests, and tests link only this framework.
- OS integrations live in `Standup/Services/`, each behind a protocol.
- Never edit the generated `.xcodeproj`. Edit `project.yml` and run `make project`.
- Never spawn subprocesses for periodic polling (see DESIGN §5).
- Don't reintroduce macOS notifications (`UserNotifications`): ad-hoc signing breaks approval on every rebuild (DESIGN §7, PLAN M5).
- Builds are ad-hoc signed, and only `/Applications/Standup.app` registers as a login item (DESIGN §9).
- Manual testing: use the Debug build (`make run`: 1-min interval, Debug ▸ Simulate call). It shares settings with the installed app, so **back up the user's settings with `defaults export` first, and restore them and `make install` afterward** (README "Debug builds").
- Don't add features listed as out of scope in DESIGN §1 or in the PLAN backlog without asking.
