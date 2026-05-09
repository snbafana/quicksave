# Mac Quicksave Test Plan

## Goal

Prove that the app saves useful clipboard contents directly into the inbox with no metadata folders, raw dumps, or blob directories.

## Unit Tests

- Text clipboard saves one `.txt` file directly in the inbox.
- URL clipboard saves one `.txt` file directly in the inbox.
- Image clipboard saves one `.png` file directly in the inbox.
- Finder file clipboard copies the file directly into the inbox.
- Re-saving the same clipboard creates a distinct file.
- Unsupported clipboard content returns a clear error.
- No `metadata.json`, `payloads/`, or `raw/` artifacts are created.

## Manual Tests

- Launch the app and confirm the menu is compact.
- Confirm the menu shortcuts display Option-based shortcuts, especially `Option + C` for Save.
- Confirm `Option + W` opens a centered liquid-glass note box and Enter writes a `.note.txt` sidecar next to the last saved item.
- Copy text, press `Option + C`, and confirm a `.txt` file appears in `~/Quicksave Inbox`.
- Copy an image, press `Option + C`, and confirm a `.png` file appears.
- Copy a file in Finder, press `Option + C`, and confirm the copied file appears.
- Use the menu item `Save` and confirm it behaves the same as the hotkey.
- Use `Choose...` and confirm captures go to the selected folder.

## Acceptance Criteria

- The menu is small enough to scan quickly.
- The visible shortcuts are Option-based by default.
- `Option + C` captures clipboard content globally.
- Captures are simple files in the inbox.
- Explicit context notes are simple `.note.txt` files.
- The app does not write metadata or raw pasteboard dumps in v1.
