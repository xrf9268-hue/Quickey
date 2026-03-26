#!/usr/bin/swift
// Standalone CGEvent sender for e2e tests.
// Usage:
//   cgevent-helper down <keyCode>            — keyDown
//   cgevent-helper up   <keyCode>            — keyUp
//   cgevent-helper combo <holdKeyCode> <tapKeyCode>
//       — holdKey down → tapKey down → tapKey up → holdKey up
//
// Events are posted at .cghidEventTap so they flow through
// session-level event taps (matching real hardware input).
//
// References:
//   - Apple CGEvent.h: CGEventCreateKeyboardEvent, CGEventPost
//   - Apple CGEventTypes.h: kCGHIDEventTap
//   - Karabiner-Elements appendix/cg_post_event: uses kCGHIDEventTap
//     with kCGEventSourceStateHIDSystemState, 10ms modifier→key delay
//   - Hammerspoon eventtap: uses kCGHIDEventTap for keyStrokes

import Foundation
import ApplicationServices

// Use HID system state source (same as Karabiner-Elements / KeyboardSimulator).
// This ties events to the HID subsystem rather than creating an anonymous source,
// ensuring they are indistinguishable from real hardware input.
let source = CGEventSource(stateID: .hidSystemState)

func postKey(_ keyCode: UInt16, keyDown: Bool) {
    guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: keyDown) else {
        fputs("Failed to create CGEvent for keyCode=\(keyCode) keyDown=\(keyDown)\n", stderr)
        exit(1)
    }
    // Post at HID tap so the event flows through session-level event taps
    // (Apple docs: "the event passes through any such taps").
    event.post(tap: .cghidEventTap)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("Usage: cgevent-helper <down|up|combo> <keyCode> [tapKeyCode]\n", stderr)
    exit(1)
}

let action = args[1]
guard let keyCode = UInt16(args[2]) else {
    fputs("Invalid keyCode: \(args[2])\n", stderr)
    exit(1)
}

switch action {
case "down":
    postKey(keyCode, keyDown: true)

case "up":
    postKey(keyCode, keyDown: false)

case "combo":
    // combo <holdKeyCode> <tapKeyCode>
    // Simulates: hold key down → tap key down → tap key up → hold key up
    // Timing follows Karabiner-Elements pattern: 10ms between modifier and key.
    guard args.count >= 4, let tapCode = UInt16(args[3]) else {
        fputs("combo requires two keyCodes\n", stderr)
        exit(1)
    }
    postKey(keyCode, keyDown: true)
    usleep(10_000)  // 10ms hold→tap (Karabiner uses 10ms for modifier→key)
    postKey(tapCode, keyDown: true)
    usleep(1_000)   // 1ms tap down→up (Karabiner uses 1ms for key down→up)
    postKey(tapCode, keyDown: false)
    usleep(10_000)  // 10ms tap→release
    postKey(keyCode, keyDown: false)

default:
    fputs("Unknown action: \(action). Use down, up, or combo.\n", stderr)
    exit(1)
}
