import CoreAudio
import Darwin
import StandupCore

/// Reads CoreAudio process objects in-process (DESIGN §5): which processes have audio input/output running.
/// A property read, not a capture, so no microphone permission is needed. Never spawn a subprocess for this.
protocol MicUsageProbing: Sendable {
    func samples() -> [AudioProcessSample]
}

struct MicUsageProbe: MicUsageProbing {
    func samples() -> [AudioProcessSample] {
        processObjects().map { object in
            AudioProcessSample(pid: readPID(object) ?? -1,
                               bundleID: readString(object, kAudioProcessPropertyBundleID) ?? "",
                               isRunningInput: readUInt32(object, kAudioProcessPropertyIsRunningInput) == 1,
                               isRunningOutput: readUInt32(object, kAudioProcessPropertyIsRunningOutput) == 1)
        }
    }

    private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private func processObjects() -> [AudioObjectID] {
        var addr = address(kAudioHardwarePropertyProcessObjectList)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private func readUInt32(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = address(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr ? value : nil
    }

    private func readPID(_ object: AudioObjectID) -> Int32? {
        var addr = address(kAudioProcessPropertyPID)
        var value: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        return AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr ? value : nil
    }

    private func readString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr,
              let string = value?.takeRetainedValue() else { return nil }
        return string as String
    }
}
