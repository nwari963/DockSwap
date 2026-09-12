# DockSwap

A lightweight, open-source CLI for saving and switching macOS Dock presets.

## Installation

### Homebrew

```sh
brew install nwari963/dockswap/dockswap
```

### Binary

Download from [GitHub Releases](https://github.com/nwari963/dockswap/releases).

Releases are **unsigned** (no Apple Developer ID yet), so Gatekeeper will
block the first launch. Clear the quarantine flag once after downloading:

```sh
xattr -d com.apple.quarantine dockswap
```

### Build from source

```sh
git clone https://github.com/nwari963/dockswap.git
cd dockswap
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
