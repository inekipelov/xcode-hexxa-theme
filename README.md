# Hexxa for Xcode

<img src="Resources/hexxa-xcode-dark.jpg" alt="Hexxa Xcode Dark" style="max-width: 800px; width: 100%;">

Packaged Hexxa Xcode color theme with bundled installer and Fira Code support. The Swift package copies the theme into Xcode's `FontAndColorThemes` directory and ensures the Fira Code fonts are available.

## Installation

### Swift Package Manager

```
# Clone the repository
$ git clone https://github.com/inekipelov/xcode-hexxa-theme.git
$ cd xcode-hexxa-theme

# Run the installer
$ swift run hexxa-xcode-theme
```

By default the installer copies the bundled `Hexxa.xccolortheme` to:

```
~/Library/Developer/Xcode/UserData/FontAndColorThemes
```

The installer also downloads the latest Fira Code release (currently v6.2) to `~/Library/Fonts` when the font is missing.

#### Options

- `--destination <path>` – copy the theme to a custom directory.
- `--dry-run` – list the actions without copying files.
- `--help`/`-h` – show the help message.

### Manual Installation

1. Copy `Sources/HexxaXcodeTheme/Themes/Hexxa.xccolortheme`.
2. Paste it into `~/Library/Developer/Xcode/UserData/FontAndColorThemes`.
3. Restart Xcode and select **Hexxa** in **Settings → Themes**.
