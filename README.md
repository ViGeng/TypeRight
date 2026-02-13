# TypeRight (BackspaceMonitor)

A native macOS Menu Bar app to improve typing efficiency by tracking your "Backspace Ratio" and providing feedback when excessive backspacing occurs.

<img alt="image" width="30%" src="https://github.com/user-attachments/assets/250b1d3a-e157-46fd-a5bf-a5344cbe952c" />


## Features

- **Menu Bar Only**: Lives exclusively in the status bar—no Dock icon
- **Real-time Backspace Ratio**: Displays `⌫ X.X%` with color coding:
  - 🟢 Green: < 5% (excellent)
  - 🟠 Orange: 5-10% (moderate)
  - 🔴 Red: > 10% (high)
- **Interactive Charts**: visualized backspace trends with smoothed lines and data interpolation.
- **Customizable Alerts**: Toggle sound and HUD overlays in the settings.
- **Burst Detection**: Detects "rage deleting" (5+ backspaces in 10 seconds)
- **Alert Feedback**: Visual HUD, haptic feedback, and sound when triggered
- **Privacy First**: No keylogging—only counts keystrokes

## Requirements

- macOS 13.0+
- Accessibility Permissions (required for global keyboard monitoring)

## Installation

### Homebrew (Recommended)

```bash
brew tap ViGeng/tap
brew install --cask typeright
```

After installation, remove the quarantine attribute (required for unsigned apps):

```bash
xattr -cr /Applications/TypeRight.app
```

### Build from Source

## Setup in Xcode

### 1. Disable App Sandbox
The app requires `CGEvent.tapCreate` for global keyboard monitoring, which is blocked by the sandbox.

1. Select your project in Xcode
2. Go to **Signing & Capabilities**
3. Remove **App Sandbox** capability (click the `x` next to it)

Alternatively, in your `.entitlements` file, set:
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

### 2. Remove Core Data (if present)
This app doesn't use Core Data. Remove the `.xcdatamodeld` file if it exists.

### 3. Build & Run
1. Build the project (`⌘B`)
2. Run (`⌘R`)
3. Grant Accessibility permissions when prompted

### 4. Accessibility Permissions (Xcode Debug Builds)

When running from Xcode, the app is built to the DerivedData folder, **not** `/Applications`. To grant Accessibility permissions:

1. Open **System Settings > Privacy & Security > Accessibility**
2. Click the `+` button
3. Press `⌘⇧G` to open "Go to Folder"
4. Paste this path:
   ```
   ~/Library/Developer/Xcode/DerivedData
   ```
5. Find the folder starting with `TypeRight-` (e.g., `TypeRight-bsozgjpagmboizbgwvyjuifpeizs`)
6. Navigate to `Build/Products/Debug/TypeRight.app`
7. Select it and click **Open**

> **Tip**: If you clean the build folder (`⌘⇧K`), you'll need to re-add the app after rebuilding.

## Usage

- Click the menu bar item to see stats
- **Reset Stats**: Clears all counters
- **Quit**: Exits the app

## Architecture

| File | Purpose |
|------|---------|
| `TypeRightApp.swift` | App entry point and AppDelegate |
| `KeyboardMonitor.swift` | Global keyboard event listener and burst detection |
| `HUDController.swift` | Floating click-through alert window |
