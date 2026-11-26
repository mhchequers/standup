import Foundation
import StandupCore
import os

/// Polls `MicUsageProbe` every 5 s while enabled and reports debounced Teams call start/end (DESIGN §5).
@MainActor
protocol MeetingMonitoring: AnyObject {
    func setEnabled(_ enabled: Bool)
    func start(onChange: @escaping @MainActor (Bool) -> Void)
}

@MainActor
final class MeetingMonitor: MeetingMonitoring {
    static let pollInterval: Duration = .seconds(5)

    private let probe: any MicUsageProbing
    private var detector = MeetingDetector(ownPID: ProcessInfo.processInfo.processIdentifier)
    private var onChange: (@MainActor (Bool) -> Void)?
    private var pollTask: Task<Void, Never>?
    private var enabled = false
    private let log = Logger(subsystem: "dev.standup.Standup", category: "meeting")

    init(probe: any MicUsageProbing = MicUsageProbe()) {
        self.probe = probe
    }

    func start(onChange: @escaping @MainActor (Bool) -> Void) {
        self.onChange = onChange
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != self.enabled else { return }
        self.enabled = enabled
        log.notice("detection \(enabled ? "on" : "off", privacy: .public)")
        if enabled {
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    self?.poll()
                    try? await Task.sleep(for: Self.pollInterval)
                }
            }
        } else {
            pollTask?.cancel()
            pollTask = nil
            let wasInMeeting = detector.inMeeting
            detector.reset()
            if wasInMeeting { onChange?(false) }
        }
    }

    private func poll() {
        let samples = probe.samples()
        let update = detector.update(samples: samples, at: Date())
        if update.rawChanged {
            // Raw transitions only (not every poll): enough to spot gaps longer than the 60 s end debounce.
            let teams = samples.filter { $0.bundleID.hasPrefix(TeamsCallSignal.teamsBundlePrefix) && ($0.isRunningInput || $0.isRunningOutput) }
                .map { "\($0.bundleID)[\($0.isRunningInput ? "in" : "")\($0.isRunningOutput ? "out" : "")]" }
            log.notice("raw teams signal=\(update.raw, privacy: .public) \(teams.joined(separator: " "), privacy: .public)")
        }
        if let changed = update.meetingChanged {
            log.notice("call \(changed ? "started" : "ended", privacy: .public)")
            onChange?(changed)
        }
    }
}
