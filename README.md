# Quicksave

Quicksave is a tiny Swift-only macOS menu-bar utility for saving whatever is on your clipboard into a local inbox.

It is intentionally simple:

- `Option + C` saves the current clipboard.
- `Option + W` opens a centered liquid-glass note box and saves your typed context as a `.note.txt` sidecar next to the latest capture.
- Captures are normal files in Finder, not a database and not opaque blob folders.
- The app uses clipboard APIs only. It does not require Accessibility, Screen Recording, OCR, browser extensions, or clipboard polling.

## What It Saves

Default inbox:

```text
~/Quicksave Inbox
```

Capture output examples:

```text
~/Quicksave Inbox/
  2026-05-09T06-41-26.266Z.txt
  2026-05-09T06-41-26.266Z.note.txt
  2026-05-09T06-42-10.101Z.png
  2026-05-09T06-43-03.512Z.pdf
  2026-05-09T06-44-12.900Z-source-file.pdf
```

Supported clipboard content:

- plain text and URLs -> `.txt`
- copied images -> `.png`
- direct PDF pasteboard data -> `.pdf`
- copied Finder files and folders -> copied into the inbox with a timestamp prefix
- explicit context notes -> `.note.txt`

## Install From Source

Requirements:

- macOS 13 or newer
- Xcode command line tools or Xcode
- Swift 6-compatible toolchain

Clone and build:

```bash
git clone https://github.com/snbafana/quicksave.git
cd quicksave
swift test
./scripts/build-dmg.sh
```

The DMG is written to:

```text
dist/Mac-Quicksave.dmg
```

Open the DMG and drag `Mac Quicksave.app` into `/Applications`.

Because this is currently a local unsigned build, macOS may show a Gatekeeper warning on first launch. If needed, right-click the app in Finder and choose `Open`.

## Run During Development

Build the app bundle:

```bash
./scripts/build-app.sh
```

Run it:

```bash
open "dist/Mac Quicksave.app"
```

If an older development build is already running:

```bash
pkill -f "Mac Quicksave.app/Contents/MacOS/Mac Quicksave" || true
open "dist/Mac Quicksave.app"
```

## Menu

- `Save` -> `Option + C`
- `Note` -> `Option + W`
- `Open Inbox` -> `Option + O`
- `Choose...` -> `Option + ,`
- `Login` toggles launch at login
- `Quit` exits the menu-bar app

The `Note` popup is a centered minimal glass text field. Press `Enter` to save the note or `Escape` to cancel.

## Project Layout

```text
Sources/
  MacQuicksave/          # AppKit menu-bar app, hotkeys, note panel
  QuicksaveCore/         # Clipboard capture and note-writing logic
Tests/
  QuicksaveCoreTests/    # Unit tests for capture and note output
scripts/
  build-app.sh           # Build dist/Mac Quicksave.app
  build-dmg.sh           # Build dist/Mac-Quicksave.dmg
```

## Verification

Run the test suite:

```bash
swift test
```

Current coverage verifies:

- text captures
- URL captures
- image captures
- direct PDF captures
- copied files
- copied folders
- repeated captures creating distinct files
- sidecar notes
- standalone notes

## Design Boundary

Quicksave only saves explicit clipboard content and explicit notes. It does not inspect the screen, scrape app accessibility trees, or automatically record every clipboard change.
