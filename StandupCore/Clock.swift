import Foundation

/// Source of "now". Injected everywhere so time-based logic can be tested with a fake clock.
public protocol Clock: Sendable {
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}
