# Obsidian Integration

This integration writes Quicksave captures into an Obsidian daily-note folder.

Target daily-note folder:

```text
/Users/snbafana/Documents/Obsidian-Vault/Zettelkatsen
```

Daily note filenames:

```text
MM-dd-yyyy.md
```

Example:

```text
05-09-2026.md
```

## Implemented App Flow

The menu-bar app can write to Obsidian directly:

- `Option + D` appends the latest capture into today's daily note.
- `Option + W` saves the context sidecar and appends the latest capture plus that note into today's daily note.
- `Option + C` stays capture-only, so quick clipping does not always mutate the vault.

## Implemented CLI Flow

Use the CLI from the repo root:

```bash
swift run quicksave obsidian append-latest \
  --daily-notes-dir /Users/snbafana/Documents/Obsidian-Vault/Zettelkatsen
```

What happens:

1. Find the newest non-note file in `~/Quicksave Inbox`.
2. If a matching `.note.txt` sidecar exists, use it as the context note.
3. Create today's daily note if it does not exist.
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

## Remaining Integration Plan

The current version writes to the default daily-note folder or the CLI override. The remaining polish is configuration, not capture logic:

1. Add a compact folder picker for the Obsidian daily-note directory.
2. Store that folder in `UserDefaults`, defaulting to `/Users/snbafana/Documents/Obsidian-Vault/Zettelkatsen`.
3. Add an optional automatic-append setting after this explicit flow feels right in daily use.
