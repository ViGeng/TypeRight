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
    
    // Hourly tracking
    private var currentHourKeystrokes: Int = 0
    private var currentHourBackspaces: Int = 0
    private var currentHourStart: Date = Date()
    private let historyManager = HistoryDataManager.shared
    
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
        currentHourKeystrokes = 0
        currentHourBackspaces = 0
        currentHourStart = Date()
        backspaceTimestamps.removeAll()
        isInAlertMode = false
        alertModeExitTime = nil
        // Clear all historical data from SQLite
        historyManager.resetAll()
    }
    
    private func handleKeyEvent(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        DispatchQueue.main.async { [weak self] in
            self?.processKey(keyCode: keyCode)
        }
    }
    
    private func processKey(keyCode: Int64) {
        // Check for hour boundary before counting
        checkHourBoundary()
        
        totalKeystrokes += 1
        currentHourKeystrokes += 1
        
        // Backspace key code is 51
        let isBackspace = keyCode == 51
        
        if isBackspace {
            totalBackspaces += 1
            currentHourBackspaces += 1
            checkBurst()
        } else {
            // Non-backspace key - check if we should exit alert mode
            exitAlertModeIfNeeded()
        }
    }
    
    /// Check if we've crossed into a new hour and save the previous hour's data
    private func checkHourBoundary() {
        let now = Date()
        let currentStartOfHour = historyManager.startOfHour(for: now)
        let previousStartOfHour = historyManager.startOfHour(for: currentHourStart)
        
        // If we've moved to a new hour
        if currentStartOfHour != previousStartOfHour {
            // Save the previous hour's data if there was any activity
            if currentHourKeystrokes > 0 {
                historyManager.recordHour(
                    hour: previousStartOfHour,
                    keystrokes: currentHourKeystrokes,
                    backspaces: currentHourBackspaces
                )
            }
            
            // Reset counters for the new hour
            currentHourKeystrokes = 0
            currentHourBackspaces = 0
            currentHourStart = now
        }
    }
    
    /// Force save current hour's data (called periodically and on shutdown)
    func saveCurrentHour() {
        if currentHourKeystrokes > 0 {
            let hourStart = historyManager.startOfHour(for: currentHourStart)
            historyManager.recordHour(
                hour: hourStart,
                keystrokes: currentHourKeystrokes,
                backspaces: currentHourBackspaces
            )
            // Reset after saving to avoid double-counting
            currentHourKeystrokes = 0
            currentHourBackspaces = 0
            currentHourStart = Date()
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
