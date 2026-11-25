import SwiftUI

/// Content of the pop-up alert (DESIGN §7).
struct PopupView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.stand")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.tint)
            VStack(spacing: 4) {
                Text(AlertCopy.title).font(.title2.weight(.semibold))
                Text(AlertCopy.body).foregroundStyle(.secondary)
            }
            Button("Done", action: onDone)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .frame(minWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// The corner toast card (DESIGN §7). Click anywhere to hide it early.
struct ToastView: View {
    let title: String
    let message: String
    let onClick: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.stand")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onClick)
    }
}

/// Alert wording, shared by toast and pop-up.
enum AlertCopy {
    static let title = "Time to stand up"
    static let body = "Stretch, walk around, grab some water."
}
