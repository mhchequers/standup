import Foundation

/// One CoreAudio process object as read by the app's mic probe (Services/MicUsageProbe).
public struct AudioProcessSample: Equatable, Sendable {
    public var pid: Int32
    public var bundleID: String
    public var isRunningInput: Bool
    public var isRunningOutput: Bool

    public init(pid: Int32, bundleID: String, isRunningInput: Bool, isRunningOutput: Bool) {
        self.pid = pid
        self.bundleID = bundleID
        self.isRunningInput = isRunningInput
        self.isRunningOutput = isRunningOutput
    }
}

/// The verified rule for "Teams is in a call" (DESIGN §5, FINDINGS.md conclusion 1).
public enum TeamsCallSignal {
    /// Teams' media process: holds mic and speaker for the whole call, including while muted.
    public static let mediaProcessBundleID = "com.microsoft.teams2.modulehost"
    /// Any Teams process capturing the mic counts (in case Teams moves capture between processes).
    public static let teamsBundlePrefix = "com.microsoft.teams"

    /// Raw (un-debounced) signal for one poll. `ownPID` is excluded.
    public static func isActive(_ samples: [AudioProcessSample], ownPID: Int32) -> Bool {
        samples.contains { sample in
            guard sample.pid != ownPID else { return false }
            if sample.bundleID == mediaProcessBundleID {
                return sample.isRunningInput || sample.isRunningOutput
            }
            // Helper OUTPUT is UI sounds (join/leave chimes): ignored. INPUT from any Teams process counts.
            return sample.bundleID.hasPrefix(teamsBundlePrefix) && sample.isRunningInput
        }
    }
}
