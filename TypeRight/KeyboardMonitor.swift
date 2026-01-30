//
//  KeyboardMonitor.swift
//  TypeRight
//
//  Created by Wei GENG on 30.01.26.
//

import Foundation
import AppKit
import CoreGraphics

class KeyboardMonitor {
    private(set) var totalKeystrokes: Int = 0
    private(set) var totalBackspaces: Int = 0
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Burst detection: sliding window of backspace timestamps
    private var backspaceTimestamps: [Date] = []
    private let burstThreshold = 5
    private let burstWindowSeconds: TimeInterval = 10
    private var isInAlertMode = false
    private var alertModeExitTime: Date?
    
    private let onBurstDetected: () -> Void
    
    var backspaceRatio: Double {
        guard totalKeystrokes > 0 else { return 0 }
        return (Double(totalBackspaces) / Double(totalKeystrokes)) * 100
    }
    
    init(onBurstDetected: @escaping () -> Void) {
        self.onBurstDetected = onBurstDetected
    }
    
    func start() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        // Create callback context
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleKeyEvent(event)
                return Unmanaged.passRetained(event)
            },
            userInfo: context
        ) else {
            print("Failed to create event tap. Check accessibility permissions.")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
    
    func reset() {
        totalKeystrokes = 0
        totalBackspaces = 0
        backspaceTimestamps.removeAll()
        isInAlertMode = false
        alertModeExitTime = nil
    }
    
    private func handleKeyEvent(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        DispatchQueue.main.async { [weak self] in
            self?.processKey(keyCode: keyCode)
        }
    }
    
    private func processKey(keyCode: Int64) {
        totalKeystrokes += 1
        
        // Backspace key code is 51
        let isBackspace = keyCode == 51
        
        if isBackspace {
            totalBackspaces += 1
            checkBurst()
        } else {
            // Non-backspace key - check if we should exit alert mode
            exitAlertModeIfNeeded()
        }
    }
    
    private func checkBurst() {
        let now = Date()
        backspaceTimestamps.append(now)
        
        // Remove timestamps outside the window
        let windowStart = now.addingTimeInterval(-burstWindowSeconds)
        backspaceTimestamps.removeAll { $0 < windowStart }
        
        // Check if burst threshold exceeded
        if backspaceTimestamps.count >= burstThreshold {
            enterAlertMode()
        }
        
        // If in alert mode, trigger feedback on every backspace
        if isInAlertMode {
            onBurstDetected()
        }
    }
    
    private func enterAlertMode() {
        isInAlertMode = true
        // Alert mode lasts for the window duration after last backspace
        alertModeExitTime = Date().addingTimeInterval(burstWindowSeconds)
    }
    
    private func exitAlertModeIfNeeded() {
        guard isInAlertMode, let exitTime = alertModeExitTime else { return }
        
        if Date() > exitTime {
            isInAlertMode = false
            alertModeExitTime = nil
            backspaceTimestamps.removeAll()
        }
    }
    
    deinit {
        stop()
    }
}
