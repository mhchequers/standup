import Testing
@testable import StandupCore

struct ScreenAwayTrackerTests {
    @Test func startsPresent() {
        #expect(!ScreenAwayTracker().isAway)
    }

    @Test func lockAndUnlock() {
        var t = ScreenAwayTracker()
        #expect(t.set(.locked, active: true) == true)
        #expect(t.set(.locked, active: false) == false)
    }

    @Test func repeatedSignalsReportNoChange() {
        var t = ScreenAwayTracker()
        _ = t.set(.locked, active: true)
        #expect(t.set(.locked, active: true) == nil)
        #expect(t.set(.asleep, active: false) == nil)  // clearing an inactive reason
    }

    @Test func wakingWhileStillLockedStaysAway() {
        var t = ScreenAwayTracker()
        _ = t.set(.locked, active: true)
        _ = t.set(.asleep, active: true)
        #expect(t.set(.asleep, active: false) == nil)  // woke, but the lock screen is up
        #expect(t.isAway)
        #expect(t.set(.locked, active: false) == false)  // unlocked: back
    }

    @Test func displaysSleepingWithoutLockCountsAsAway() {
        var t = ScreenAwayTracker()
        #expect(t.set(.displaysAsleep, active: true) == true)
        #expect(t.set(.displaysAsleep, active: false) == false)
    }

    @Test func screensaverAndUserSwitchCount() {
        var t = ScreenAwayTracker()
        #expect(t.set(.screensaver, active: true) == true)
        #expect(t.set(.sessionInactive, active: true) == nil)
        #expect(t.set(.screensaver, active: false) == nil)
        #expect(t.set(.sessionInactive, active: false) == false)
    }

    @Test func initialStateFromLaunch() {
        #expect(ScreenAwayTracker(reasons: [.locked]).isAway)
    }
}
