import Foundation

/// Combines the OS signals that mean "you're away from the screen" (DESIGN §6) into one Bool.
/// Each signal is tracked separately so, e.g., waking from sleep while still locked stays "away".
public struct ScreenAwayTracker: Equatable, Sendable {
    public enum Reason: String, CaseIterable, Sendable {
        case locked, asleep, displaysAsleep, screensaver, sessionInactive
    }

    public private(set) var reasons: Set<Reason>

    public init(reasons: Set<Reason> = []) {
        self.reasons = reasons
    }

    public var isAway: Bool { !reasons.isEmpty }

    /// Records a signal. Returns the new `isAway` value if it changed, otherwise nil.
    public mutating func set(_ reason: Reason, active: Bool) -> Bool? {
        let wasAway = isAway
        if active {
            reasons.insert(reason)
        } else {
            reasons.remove(reason)
        }
        return isAway != wasAway ? isAway : nil
    }
}
