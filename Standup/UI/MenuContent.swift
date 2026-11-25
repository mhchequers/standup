import AppKit
import StandupCore
import SwiftUI

/// The MenuBarExtra menu (PLAN M4).
struct MenuContent: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.statusLine)

        Divider()

        Menu("Mute") {
            Button("For 30 minutes") { model.mute(.minutes(30)) }
            Button("For 1 hour") { model.mute(.minutes(60)) }
            Button("For 2 hours") { model.mute(.minutes(120)) }
            Button("Until tomorrow") { model.mute(.untilTomorrow) }
            Button("Until…") { openWindow.bringToFront(id: WindowID.customMute) }
            Divider()
            Button("Until I unmute") { model.mute(.indefinitely) }
        }
        if model.isMuted {
            Button("Unmute") { model.unmute() }
        }

        Divider()

        Button("Settings…") { openWindow.bringToFront(id: WindowID.settings) }
            .keyboardShortcut(",")

        Divider()

        Button("Quit Standup") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
