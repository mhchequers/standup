import Foundation

/// Persists `AppSettings` and `muteUntil` in UserDefaults (DESIGN §2). Inject a suite for tests.
public struct SettingsStore {
    static let settingsKey = "settings.v1"
    static let muteUntilKey = "muteUntil"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Saved settings (validated), or defaults if nothing is saved or the data is unreadable.
    public func loadSettings(minimumInterval: Int = AppSettings.intervalRange.lowerBound) -> AppSettings {
        guard let data = defaults.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return settings.validated(minimumInterval: minimumInterval)
    }

    public func save(_ settings: AppSettings) {
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
