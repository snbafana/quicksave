# Mac Quicksave Plan

## Product Shape

Build a tiny macOS menu-bar app that saves the current clipboard into the inbox whenever the user presses a global hotkey or clicks a menu item.

The app should feel like a capture primitive, not a notes app:

- always running in the background
- visible in the top-right menu bar
- one hotkey for "save current clipboard"
- configurable inbox directory
- each saved item becomes a normal file in the inbox
- no browser extension in v1 unless clipboard capture proves insufficient

## Why Swift Only

Use Swift/AppKit because the core API is `NSPasteboard`, and the menu-bar/hotkey/LaunchAgent parts are native macOS concerns. Rust adds ceremony here without buying much for v1.

## Target Architecture

### 1. Menu-Bar App

SwiftUI or AppKit status-item app with:

- menu-bar icon
- "Save"
- "Note"
- "Open Inbox"
- "Choose..."
- "Login" toggle
- "Quit"
- last capture status in the menu

Implementation target:

- `NSStatusItem` for menu-bar presence
- `Settings` persisted in `UserDefaults`
- helper functions isolated from UI so capture can be tested directly

### 2. Global Hotkey

Start with one configurable default:

- `Option + C`

Use a small native hotkey package if building as a Swift package, or Carbon `RegisterEventHotKey` if keeping dependencies minimal.

Decision:

- v1 can use Carbon directly to avoid dependency drift.
- Later versions can add configurable hotkeys.

### 3. Clipboard Capture Engine

Core function:

```swift
captureClipboard(to inboxDirectory: URL) throws -> CaptureResult
```

Each capture writes useful clipboard content directly into the inbox:

```text
<inbox>/
  <timestamp>.txt
  <timestamp>.png
  <timestamp>.pdf
  <timestamp>-copied-file-or-folder
```

Rules:

- Save every supported pasteboard item independently.
- Save only the useful content, not metadata or raw pasteboard dumps.
- Text and URLs become `.txt`.
- Images become `.png`.
- Direct PDF data becomes `.pdf`.
- Finder file/folder references are copied into the inbox with a timestamp prefix.
- `Option + W` opens a centered liquid-glass note input and saves explicit user context as a `.note.txt` sidecar next to the last saved item.
- Do not dedupe in v1. Re-saving the same clipboard should still create a new file because the act of capture is meaningful.

### 4. Supported Clipboard Types For V1

Must support:

- plain text
- rich text / RTF
- HTML
- URLs
- copied Finder files and folders
- images copied from Chrome, Preview, Finder, screenshots, etc.
- PDFs when exposed by the pasteboard

Explicitly not v1:

- OCR
- screen capture
- accessibility tree scraping
- Chrome extension
- automatic polling/saving every clipboard change
- semantic indexing or sync backend

## Metadata

Do not write metadata files in v1. The capture should stay obvious in Finder: a text file, image file, PDF, copied file, or copied folder.

## Persistence

Use a normal app bundle plus launch-at-login:

- menu-bar app remains the main always-on process
- login item starts it after reboot/login
- no LaunchAgent needed unless we later split a headless daemon from the UI

This is simpler and more macOS-native than a separate daemon for v1.

## Initial Build Path

1. Create Swift package or Xcode project skeleton under this directory.
2. Implement pure capture engine with tests first.
3. Add a minimal menu-bar app.
4. Add global hotkey.
5. Add inbox chooser and persisted settings.
6. Add launch-at-login.
7. Package a local `.app`.
8. Only then consider `.dmg` packaging.

## Open Decisions

- App name: working name is `Mac Quicksave`.
- Default inbox: `~/Quicksave Inbox` unless changed.
- Hotkey: default `Option + C`.
- Package style: SwiftPM-first if possible, Xcode project if needed for app bundle/signing friction.
- Icon: use a plain system symbol in v1; custom icon later.
