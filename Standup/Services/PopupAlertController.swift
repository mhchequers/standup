import AppKit
import StandupCore
import SwiftUI

/// The click-to-clear pop-up (DESIGN §7): a floating, non-activating panel plus a looping sound
/// that repeats every `PopupSoundTiming.repeatInterval` for at most `PopupSoundTiming.maxDuration`.
@MainActor
protocol PopupPresenting: AnyObject {
    var isShowing: Bool { get }
    func show(soundName: String?, onDone: @escaping @MainActor () -> Void)
    func stopSound()
    func dismiss()
}

@MainActor
final class PopupAlertController: PopupPresenting {
    private let sounds: any SoundPlaying
    private var panel: NSPanel?
    private var soundTask: Task<Void, Never>?

    init(sounds: any SoundPlaying) {
        self.sounds = sounds
    }

    var isShowing: Bool { panel != nil }

    func show(soundName: String?, onDone: @escaping @MainActor () -> Void) {
        dismiss()
        let panel = FloatingPanel()
        let view = PopupView {
            onDone()
        }
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        position(panel)
        panel.orderFrontRegardless()  // visible on top without stealing focus from your work
        self.panel = panel

        if let soundName {
            startSoundLoop(soundName)
        }
    }

    func stopSound() {
        soundTask?.cancel()
        soundTask = nil
        sounds.stop()
    }

    func dismiss() {
        stopSound()
        panel?.orderOut(nil)
        panel = nil
    }

    private func startSoundLoop(_ name: String) {
        stopSound()
        soundTask = Task { [sounds] in
            let started = ContinuousClock.now
            let maxDuration = Duration.seconds(PopupSoundTiming.maxDuration)
            while !Task.isCancelled, ContinuousClock.now - started < maxDuration {
                sounds.play(name)
                try? await Task.sleep(for: .seconds(PopupSoundTiming.repeatInterval))
            }
        }
    }

    /// Top-center of the screen the mouse is on.
    private func position(_ panel: NSPanel) {
        guard let frame = FloatingPanel.screenUnderMouse()?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 80))
    }
}
