import Foundation

/// Engine + persistence + derived UI state, independent of AppKit (DESIGN §3).
/// `AppModel` (app target) is a thin @Observable wrapper around this, so the wiring is unit tested.
public struct ReminderController {
    public enum MenuIcon: Equatable, Sendable {
        case normal, muted, inCall
    }

    public private(set) var engine: ReminderEngine
    public private(set) var statusLine = ""
    public private(set) var menuIcon: MenuIcon = .normal

    public let minimumInterval: Int
    private let store: SettingsStore
    private let clock: any Clock
    private let statusText: StatusText
    private var savedMuteUntil: Date?

    /// Loads saved settings and mute state, and reconciles once (so a countdown starts at launch).
    public init(store: SettingsStore,
                clock: any Clock = SystemClock(),
                minimumInterval: Int = AppSettings.intervalRange.lowerBound,
                calendar: Calendar = .current,
                statusText: StatusText = StatusText()) {
        self.store = store
        self.clock = clock
        self.minimumInterval = minimumInterval
        self.statusText = statusText
        let muteUntil = store.loadMuteUntil()
        savedMuteUntil = muteUntil
        engine = ReminderEngine(settings: store.loadSettings(minimumInterval: minimumInterval),
                                muteUntil: muteUntil, calendar: calendar)
        _ = send(.tick)
    }

    public var settings: AppSettings { engine.settings }
    public var isMuted: Bool { engine.isMuted(at: clock.now) }

    /// Validates, saves, and applies new settings. Returns effects to perform.
    public mutating func apply(_ newSettings: AppSettings) -> [ReminderEngine.Effect] {
        let validated = newSettings.validated(minimumInterval: minimumInterval)
        guard validated != engine.settings else { return [] }
        store.save(validated)
        return send(.settingsChanged(validated))
    }

    public mutating func mute(_ preset: MutePreset) -> [ReminderEngine.Effect] {
        guard let until = preset.muteUntil(now: clock.now, calendar: engine.calendar) else { return [] }
        return send(.muted(until: until))
    }

    public mutating func unmute() -> [ReminderEngine.Effect] {
        send(.unmuted)
    }

    /// Feeds an event at the clock's current time; persists mute changes; refreshes status and icon.
    public mutating func send(_ event: ReminderEngine.Event) -> [ReminderEngine.Effect] {
        let now = clock.now
        let effects = engine.handle(event, at: now)
        if engine.muteUntil != savedMuteUntil {
            store.saveMuteUntil(engine.muteUntil)  // includes clearing an expired mute
            savedMuteUntil = engine.muteUntil
        }
        let status = engine.status(at: now)
        statusLine = statusText.text(for: status, now: now)
        menuIcon = switch status {
        case .muted: .muted
        case .inMeeting: .inCall
        default: .normal
        }
        return effects
    }
}
