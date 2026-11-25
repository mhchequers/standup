import Foundation

/// The menu's status line (DESIGN §4 "Menu status line").
public struct StatusText: Sendable {
    public var calendar: Calendar
    public var locale: Locale

    public init(calendar: Calendar = .current, locale: Locale = .current) {
        self.calendar = calendar
        self.locale = locale
    }

    public func text(for status: ReminderEngine.Status, now: Date) -> String {
        switch status {
        case .nextBreak(let at):
            let minutes = Int((at.timeIntervalSince(now) / 60).rounded(.up))
            return minutes <= 1 ? "Next break in less than a minute" : "Next break in \(minutes) min"
        case .popupShowing:
            return "Break time!"
        case .inMeeting(let willRemindAfter):
            return willRemindAfter ? "In a Teams call — will remind after" : "In a Teams call"
        case .muted(let until):
            if Mute.isIndefinite(until) { return "Muted" }
            if isStartOfTomorrow(until, now: now) { return "Muted until tomorrow" }
            return "Muted until \(describe(until, now: now))"
        case .outsideWorkHours(let resumesAt):
            guard let resumesAt else { return "No active days set" }
            return "Outside work hours — resumes \(describe(resumesAt, now: now))"
        case .screenAway:
            return "Paused — screen locked"
        }
    }

    /// "3:30 PM" today, "tomorrow 9:00 AM", otherwise "Mon 9:00 AM" (within a week) or "Dec 2, 9:00 AM".
    func describe(_ date: Date, now: Date) -> String {
        let time = format(date, template: "jmm")
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) { return "tomorrow \(time)" }
        if date.timeIntervalSince(now) < 6 * 86_400 { return "\(format(date, template: "EEE")) \(time)" }
        return "\(format(date, template: "MMMd")), \(time)"
    }

    private func isStartOfTomorrow(_ date: Date, now: Date) -> Bool {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return false }
        return date == tomorrow
    }

    private func format(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
