import StandupCore
import SwiftUI

/// AppSettings window (DESIGN §8). Edits a draft and applies each valid change immediately.
struct SettingsView: View {
    let model: AppModel
    private var sounds: any SoundPlaying { model.sounds }

    @State private var draft = AppSettings()

    /// Monday-first display order.
    private let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    private var hoursAreValid: Bool { draft.workEnd > draft.workStart }

    var body: some View {
        Form {
            Section("Schedule") {
                LabeledContent("Remind me every") {
                    HStack(spacing: 6) {
                        TextField("Minutes", value: $draft.intervalMinutes, format: .number)
                            .frame(width: 48)
                            .multilineTextAlignment(.trailing)
                            .labelsHidden()
                            .onSubmit { draft.intervalMinutes = model.settings.intervalMinutes }
                        Stepper("Minutes", value: $draft.intervalMinutes,
                                in: AppModel.minimumInterval...AppSettings.intervalRange.upperBound, step: 5)
                            .labelsHidden()
                        Text("minutes")
                    }
                }

                LabeledContent("Active days") {
                    HStack(spacing: 4) {
                        ForEach(weekdays, id: \.self) { day in
                            Toggle(shortName(day), isOn: dayBinding(day))
                                .toggleStyle(.button)
                        }
                    }
                }

                DatePicker("Start", selection: timeBinding(\.workStart), displayedComponents: .hourAndMinute)
                DatePicker("End", selection: timeBinding(\.workEnd), displayedComponents: .hourAndMinute)
                if !hoursAreValid {
                    Text("End time must be after start time. Not saved yet.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Alerts") {
                Picker("Style", selection: $draft.alertStyle) {
                    Text("Pop-up (click Done to clear)").tag(AlertStyle.popup)
                    Text("Corner toast (hides itself)").tag(AlertStyle.banner)
                }
                .pickerStyle(.radioGroup)

                LabeledContent("Sound") {
                    HStack {
                        Picker("Sound", selection: $draft.soundName) {
                            Text("None").tag(String?.none)
                            Divider()
                            ForEach(sounds.availableSounds, id: \.self) { name in
                                Text(name).tag(Optional(name))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 160)
                        Button("Preview") {
                            if let name = draft.soundName { sounds.play(name) }
                        }
                        .disabled(draft.soundName == nil)
                    }
                }

                LabeledContent("Try it") {
                    Button("Show test alert") { model.showTestAlert() }
                }
            }

            Section {
                Toggle("Detect Microsoft Teams calls", isOn: $draft.detectTeamsCalls)
                Toggle("Remind me after the call ends", isOn: $draft.remindAfterCall)
                    .disabled(!draft.detectTeamsCalls)
            } header: {
                Text("Meetings")
            } footer: {
                Text("During a Teams call nothing pops up, so nothing shows in a screen share. Detection checks which app is using the microphone, and nothing is recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                LabeledContent("Version", value: Self.version)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { draft = model.settings }
        .onChange(of: draft) { _, newValue in
            if newValue.workEnd > newValue.workStart {
                model.apply(newValue)
            }
        }
    }

    // MARK: Helpers

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private func shortName(_ day: Weekday) -> String {
        Calendar.current.shortWeekdaySymbols[day.rawValue - 1]
    }

    private func dayBinding(_ day: Weekday) -> Binding<Bool> {
        Binding(
            get: { draft.activeDays.contains(day) },
            set: { isOn in
                if isOn {
                    draft.activeDays.insert(day)
                } else if draft.activeDays.count > 1 {  // keep at least one active day
                    draft.activeDays.remove(day)
                }
            }
        )
    }

    private func timeBinding(_ keyPath: WritableKeyPath<AppSettings, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: {
                let time = draft[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft[keyPath: keyPath] = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
            }
        )
    }
}
