import Foundation

/// Turns raw per-poll "is Teams active" samples into a stable in-meeting state (DESIGN §5).
/// Start requires `onDelay` of continuous activity; end requires `offDelay` of continuous inactivity.
public struct MeetingDebouncer: Sendable {
    public static let defaultOnDelay: TimeInterval = 10
    public static let defaultOffDelay: TimeInterval = 60

    public let onDelay: TimeInterval
    public let offDelay: TimeInterval
    public private(set) var inMeeting = false
    private var candidateSince: Date?

    public init(onDelay: TimeInterval = defaultOnDelay, offDelay: TimeInterval = defaultOffDelay) {
        self.onDelay = onDelay
        self.offDelay = offDelay
    }

    /// Feed one sample. Returns the new state if it flipped, otherwise nil.
    public mutating func update(rawActive: Bool, at now: Date) -> Bool? {
        guard rawActive != inMeeting else {
            candidateSince = nil
            return nil
        }
        let since = candidateSince ?? now
        candidateSince = since
        let required = rawActive ? onDelay : offDelay
        guard now.timeIntervalSince(since) >= required else { return nil }
        inMeeting = rawActive
        candidateSince = nil
        return inMeeting
    }

    /// Forget any pending transition and force the state (e.g. when detection is turned off).
    public mutating func reset(inMeeting: Bool = false) {
        self.inMeeting = inMeeting
        candidateSince = nil
    }
}
