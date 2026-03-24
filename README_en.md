# Configs

[中文 README](./README.md)

<p align="center">
  <a href="https://github.com/iHongRen/configEditor/releases/latest"><img src="https://img.shields.io/github/v/release/iHongRen/configEditor?label=version&color=green" alt="version"></a>
  <a href="https://github.com/iHongRen/configEditor"><img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+"></a>
  <a href="https://ihongren.github.io/donate.html"><img src="https://img.shields.io/badge/Sponsor-Donate-orange" alt="Sponsor"></a>
</p>

A **macOS** config file manager that lets you quickly view, edit, and manage configuration files on your computer (such as `.zshrc`, `.gitconfig`, etc.). Built with SwiftUI.

## Screenshots

![](./screenshots/preview.png)



## Features

- **Auto Discovery**: Automatically finds common config files (`.zshrc`, `.bashrc`, `.gitconfig`, `.vimrc`, etc.)
- **Multi-file Import and Drag & Drop**: Import multiple files at once, or drag files directly into the app window
- **Instant Effect**: When editing shell config files like `.zshrc`, the app automatically executes `source` on save, making changes take effect immediately
- **Version History**: Uses Git to automatically track all edits, with full history view, diff comparison, and one-click restore
- **File Management**: Add custom files, pin frequently used configs, and organize with color tags
- **Code Editor**: Syntax highlighting for multiple file types, search, zoom, and dark mode support
- **Context Menu**: Right-click files to quickly open in Finder, Terminal, VSCode, and more
- **Color Tags**: Add short colored text tags to files for easy organization
- **Localization**: Built-in Chinese and English support, defaults to the system language, and can be changed manually from the About page
- 
### Keyboard Shortcuts
- `Cmd + F`: Search
- `Cmd + S`: Save
- `Cmd + /`: Toggle comment
- `Cmd + =` / `Cmd + -`: Zoom
- `Cmd + 0`: Reset zoom
- `Esc`: Close search

## Installation

### Build from Source
You need to have Xcode installed:

```bash
git clone https://github.com/iHongRen/configEditor.git
cd configEditor/Configs
# Open Configs.xcodeproj in Xcode, select "My Mac" as target, and click Build (⌘B)
```

After building, find `Configs.app` in Xcode's Products folder.

### Direct Installation
Download [Configs.dmg](https://github.com/iHongRen/configEditor/releases) and double-click to open:

1. Drag `Configs.app` to your `/Applications` folder
2. Open Terminal and run:

   ```bash
   xattr -d com.apple.quarantine /Applications/Configs.app
   ```

3. Now you can launch it from Applications folder or Launchpad
