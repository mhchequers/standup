import Foundation
import Testing
@testable import StandupCore

struct MeetingDebouncerTests {
    let t0 = date(Nov.mon, 10, 0)

    /// Feeds samples every 5 s (the app's poll interval); returns the times at which state flipped.
    func run(_ debouncer: inout MeetingDebouncer, _ samples: [Bool]) -> [(Int, Bool)] {
        var flips: [(Int, Bool)] = []
        for (i, raw) in samples.enumerated() {
            if let flipped = debouncer.update(rawActive: raw, at: t0.addingTimeInterval(Double(i * 5))) {
                flips.append((i * 5, flipped))
            }
        }
        return flips
    }

    @Test func startsAfterTenSecondsOfActivity() {
        var d = MeetingDebouncer()
        let flips = run(&d, [true, true, true, true])
        #expect(flips.count == 1 && flips[0] == (10, true))
    }

    @Test func shortBlipDoesNotStart() {
        var d = MeetingDebouncer()
        #expect(run(&d, [true, true, false, true, true, false]).isEmpty)
        #expect(!d.inMeeting)
    }

    @Test func endsAfterSixtySecondsOfInactivity() {
        var d = MeetingDebouncer()
        let flips = run(&d, Array(repeating: true, count: 3) + Array(repeating: false, count: 14))
        #expect(flips.map(\.1) == [true, false])
        #expect(flips.last?.0 == 15 + 60)
    }

    @Test func fiftyFourSecondGapFromFindingsRun1DoesNotEnd() {
        var d = MeetingDebouncer()
        // ~54 s gap ≈ 11 inactive polls
        let samples = Array(repeating: true, count: 3) + Array(repeating: false, count: 11) + Array(repeating: true, count: 3)
        #expect(run(&d, samples).map(\.1) == [true])
        #expect(d.inMeeting)
    }

    @Test func resetClearsState() {
        var d = MeetingDebouncer()
        _ = run(&d, [true, true, true])
        d.reset()
        #expect(!d.inMeeting)
    }
}

struct TeamsCallSignalTests {
    let own: Int32 = 1
    func p(_ bundle: String, input: Bool = false, output: Bool = false, pid: Int32 = 100) -> AudioProcessSample {
        AudioProcessSample(pid: pid, bundleID: bundle, isRunningInput: input, isRunningOutput: output)
    }

    // Cases taken from FINDINGS.md run 2.
    @Test func idleTeamsProcessesAreNotACall() {
        let idle = [p("com.microsoft.teams2.helper"), p("com.microsoft.teams2.modulehost")]
        #expect(!TeamsCallSignal.isActive(idle, ownPID: own))
    }

    @Test func helperOutputIsJustUISounds() {
        #expect(!TeamsCallSignal.isActive([p("com.microsoft.teams2.helper", output: true)], ownPID: own))
    }

    @Test func moduleHostInputIsACall() {
        #expect(TeamsCallSignal.isActive([p("com.microsoft.teams2.modulehost", input: true)], ownPID: own))
    }

    @Test func moduleHostOutputAloneIsACall() {
        #expect(TeamsCallSignal.isActive([p("com.microsoft.teams2.modulehost", output: true)], ownPID: own))
    }

    @Test func anyTeamsProcessCapturingCounts() {
        #expect(TeamsCallSignal.isActive([p("com.microsoft.teams2.helper", input: true)], ownPID: own))
    }

    @Test func otherAppsDoNotCount() {
        let others = [p("com.google.Chrome.helper", input: true, output: true), p("com.microsoft.vcxpc", input: true)]
        #expect(!TeamsCallSignal.isActive(others, ownPID: own))
    }

    @Test func ownProcessIsExcluded() {
        #expect(!TeamsCallSignal.isActive([p("com.microsoft.teams2.modulehost", input: true, pid: own)], ownPID: own))
    }
}
