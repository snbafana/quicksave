# Obsidian Integration

This integration writes Quicksave captures into an Obsidian daily-note folder.

When today's daily note does not exist, Quicksave asks Obsidian for the configured daily-note path and then creates/opens the daily note through the Obsidian CLI:

```bash
obsidian daily:path
obsidian daily
```

That keeps creation under Obsidian's Daily notes plugin instead of hardcoding an empty markdown file in Quicksave. The Obsidian app/CLI must be installed and the Daily notes plugin should point at the same folder and date format used below.

Target daily-note folder:

```text
/Users/snbafana/Documents/Obsidian-Vault/Zettelkatsen
```

Daily note filenames:

```text
MM-dd-yyyy.md
```

Obsidian Daily notes settings should match:

```text
New file location: Zettelkatsen
Date format: MM-dd-yyyy
```

Example:

```text
05-09-2026.md
```

## Implemented App Flow

The menu-bar app can write to Obsidian directly:

- `Option + C` saves the clipboard and appends every saved capture into today's daily note.
- `Option + W` saves the context sidecar and appends the note for each related capture.
- `Option + D` manually appends the latest capture into today's daily note again if you need a retry.

## Implemented CLI Flow

Use the CLI from the repo root:

```bash
swift run quicksave obsidian append-latest \
  --daily-notes-dir /Users/snbafana/Documents/Obsidian-Vault/Zettelkatsen
```

What happens:

1. Find the newest non-note file in `~/Quicksave Inbox`.
2. If a matching `.note.txt` sidecar exists, use it as the context note.
3. Run `obsidian daily:path`, then `obsidian daily` if today's daily note does not exist.
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

Images and files are copied into:

```text
<daily-note-folder>/quicksave-assets/
```

## Configuration

Default daily-note folder:

```text
~/Documents/Obsidian-Vault/Zettelkatsen
```

You can override it per command:

```bash
swift run quicksave obsidian append-latest --daily-notes-dir /path/to/daily-notes
```

Or set an environment variable:

```bash
export QUICKSAVE_OBSIDIAN_DAILY_NOTES=/Users/snbafana/Documents/Obsidian-Vault/Zettelkatsen
```

If the CLI binary is not available as `obsidian`, point Quicksave at it:

```bash
export QUICKSAVE_OBSIDIAN_CLI=/path/to/obsidian
```

## Remaining Integration Plan

The current version writes to the default daily-note folder or the CLI override. The remaining polish is configuration, not capture logic:

1. Add a compact folder picker for the Obsidian daily-note directory.
2. Store that folder in `UserDefaults`, defaulting to `/Users/snbafana/Documents/Obsidian-Vault/Zettelkatsen`.
3. Add an optional automatic-append setting after this explicit flow feels right in daily use.
