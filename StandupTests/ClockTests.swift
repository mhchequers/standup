import Foundation
import Testing
@testable import StandupCore

struct ClockTests {
    @Test func systemClockReturnsCurrentTime() {
        let delta = SystemClock().now.timeIntervalSince(Date())
        #expect(abs(delta) < 1)
    }
}
