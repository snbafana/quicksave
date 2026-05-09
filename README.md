# Quicksave

Quicksave is a tiny Swift-only macOS menu-bar app for saving the current clipboard into a local inbox and, optionally, appending the same capture into an Obsidian daily note.

The core flow is intentionally small:

- `Option + C` saves the current clipboard.
- `Option + W` opens a minimal note box for context on the latest capture.
- `Option + D` retries appending the latest capture to Obsidian.
- Captures are saved as normal files, not a database or opaque blob store.
- No screen recording, OCR, browser extension, Accessibility scraping, or clipboard polling is used.

## What It Captures

Default inbox:

```text
~/Quicksave Inbox
```

Supported clipboard content:

- Plain text and URLs -> `.txt`
- HTML/RTF text with links -> `.md`
- Images -> `.png`
- Direct PDF pasteboard data -> `.pdf`
- Copied Finder files and folders -> copied into the inbox with a timestamp prefix
- Explicit notes -> `.note.txt` sidecars

Example inbox:

```text
~/Quicksave Inbox/
  2026-05-09T06-41-26.266Z.txt
  2026-05-09T06-41-26.266Z.note.txt
  2026-05-09T06-42-10.101Z.md
  2026-05-09T06-43-03.512Z.png
  2026-05-09T06-44-12.900Z-source-file.pdf
```

## Install

Requirements:

- macOS 13 or newer
- Xcode or Xcode Command Line Tools
- Swift 6-compatible toolchain
- Obsidian installed if you want daily-note appends

Build from source:

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

This is currently an unsigned local build. If macOS blocks first launch, right-click `Mac Quicksave.app` in Finder and choose `Open`.

Install the companion CLI:

```bash
./scripts/install-cli.sh
```

By default, the CLI is installed to:

```text
~/.local/bin/quicksave
```

Make sure `~/.local/bin` is on your shell `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Confirm the install:

```bash
quicksave config show
```

## Configure

The menu-bar app and CLI share config through the `com.snbafana.quicksave` defaults domain.

Default config:

```text
inbox=~/Quicksave Inbox
obsidian_vault=~/Documents/Obsidian-Vault
obsidian_daily_notes=~/Documents/Obsidian-Vault/Zettelkatsen
obsidian_daily_template=~/Documents/Obsidian-Vault/Templates/Daily Note.md
```

Set the config from the CLI:

```bash
quicksave config set \
  --inbox ~/Quicksave\ Inbox \
  --vault ~/Documents/Obsidian-Vault \
  --daily-notes-dir ~/Documents/Obsidian-Vault/Zettelkatsen \
  --daily-template ~/Documents/Obsidian-Vault/Templates/Daily\ Note.md
```

Inspect it:

```bash
quicksave config show
quicksave obsidian today
```

Reset only the Obsidian paths to defaults:

```bash
quicksave config reset-obsidian
```

You can also configure paths from the menu-bar app:

- `Choose Inbox...`
- `Choose Vault...`
- `Choose Daily Notes...`
- `Choose Daily Template...`
- `Reset Obsidian Config`

## Daily Use

Menu shortcuts:

- `Save` -> `Option + C`
- `Note` -> `Option + W`
- `Obsidian` -> `Option + D`
- `Open Inbox` -> `Option + O`
- `Choose Inbox...` -> `Option + ,`

Typical workflow:

1. Copy text, an image, a PDF, or a file.
2. Press `Option + C`.
3. Quicksave writes a simple file into the inbox.
4. Quicksave appends that capture into today’s Obsidian daily note.
5. Press `Option + W` to add context; that note is saved as a sidecar and appended under the related capture.

The note popup is a centered minimal glass text box. It wraps across lines; press `Command + Enter` to save, or `Escape` to cancel.

## Obsidian Behavior

Quicksave writes to the configured daily-note directory using `MM-DD-YYYY.md` names.

Default daily-note target:

```text
~/Documents/Obsidian-Vault/Zettelkatsen/MM-DD-YYYY.md
```

Default template:

```text
~/Documents/Obsidian-Vault/Templates/Daily Note.md
```

If today’s note does not exist, Quicksave renders the configured template and creates the note before appending. It first tries the Obsidian CLI:

```bash
obsidian create path=Zettelkatsen/05-09-2026.md content="<rendered template>" open
```

If that fails, Quicksave writes the rendered template directly so captures still land.

Quicksave does not use `obsidian daily:path` as the source of truth, because that can point to a different Daily Notes plugin location than the configured capture folder.

Append format:

```md
- 12:30 PM
  > copied text
  - optional context note
```

Rich text links are preserved when the clipboard exposes HTML/RTF:

```md
- 12:30 PM
  > Read [example](https://example.com) now
```

Images are copied into the vault media folder and embedded with Obsidian wikilinks:

```md
- 12:30 PM
  ![[image.png]]
```

Image files are stored in the configured vault at `Visuals/Media`, matching Obsidian's local attachment convention.

Files are copied beside the daily note and linked:

```md
- 12:30 PM
  [document.pdf](quicksave-assets/document.pdf)
```

No `## Quicksave` heading is inserted. Captures append directly into the daily note.

## CLI Reference

Append a specific capture:

```bash
quicksave obsidian append \
  --capture ~/Quicksave\ Inbox/2026-05-09T06-41-26.266Z.txt \
  --note "why this mattered"
```

Append the newest inbox capture:

```bash
quicksave obsidian append-latest
```

Print today’s configured daily note:

```bash
quicksave obsidian today
```

One-off override:

```bash
quicksave obsidian append-latest \
  --daily-notes-dir /path/to/daily-notes \
  --daily-template /path/to/Daily.md
```

If the Obsidian CLI binary is not named `obsidian`, set:

```bash
export QUICKSAVE_OBSIDIAN_CLI=/path/to/obsidian
```

## Development

Build the app bundle:

```bash
./scripts/build-app.sh
```

Run the app:

```bash
open "dist/Mac Quicksave.app"
```

Restart an existing development build:

```bash
pkill -f "Mac Quicksave.app/Contents/MacOS/Mac Quicksave" || true
open "dist/Mac Quicksave.app"
```

Build the DMG:

```bash
./scripts/build-dmg.sh
```

Run tests:

```bash
swift test
```

Current tests cover clipboard capture, file/folder copies, image capture, PDF capture, rich text links, note sidecars, configurable paths, Obsidian daily-note creation, image embedding, file linking, and repeated distinct captures.

## Project Layout

```text
src/
  app/                   # AppKit menu-bar app, global hotkeys, note panel
  cli/                   # CLI commands for config and Obsidian appends
  core/                  # Clipboard capture, settings, file naming, Obsidian writer
tests/                   # Unit tests for capture, settings, notes, Obsidian output
scripts/
  build-app.sh           # Build dist/Mac Quicksave.app
  build-dmg.sh           # Build dist/Mac-Quicksave.dmg
  install-cli.sh         # Install ~/.local/bin/quicksave
```

## Design Boundary

Quicksave saves only explicit clipboard content and explicit notes you type. It does not inspect the screen, scrape Accessibility trees, watch the clipboard in the background, OCR images, or use browser extensions.
