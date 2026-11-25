import StandupCore
import SwiftUI

/// "Mute until…" picker (DESIGN §8).
struct CustomMuteView: View {
    let model: AppModel
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var until = CustomMuteView.defaultUntil()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mute reminders until").font(.headline)
            DatePicker("Until", selection: $until, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
            HStack {
                Spacer()
                Button("Cancel") { dismissWindow(id: WindowID.customMute) }
                    .keyboardShortcut(.cancelAction)
                Button("Mute") {
                    model.mute(.until(until))
                    dismissWindow(id: WindowID.customMute)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(until <= Date())
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear { until = Self.defaultUntil() }
    }

    /// Now + 90 minutes, rounded up to the next 5 minutes.
    static func defaultUntil(now: Date = Date()) -> Date {
        let target = now.addingTimeInterval(90 * 60)
        let fiveMinutes: TimeInterval = 300
        return Date(timeIntervalSinceReferenceDate: (target.timeIntervalSinceReferenceDate / fiveMinutes).rounded(.up) * fiveMinutes)
    }
}
