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

    @ObservationIgnored let sounds: any SoundPlaying
    @ObservationIgnored private let toast: any ToastPresenting
    @ObservationIgnored private let popup: any PopupPresenting
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "dev.standup.Standup", category: "app")

    init() {
        let sounds = SoundPlayer.shared
        self.sounds = sounds
        toast = ToastController()
        popup = PopupAlertController(sounds: sounds)
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

    /// Settings → "Show test alert": shows the current style without touching the countdown.
    func showTestAlert() {
        switch settings.alertStyle {
        case .banner: showToast(silent: settings.soundName == nil)
        case .popup: popup.show(soundName: settings.soundName) { [weak self] in self?.popup.dismiss() }
        }
    }

    // MARK: Effects

    private func perform(_ effects: [ReminderEngine.Effect]) {
        for effect in effects {
            log.info("effect: \(String(describing: effect), privacy: .public)")
            switch effect {
            case .showToast(let silent):
                showToast(silent: silent)
            case .showPopup:
                popup.show(soundName: settings.soundName) { [weak self] in
                    self?.popup.dismiss()
                    self?.send(.popupDismissed)
                }
            case .dismissPopup:
                popup.dismiss()
            case .stopPopupSound:
                popup.stopSound()
            }
        }
    }

    private func showToast(silent: Bool) {
        toast.show(title: AlertCopy.title, body: AlertCopy.body)
        if !silent, let name = settings.soundName {
            sounds.play(name)
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
