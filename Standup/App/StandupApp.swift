import SwiftUI
import StandupCore

@main
struct StandupApp: App {
    init() {
        SingleInstance.enforce()
    }

    var body: some Scene {
        MenuBarExtra("Standup", systemImage: "figure.stand") {
            Button("Quit Standup") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
