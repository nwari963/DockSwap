# DockSwap

A lightweight, open-source CLI for saving and switching macOS Dock presets.

## Installation

### Homebrew

The formula lives in this repo rather than a separate `homebrew-dockswap`
tap, so it needs the explicit tap URL (the `user/repo` shorthand only works
for a tap repo literally named `homebrew-<name>`):

```sh
brew tap nwari963/dockswap https://github.com/nwari963/DockSwap
brew install dockswap
```

Homebrew may prompt you to trust this third-party tap the first time.

### Binary

Download from [GitHub Releases](https://github.com/nwari963/DockSwap/releases).

Releases are **unsigned** (no Apple Developer ID yet), so Gatekeeper will
block the first launch. Clear the quarantine flag once after downloading:

```sh
xattr -d com.apple.quarantine dockswap
```

### Build from source

```sh
git clone https://github.com/nwari963/DockSwap.git
cd DockSwap
swift build -c release
cp .build/release/dockswap /usr/local/bin/
```

## Usage

### Quickstart

1. Save your current Dock:

    ```sh
dockswap save dev
```

2. Switch to it later:

    ```sh
dockswap switch dev
```

3. List all presets:

    ```sh
dockswap list
```

4. Delete a preset:

    ```sh
dockswap delete dev
```

### Demo

![Demo](https://asciinema.org/a/123456)

## Presets

Presets are stored as JSON files in `~/.dockswap/presets/`.

## License

MIT
