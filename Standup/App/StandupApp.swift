import SwiftUI
import StandupCore

@main
struct StandupApp: App {
    @State private var model: AppModel

    init() {
        LoginItemManager.unregisterAndExitIfRequested()  // `make uninstall`
        SingleInstance.enforce()
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.menuBarSymbol)
                .accessibilityLabel("Standup")
        }

        Window("Standup Settings", id: WindowID.settings) {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        Window("Mute Until", id: WindowID.customMute) {
            CustomMuteView(model: model)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}
