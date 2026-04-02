#!/bin/bash
# create-xcode-project.sh
# Creates the Xcode project for MacVital.
# Run this once, then open the .xcodeproj in Xcode.

cat << 'INSTRUCTIONS'
MacVital Xcode Project Setup
============================

To regenerate the Xcode project from spec, follow these steps:

1. Open Xcode → File → New → Project → macOS → App
   - Product Name: MacVital
   - Team: Your team
   - Organization Identifier: com.macvital
   - Interface: SwiftUI
   - Language: Swift
   - Storage: None
   - Uncheck "Include Tests"

2. Delete the auto-generated ContentView.swift and MacVitalApp.swift

3. Add existing files:
   - Drag the MacVital/ folder into the MacVital target
   - Drag the Shared/ folder and add to MacVital target

4. Add Helper target:
   - File → New → Target → macOS → Command Line Tool
   - Product Name: MacVitalHelper
   - Bundle ID: com.macvital.helper
   - Drag MacVitalHelper/ folder into this target
   - Drag Shared/ folder and add to this target too

5. Configure Helper target:
   - Build Settings → Skip Install = Yes
   - Build Phases → Copy Files → add launchd.plist to
     Contents/Library/LaunchDaemons/com.macvital.helper.plist

6. Configure App target:
   - Build Phases → Embed content → add MacVitalHelper
   - In App Info.plist, add:
     SMPrivilegedExecutables → com.macvital.helper → "identifier com.macvital.helper"

7. Frameworks (both targets):
   - IOKit.framework
   - Charts (App target only)
   - PDFKit (App target only)

8. Signing:
   - Both targets: Sign to Run Locally (or your Developer ID)
   - App Sandbox: OFF (app target)
   - Hardened Runtime: ON (both targets)

9. Build and run!

INSTRUCTIONS
