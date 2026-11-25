import AppKit
import StandupCore
import SwiftUI

/// The "Corner toast" alert style (DESIGN §7): a small card at the top-right that hides itself.
/// Our own window instead of macOS notifications, so no permission or code-signing identity is needed.
@MainActor
protocol ToastPresenting: AnyObject {
    func show(title: String, body: String)
    func dismiss()
}

@MainActor
final class ToastController: ToastPresenting {
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(title: String, body: String) {
        dismiss()
        let panel = FloatingPanel()
        let hosting = NSHostingView(rootView: ToastView(title: title, message: body) { [weak self] in
            self?.dismiss()
        })
        hosting.frame.size = hosting.fittingSize
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        if let frame = FloatingPanel.screenUnderMouse()?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 16, y: frame.maxY - size.height - 12))
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.2; panel.animator().alphaValue = 1 }
        self.panel = panel

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ToastTiming.visibleDuration))
            guard !Task.isCancelled else { return }
            self?.dismiss(animated: true)
        }
    }

    func dismiss() {
        dismiss(animated: false)
    }

    private func dismiss(animated: Bool) {
        hideTask?.cancel()
        hideTask = nil
        guard let panel else { return }
        self.panel = nil
        guard animated else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel.animator().alphaValue = 0 },
                                             completionHandler: { panel.orderOut(nil) })
    }
}

/// Borderless floating panel shared by the toast and the pop-up: on top of everything (all Spaces,
/// full-screen apps), takes clicks without activating Standup or stealing focus from your work.
final class FloatingPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        sharingType = .none  // best effort; ScreenCaptureKit may ignore it (DESIGN §5)
    }

    override var canBecomeKey: Bool { true }

    /// The screen the mouse is on (where you're most likely looking).
    static func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }
}
