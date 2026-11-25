#!/usr/bin/env swift
// mic-probe: shows which processes are using the microphone right now (CoreAudio process objects, macOS 14.2+).
// It's a property read, not a capture, so it needs no microphone permission.
//
//   swift scripts/mic-probe.swift          # watch, printing whenever the state changes (Ctrl-C to stop)
//   swift scripts/mic-probe.swift --once   # print once and exit
//
// While watching, type a note and press Enter (e.g. "muted") to timestamp what you just did.
// Shows: every process using the mic (INPUT), every process playing audio (OUTPUT), and every
// Microsoft process registered with CoreAudio even if idle (the set changes when calls start/end).
//
// Diagnostic only, for DESIGN §5 / PLAN M2. The app does the same reads in-process.

import CoreAudio
import Darwin
import Foundation

func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector,
                               mScope: kAudioObjectPropertyScopeGlobal,
                               mElement: kAudioObjectPropertyElementMain)
}

func readUInt32(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
    var addr = address(selector)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr ? value : nil
}

func readPID(_ object: AudioObjectID) -> pid_t? {
    var addr = address(kAudioProcessPropertyPID)
    var value: pid_t = 0
    var size = UInt32(MemoryLayout<pid_t>.size)
    return AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr ? value : nil
}

func readString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var addr = address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr,
          let string = value?.takeRetainedValue() else { return nil }
    return string as String
}

func readObjectList(_ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
    var addr = address(selector)
    var size: UInt32 = 0
    let system = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids
}

func processName(_ pid: pid_t) -> String {
    var buffer = [CChar](repeating: 0, count: 256)
    return proc_name(pid, &buffer, UInt32(buffer.count)) > 0 ? String(cString: buffer) : "?"
}

func snapshot() -> [String] {
    var lines: [String] = []

    var deviceID = AudioObjectID(0)
    var addr = address(kAudioHardwarePropertyDefaultInputDevice)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID) == noErr {
        let name = readString(deviceID, kAudioObjectPropertyName) ?? "?"
        let running = readUInt32(deviceID, kAudioDevicePropertyDeviceIsRunningSomewhere).map { $0 != 0 }
        lines.append("default input: \"\(name)\" runningSomewhere=\(running.map(String.init) ?? "read failed")")
    }

    let processes = readObjectList(kAudioHardwarePropertyProcessObjectList)
    var active: [String] = []
    var microsoftIdle: [String] = []
    var micUsers = 0
    for object in processes {
        let pid = readPID(object) ?? -1
        let bundleID = readString(object, kAudioProcessPropertyBundleID) ?? ""
        let input = readUInt32(object, kAudioProcessPropertyIsRunningInput) == 1
        let output = readUInt32(object, kAudioProcessPropertyIsRunningOutput) == 1
        let label = "pid=\(pid)  bundle=\(bundleID.isEmpty ? "(none)" : bundleID)  name=\(processName(pid))"
        if input { micUsers += 1; active.append("  INPUT   \(label)") }
        if output { active.append("  OUTPUT  \(label)") }
        if !input && !output && bundleID.hasPrefix("com.microsoft.") { microsoftIdle.append("  idle    \(label)") }
    }
    lines.append("processes known to CoreAudio: \(processes.count); using mic: \(micUsers)")
    lines += active.sorted()
    lines += microsoftIdle.sorted()
    return lines
}

let formatter = DateFormatter()
formatter.dateFormat = "HH:mm:ss"
setvbuf(stdout, nil, _IOLBF, 0)

if CommandLine.arguments.contains("--once") {
    snapshot().forEach { print($0) }
    exit(0)
}

print("mic-probe: watching (prints on change, heartbeat every 30 s). Type a note + Enter to mark a step. Ctrl-C to stop.")
let markerThread = Thread {
    while let note = readLine() {
        print("[\(formatter.string(from: Date()))] >>> MARK: \(note)")
    }
}
markerThread.start()
var last: [String] = []
var lastPrint = Date.distantPast
while true {
    let now = snapshot()
    if now != last || Date().timeIntervalSince(lastPrint) >= 30 {
        print("[\(formatter.string(from: Date()))]\(now == last ? " (no change)" : "")")
        if now != last { now.forEach { print($0) } }
        last = now
        lastPrint = Date()
    }
    Thread.sleep(forTimeInterval: 2)
}
