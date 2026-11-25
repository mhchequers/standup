import Foundation
import Testing
@testable import StandupCore

/// One suite per DESIGN §4 rule. Default settings: every 30 min, Mon–Fri 9–17, pop-up, sound "Glass".
@Suite struct ReminderEngineTests {
    func makeEngine(screenAway: Bool = false, _ configure: (inout Settings) -> Void = { _ in }) -> ReminderEngine {
        var settings = Settings()
        configure(&settings)
        return ReminderEngine(settings: settings, screenAway: screenAway, calendar: testCalendar)
    }

    /// Ticks every 5 s from `from` through `to` (inclusive); returns all effects with their times.
    @discardableResult
    func tick(_ engine: inout ReminderEngine, from: Date, to: Date) -> [(Date, ReminderEngine.Effect)] {
        var out: [(Date, ReminderEngine.Effect)] = []
        var t = from
        while t <= to {
            for effect in engine.handle(.tick, at: t) { out.append((t, effect)) }
            t = t.addingTimeInterval(5)
        }
        return out
    }

    // MARK: Rule 1 — becoming eligible starts a fresh countdown

    @Test func rule1_launchInsideHoursStartsCountdown() {
        var e = makeEngine()
        #expect(e.handle(.tick, at: date(Nov.mon, 10, 0)).isEmpty)
        #expect(e.dueAt == date(Nov.mon, 10, 30))
    }

