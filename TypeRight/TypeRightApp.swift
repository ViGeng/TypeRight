//
//  TypeRightApp.swift
//  TypeRight
//
//  Created by Wei GENG on 30.01.26.
//

import SwiftUI
import AppKit

@main
struct TypeRightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var keyboardMonitor: KeyboardMonitor!
    private var hudController: HUDController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)
        
        // Check accessibility permissions
        guard checkAccessibilityPermissions() else {
            showAccessibilityAlert()
            NSApp.terminate(nil)
            return
        }
        
        // Initialize components
        hudController = HUDController()
        keyboardMonitor = KeyboardMonitor { [weak self] in
            self?.onBurstDetected()
        }
        
        setupStatusItem()
        keyboardMonitor.start()
        
        // Update status bar periodically
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatusItem()
        }
    }
    
    private func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "TypeRight needs Accessibility permissions to monitor keyboard input.\n\nPlease grant access in System Settings > Privacy & Security > Accessibility, then relaunch the app."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItem()
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Stats", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let statsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statsItem.tag = 100
        menu.addItem(statsItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Reset Stats", action: #selector(resetStats), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        // Update stats display when menu opens
        menu.delegate = self
    }
    
    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        
        let ratio = keyboardMonitor?.backspaceRatio ?? 0
        let ratioText = String(format: "⌫ %.1f%%", ratio)
        
        let color: NSColor
        switch ratio {
        case ..<5:
            color = .systemGreen
        case 5..<10:
            color = .systemOrange
        default:
            color = .systemRed
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        ]
        button.attributedTitle = NSAttributedString(string: ratioText, attributes: attributes)
    }
    
    private func onBurstDetected() {
        hudController.showAlert()
        playHaptic()
        playSound()
    }
    
    private func playHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
    
    private func playSound() {
        NSSound.beep()
    }
    
    @objc private func resetStats() {
        keyboardMonitor.reset()
        updateStatusItem()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let statsItem = menu.item(withTag: 100) {
            let total = keyboardMonitor.totalKeystrokes
            let backspaces = keyboardMonitor.totalBackspaces
            statsItem.title = "Keystrokes: \(total)  |  Backspaces: \(backspaces)"
        }
    }
}
