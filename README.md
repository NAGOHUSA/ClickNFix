# ClickNFix

ClickNFix is a macOS 13+ native SwiftUI menu bar app that wraps OptimacOS-style maintenance fixes with a GUI-first workflow.

## Features

- Menu bar popover app (`LSUIElement`) with no dock icon by default
- One-click fixes:
  - Fix Finder
  - Clear Caches
  - Repair Permissions
  - Reset Launch Services
  - Fix App Crashes
  - Clear DNS Cache
  - Fix iCloud Sync
- Batch mode with checkbox selection and optional local snapshot creation
- Privileged execution prompts via Authorization Services
- Embedded shell scripts (`ClickNFix/Resources/OptimacOS/*.sh`)
- Real-time terminal stream in-app with ANSI color parsing
- Backup + Undo Last Fix workflow
- Logs written to `~/Library/Logs/OptimacOSGUI` (30-day cleanup)
- Keyboard shortcut: `⌘⇧O` to open popover
- Status icon severity indicators (normal / warning / critical)
- Optional Dry Run mode

## Build in Xcode

1. Open `ClickNFix.xcodeproj` in Xcode 15+.
2. Select the `ClickNFix` scheme and a macOS run target.
3. Build and run.

## Command-line build (ad-hoc test signing)

```bash
./build.sh
```

## Production signing & notarization

1. Replace ad-hoc identity with your Developer ID identity in build settings or `build.sh`.
2. Archive with Xcode or `xcodebuild archive`.
3. Export a signed app.
4. Submit for notarization:

```bash
xcrun notarytool submit /path/to/ClickNFix.zip --keychain-profile "AC_PROFILE" --wait
xcrun stapler staple /path/to/ClickNFix.app
```

## Security notes

- The app requests administrator rights before privileged repairs.
- Risky operations require user confirmation.
- Backups are created before destructive operations and can be reverted via **Undo Last Fix**.
