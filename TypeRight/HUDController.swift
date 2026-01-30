//
//  HUDController.swift
//  TypeRight
//
//  Created by Wei GENG on 30.01.26.
//

import AppKit

class HUDController {
    private var hudWindow: NSWindow?
    private var fadeWorkItem: DispatchWorkItem?
    
    func showAlert() {
        DispatchQueue.main.async { [weak self] in
            self?.displayHUD()
        }
    }
    
    private func displayHUD() {
        // Cancel any pending fade
        fadeWorkItem?.cancel()
        
        // Create or reuse window
        let window = hudWindow ?? createHUDWindow()
        hudWindow = window
        
        // Reset alpha and show
        window.alphaValue = 1.0
        window.orderFrontRegardless()
        
        // Schedule fade out
        let workItem = DispatchWorkItem { [weak self] in
            self?.fadeOutHUD()
        }
        fadeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    private func createHUDWindow() -> NSWindow {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let windowSize = CGSize(width: 200, height: 200)
        let windowOrigin = CGPoint(
            x: (screenSize.width - windowSize.width) / 2,
            y: (screenSize.height - windowSize.height) / 2
        )
        
        let window = NSWindow(
            contentRect: NSRect(origin: windowOrigin, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.hasShadow = false
        
        // Create content view with warning symbol
        let contentView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        
        let label = NSTextField(labelWithString: "🚫")
        label.font = NSFont.systemFont(ofSize: 120)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 40, width: windowSize.width, height: 140)
        label.backgroundColor = .clear
        label.isBordered = false
        
        // Semi-transparent background circle
        let backgroundView = NSView(frame: NSRect(x: 25, y: 25, width: 150, height: 150))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        backgroundView.layer?.cornerRadius = 75
        
        contentView.addSubview(backgroundView)
        contentView.addSubview(label)
        
        window.contentView = contentView
        
        return window
    }
    
    private func fadeOutHUD() {
        guard let window = hudWindow else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.hudWindow?.orderOut(nil)
        })
    }
}