    @Test func rule1_firstReminderIsOneIntervalAfterWindowOpens() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 8, 50))
        #expect(e.dueAt == nil)
        let effects = tick(&e, from: date(Nov.mon, 8, 50), to: date(Nov.mon, 9, 30))
        #expect(effects.count == 1)
        #expect(effects.first?.0 == date(Nov.mon, 9, 30))
        #expect(effects.first?.1 == .showPopup)
    }

    @Test func rule1_unmuteStartsFreshCountdown() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        _ = e.handle(.muted(until: Mute.indefinite), at: date(Nov.mon, 10, 10))
        #expect(e.dueAt == nil)
        _ = e.handle(.unmuted, at: date(Nov.mon, 11, 0))
        #expect(e.dueAt == date(Nov.mon, 11, 30))
    }

    @Test func rule1_expiredMuteClearsItselfAndRestarts() {
        var e = makeEngine()
        _ = e.handle(.muted(until: date(Nov.mon, 10, 30)), at: date(Nov.mon, 10, 0))
        #expect(e.isMuted(at: date(Nov.mon, 10, 29)))
        _ = e.handle(.tick, at: date(Nov.mon, 10, 30))
        #expect(e.muteUntil == nil)
        #expect(e.dueAt == date(Nov.mon, 11, 0))
    }

    // MARK: Rule 2 — becoming ineligible discards the countdown

    @Test func rule2_lockDiscardsCountdownAndUnlockGivesFullInterval() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        _ = e.handle(.screenAwayChanged(true), at: date(Nov.mon, 10, 20))
        #expect(e.dueAt == nil)
        #expect(tick(&e, from: date(Nov.mon, 10, 20), to: date(Nov.mon, 11, 0)).isEmpty)
        #expect(e.handle(.screenAwayChanged(false), at: date(Nov.mon, 11, 0)).isEmpty)  // no alert on unlock
        #expect(e.dueAt == date(Nov.mon, 11, 30))
    }

    @Test func rule2_noAlertsOutsideWorkHours() {
        var e = makeEngine()
        #expect(tick(&e, from: date(Nov.mon, 17, 0), to: date(Nov.mon, 19, 0)).isEmpty)
        #expect(tick(&e, from: date(Nov.sat, 9, 0), to: date(Nov.sat, 12, 0)).isEmpty)
    }

    @Test func rule2_noAlertsWhileMuted() {
        var e = makeEngine()
        _ = e.handle(.muted(until: date(Nov.mon, 12, 0)), at: date(Nov.mon, 10, 0))
        #expect(tick(&e, from: date(Nov.mon, 10, 0), to: date(Nov.mon, 11, 59)).isEmpty)
    }

    @Test func rule2_startedLockedStaysQuiet() {
        var e = makeEngine(screenAway: true)
        #expect(tick(&e, from: date(Nov.mon, 9, 0), to: date(Nov.mon, 11, 0)).isEmpty)
    }

    // MARK: Rule 3 — interval change restarts the countdown

    @Test func rule3_newIntervalRestartsCountdown() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        var s = e.settings
        s.intervalMinutes = 45
        _ = e.handle(.settingsChanged(s), at: date(Nov.mon, 10, 10))
        #expect(e.dueAt == date(Nov.mon, 10, 55))
    }

    @Test func rule3_otherSettingChangesKeepCountdown() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        var s = e.settings
        s.soundName = "Hero"
        _ = e.handle(.settingsChanged(s), at: date(Nov.mon, 10, 10))
        #expect(e.dueAt == date(Nov.mon, 10, 30))
    }

    @Test func rule3_shrinkingHoursMakesIneligible() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 16, 0))
        var s = e.settings
        s.workEnd = TimeOfDay(hour: 15)
        _ = e.handle(.settingsChanged(s), at: date(Nov.mon, 16, 1))
        #expect(e.dueAt == nil)
    }

    // MARK: Rule 4 — firing

    @Test func rule4_bannerWithSound() {
        var e = makeEngine { $0.alertStyle = .banner }
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        #expect(e.handle(.tick, at: date(Nov.mon, 10, 30)) == [.showBanner(silent: false)])
        #expect(e.dueAt == date(Nov.mon, 11, 0))
    }

    @Test func rule4_bannerWithoutSoundIsSilent() {
        var e = makeEngine { $0.alertStyle = .banner; $0.soundName = nil }
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        #expect(e.handle(.tick, at: date(Nov.mon, 10, 30)) == [.showBanner(silent: true)])
    }

    @Test func rule4_bannerRepeatsEveryInterval() {
        var e = makeEngine { $0.alertStyle = .banner }
        let effects = tick(&e, from: date(Nov.mon, 10, 0), to: date(Nov.mon, 11, 30))
        #expect(effects.map(\.0) == [date(Nov.mon, 10, 30), date(Nov.mon, 11, 0), date(Nov.mon, 11, 30)])
    }

    @Test func rule4_popupWaitsForDone() {
        var e = makeEngine()
        let effects = tick(&e, from: date(Nov.mon, 10, 0), to: date(Nov.mon, 12, 0))
        #expect(effects.map(\.1) == [.showPopup])  // only once, no matter how long it sits
        #expect(e.popupShowing && e.dueAt == nil)
    }

    @Test func rule4_inMeetingShowsOneSilentBannerPerCall() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        _ = e.handle(.meetingChanged(true), at: date(Nov.mon, 10, 5))
        let effects = tick(&e, from: date(Nov.mon, 10, 5), to: date(Nov.mon, 11, 45))
        #expect(effects.map(\.1) == [.showBanner(silent: true)])
        #expect(effects.first?.0 == date(Nov.mon, 10, 30))
    }

    @Test func rule4_detectionOffIgnoresMeetings() {
        var e = makeEngine { $0.detectTeamsCalls = false }
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        _ = e.handle(.meetingChanged(true), at: date(Nov.mon, 10, 5))
        #expect(e.handle(.tick, at: date(Nov.mon, 10, 30)) == [.showPopup])
    }

    // MARK: Rule 5 — Done restarts the countdown

    @Test func rule5_doneStartsNextInterval() {
        var e = makeEngine()
        tick(&e, from: date(Nov.mon, 10, 0), to: date(Nov.mon, 10, 30))
        #expect(e.popupShowing)
        #expect(e.handle(.popupDismissed, at: date(Nov.mon, 10, 37)).isEmpty)
        #expect(!e.popupShowing)
        #expect(e.dueAt == date(Nov.mon, 11, 7))
    }

    @Test func rule5_dismissWhenNotShowingIsIgnored() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        _ = e.handle(.popupDismissed, at: date(Nov.mon, 10, 10))
        #expect(e.dueAt == date(Nov.mon, 10, 30))
    }

    // MARK: Rule 6 — one normal alert after the call

    func engineWithDeferredReminder(_ configure: (inout Settings) -> Void = { _ in }) -> ReminderEngine {
        var e = makeEngine(configure)
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        _ = e.handle(.meetingChanged(true), at: date(Nov.mon, 10, 5))
        tick(&e, from: date(Nov.mon, 10, 5), to: date(Nov.mon, 10, 40))  // silent banner at 10:30
        return e
    }

    @Test func rule6_alertAfterCallWhenReminderWasDeferred() {
        var e = engineWithDeferredReminder()
        #expect(e.handle(.meetingChanged(false), at: date(Nov.mon, 10, 50)) == [.showPopup])
    }

    @Test func rule6_bannerStyleAfterCall() {
        var e = engineWithDeferredReminder { $0.alertStyle = .banner }
        #expect(e.handle(.meetingChanged(false), at: date(Nov.mon, 10, 50)) == [.showBanner(silent: false)])
        #expect(e.dueAt == date(Nov.mon, 11, 20))
    }

    @Test func rule6_noAlertWhenToggleOff() {
        var e = engineWithDeferredReminder { $0.remindAfterCall = false }
        #expect(e.handle(.meetingChanged(false), at: date(Nov.mon, 10, 50)).isEmpty)
    }

    @Test func rule6_noAlertIfNothingWasDeferred() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        _ = e.handle(.meetingChanged(true), at: date(Nov.mon, 10, 5))
        #expect(e.handle(.meetingChanged(false), at: date(Nov.mon, 10, 20)).isEmpty)
        #expect(e.dueAt == date(Nov.mon, 10, 30))
    }

    @Test func rule6_noAlertIfCallEndsWhileLocked() {
        var e = engineWithDeferredReminder()
        _ = e.handle(.screenAwayChanged(true), at: date(Nov.mon, 10, 45))
        #expect(e.handle(.meetingChanged(false), at: date(Nov.mon, 10, 50)).isEmpty)
    }

    @Test func rule6_noAlertIfCallEndsAfterHours() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 16, 0))
        _ = e.handle(.meetingChanged(true), at: date(Nov.mon, 16, 5))
        tick(&e, from: date(Nov.mon, 16, 5), to: date(Nov.mon, 16, 40))
        #expect(e.handle(.meetingChanged(false), at: date(Nov.mon, 17, 10)).isEmpty)
    }

    @Test func rule6_eachCallGetsItsOwnBanner() {
        var e = engineWithDeferredReminder { $0.alertStyle = .banner }
        _ = e.handle(.meetingChanged(false), at: date(Nov.mon, 10, 50))  // after-call banner, due 11:20
        _ = e.handle(.meetingChanged(true), at: date(Nov.mon, 11, 0))
        #expect(e.handle(.tick, at: date(Nov.mon, 11, 20)) == [.showBanner(silent: true)])
    }

    @Test func rule6_turningDetectionOffDropsDeferredReminder() {
        var e = engineWithDeferredReminder()
        var s = e.settings
        s.detectTeamsCalls = false
        _ = e.handle(.settingsChanged(s), at: date(Nov.mon, 10, 45))
        #expect(!e.inMeeting)
        #expect(e.handle(.meetingChanged(false), at: date(Nov.mon, 10, 50)).isEmpty)
    }

    // MARK: Rules 7–9, 11 — pop-up interactions

    func engineWithPopup() -> ReminderEngine {
        var e = makeEngine()
        tick(&e, from: date(Nov.mon, 10, 0), to: date(Nov.mon, 10, 30))
        return e
    }

    @Test func rule7_callStartingSilencesPopupButKeepsIt() {
        var e = engineWithPopup()
        #expect(e.handle(.meetingChanged(true), at: date(Nov.mon, 10, 31)) == [.stopPopupSound])
        #expect(e.popupShowing)
    }

    @Test func rule8_lockDismissesPopupAndUnlockStartsFresh() {
        var e = engineWithPopup()
        #expect(e.handle(.screenAwayChanged(true), at: date(Nov.mon, 10, 31)) == [.dismissPopup])
        #expect(!e.popupShowing)
        _ = e.handle(.screenAwayChanged(false), at: date(Nov.mon, 10, 45))
        #expect(e.dueAt == date(Nov.mon, 11, 15))
    }

    @Test func rule9_muteDismissesPopup() {
        var e = engineWithPopup()
        #expect(e.handle(.muted(until: date(Nov.mon, 12, 0)), at: date(Nov.mon, 10, 31)) == [.dismissPopup])
        #expect(!e.popupShowing)
    }

    @Test func rule11_popupSurvivesEndOfWorkHours() {
        var e = makeEngine()
        tick(&e, from: date(Nov.mon, 16, 0), to: date(Nov.mon, 16, 30))
        #expect(e.popupShowing)
        #expect(tick(&e, from: date(Nov.mon, 16, 30), to: date(Nov.mon, 17, 30)).isEmpty)
        #expect(e.popupShowing)
        // Next morning: still waiting for Done, so no new countdown yet.
        _ = e.handle(.tick, at: date(Nov.tue, 9, 0))
        #expect(e.dueAt == nil)
        _ = e.handle(.popupDismissed, at: date(Nov.tue, 9, 2))
        #expect(e.dueAt == date(Nov.tue, 9, 32))
    }

    @Test func rule11_dismissAfterHoursWaitsForWindow() {
        var e = makeEngine()
        tick(&e, from: date(Nov.mon, 16, 0), to: date(Nov.mon, 16, 30))
        _ = e.handle(.popupDismissed, at: date(Nov.mon, 18, 0))
        #expect(e.dueAt == nil)
        _ = e.handle(.tick, at: date(Nov.tue, 9, 0))
        #expect(e.dueAt == date(Nov.tue, 9, 30))
    }

    // MARK: Status

    @Test func statusReflectsState() {
        var e = makeEngine()
        _ = e.handle(.tick, at: date(Nov.mon, 10, 0))
        #expect(e.status(at: date(Nov.mon, 10, 7)) == .nextBreak(at: date(Nov.mon, 10, 30)))

        _ = e.handle(.meetingChanged(true), at: date(Nov.mon, 10, 8))
        #expect(e.status(at: date(Nov.mon, 10, 9)) == .inMeeting(willRemindAfter: true))
        _ = e.handle(.meetingChanged(false), at: date(Nov.mon, 10, 9))

        _ = e.handle(.muted(until: date(Nov.mon, 15, 30)), at: date(Nov.mon, 10, 10))
        #expect(e.status(at: date(Nov.mon, 10, 11)) == .muted(until: date(Nov.mon, 15, 30)))
        _ = e.handle(.unmuted, at: date(Nov.mon, 10, 12))

        _ = e.handle(.screenAwayChanged(true), at: date(Nov.mon, 10, 13))
        #expect(e.status(at: date(Nov.mon, 10, 14)) == .screenAway)
        _ = e.handle(.screenAwayChanged(false), at: date(Nov.mon, 10, 15))

        #expect(e.status(at: date(Nov.fri, 18, 0)) == .outsideWorkHours(resumesAt: date(30, 9, 0)))
    }

    @Test func statusPopupShowing() {
        let e = engineWithPopup()
        #expect(e.status(at: date(Nov.mon, 10, 31)) == .popupShowing)
    }
}
