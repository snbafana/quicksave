# Obsidian Integration

This integration writes Quicksave captures into an Obsidian daily-note folder.

When today's daily note does not exist, Quicksave creates it at the Zettelkatsen path:

```text
/Users/snbafana/Documents/Obsidian-Vault/Zettelkatsen/MM-DD-YYYY.md
```

The missing note is created from the existing daily template:

```text
/Users/snbafana/Documents/Obsidian-Vault/Templates/Daily Note.md
```

Quicksave first tries to create the note through the Obsidian CLI:

```bash
obsidian create path=Zettelkatsen/05-09-2026.md content="<rendered template>" open
```

If that command fails, Quicksave writes the same rendered template directly and then appends the capture. The app does not follow `obsidian daily:path` because your Obsidian Daily Notes plugin currently reports the root-level `YYYY-MM-DD.md` path, which is not the capture target.

## Implemented App Flow

The menu-bar app can write to Obsidian directly:

- `Option + C` saves the clipboard and appends every saved capture into today's daily note.
- `Option + W` saves the context sidecar and appends the note for each related capture.
- `Option + D` manually appends the latest capture into today's daily note again if you need a retry.

## Implemented CLI Flow

Use the CLI from the repo root:

```bash
swift run quicksave obsidian append-latest
```

What happens:

1. Find the newest non-note file in `~/Quicksave Inbox`.
2. If a matching `.note.txt` sidecar exists, use it as the context note.
3. Create `Zettelkatsen/MM-DD-YYYY.md` from `Templates/Daily Note.md` if today's note does not exist.
4. Ensure the daily note has a `## Quicksave` section.
5. Append the capture entry.

Install the CLI once if you want the command available outside this repo:

```bash
./scripts/install-cli.sh
```

The script installs:

```text
~/.local/bin/quicksave
```

You can override the install directory with `QUICKSAVE_INSTALL_DIR`.

## Markdown Format

Text capture:

```md
- 12:30 PM
  > copied text
  - user context note
```

Rich text capture:

```md
- 12:30 PM
  > Read [example](https://example.com) now
  - user context note
```

Image capture:

```md
- 12:30 PM
  ![image.png](quicksave-assets/image.png)
  - user context note
```

PDF or other file:

```md
- 12:30 PM
  [document.pdf](quicksave-assets/document.pdf)
  - user context note
```

Note appended after a capture:

```md
- 12:31 PM
  Note for `2026-05-09T06-41-26.266Z.txt`
  - user context note
```

Images and files are copied beside the Zettelkatsen daily note:

```text
<daily-note-folder>/quicksave-assets/
```

## Configuration

By default, Quicksave writes to:

```text
~/Documents/Obsidian-Vault/Zettelkatsen
```

For CLI-only tests or one-off exports, you can write to a specific folder:

```bash
swift run quicksave obsidian append-latest --daily-notes-dir /path/to/daily-notes
```

The default template is:

```text
~/Documents/Obsidian-Vault/Templates/Daily Note.md
```

You can override it with:

```bash
export QUICKSAVE_OBSIDIAN_DAILY_TEMPLATE=/path/to/Daily\ Note.md
```

If the CLI binary is not available as `obsidian`, point Quicksave at it:

```bash
export QUICKSAVE_OBSIDIAN_CLI=/path/to/obsidian
```

## Remaining Integration Plan

The current version follows the Zettelkatsen daily-note path by default. The remaining polish is configuration, not capture logic:

1. Add a compact command to open Obsidian Daily Notes settings.
2. Add a small status surface that shows the Zettelkatsen path Quicksave will append to.
3. Add optional app settings only if this CLI-backed default is not enough in daily use.
