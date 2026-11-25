import AppKit

/// Plays macOS system sounds (/System/Library/Sounds) by name (DESIGN §7).
@MainActor
protocol SoundPlaying: AnyObject {
    var availableSounds: [String] { get }
    func play(_ name: String)
    func stop()
}

@MainActor
final class SoundPlayer: SoundPlaying {
    static let shared = SoundPlayer()

    let availableSounds: [String] = {
        let directory = URL(fileURLWithPath: "/System/Library/Sounds")
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { ["aiff", "aif", "caf", "wav"].contains($0.pathExtension.lowercased()) }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }()

    private var current: NSSound?

    func play(_ name: String) {
        current?.stop()
        current = NSSound(named: NSSound.Name(name))
        current?.play()
    }

    func stop() {
        current?.stop()
        current = nil
    }
}
