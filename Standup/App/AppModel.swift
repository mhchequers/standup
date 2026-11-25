import AppKit
import Observation
import StandupCore
import os

/// Thin @Observable wrapper: drives `ReminderController` with a timer and performs its effects (DESIGN §3).
@MainActor @Observable
final class AppModel {
    #if DEBUG
    static let minimumInterval = 1  // quick manual testing (PLAN M5)
    #else
    static let minimumInterval = AppSettings.intervalRange.lowerBound
    #endif
    static let tickInterval: Duration = .seconds(5)

    private(set) var controller: ReminderController

    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "dev.standup.Standup", category: "app")

    init() {
        controller = ReminderController(store: SettingsStore(), minimumInterval: Self.minimumInterval)
        startTicking()
    }

    var settings: AppSettings { controller.settings }
    var isMuted: Bool { controller.isMuted }
    var statusLine: String { controller.statusLine }

    var menuBarSymbol: String {
        switch controller.menuIcon {
        case .normal: "figure.stand"
        case .muted: "bell.slash"
        case .inCall: "phone.fill"
        }
    }

    // MARK: UI actions

    func apply(_ newSettings: AppSettings) { perform(controller.apply(newSettings)) }
    func mute(_ preset: MutePreset) { perform(controller.mute(preset)) }
    func unmute() { perform(controller.unmute()) }
    func send(_ event: ReminderEngine.Event) { perform(controller.send(event)) }

    // MARK: Effects

    private func perform(_ effects: [ReminderEngine.Effect]) {
        for effect in effects {
            log.info("effect: \(String(describing: effect), privacy: .public)")
            // M4 placeholder until real alerts exist (M5): treat a pop-up as instantly dismissed
            // so the countdown keeps cycling instead of sticking on "Break time!".
            if effect == .showPopup {
                send(.popupDismissed)
            }
        }
    }

    private func startTicking() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                self?.send(.tick)
            }
        }
    }
}
