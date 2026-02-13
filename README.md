# WindowTiler

A lightweight macOS menu bar app that tiles your windows into equal-sized layouts.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Tile All Windows** - Arrange all visible windows in an optimal grid layout
- **Selective Tiling** - Choose specific apps to tile (e.g., just your Terminal windows)
- **Smart Grid** - Automatically calculates the best grid size (2x2, 3x2, etc.)
- **Dock/Menu Bar Aware** - Respects your screen's usable area

## Installation

### Download

1. Download `WindowTiler.app.zip` from the [latest release](../../releases/latest)
2. Unzip and drag `WindowTiler.app` to your Applications folder
3. Launch WindowTiler
4. Grant Accessibility permission when prompted

### Build from Source

```bash
git clone https://github.com/YOUR_USERNAME/WindowTiler.git
cd WindowTiler
swift build -c release
cp -R WindowTiler.app /Applications/
```

## Usage

1. Click the grid icon (⊞) in your menu bar
2. **Tile All Windows** - Tiles every visible window
3. Or select specific apps using the checkboxes, then click **Tile Selected**

## Permissions

WindowTiler requires Accessibility permission to move and resize windows.

**System Settings → Privacy & Security → Accessibility → Enable WindowTiler**

## Requirements

- macOS 13.0 (Ventura) or later

## License

MIT License - feel free to use, modify, and distribute.
