import Foundation

/// One poll's worth of Teams-call detection: `TeamsCallSignal` (raw) → `MeetingDebouncer` (stable).
/// Pure, so the whole pipeline the app runs every 5 s is unit tested (DESIGN §5).
public struct MeetingDetector: Sendable {
    public let ownPID: Int32
    public private(set) var debouncer: MeetingDebouncer
    /// The last raw (un-debounced) signal, for logging gaps.
    public private(set) var lastRaw: Bool?

    public init(ownPID: Int32, debouncer: MeetingDebouncer = MeetingDebouncer()) {
        self.ownPID = ownPID
        self.debouncer = debouncer
    }

    public var inMeeting: Bool { debouncer.inMeeting }

    public struct Update: Equatable, Sendable {
        /// Raw signal this poll.
        public var raw: Bool
        /// True if the raw signal differs from the previous poll (worth logging).
        public var rawChanged: Bool
        /// New debounced state if it flipped this poll.
        public var meetingChanged: Bool?
    }

    public mutating func update(samples: [AudioProcessSample], at now: Date) -> Update {
        let raw = TeamsCallSignal.isActive(samples, ownPID: ownPID)
        let rawChanged = raw != lastRaw
        lastRaw = raw
        return Update(raw: raw, rawChanged: rawChanged, meetingChanged: debouncer.update(rawActive: raw, at: now))
    }

    /// Detection turned off: forget everything.
    public mutating func reset() {
        debouncer.reset()
        lastRaw = nil
    }
}
