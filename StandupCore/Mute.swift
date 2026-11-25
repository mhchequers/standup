import Foundation

/// Mute options from the menu (DESIGN §1, §8). Resolved to a `muteUntil` date.
public enum MutePreset: Equatable, Sendable {
    case minutes(Int)
    case untilTomorrow
    case until(Date)
    case indefinitely

    /// The fixed presets shown in the Mute menu, in order (custom "Until…" is separate).
    public static let menuPresets: [MutePreset] = [.minutes(30), .minutes(60), .minutes(120), .untilTomorrow, .indefinitely]

    /// The `muteUntil` date for this preset, or nil if it would already be over.
    public func muteUntil(now: Date, calendar: Calendar = .current) -> Date? {
        let result: Date?
        switch self {
        case .minutes(let minutes):
            result = minutes > 0 ? now.addingTimeInterval(TimeInterval(minutes * 60)) : nil
        case .untilTomorrow:
            result = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        case .until(let date):
            result = date
        case .indefinitely:
            result = Mute.indefinite
        }
        guard let result, result > now else { return nil }
        return result
    }
}

public enum Mute {
    /// Sentinel for "until I unmute".
    public static let indefinite = Date.distantFuture

    public static func isMuted(until muteUntil: Date?, now: Date) -> Bool {
        guard let muteUntil else { return false }
        return now < muteUntil
    }

    public static func isIndefinite(_ muteUntil: Date) -> Bool { muteUntil == indefinite }
}
