import AppKit

/// Ensures only one copy of Standup runs, even if several builds exist on disk
/// (e.g. /Applications plus a Debug build). Two copies would mean double reminders.
enum SingleInstance {
    /// Call at launch. If another copy with our bundle ID is already running, quit this one.
    @MainActor
    static func enforce() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != me }
        guard !others.isEmpty else { return }
        NSLog("Standup is already running (pid %d); exiting this copy.", others[0].processIdentifier)
        exit(0)
    }
}
