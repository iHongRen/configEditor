# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Configs is a macOS 13+ SwiftUI app for discovering, editing, organizing, and versioning local configuration files such as `.zshrc`, `.gitconfig`, and other dotfiles. The Xcode project lives under `Configs/`, with a single app target and scheme named `Configs`.

## Common commands

Run commands from the repository root unless noted.

```bash
# Inspect available Xcode schemes and targets
xcodebuild -list -project Configs/Configs.xcodeproj

# Build the app for local development
xcodebuild -project Configs/Configs.xcodeproj -scheme Configs -configuration Debug build

# Build a release app
xcodebuild -project Configs/Configs.xcodeproj -scheme Configs -configuration Release build

# Clean build artifacts for the scheme
xcodebuild -project Configs/Configs.xcodeproj -scheme Configs clean

# Package a release DMG; run from scripts/ because the script assumes that cwd
cd scripts && ./build_dmg.sh
```

There is currently no XCTest target in `Configs.xcodeproj`, so there is no project test or single-test command to run until a test target is added.

## Architecture notes

- `Configs/Configs/ConfigsApp.swift` is the SwiftUI entry point. It creates the main `ContentView`, replaces the app info command with a custom About window, hides most default macOS menu items, and disables automatic window tabbing.
- `ContentView` is the top-level coordinator for the main window. It owns the `ConfigManager`, selected file state, loaded/original file contents, editor search state, global zoom, color scheme, drag-and-drop state, and the optional history sidebar. It wires the sidebar, editor/detail view, history sidebar, file importer, drop handling, refresh-on-activation, and global keyboard shortcut handling together.
- `ConfigManager` is the app's source of truth for the file list and groups. It auto-discovers config-like files in the user's home directory and one level under dot-directories, merges them with saved custom files, persists files/groups/selected group/deleted auto-discovered paths in `UserDefaults`, normalizes paths, and keeps pinned files sorted first.
- `ConfigFile.swift` contains the persisted domain models: `ConfigFile`, `ConfigGroup`, and `FileTag`. Persistence is manual dictionary serialization rather than `Codable`.
- `FileOperations` handles file I/O and AppKit integrations: async content loading, metadata loading, UTF-8/Latin-1/ASCII decoding, saving, clipboard copy, opening in Finder/Terminal/VS Code/Cursor, and auto-sourcing shell config files after save. Saves that should appear in history go through `saveFileContentWithVersioning`.
- `VersionManager` maintains per-config-file Git repositories under `~/Library/Application Support/Configs/versions`. Repositories are keyed by the config file's last path component with dots replaced by underscores, are initialized with local Git user config, and are used for commit history, diffs, restore content, and history-change notifications.
- `DetailContentView` hosts `CodeEditorView`, the editor search bar, the status bar, theme toolbar, and the history toggle. It passes saves through `FileOperations.saveFileContentWithVersioning`, using the current cursor line as the commit message when available.
- `CodeEditorView` wraps an AppKit `NSTextView` via `NSViewRepresentable`. It implements syntax highlighting, line numbers, search navigation, comment toggling, JSON/JSONL formatting, JSON-family indentation behavior, large-file lightweight highlighting thresholds, URL link opening, and editor context-menu actions.
- `SidebarView` owns the file/group list UI: search, file import trigger, draggable group chips, tag editor, group editor, file context menu actions, and selection synchronization when filters/groups/files change.
- `HistorySidebarView` listens for `VersionManager` history notifications, lists commits, shows diffs through `DiffTextView`, supports keyboard navigation notifications from `KeyboardShortcutHandler`, previews large initial commits, and restores selected commit content through the callback supplied by `ContentView`.
- `Localization.swift` contains the in-code English and Simplified Chinese string table. User language selection is stored in `UserDefaults` via `LocalizationSettings.shared`; use `L10n.tr(...)` for UI strings.
- `LanguageDetector` maps config-file names/extensions to language identifiers used by `CodeEditorView` highlighting and editor behaviors.

## Development notes

- The app is intentionally a mixed SwiftUI/AppKit macOS app. Editor behavior, context menus, drag/drop, file opening, keyboard monitoring, and clipboard interactions often use AppKit directly.
- Many UI sizes scale from `globalZoomLevel`, persisted with `@AppStorage("globalZoomLevel")`; keep new UI in the main window consistent with that scaling pattern.
- Changes to save/load/versioning behavior usually cross `DetailContentView`, `FileOperations`, `VersionManager`, and `HistorySidebarView`; check all four when modifying the edit/history flow.
- The DMG script uses local build output under `scripts/build/` and assumes its working directory is `scripts/` because `PROJECT_PATH` is `../Configs/Configs.xcodeproj`.
