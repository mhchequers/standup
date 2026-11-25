import Foundation
import Testing
@testable import StandupCore

/// A clock tests can move forward. Class so the controller and the test share it.
final class FakeClock: Clock, @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

/// The app's wiring: persistence of settings and mute across restarts, status line, icon (PLAN M4).
@Suite struct ReminderControllerTests {
    let suiteName = "dev.standup.tests.\(UUID().uuidString)"
    let statusText = StatusText(calendar: testCalendar, locale: Locale(identifier: "en_US"))

    func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    func makeController(_ defaults: UserDefaults, clock: FakeClock) -> ReminderController {
        ReminderController(store: SettingsStore(defaults: defaults), clock: clock,
                           calendar: testCalendar, statusText: statusText)
    }

    @Test func launchStartsCountdownAndStatus() {
        withDefaults { defaults in
            let c = makeController(defaults, clock: FakeClock(date(Nov.mon, 10, 0)))
            #expect(c.engine.dueAt == date(Nov.mon, 10, 30))
            #expect(c.statusLine == "Next break in 30 min")
            #expect(c.menuIcon == .normal)
        }
    }

    @Test func settingsSurviveRestart() {
        withDefaults { defaults in
            let clock = FakeClock(date(Nov.mon, 10, 0))
            var c = makeController(defaults, clock: clock)
            var s = c.settings
            s.intervalMinutes = 45
            s.alertStyle = .banner
            _ = c.apply(s)
            let relaunched = makeController(defaults, clock: clock)
            #expect(relaunched.settings == s)
            #expect(relaunched.engine.dueAt == date(Nov.mon, 10, 45))
        }
    }

    @Test func applyClampsBeforeSaving() {
        withDefaults { defaults in
            var c = makeController(defaults, clock: FakeClock(date(Nov.mon, 10, 0)))
            var s = c.settings
            s.intervalMinutes = 1000
            _ = c.apply(s)
            #expect(c.settings.intervalMinutes == 240)
            #expect(SettingsStore(defaults: defaults).loadSettings().intervalMinutes == 240)
        }
    }

    @Test func unchangedSettingsAreNoOp() {
        withDefaults { defaults in
            var c = makeController(defaults, clock: FakeClock(date(Nov.mon, 10, 0)))
            #expect(c.apply(c.settings).isEmpty)
            #expect(defaults.data(forKey: SettingsStore.settingsKey) == nil)  // nothing written
        }
    }

    @Test func muteSurvivesRestartAndShowsInMenu() {
        withDefaults { defaults in
            let clock = FakeClock(date(Nov.mon, 10, 0))
            var c = makeController(defaults, clock: clock)
            _ = c.mute(.minutes(60))
            #expect(c.isMuted && c.menuIcon == .muted)
            #expect(c.statusLine.replacingOccurrences(of: "\u{202F}", with: " ") == "Muted until 11:00 AM")
            let relaunched = makeController(defaults, clock: clock)
            #expect(relaunched.isMuted)
            #expect(relaunched.engine.muteUntil == date(Nov.mon, 11, 0))
        }
    }

    @Test func unmuteClearsSavedMute() {
        withDefaults { defaults in
            var c = makeController(defaults, clock: FakeClock(date(Nov.mon, 10, 0)))
            _ = c.mute(.indefinitely)
            _ = c.unmute()
            #expect(!c.isMuted && c.menuIcon == .normal)
            #expect(SettingsStore(defaults: defaults).loadMuteUntil() == nil)
        }
    }

    @Test func expiredMuteIsClearedFromStorage() {
        withDefaults { defaults in
            let clock = FakeClock(date(Nov.mon, 10, 0))
            var c = makeController(defaults, clock: clock)
            _ = c.mute(.minutes(30))
            clock.now = date(Nov.mon, 10, 30)
            _ = c.send(.tick)
            #expect(!c.isMuted)
            #expect(SettingsStore(defaults: defaults).loadMuteUntil() == nil)
            #expect(c.statusLine == "Next break in 30 min")
        }
    }

    @Test func customMuteInPastIsIgnored() {
        withDefaults { defaults in
            var c = makeController(defaults, clock: FakeClock(date(Nov.mon, 10, 0)))
            #expect(c.mute(.until(date(Nov.mon, 9, 0))).isEmpty)
            #expect(!c.isMuted)
        }
    }

    @Test func statusLineCountsDownWithClock() {
        withDefaults { defaults in
            let clock = FakeClock(date(Nov.mon, 10, 0))
            var c = makeController(defaults, clock: clock)
            clock.now = date(Nov.mon, 10, 7)
            _ = c.send(.tick)
            #expect(c.statusLine == "Next break in 23 min")
        }
    }

    @Test func callShowsCallIcon() {
        withDefaults { defaults in
            var c = makeController(defaults, clock: FakeClock(date(Nov.mon, 10, 0)))
            _ = c.send(.meetingChanged(true))
            #expect(c.menuIcon == .inCall)
            #expect(c.statusLine == "In a Teams call — will remind after")
        }
    }
}
