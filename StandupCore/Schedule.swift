import Foundation

/// Work-hours math (DESIGN §4 "Derived"). Uses wall-clock components, so it is DST-safe.
public struct Schedule: Sendable {
    public var activeDays: Set<Weekday>
    public var start: TimeOfDay
    public var end: TimeOfDay
    public var calendar: Calendar

    public init(activeDays: Set<Weekday>, start: TimeOfDay, end: TimeOfDay, calendar: Calendar = .current) {
        self.activeDays = activeDays
        self.start = start
        self.end = end
        self.calendar = calendar
    }

    public init(settings: Settings, calendar: Calendar = .current) {
        self.init(activeDays: settings.activeDays, start: settings.workStart, end: settings.workEnd, calendar: calendar)
    }

    /// True if `date` falls on an active weekday and start ≤ time-of-day < end.
    public func isInWorkHours(_ date: Date) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekdayNumber = parts.weekday, let weekday = Weekday(rawValue: weekdayNumber),
              activeDays.contains(weekday),
              let hour = parts.hour, let minute = parts.minute else { return false }
        let minutes = hour * 60 + minute
        return minutes >= start.minutesSinceMidnight && minutes < end.minutesSinceMidnight
    }

    /// The next moment (strictly after `date`) when a work window opens, or nil if no day is active.
    public func nextWindowStart(after date: Date) -> Date? {
        let today = calendar.startOfDay(for: date)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let weekday = Weekday(rawValue: calendar.component(.weekday, from: day)),
                  activeDays.contains(weekday),
                  let opening = calendar.date(bySettingHour: start.hour, minute: start.minute, second: 0, of: day),
                  opening > date else { continue }
            return opening
        }
        return nil
    }
}
