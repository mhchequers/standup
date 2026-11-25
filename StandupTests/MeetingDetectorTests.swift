import Foundation
import Testing
@testable import StandupCore

/// The full detection pipeline replayed against FINDINGS.md run 2 (5 s polls).
struct MeetingDetectorTests {
    let own: Int32 = 1
    let t0 = date(Nov.mon, 15, 12, 0)

    let idle = [AudioProcessSample(pid: 9948, bundleID: "com.microsoft.teams2.modulehost", isRunningInput: false, isRunningOutput: false),
                AudioProcessSample(pid: 9957, bundleID: "com.microsoft.teams2.helper", isRunningInput: false, isRunningOutput: false)]
    let uiSound = [AudioProcessSample(pid: 9957, bundleID: "com.microsoft.teams2.helper", isRunningInput: false, isRunningOutput: true)]
    let inCall = [AudioProcessSample(pid: 9948, bundleID: "com.microsoft.teams2.modulehost", isRunningInput: true, isRunningOutput: true)]
    let inCallSpeakerOnly = [AudioProcessSample(pid: 9948, bundleID: "com.microsoft.teams2.modulehost", isRunningInput: false, isRunningOutput: true)]

    /// Runs `polls` (one per 5 s) and returns the seconds at which the debounced state flipped.
    func replay(_ polls: [[AudioProcessSample]]) -> [(Int, Bool)] {
        var detector = MeetingDetector(ownPID: own)
        var flips: [(Int, Bool)] = []
        for (i, samples) in polls.enumerated() {
            if let flipped = detector.update(samples: samples, at: t0.addingTimeInterval(Double(i * 5))).meetingChanged {
                flips.append((i * 5, flipped))
            }
        }
        return flips
    }

    @Test func teamsOpenWithoutCallNeverTriggers() {
        let polls = [uiSound, idle, idle, uiSound, idle] + Array(repeating: idle, count: 20)
        #expect(replay(polls).isEmpty)
    }

    @Test func callStartsAboutTenSecondsInAndEndsAboutSixtyAfterLeaving() {
        // 2 idle polls, 30 in call (incl. muted), then idle 20 polls.
        let polls = Array(repeating: idle, count: 2) + Array(repeating: inCall, count: 30) + Array(repeating: idle, count: 20)
        let flips = replay(polls)
        #expect(flips.map(\.1) == [true, false])
        #expect(flips[0].0 == 10 + 10)            // first in-call poll at 10 s, +10 s debounce
        #expect(flips[1].0 == 160 + 60)           // first idle poll at 160 s, +60 s debounce
    }

    @Test func micDropWithSpeakerStillOnKeepsCall() {
        // FINDINGS run 1: input dropped mid-call; ModuleHost output keeps the raw signal on.
        let polls = Array(repeating: inCall, count: 6) + Array(repeating: inCallSpeakerOnly, count: 20) + Array(repeating: inCall, count: 6)
        #expect(replay(polls).map(\.1) == [true])
    }

    @Test func reportsRawChangesForLogging() {
        var detector = MeetingDetector(ownPID: own)
        #expect(detector.update(samples: idle, at: t0).rawChanged)            // first poll always "changed"
        #expect(!detector.update(samples: idle, at: t0.addingTimeInterval(5)).rawChanged)
        let u = detector.update(samples: inCall, at: t0.addingTimeInterval(10))
        #expect(u.raw && u.rawChanged && u.meetingChanged == nil)
    }

    @Test func resetForgetsCall() {
        var detector = MeetingDetector(ownPID: own)
        for i in 0..<4 { _ = detector.update(samples: inCall, at: t0.addingTimeInterval(Double(i * 5))) }
        #expect(detector.inMeeting)
        detector.reset()
        #expect(!detector.inMeeting && detector.lastRaw == nil)
    }
}
