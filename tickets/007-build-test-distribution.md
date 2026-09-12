# Build, Test & Distribution — RESOLVED

## Question

Build/test/distribution decisions.

- Swift Package Manager executable target
- Testing: preset parse/serialize roundtrip; diff logic; mock dockutil; manual QA checklist
- Distribution: Homebrew tap/formula, GitHub Releases, signing + notarization
- Repo bootstrap: README (demo GIF), LICENSE (MIT), CI (GitHub Actions macOS runner)

## Resolution (2026-09-06)

**One SwiftPM package: a `DockSwapCore` library + a thin `dockswap` executable, only external dependency swift-argument-parser. Unit tests target the library; distribution is GitHub Releases (signed & notarized binary) + an in-repo Homebrew tap formula; CI is GitHub Actions on a macOS runner gated to unit tests.**

Repo bootstrap:
- **LICENSE: MIT** for the project (per 005, all deps are permissive; MIT is the most common lightweight-Swift-CLI license and harmonizes with the open-source positioning — swift-argument-parser · Apache-2.0 is header-attributed, no conflict for a shelled-out MIT CLI that never links dockutil code).
- **README**: install (brew / binary / build from source), 3-command quickstart (`save`/`switch`/`list`), a demo GIF captured with `asciinema` + `agg` (TUI picker + switch), config/preset-dir map to 001/006.
- **CONTRIBUTING.md** with the manual QA checklist (see Testing).
- **CI**: GitHub Actions `ci.yml` on `macos-latest` — `swift build -c release` + `swift test` on each push/PR. Never runs interactive/integration tests.

SPM package layout (targets in `Package.swift`):
- **Platform floor**: `.macOS(.v13)` (Ventura) — matches the brew bottle surface (ventura+) and post-dockutil-3.1.3 support; macOS-only product anyway.
- **`DockSwapCore` library target** — all logic: preset model + Codable (001), dockutil shell-out wrapper (002), switch diff engine (003), ANSI picker (005). This split is what makes every named test possible without exec'ing the CLI.
- **`dockswap` executable target** — swift-argument-parser command surface only (004); thin main calling into `DockSwapCore`. No testable logic here.
- **Dependencies**: `swift-argument-parser` pinned by minor (e.g. `from: "1.3.0"`), only external dep.

Testing strategy (target = `DockSwapCoreTests`):
- **Unit tests (always, on CI)**: preset `Codable` parse→serialize→parse **roundtrip** (golden fixtures in `Tests/Fixtures/*.json`); switch **diff engine** (remove/add/move ordering, missing-app & empty-preset edges per 003); dockutil `--list` tab-parse (fixture strings); first-run/config path resolution (006). Run with `swift test`.
- **Integration tests (opt-in, never on CI)**: real dock-switch against a live `dockutil`/Dock. Gated behind `--enable-integration` and an env guard (`DOCKSWAP_INTEGRATION=1`) that skips when unset. These are destructive (mutate the live Dock) → must not run in CI; run locally or on a throwaway VM. Assert preset applied then restore the prior dock.
- **Mock dockutil**: inject a `DockUtilExecuting` protocol into the wrapper (002); tests use a fake that records args and returns canned stdout/exit codes — lets diff logic be tested for non-zero/missing-binary paths without a Dock.
- **Manual QA checklist** (CONTRIBUTING.md): fresh install on a clean user, save→switch→restore captures spacing/stacks/URLs, missing app handling, dock restart timing, picker keys, uninstall (`rm -rf ~/.dockswap`).

Distribution:
- **GitHub Releases** are the canonical artifact source. Release workflow builds `-c release`, zips the binary, and attaches it. Artifacts: source tarball (auto) + `dockswap-<ver>-macos-<arch>.zip`.
- **Homebrew**: `Formula/dockswap.rb` committed in-repo, made installable via a tap. MVP ships a `homebrew-` prefixed tap repo (or `brew install <org>/<repo>/dockswap` from this repo's `Formula/`) — builds from source via SPM (no bottle initially, unlike dockutil which has bottles). **Graduate to `homebrew-core` post-MVP** once the formula is accepted and bottled.
- **Signing + notarization**: optional-at-launch, mandatory-for-polish. Release workflow signs the binary with a **Developer ID Application** cert and notarizes via `notarytool` (secrets in repo: cert p12 + signing ID, Apple ID / App Store Connect API key). If the maintainer lacks a cert at MVP, ship the unsigned binary with the Gatekeeper caveat documented (right-click-Open / `xattr -dr com.apple.quarantine`) in README; enable signing+notarization as soon as a Developer ID is available so Gatekeeper is clean.

Post-MVP:
- Embed dockutil as a vendored target only if distribution demands it (002) — would add Apache-2.0 attribution to `NOTICE`.
- homebrew-core bottle support and auto-update (autobump), once adopted.
