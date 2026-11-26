import Foundation

/// When Standup may register itself as a login item (DESIGN §9).
public enum LoginItemPolicy {
    /// Only the installed copy registers: Debug/Release build products in the repo would add a
    /// duplicate login item per build path.
    public static func isInstalledLocation(bundlePath: String) -> Bool {
        let path = (bundlePath as NSString).standardizingPath
        return path.hasPrefix("/Applications/") && path.hasSuffix(".app")
    }

    /// Register automatically once, on the first launch from /Applications (default: on).
    /// After that, the user's choice in Settings wins — even if they turned it off.
    public static func shouldAutoRegister(isInstalled: Bool, alreadyAttempted: Bool, isRegistered: Bool) -> Bool {
        isInstalled && !alreadyAttempted && !isRegistered
    }

    /// Launch argument used by `make uninstall` to remove the login item before deleting the app.
    public static let unregisterArgument = "--unregister-login-item"
}
