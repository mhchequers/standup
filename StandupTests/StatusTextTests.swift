import Foundation
import Testing
@testable import StandupCore

struct StatusTextTests {
    let formatter = StatusText(calendar: testCalendar, locale: Locale(identifier: "en_US"))
    let now = date(Nov.mon, 10, 7)

    /// ICU may use a narrow no-break space before AM/PM; normalize for comparison.
    func text(_ status: ReminderEngine.Status) -> String {
        formatter.text(for: status, now: now)
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    @Test func nextBreak() {
        #expect(text(.nextBreak(at: date(Nov.mon, 10, 30))) == "Next break in 23 min")
        #expect(text(.nextBreak(at: date(Nov.mon, 10, 29, 30))) == "Next break in 23 min")  // rounds up
        #expect(text(.nextBreak(at: date(Nov.mon, 10, 7, 40))) == "Next break in less than a minute")
    }

    @Test func meeting() {
        #expect(text(.inMeeting(willRemindAfter: true)) == "In a Teams call — will remind after")
        #expect(text(.inMeeting(willRemindAfter: false)) == "In a Teams call")
    }

    @Test func muted() {
        #expect(text(.muted(until: Mute.indefinite)) == "Muted")
        #expect(text(.muted(until: date(Nov.tue, 0, 0))) == "Muted until tomorrow")
        #expect(text(.muted(until: date(Nov.mon, 15, 30))) == "Muted until 3:30 PM")
        #expect(text(.muted(until: date(Nov.tue, 9, 0))) == "Muted until tomorrow 9:00 AM")
    }

    @Test func outsideHours() {
        let fridayEvening = date(Nov.fri, 18, 0)
        let t = formatter.text(for: .outsideWorkHours(resumesAt: date(30, 9, 0)), now: fridayEvening)
            .replacingOccurrences(of: "\u{202F}", with: " ")
        #expect(t == "Outside work hours — resumes Mon 9:00 AM")
        #expect(text(.outsideWorkHours(resumesAt: nil)) == "No active days set")
    }

    @Test func otherStates() {
        #expect(text(.screenAway) == "Paused — screen locked")
        #expect(text(.popupShowing) == "Break time!")
    }
}
