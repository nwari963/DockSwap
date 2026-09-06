# dockutil Integration Strategy

## Question

How does dockswap invoke dockutil?

- Shell out to `dockutil` binary (PATH or config'd path) vs. vendor/embed Swift source
- Version pinning: minimum dockutil version (3.x)
- Error handling: nonzero exit, stderr, missing binary → actionable message
- `--no-restart` semantics: batch multiple ops into one Dock restart
- Capturing current dock: `dockutil --list` output parsing vs. reading `com.apple.dock.plist` directly
