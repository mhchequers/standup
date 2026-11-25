import AppKit
import SwiftUI

enum WindowID {
    static let settings = "settings"
    static let customMute = "custom-mute"
}

extension OpenWindowAction {
    /// Opens (or brings forward) a window without giving Standup a Dock icon (FINDINGS D4).
    @MainActor
    func bringToFront(id: String) {
        callAsFunction(id: id)
        NSApp.activate()
    }
}
