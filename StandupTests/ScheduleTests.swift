import Foundation
import Testing
@testable import StandupCore

struct ScheduleTests {
    let schedule = Schedule(settings: Settings(), calendar: testCalendar)  // Mon–Fri 9–17

    @Test func insideAndOutsideHours() {
        #expect(!schedule.isInWorkHours(date(Nov.mon, 8, 59, 59)))
        #expect(schedule.isInWorkHours(date(Nov.mon, 9, 0)))       // start is inclusive
        #expect(schedule.isInWorkHours(date(Nov.mon, 16, 59, 59)))
        #expect(!schedule.isInWorkHours(date(Nov.mon, 17, 0)))     // end is exclusive
    }

    @Test func weekendsAreInactive() {
        #expect(!schedule.isInWorkHours(date(Nov.sat, 10, 0)))
        #expect(!schedule.isInWorkHours(date(Nov.sun, 10, 0)))
    }

    @Test func nextWindowStartLaterToday() {
        #expect(schedule.nextWindowStart(after: date(Nov.mon, 7, 0)) == date(Nov.mon, 9, 0))
    }

    @Test func nextWindowStartIsStrictlyAfter() {
        #expect(schedule.nextWindowStart(after: date(Nov.mon, 9, 0)) == date(Nov.tue, 9, 0))
    }

    @Test func nextWindowStartSkipsWeekend() {
        #expect(schedule.nextWindowStart(after: date(Nov.fri, 18, 0)) == date(30, 9, 0))  // Mon Nov 30
    }

    @Test func noActiveDaysMeansNoWindow() {
        let none = Schedule(activeDays: [], start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 17), calendar: testCalendar)
        #expect(none.nextWindowStart(after: date(Nov.mon, 7, 0)) == nil)
        #expect(!none.isInWorkHours(date(Nov.mon, 10, 0)))
    }

    @Test func dstStartDayUsesWallClock() {
        // Sun Mar 8 2026: clocks jump 2:00 → 3:00 in New York.
        let everyDay = Schedule(activeDays: Set(Weekday.allCases), start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 17), calendar: testCalendar)
        let dstSunday = date(8, 9, 0, month: 3)
        #expect(everyDay.isInWorkHours(dstSunday))
        #expect(!everyDay.isInWorkHours(date(8, 8, 59, month: 3)))
        #expect(everyDay.nextWindowStart(after: date(7, 20, 0, month: 3)) == dstSunday)
    }
}
