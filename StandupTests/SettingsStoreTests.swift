import Foundation
import Testing
@testable import StandupCore

struct SettingsStoreTests {
    let suiteName = "dev.standup.tests.\(UUID().uuidString)"

    func withStore(_ body: (SettingsStore, UserDefaults) throws -> Void) rethrows {
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(SettingsStore(defaults: defaults), defaults)
    }

    @Test func emptyStoreGivesDefaults() {
        withStore { store, _ in
            #expect(store.loadSettings() == Settings())
            #expect(store.loadMuteUntil() == nil)
        }
    }

    @Test func settingsRoundTrip() {
        withStore { store, _ in
            var s = Settings()
            s.intervalMinutes = 50
            s.alertStyle = .banner
            store.save(s)
            #expect(store.loadSettings() == s)
        }
    }

    @Test func loadValidates() {
        withStore { store, _ in
            var s = Settings()
            s.intervalMinutes = 1
            store.save(s)
            #expect(store.loadSettings().intervalMinutes == 5)
            #expect(store.loadSettings(minimumInterval: 1).intervalMinutes == 1)
        }
    }

    @Test func corruptDataGivesDefaults() {
        withStore { store, defaults in
            defaults.set(Data("not json".utf8), forKey: SettingsStore.settingsKey)
            #expect(store.loadSettings() == Settings())
        }
    }

    @Test func muteUntilRoundTripAndClear() {
        withStore { store, _ in
            let until = date(Nov.mon, 15, 30)
            store.saveMuteUntil(until)
            #expect(store.loadMuteUntil() == until)
            store.saveMuteUntil(Mute.indefinite)
            #expect(store.loadMuteUntil() == Mute.indefinite)
            store.saveMuteUntil(nil)
            #expect(store.loadMuteUntil() == nil)
        }
    }
}
