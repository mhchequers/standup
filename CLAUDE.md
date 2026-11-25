# CLAUDE.md

Standup is a native macOS menu bar break-reminder app (Swift 6 + SwiftUI, XcodeGen, no dependencies).

## Read first
- `docs/PLAN.md`: the milestone sequence. Work on the **next unchecked milestone** only. Tick its checkboxes, add notes on deviations, and stop at its **Commit point** so the user can commit.
- `docs/DESIGN.md`: the source of truth for behavior. §4 is the reminder engine spec. If the implementation needs to differ, update DESIGN.md in the same change.

## Commands
`make project | build | test | coverage | run | install | uninstall | clean`. Always run `make test` before declaring a milestone done. The user relies on Claude for test coverage: when behavior changes, update the requirement→test map in DESIGN §12.

## Conventions
- `StandupCore/` (framework target) must stay pure: Foundation only, no AppKit, SwiftUI, CoreAudio, or UserNotifications. Pass time explicitly (`handle(_:at:)`) or via `Clock`. Everything there gets Swift Testing tests, and tests link only this framework.
- OS integrations live in `Standup/Services/`, each behind a protocol.
- Never edit the generated `.xcodeproj`. Edit `project.yml` and run `make project`.
- Never spawn subprocesses for periodic polling (see DESIGN §5).
- Don't add features listed as out of scope in DESIGN §1 or in the PLAN backlog without asking.
