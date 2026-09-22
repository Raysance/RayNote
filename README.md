# RayNote

RayNote is an unofficial macOS notes app inspired by the interface and keyboard-first workflow of **Raycast Notes**. It recreates the idea of a fast, always-available writing surface while using an independent implementation and original source code.

> [!IMPORTANT]
> RayNote is not affiliated with, endorsed by, or sponsored by Raycast Technologies Ltd. Raycast and Raycast Notes are trademarks of their respective owner.

## Features

- Native SwiftUI and AppKit interface
- Opens directly to the most recently edited note
- Searchable floating note switcher
- Create, delete, and pin notes
- Rich-text editing with keyboard shortcuts
- Automatic local persistence
- Translucent macOS material background
- Always-on-top floating panel across desktop Spaces
- Support for joining other applications' full-screen Spaces on macOS 26 and later
- Menu bar controls
- No third-party dependencies

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘ N` | Create a note |
| `⌘ F` | Open the note switcher and search |
| `⌘ Return` | Focus the editor |
| `⌘ ⇧ P` | Pin or unpin the current note |
| `⌘ B` | Bold selected text |
| `⌘ I` | Italicize selected text |
| `⌘ U` | Underline selected text |
| `⌘ +` / `⌘ -` | Increase or decrease selected text size |
| `⌘ ⌥ ↑` / `⌘ ⌥ ↓` | Select the previous or next note |
| `⌘ ⇧ Delete` | Delete the current note |

## Requirements

- macOS 13 or later
- Xcode with the macOS SDK, or a compatible Swift toolchain

## Run from Xcode

Open `Package.swift` in Xcode, select the `RayNote` executable, and press **Run**.

## Run from Terminal

```bash
swift run RayNote
```

To create a standalone, ad-hoc-signed application bundle:

```bash
./scripts/build-app.sh
open dist/RayNote.app
```

## Local data

Notes are stored locally at:

```text
~/Library/Application Support/RayNote/notes.json
```

RayNote also keeps a current mirror and the 20 most recent historical snapshots in:

```text
~/Library/Application Support/RayNote/Backups/
```

If the primary file cannot be decoded at launch, RayNote automatically restores the newest valid backup.

RayNote does not include sync, analytics, accounts, or network services.

## Project structure

```text
Sources/RayNote/       Application source
Tests/RayNoteTests/    Model tests
Resources/             Application metadata
scripts/build-app.sh   Standalone app bundler
```

## License

Released under the MIT License. See [LICENSE](LICENSE).
