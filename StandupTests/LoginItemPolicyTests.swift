import Testing
@testable import StandupCore

struct LoginItemPolicyTests {
    @Test(arguments: [
        ("/Applications/Standup.app", true),
        ("/Applications/Utilities/Standup.app", true),
        ("/Users/me/code/standup/build.noindex/Build/Products/Debug/Standup.app", false),
        ("/Users/me/Applications/Standup.app", false),
        ("/Applications/../tmp/Standup.app", false),
    ])
    func installedLocation(path: String, expected: Bool) {
        #expect(LoginItemPolicy.isInstalledLocation(bundlePath: path) == expected)
    }

    @Test func autoRegistersOnlyOnFirstInstalledLaunch() {
        #expect(LoginItemPolicy.shouldAutoRegister(isInstalled: true, alreadyAttempted: false, isRegistered: false))
        #expect(!LoginItemPolicy.shouldAutoRegister(isInstalled: true, alreadyAttempted: true, isRegistered: false))  // user turned it off
        #expect(!LoginItemPolicy.shouldAutoRegister(isInstalled: true, alreadyAttempted: false, isRegistered: true))  // already on
        #expect(!LoginItemPolicy.shouldAutoRegister(isInstalled: false, alreadyAttempted: false, isRegistered: false)) // Debug build
    }
}
