//
//  TypeRightApp.swift
//  TypeRight
//
//  Created by Wei GENG on 30.01.26.
//

import SwiftUI
import AppKit
import ServiceManagement

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
    private var soundEnabledItem: NSMenuItem!
    private var hudEnabledItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    
    // MARK: - User Settings
    
    private var isSoundEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "isSoundEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "isSoundEnabled") }
    }
    
    private var isHUDEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "isHUDEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "isHUDEnabled") }
    }
    
    private var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }
    
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
        
        // Save current hour's data periodically (every 5 minutes)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.keyboardMonitor.saveCurrentHour()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Save current hour's data before quitting
        keyboardMonitor.saveCurrentHour()
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
        
        let statsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statsItem.tag = 100
        menu.addItem(statsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add chart view as menu item
        let chartMenuItem = NSMenuItem()
        let chartHostingView = NSHostingView(rootView: ChartMenuView())
        chartHostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 200)
        chartMenuItem.view = chartHostingView
        menu.addItem(chartMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        // Settings Section
        menu.addItem(NSMenuItem(title: "Settings", action: nil, keyEquivalent: ""))
        
        // Sound Toggle
        soundEnabledItem = NSMenuItem(title: "Enable Sound", action: #selector(toggleSound), keyEquivalent: "")
        soundEnabledItem.state = isSoundEnabled ? .on : .off
        menu.addItem(soundEnabledItem)
        
        // HUD Toggle
        hudEnabledItem = NSMenuItem(title: "Enable HUD", action: #selector(toggleHUD), keyEquivalent: "")
        hudEnabledItem.state = isHUDEnabled ? .on : .off
        menu.addItem(hudEnabledItem)
                
        // Launch at Login toggle
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Reset Stats", action: #selector(resetStats), keyEquivalent: "r"))
        
        menu.addItem(NSMenuItem.separator())
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        menu.addItem(NSMenuItem(title: "Version \(version)", action: nil, keyEquivalent: ""))
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
        if isHUDEnabled {
            hudController.showAlert()
        }
        
        if isSoundEnabled {
            playHaptic() // Keep haptic feedback even if sound is off? Assuming "Strong Sound" refers to beep.
            playSound()
        } else {
             playHaptic()
        }
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
    
    @objc private func toggleSound() {
        isSoundEnabled.toggle()
        soundEnabledItem.state = isSoundEnabled ? .on : .off
    }
    
    @objc private func toggleHUD() {
        isHUDEnabled.toggle()
        hudEnabledItem.state = isHUDEnabled ? .on : .off
    }
    
    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
        launchAtLoginItem.state = launchAtLogin ? .on : .off
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
