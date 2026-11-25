import Foundation
import Testing
@testable import StandupCore

/// Cross-feature scenarios found by mapping each user requirement (DESIGN §1) to tests.
@Suite struct ReminderEngineScenarioTests {
    func makeEngine(muteUntil: Date? = nil, _ configure: (inout AppSettings) -> Void = { _ in }) -> ReminderEngine {
        var settings = AppSettings()
        configure(&settings)
        return ReminderEngine(settings: settings, muteUntil: muteUntil, calendar: testCalendar)
    }

    @discardableResult
    func tick(_ engine: inout ReminderEngine, from: Date, to: Date) -> [ReminderEngine.Effect] {
        var out: [ReminderEngine.Effect] = []
        var t = from
        while t <= to {
            out += engine.handle(.tick, at: t)
            t = t.addingTimeInterval(5)
        }
        return out
    }

    // Requirement: "mute survives app restarts" — a persisted mute is honored at launch.
    @Test func persistedMuteIsHonoredAtLaunch() {
        var e = makeEngine(muteUntil: date(Nov.mon, 12, 0))
        #expect(tick(&e, from: date(Nov.mon, 10, 0), to: date(Nov.mon, 11, 59)).isEmpty)
        _ = e.handle(.tick, at: date(Nov.mon, 12, 0))
        #expect(e.dueAt == date(Nov.mon, 12, 30))
    }

    @Test func persistedMuteThatExpiredWhileQuitIsCleared() {
        var e = makeEngine(muteUntil: date(Nov.mon, 8, 0))
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        #expect(e.muteUntil == nil)
        #expect(e.dueAt == date(Nov.mon, 10, 30))
    }

    // Requirement: configurable days — enabling today mid-day starts reminders.
    @Test func enablingTodayStartsCountdown() {
        var e = makeEngine { $0.activeDays = [.tuesday] }
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        #expect(e.dueAt == nil)
        var s = e.settings
        s.activeDays.insert(.monday)
        _ = e.handle(.settingsChanged(s), at: date(Nov.mon, 10, 5))
        #expect(e.dueAt == date(Nov.mon, 10, 35))
    }

    // Requirement: configurable interval — a change made while away applies on return.
    @Test func intervalChangedWhileAwayAppliesOnReturn() {
        var e = makeEngine()
        _ = e.handle(.screenAwayChanged(true), at: date(Nov.mon, 10, 0))
        var s = e.settings
        s.intervalMinutes = 60
        _ = e.handle(.settingsChanged(s), at: date(Nov.mon, 10, 5))
        _ = e.handle(.screenAwayChanged(false), at: date(Nov.mon, 10, 10))
        #expect(e.dueAt == date(Nov.mon, 11, 10))
    }

    @Test func intervalChangeWhilePopupShowingWaitsForDone() {
        var e = makeEngine()
        tick(&e, from: date(Nov.mon, 10, 0), to: date(Nov.mon, 10, 30))
        var s = e.settings
        s.intervalMinutes = 60
        _ = e.handle(.settingsChanged(s), at: date(Nov.mon, 10, 31))
        #expect(e.dueAt == nil)
        _ = e.handle(.popupDismissed, at: date(Nov.mon, 10, 32))
        #expect(e.dueAt == date(Nov.mon, 11, 32))
    }

    // Requirement: mute + Teams — muting during a call cancels the after-call reminder.
    @Test func mutingDuringCallCancelsAfterCallReminder() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        _ = e.handle(.meetingChanged(true), at: date(Nov.mon, 10, 5))
        tick(&e, from: date(Nov.mon, 10, 5), to: date(Nov.mon, 10, 40))
        _ = e.handle(.muted(until: date(Nov.mon, 12, 0)), at: date(Nov.mon, 10, 45))
        #expect(e.handle(.meetingChanged(false), at: date(Nov.mon, 10, 50)).isEmpty)
    }

    // Requirement: one reminder at a time — a call during a pop-up never produces a second one.
    @Test func callDuringPopupNeverDoublesUp() {
        var e = makeEngine()
        tick(&e, from: date(Nov.mon, 10, 0), to: date(Nov.mon, 10, 30))  // pop-up up
        _ = e.handle(.meetingChanged(true), at: date(Nov.mon, 10, 31))
        let during = tick(&e, from: date(Nov.mon, 10, 31), to: date(Nov.mon, 11, 30))
        #expect(during.isEmpty)
        #expect(e.handle(.meetingChanged(false), at: date(Nov.mon, 11, 31)).isEmpty)
        #expect(e.popupShowing)
    }

    // Requirement: the whole workday behaves — 9–17 every 30 min with banner = 15 reminders.
    @Test func fullWorkdayProducesExpectedReminders() {
        var e = makeEngine { $0.alertStyle = .banner }
        let effects = tick(&e, from: date(Nov.mon, 8, 0), to: date(Nov.mon, 18, 0))
        #expect(effects.count == 15)  // 9:30, 10:00, … 16:30 (17:00 is outside hours)
        #expect(effects.allSatisfy { $0 == .showBanner(silent: false) })
    }

    // Status priority: muted wins over outside-hours; locked wins over everything.
    @Test func statusPriority() {
        var e = makeEngine(muteUntil: Mute.indefinite)
        #expect(e.status(at: date(Nov.sat, 10, 0)) == .muted(until: Mute.indefinite))
        _ = e.handle(.screenAwayChanged(true), at: date(Nov.sat, 10, 0))
        #expect(e.status(at: date(Nov.sat, 10, 1)) == .screenAway)
    }
}
