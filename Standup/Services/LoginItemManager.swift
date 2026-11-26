import Foundation
import ServiceManagement
import StandupCore
import os

/// Launch at login via SMAppService.mainApp (DESIGN §9).
@MainActor
protocol LoginItemManaging: AnyObject {
    var isInstalledLocation: Bool { get }
    var status: SMAppService.Status { get }
    func autoRegisterIfNeeded()
    func setEnabled(_ enabled: Bool)
    func openSystemSettings()
}

@MainActor
final class LoginItemManager: LoginItemManaging {
    static let attemptedKey = "loginItem.autoRegisterAttempted"

    private let defaults: UserDefaults
    private let log = Logger(subsystem: "dev.standup.Standup", category: "login")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isInstalledLocation: Bool { LoginItemPolicy.isInstalledLocation(bundlePath: Bundle.main.bundlePath) }
    var status: SMAppService.Status { SMAppService.mainApp.status }

    func autoRegisterIfNeeded() {
        let attempted = defaults.bool(forKey: Self.attemptedKey)
        let registered = status == .enabled
        if isInstalledLocation, registered, !attempted {
            defaults.set(true, forKey: Self.attemptedKey)  // e.g. registered earlier (M2): adopt it
            return
        }
        guard LoginItemPolicy.shouldAutoRegister(isInstalled: isInstalledLocation, alreadyAttempted: attempted,
                                                 isRegistered: registered) else { return }
        defaults.set(true, forKey: Self.attemptedKey)
        setEnabled(true)
    }

    func setEnabled(_ enabled: Bool) {
        guard isInstalledLocation else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("login item \(enabled ? "register" : "unregister", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
        log.info("login item status: \(String(describing: self.status.rawValue), privacy: .public)")
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// For `make uninstall`: remove the login item and exit without starting the app.
    static func unregisterAndExitIfRequested() {
        guard CommandLine.arguments.contains(LoginItemPolicy.unregisterArgument) else { return }
        do {
            try SMAppService.mainApp.unregister()
            print("Standup: login item removed")
        } catch {
            print("Standup: no login item to remove (\(error.localizedDescription))")
        }
        exit(0)
    }
}
