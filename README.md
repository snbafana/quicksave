# Mac Quicksave

Swift-only macOS clipboard capture utility.

The app lives in the menu bar and saves the current clipboard into a normal file when triggered from the menu or with the default hotkey:

```text
Option + C
```

Default inbox:

```text
~/Quicksave Inbox
```

Context note hotkey:

```text
Option + W
```

`Option + W` opens a centered liquid-glass note box and saves explicit context as a `.note.txt` sidecar next to the most recent capture.

## Build

Run tests:

```bash
swift test
```

Build a local app bundle:

```bash
./scripts/build-app.sh
```

Run it:

```bash
open "dist/Mac Quicksave.app"
```

## Capture Format

Each capture writes the useful clipboard content directly into the inbox:

```text
<inbox>/
  <timestamp>.txt
  <timestamp>.png
  <timestamp>-copied-file.pdf
```

Text and URLs become `.txt` files. Images become `.png` files. Copied files and folders are copied into the inbox with a timestamp prefix. Direct PDF pasteboard data becomes `.pdf`.

## Menu

- `Save` uses `Option + C`
- `Note` uses `Option + W`
- `Open Inbox` uses `Option + O`
- `Choose...` uses `Option + ,`
- `Login` toggles launch at login

`Note` opens a centered liquid-glass text box. Press Enter to write a `.note.txt` file next to the last saved item, or Escape to cancel. If nothing has been saved yet, it creates a standalone note in the inbox.

## DMG

Build a local DMG:

```bash
./scripts/build-dmg.sh
```

The generated `.app` and `.dmg` live under `dist/` and are intentionally not committed.

## V1 Boundary

This version intentionally uses clipboard data only. It does not require Accessibility, Screen Recording, OCR, Chrome extensions, or automatic clipboard polling.
