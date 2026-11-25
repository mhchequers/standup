import Foundation

public enum AlertStyle: String, Codable, Sendable, CaseIterable {
    case banner
    case popup
}

/// Calendar weekday numbering (matches `Calendar.component(.weekday, ...)`: 1 = Sunday).
public enum Weekday: Int, Codable, Sendable, CaseIterable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public static let workweek: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A wall-clock time of day (no date, no time zone).
public struct TimeOfDay: Codable, Hashable, Sendable, Comparable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }
    public var isValid: Bool { (0...23).contains(hour) && (0...59).contains(minute) }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

/// User settings (DESIGN §8). Launch-at-login is not stored here; it is read from SMAppService.
public struct Settings: Codable, Equatable, Sendable {
    public static let intervalRange = 5...240
    public static let defaultSoundName = "Glass"

    public var intervalMinutes = 30
    public var activeDays: Set<Weekday> = Weekday.workweek
    public var workStart = TimeOfDay(hour: 9)
    public var workEnd = TimeOfDay(hour: 17)
    public var alertStyle: AlertStyle = .popup
    /// A system sound name (e.g. "Glass"), or nil for no sound.
    public var soundName: String? = Settings.defaultSoundName
    public var detectTeamsCalls = true
    public var remindAfterCall = true

    public init() {}

    public var interval: TimeInterval { TimeInterval(intervalMinutes * 60) }

    /// Returns a copy with any invalid values replaced by defaults or clamped (DESIGN §8).
    /// `minimumInterval` is lowered to 1 in Debug builds for quick testing.
    public func validated(minimumInterval: Int = Settings.intervalRange.lowerBound) -> Settings {
        var copy = self
        let defaults = Settings()
        copy.intervalMinutes = min(max(intervalMinutes, minimumInterval), Settings.intervalRange.upperBound)
        if copy.activeDays.isEmpty {
            copy.activeDays = defaults.activeDays
        }
        if !workStart.isValid || !workEnd.isValid || workEnd <= workStart {
            copy.workStart = defaults.workStart
            copy.workEnd = defaults.workEnd
        }
        if let name = soundName, name.trimmingCharacters(in: .whitespaces).isEmpty {
            copy.soundName = nil
        }
        return copy
    }

    // Tolerant decoding: missing keys (e.g. settings saved by an older version) fall back to defaults.
    private enum CodingKeys: String, CodingKey {
        case intervalMinutes, activeDays, workStart, workEnd, alertStyle, soundName, detectTeamsCalls, remindAfterCall
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        intervalMinutes = try c.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? d.intervalMinutes
        activeDays = try c.decodeIfPresent(Set<Weekday>.self, forKey: .activeDays) ?? d.activeDays
        workStart = try c.decodeIfPresent(TimeOfDay.self, forKey: .workStart) ?? d.workStart
        workEnd = try c.decodeIfPresent(TimeOfDay.self, forKey: .workEnd) ?? d.workEnd
        alertStyle = try c.decodeIfPresent(AlertStyle.self, forKey: .alertStyle) ?? d.alertStyle
        soundName = c.contains(.soundName) ? try c.decodeIfPresent(String.self, forKey: .soundName) : d.soundName
        detectTeamsCalls = try c.decodeIfPresent(Bool.self, forKey: .detectTeamsCalls) ?? d.detectTeamsCalls
        remindAfterCall = try c.decodeIfPresent(Bool.self, forKey: .remindAfterCall) ?? d.remindAfterCall
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(intervalMinutes, forKey: .intervalMinutes)
        try c.encode(activeDays.sorted(), forKey: .activeDays)
        try c.encode(workStart, forKey: .workStart)
        try c.encode(workEnd, forKey: .workEnd)
        try c.encode(alertStyle, forKey: .alertStyle)
        try c.encode(soundName, forKey: .soundName)  // encodes null for "no sound"
        try c.encode(detectTeamsCalls, forKey: .detectTeamsCalls)
        try c.encode(remindAfterCall, forKey: .remindAfterCall)
    }
}
