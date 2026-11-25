import Foundation
import Testing
@testable import StandupCore

struct MuteTests {
    let now = date(Nov.mon, 10, 15)

    @Test func minutePresets() {
        #expect(MutePreset.minutes(30).muteUntil(now: now, calendar: testCalendar) == date(Nov.mon, 10, 45))
        #expect(MutePreset.minutes(60).muteUntil(now: now, calendar: testCalendar) == date(Nov.mon, 11, 15))
        #expect(MutePreset.minutes(120).muteUntil(now: now, calendar: testCalendar) == date(Nov.mon, 12, 15))
        #expect(MutePreset.minutes(0).muteUntil(now: now, calendar: testCalendar) == nil)
    }

    @Test func untilTomorrowIsNextLocalMidnight() {
        #expect(MutePreset.untilTomorrow.muteUntil(now: now, calendar: testCalendar) == date(Nov.tue, 0, 0))
    }

    @Test func customDateMustBeInFuture() {
        #expect(MutePreset.until(date(Nov.mon, 15, 30)).muteUntil(now: now, calendar: testCalendar) == date(Nov.mon, 15, 30))
        #expect(MutePreset.until(date(Nov.mon, 9, 0)).muteUntil(now: now, calendar: testCalendar) == nil)
    }

    @Test func indefinitely() throws {
        let until = try #require(MutePreset.indefinitely.muteUntil(now: now, calendar: testCalendar))
        #expect(Mute.isIndefinite(until))
        #expect(Mute.isMuted(until: until, now: now))
    }

    @Test func isMutedExpires() {
        let until = date(Nov.mon, 10, 45)
        #expect(Mute.isMuted(until: until, now: date(Nov.mon, 10, 44, 59)))
        #expect(!Mute.isMuted(until: until, now: until))
        #expect(!Mute.isMuted(until: nil, now: now))
    }

    @Test func menuPresetsInOrder() {
        #expect(MutePreset.menuPresets == [.minutes(30), .minutes(60), .minutes(120), .untilTomorrow, .indefinitely])
    }
}
