import Foundation
import Testing
@testable import StandupCore

struct SettingsTests {
    @Test func defaultsMatchDesign() {
        let s = Settings()
        #expect(s.intervalMinutes == 30)
        #expect(s.activeDays == [.monday, .tuesday, .wednesday, .thursday, .friday])
        #expect(s.workStart == TimeOfDay(hour: 9) && s.workEnd == TimeOfDay(hour: 17))
        #expect(s.alertStyle == .popup)
        #expect(s.soundName == "Glass")
        #expect(s.detectTeamsCalls && s.remindAfterCall)
    }

    @Test(arguments: [(0, 5), (4, 5), (5, 5), (45, 45), (240, 240), (999, 240)])
    func intervalIsClamped(input: Int, expected: Int) {
        var s = Settings()
        s.intervalMinutes = input
        #expect(s.validated().intervalMinutes == expected)
    }

    @Test func debugBuildsMayUseOneMinute() {
        var s = Settings()
        s.intervalMinutes = 1
        #expect(s.validated(minimumInterval: 1).intervalMinutes == 1)
    }

    @Test func emptyDaysFallBackToWorkweek() {
        var s = Settings()
        s.activeDays = []
        #expect(s.validated().activeDays == Weekday.workweek)
    }

    @Test(arguments: [
        (TimeOfDay(hour: 17), TimeOfDay(hour: 9)),   // end before start
        (TimeOfDay(hour: 9), TimeOfDay(hour: 9)),    // empty window
        (TimeOfDay(hour: 25), TimeOfDay(hour: 26)),  // invalid
    ])
    func invalidHoursFallBackToDefaults(start: TimeOfDay, end: TimeOfDay) {
        var s = Settings()
        s.workStart = start
        s.workEnd = end
        let v = s.validated()
        #expect(v.workStart == TimeOfDay(hour: 9) && v.workEnd == TimeOfDay(hour: 17))
    }

    @Test func blankSoundBecomesNone() {
        var s = Settings()
        s.soundName = "  "
        #expect(s.validated().soundName == nil)
    }

    @Test func roundTripsThroughJSON() throws {
        var s = Settings()
        s.intervalMinutes = 45
        s.activeDays = [.monday, .saturday]
        s.workStart = TimeOfDay(hour: 8, minute: 30)
        s.workEnd = TimeOfDay(hour: 16, minute: 15)
        s.alertStyle = .banner
        s.soundName = nil
        s.detectTeamsCalls = false
        s.remindAfterCall = false
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        #expect(decoded == s)
    }

    @Test func missingKeysDecodeToDefaults() throws {
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(#"{"intervalMinutes": 50}"#.utf8))
        var expected = Settings()
        expected.intervalMinutes = 50
        #expect(decoded == expected)
    }

    @Test func explicitNullSoundStaysNone() throws {
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(#"{"soundName": null}"#.utf8))
        #expect(decoded.soundName == nil)
    }
}
