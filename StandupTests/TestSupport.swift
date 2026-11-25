import Foundation
@testable import StandupCore

/// Fixed calendar/time zone so tests don't depend on the machine's settings.
let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}()

/// November 2026: Mon 23, Tue 24, Wed 25, Thu 26, Fri 27, Sat 28, Sun 29.
enum Nov {
    static let mon = 23, tue = 24, fri = 27, sat = 28, sun = 29
}

func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0, month: Int = 11, year: Int = 2026) -> Date {
    testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

func minutes(_ m: Double) -> TimeInterval { m * 60 }
