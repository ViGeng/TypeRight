---
agent: agent
---

Role: You are an expert macOS Systems Developer proficient in Swift, AppKit, and CoreGraphics.

Project Goal: Create a native macOS Menu Bar application called "BackspaceMonitor". Purpose: To improve typing efficiency by tracking the user's "Backspace Ratio" and providing immediate, intrusive (but safe) feedback when "rage deleting" or excessive backspacing occurs.

Architecture & Stack:

Language: Swift 5+

UI Framework: AppKit (preferred for lightweight global Menu Bar apps) or SwiftUI.

Concurrency: Use DispatchQueue or Swift Concurrency for background event handling.

Functional Requirements

1. The "Stealth" Mode (Menu Bar UI)

Appearance: No Dock icon. The app lives exclusively in the Status Bar.

Display: Show the real-time Backspace Ratio as a percentage (e.g., "3.5%").

Formula: Ratio = (Total Backspace Events / Total KeyDown Events) * 100.

Dynamic Coloring: Change the text color of the status bar item based on efficiency:

Green: Ratio < 5%

Orange: Ratio between 5% and 10%

Red: Ratio > 10%

Menu Items: When clicked, show:

Current Stats (Total Keystrokes, Total Backspaces).

"Reset Stats" button.

"Quit" button.

2. The Global Event Listener

Use CGEvent.tapCreate to monitor global keyboard input (.keyDown).

Permission Check: On app launch, check AXIsProcessTrusted(). If false, show a dialog prompting the user to grant Accessibility Permissions in System Settings, then terminate.

Privacy: Do NOT log or save what is typed. Only increment counters (Integer +1).

3. The "Burst" Detection (Punishment Logic)

Implement a Sliding Window algorithm.

Maintain a history of timestamps for the last N backspaces.

Logic: If the user hits Backspace more than 5 times within a 10-second window, trigger "Alert Mode."

While in Alert Mode, every subsequent backspace triggers the Feedback System immediately.

4. The Feedback System (HUD & Haptics) When Alert Mode is triggered:

Visual (Ghost HUD):

Flash a large, semi-transparent symbol (⛔️ or 🚫) in the center of the screen.

CRITICAL: The window must have ignoresMouseEvents = true (click-through), styleMask = [.borderless, .nonactivatingPanel], and level = .floating. It must NOT steal focus from the active work window.

Animation: Fade in instantly, fade out over 0.5 seconds.

Haptic: Trigger the trackpad using NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now).

Audio: Play a system beep or subtle sound.

Code Output Requirements

Provide the full, compilable code split into logical files if necessary, or a single comprehensive main.swift / AppDelegate.swift structure. Ensure you explicitly handle the AppSandbox limitations by noting where settings need to be changed in Xcode (e.g., Signing & Capabilities).