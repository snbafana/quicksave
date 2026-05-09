# Quicksave

Quicksave is a tiny Swift-only macOS menu-bar utility for saving whatever is on your clipboard into a local inbox.

It is intentionally simple:

- `Option + C` saves the current clipboard.
- `Option + W` opens a centered liquid-glass note box and saves your typed context as a `.note.txt` sidecar next to the latest capture.
- Every successful capture is appended to today's Obsidian daily note.
- Every context note for a capture is appended to today's Obsidian daily note.
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
- `Obsidian` -> `Option + D`
- `Open Inbox` -> `Option + O`
- `Choose...` -> `Option + ,`
- `Login` toggles launch at login
- `Quit` exits the menu-bar app

The `Note` popup is a centered minimal glass text field. Press `Enter` to save the note or `Escape` to cancel.

## Obsidian Daily Notes

Quicksave includes a CLI for appending captures into Obsidian-style daily notes.

The menu-bar app appends every `Option + C` capture into today's daily note. Saving a note with `Option + W` also appends that note for each related capture.

When today's daily note does not exist yet, Quicksave asks Obsidian to create it:

```bash
obsidian daily
```

After the file exists, Quicksave appends markdown directly. This keeps daily-note creation under Obsidian's Daily notes plugin and template settings.

Default daily-note directory:

```text
~/Documents/Obsidian-Vault/Zettelkatsen
```

Daily note names use the same format as `05-09-2026.md`.

Append a specific capture:

```bash
swift run quicksave obsidian append \
  --capture ~/Quicksave\ Inbox/2026-05-09T06-41-26.266Z.txt \
  --note "why this mattered"
```

Append the newest capture from the inbox, automatically using a matching `.note.txt` sidecar if one exists:

```bash
swift run quicksave obsidian append-latest
```

Override the daily-note directory:

```bash
swift run quicksave obsidian append-latest \
  --daily-notes-dir /Users/snbafana/Documents/Obsidian-Vault/Zettelkatsen
```

Text captures are appended as blockquotes. Images are copied into `quicksave-assets/` and embedded with markdown image syntax. Other files are copied into `quicksave-assets/` and linked. Capture notes are appended as note entries tied to the capture filename.

If the Obsidian CLI binary is not named `obsidian`, set:

```bash
export QUICKSAVE_OBSIDIAN_CLI=/path/to/obsidian
```

Install the CLI to `~/.local/bin/quicksave`:

```bash
./scripts/install-cli.sh
```

Then it can be used from anywhere:

```bash
quicksave obsidian append-latest
```

See [docs/OBSIDIAN.md](docs/OBSIDIAN.md) for the implementation plan and integration details.

## Project Layout

```text
Sources/
  MacQuicksave/          # AppKit menu-bar app, hotkeys, note panel
  QuicksaveCLI/          # CLI commands for Obsidian integration
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
- Obsidian daily-note creation and appends
- Obsidian CLI-backed daily-note creation
- multiple captures and capture note entries

## Design Boundary

Quicksave only saves explicit clipboard content and explicit notes. It does not inspect the screen, scrape app accessibility trees, or automatically record every clipboard change.
