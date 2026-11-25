import Foundation

/// Persists `Settings` and `muteUntil` in UserDefaults (DESIGN §2). Inject a suite for tests.
public struct SettingsStore {
    static let settingsKey = "settings.v1"
    static let muteUntilKey = "muteUntil"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Saved settings (validated), or defaults if nothing is saved or the data is unreadable.
    public func loadSettings(minimumInterval: Int = Settings.intervalRange.lowerBound) -> Settings {
        guard let data = defaults.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return settings.validated(minimumInterval: minimumInterval)
    }

    public func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.settingsKey)
    }

    public func loadMuteUntil() -> Date? {
        defaults.object(forKey: Self.muteUntilKey) as? Date
    }

    public func saveMuteUntil(_ date: Date?) {
        if let date {
            defaults.set(date, forKey: Self.muteUntilKey)
        } else {
            defaults.removeObject(forKey: Self.muteUntilKey)
        }
    }
}
