# ClipHistory

macOS menu bar clipboard history manager. Records everything you copy — text and images — with search, pin, delete, and automatic cleanup.

## Features

- Records copied text and images automatically
- Image thumbnails in history cards
- Search by keyword
- Pin important items to the top
- Delete unwanted items
- Configurable retention: 1 / 3 / 5 days
- Global keyboard shortcut (default: Cmd+Shift+V)
- Auto-launch at login

## Requirements

- macOS 14 (Sonoma) or later
- Xcode (to build from source)

## Install

```bash
# Install xcodegen if needed
brew install xcodegen

# Clone and build
cd ClipHistory
xcodegen generate
./build.sh
```

After building, ClipHistory will be installed to `/Applications` and available in Launchpad.

Or open `ClipHistory.xcodeproj` in Xcode and press Cmd+R.

## Usage

- Click the clipboard icon in the menu bar to open the history panel
- Click a card to copy it back to the clipboard
- Hover over a card to reveal pin and delete buttons
- Press Cmd+Shift+V to open the panel from anywhere
- Navigate with ↑/↓, press Return to copy, Esc to close, or Cmd+1–9 to copy the nth item
- Right-click the menu bar icon for the quit option

## Built With

- Swift 6 + SwiftUI
- [GRDB.swift](https://github.com/groue/GRDB.swift) — SQLite database
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — global hotkey
