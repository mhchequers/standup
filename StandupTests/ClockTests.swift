import Foundation
import Testing
@testable import StandupCore

struct ClockTests {
    @Test func systemClockReturnsCurrentTime() {
        #expect(abs(SystemClock().now.timeIntervalSince(Date())) < 1)
    }
}
