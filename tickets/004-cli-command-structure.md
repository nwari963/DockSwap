# CLI Command Structure

## **Question** (Prototype)

Design the `dockswap` command surface.

- Subcommands: `save <name>`, `switch <name>`, `list`, `delete <name>`, and TUI entry (`dockswap` bare or `dockswap ui`)
- Output: human vs. `--json` machine-readable
- Flags: `--dry-run` (print diff, don't apply), `--no-restart`, `--quiet`
- Exit codes: 0 ok, 1 usage, 2 preset-not-found, 3 dockutil-missing, etc.
- Help text style; shell completion
