import Foundation

/// The reminder state machine — DESIGN §4 is its spec, and rule numbers below refer to it.
/// Pure value type: feed it events with the current time, perform the effects it returns.
public struct ReminderEngine: Sendable {
    public enum Event: Equatable, Sendable {
        /// Periodic heartbeat (every ~5 s); also used once at launch.
        case tick
        case settingsChanged(AppSettings)
        /// Locked, asleep, displays asleep, or user session inactive.
        case screenAwayChanged(Bool)
        /// Debounced Teams call state (DESIGN §5).
        case meetingChanged(Bool)
        case muted(until: Date)
        case unmuted
        /// The user clicked Done on the pop-up.
        case popupDismissed
    }

    public enum Effect: Equatable, Sendable {
        /// `silent`: post without sound (during a call, or when no sound is chosen).
        case showBanner(silent: Bool)
        /// Show the pop-up; the app loops `settings.soundName` if set (DESIGN §4 rule 10).
        case showPopup
        case dismissPopup
        case stopPopupSound
    }

    public enum Status: Equatable, Sendable {
        case nextBreak(at: Date)
        case popupShowing
        case inMeeting(willRemindAfter: Bool)
        /// `until == Mute.indefinite` means "until unmuted".
        case muted(until: Date)
        /// `resumesAt` is nil when no weekday is active.
        case outsideWorkHours(resumesAt: Date?)
        case screenAway
    }

    public private(set) var settings: AppSettings
    public private(set) var muteUntil: Date?
    public private(set) var screenAway: Bool
    public private(set) var meetingDetected = false
    public private(set) var popupShowing = false
    /// When the next reminder is due; nil while ineligible or while the pop-up is up.
    public private(set) var dueAt: Date?
    public let calendar: Calendar

    private var wasEligible = false
    private var shownMeetingBanner = false
    private var pendingAfterCall = false

    public init(settings: AppSettings, muteUntil: Date? = nil, screenAway: Bool = false, calendar: Calendar = .current) {
        self.settings = settings
        self.muteUntil = muteUntil
        self.screenAway = screenAway
        self.calendar = calendar
    }

    // MARK: Derived state

    public var schedule: Schedule { Schedule(settings: settings, calendar: calendar) }

    /// Meeting state as far as reminders are concerned (off when detection is disabled).
    public var inMeeting: Bool { meetingDetected && settings.detectTeamsCalls }

    public func isMuted(at now: Date) -> Bool { Mute.isMuted(until: muteUntil, now: now) }

    public func isEligible(at now: Date) -> Bool {
        schedule.isInWorkHours(now) && !isMuted(at: now) && !screenAway
    }

    public func status(at now: Date) -> Status {
        if screenAway { return .screenAway }
        if isMuted(at: now), let muteUntil { return .muted(until: muteUntil) }
        if !schedule.isInWorkHours(now) { return .outsideWorkHours(resumesAt: schedule.nextWindowStart(after: now)) }
        if popupShowing { return .popupShowing }
        if inMeeting { return .inMeeting(willRemindAfter: settings.remindAfterCall) }
        if let dueAt { return .nextBreak(at: dueAt) }
        return .nextBreak(at: now.addingTimeInterval(settings.interval))  // not yet reconciled
    }

    // MARK: Events

    public mutating func handle(_ event: Event, at now: Date) -> [Effect] {
        var effects: [Effect] = []

        switch event {
        case .tick:
            break

        case .settingsChanged(let newSettings):
            let old = settings
            settings = newSettings
            if old.detectTeamsCalls && !newSettings.detectTeamsCalls {
                clearMeetingFlags()  // turning detection off drops any deferred reminder
            }
            // Rule 3: a new interval restarts the countdown.
            if newSettings.intervalMinutes != old.intervalMinutes, dueAt != nil {
                dueAt = now.addingTimeInterval(newSettings.interval)
            }

        case .screenAwayChanged(let away):
            screenAway = away
            // Rule 8: walking away dismisses the pop-up with no follow-up.
            if away && popupShowing {
                popupShowing = false
                effects.append(.dismissPopup)
            }

        case .meetingChanged(let detected):
            let wasInMeeting = inMeeting
            meetingDetected = detected
            if inMeeting && !wasInMeeting && popupShowing {
                effects.append(.stopPopupSound)  // Rule 7
            }
            if wasInMeeting && !inMeeting {
                // Rule 6: one normal alert after the call if a reminder was deferred.
                if pendingAfterCall && settings.remindAfterCall && isEligible(at: now) {
                    effects += fireNormalAlert(at: now)
                }
                clearMeetingFlags()
            }

        case .muted(let until):
            muteUntil = until
            // Rule 9
            if isMuted(at: now) && popupShowing {
                popupShowing = false
                effects.append(.dismissPopup)
            }

        case .unmuted:
            muteUntil = nil

        case .popupDismissed:
            guard popupShowing else { break }
            popupShowing = false
            // Rule 5: next countdown starts at Done (only if we could alert now; else rule 1 later).
            if isEligible(at: now) {
                dueAt = now.addingTimeInterval(settings.interval)
            }
        }

        effects += reconcile(at: now)
        return effects
    }

    // MARK: Internals

    /// Applies rules 1, 2 and 4 after every event.
    private mutating func reconcile(at now: Date) -> [Effect] {
        if let muteUntil, now >= muteUntil {
            self.muteUntil = nil  // expired mute clears itself
        }

        let eligible = isEligible(at: now)
        if eligible && !wasEligible {
            // Rule 1 (unless the pop-up is still waiting for Done — rule 11 then rule 5).
            dueAt = popupShowing ? nil : now.addingTimeInterval(settings.interval)
        } else if !eligible && wasEligible {
            dueAt = nil  // Rule 2: discard, don't pause
        }
        wasEligible = eligible

        guard eligible, let dueAt, now >= dueAt else { return [] }

        // Rule 4
        if inMeeting {
            var effects: [Effect] = []
            if !shownMeetingBanner {
                shownMeetingBanner = true
                effects.append(.showBanner(silent: true))
            }
            pendingAfterCall = true
            self.dueAt = now.addingTimeInterval(settings.interval)
            return effects
        }
        return fireNormalAlert(at: now)
    }

    private mutating func fireNormalAlert(at now: Date) -> [Effect] {
        guard !popupShowing else { return [] }
        switch settings.alertStyle {
        case .banner:
            dueAt = now.addingTimeInterval(settings.interval)
            return [.showBanner(silent: settings.soundName == nil)]
        case .popup:
            popupShowing = true
            dueAt = nil
            return [.showPopup]
        }
    }

    private mutating func clearMeetingFlags() {
        pendingAfterCall = false
        shownMeetingBanner = false
    }
}

/// Pop-up sound timing (DESIGN §4 rule 10). Applied by the app's PopupAlertController.
public enum PopupSoundTiming {
    public static let repeatInterval: TimeInterval = 4
    public static let maxDuration: TimeInterval = 120
}
