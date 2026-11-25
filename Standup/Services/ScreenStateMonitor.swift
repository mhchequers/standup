import AppKit
import CoreGraphics
import StandupCore
import os

/// Watches lock / sleep / display sleep / screensaver / user switching (DESIGN §6)
/// and reports when the combined "away" state changes.
@MainActor
protocol ScreenStateMonitoring: AnyObject {
    var isAway: Bool { get }
    func start(onChange: @escaping @MainActor (Bool) -> Void)
}

@MainActor
final class ScreenStateMonitor: ScreenStateMonitoring {
    private var tracker: ScreenAwayTracker
    private var onChange: (@MainActor (Bool) -> Void)?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private let log = Logger(subsystem: "dev.standup.Standup", category: "screen")

    init() {
        tracker = ScreenAwayTracker(reasons: Self.isScreenLockedNow() ? [.locked] : [])
    }

    var isAway: Bool { tracker.isAway }

    func start(onChange: @escaping @MainActor (Bool) -> Void) {
        self.onChange = onChange
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, "com.apple.screenIsLocked", .locked, true)
        observe(distributed, "com.apple.screenIsUnlocked", .locked, false)
        observe(distributed, "com.apple.screensaver.didstart", .screensaver, true)
        observe(distributed, "com.apple.screensaver.didstop", .screensaver, false)

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification.rawValue, .asleep, true)
        observe(workspace, NSWorkspace.didWakeNotification.rawValue, .asleep, false)
        observe(workspace, NSWorkspace.screensDidSleepNotification.rawValue, .displaysAsleep, true)
        observe(workspace, NSWorkspace.screensDidWakeNotification.rawValue, .displaysAsleep, false)
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification.rawValue, .sessionInactive, true)
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification.rawValue, .sessionInactive, false)
        log.info("started; locked at launch: \(self.tracker.reasons.contains(.locked), privacy: .public)")
    }

    private func observe(_ center: NotificationCenter, _ name: String,
                         _ reason: ScreenAwayTracker.Reason, _ active: Bool) {
        let token = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.update(reason, active: active)
            }
        }
        tokens.append((center, token))
    }

    private func update(_ reason: ScreenAwayTracker.Reason, active: Bool) {
        var reason = reason
        var active = active
        // On wake, the lock notification may have been missed; re-read the real lock state.
        if reason == .asleep, !active, Self.isScreenLockedNow() {
            _ = tracker.set(.asleep, active: false)
            reason = .locked
            active = true
        }
        let changed = tracker.set(reason, active: active)
        log.info("\(reason.rawValue, privacy: .public)=\(active, privacy: .public) → away=\(self.tracker.isAway, privacy: .public)")
        if let changed {
            onChange?(changed)
        }
    }

    /// Current lock state from the window server session (`CGSSessionScreenIsLocked`).
    static func isScreenLockedNow() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? Bool) ?? ((session["CGSSessionScreenIsLocked"] as? Int) == 1)
    }
}
