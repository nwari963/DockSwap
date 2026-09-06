# CLI Command Structure

## **Question** (Prototype)

Design the `dockswap` command surface.

- Subcommands: `save <name>`, `switch <name>`, `list`, `delete <name>`, and TUI entry (`dockswap` bare or `dockswap ui`)
- Output: human vs. `--json` machine-readable
- Flags: `--dry-run` (print diff, don't apply), `--no-restart`, `--quiet`
- Exit codes: 0 ok, 1 usage, 2 preset-not-found, 3 dockutil-missing, etc.
- Help text style; shell completion

## Resolution (2026-09-06)

**Exactly four verbs + the bare no-arg picker. No `ui` subcommand, no aliases.**

```
dockswap                        # no subcommand → open TUI picker (005)
dockswap save <name>            # capture current Dock → ~/.dockswap/presets/<name>.json
dockswap switch <name>          # apply preset (diff semantics, 003); flags: --dry-run --quiet
dockswap list                   # list presets; flags: --json --quiet
dockswap delete <name>          # remove preset file; flag: --quiet
dockswap --version              # print version
dockswap --generate-completion-script <bash|zsh|fish>   # print completion script (library)
```

**Design decisions**

- **No `--no-restart` in MVP.** Diff-apply already batches all add/remove into one dockutil invocation with exactly one Dock restart (003). Exposing the flag creates a half-applied Dock (plist written, Dock not restarted) for zero user benefit. Reserved for post-MVP.
- **No `--preview` flag in MVP.** CLI preview of an apply is `switch --dry-run` (prints the planned removal/add lists, 003). Interactive preview is the TUI's second-Enter (005). A `show`/`preview` verb is post-MVP.
- **`--json` lives on `list` only.** It is the single machine-readable interface, pinned to a stable schema. `switch`/`save`/`delete` emit no parseable payload, so they never accept `--json` (delete over add). `--quiet` (global) silences informational stdout everywhere; errors still go to stderr with a nonzero exit.
- **`save` overwrites silently.** A preset is "my Dock right now"; re-running `save <same-name>` is the update path. Content is small and re-capturable, so clobber is cheap; a `--force` wall would punish the common case. Recovery from a typo'd name is one `delete` or re-capture away.
- **Preset names**: must match `^[A-Za-z0-9][A-Za-z0-9._-]*$` — a valid filename token (no `/`, no leading `.`), so no path traversal and no hidden files. A name outside this is a usage error (1).
- **Check order for `switch`**: validate name → preset exists? (else 2) → dockutil available? (else 3) → run diff/apply. `--dry-run` still requires dockutil (it needs `dockutil --list` for the diff).
- **First run**: `~/.dockswap/presets/` auto-created on first `save` (006); IO failure here is exit 6.

**Flags**

- Root: `--quiet`, `--version`, `--help` (latter two library-provided; plus `--generate-completion-script`)
- `switch`: `--dry-run` — print planned removals/additions computed from `dockutil --list`, apply nothing, exit 0
- `list`: `--json` — machine-readable output (only on `list`)

**Exit codes**

| Code | Meaning |
| ---: | --- |
| 0 | success — including `--dry-run`, "already applied", empty `list` |
| 1 | usage / validation — unknown subcommand or flag, invalid preset name |
| 2 | preset not found (`switch`, `delete`) |
| 3 | dockutil unavailable — exec not found or version < 3.0; message offers `brew install dockutil` (002) |
| 4 | preset file invalid — not JSON, schema version mismatch, unreadable |
| 5 | dockutil run failed — nonzero exit; dockutil's own stderr echoed verbatim (002) |
| 6 | filesystem / config I/O failure — cannot create `~/.dockswap/`, cannot write preset |

Note on 1: swift-argument-parser's default exit for parse/validation failures is `EX_USAGE` (64). To honor the contract, `main` uses the lower-level `parseAsRoot` inside `do/catch` and re-exits with 1; a build that shortcuts with the `.main()` convenience would return 64. The contract's number is **1**, asserted in CI.

**Help + shell completion**: swift-argument-parser free features — `--help` with one-line per-command `abstract`, `--version`, and built-in `--generate-completion-script <bash|zsh|fish>`. No custom help text beyond the abstracts.

**Human output shapes**

- `save`: `Saved 'dev' (6 apps, 2 others).`
- `switch`: `Switched to 'dev' (2 removed, 3 added).` | `already applied.`
- `switch --dry-run`:
  ```
  Would switch to 'dev':
    remove: Safari, Notes
    add:    iTerm, Visual Studio Code, ~/Projects
  ```
- `list`:
  ```
  dev       8 items  2026-09-06T15:00:00Z
  design   14 items  2026-09-06T13:00:00Z
  ```
- `list --json` (stable):
  ```json
  [{"name":"dev","apps":6,"others":2,"updatedAt":"2026-09-06T15:00:00Z"},
   {"name":"design","apps":12,"others":2,"updatedAt":"2026-09-06T13:00:00Z"}]
  ```
  Empty: `[]` (still exit 0).
- `delete`: `Deleted 'dev'.` (`--quiet` suppresses).

**Example invocations**

```
$ dockswap                             # picker; Enter applies highlighted preset
$ dockswap save dev                    # capture → "Saved 'dev' (6 apps, 2 others)."
$ dockswap save dev                    # re-capture overwrites silently (update path)
$ dockswap switch dev --dry-run        # prints Would switch... diff; exit 0
$ dockswap switch dev                  # applies → "Switched to 'dev' (2 removed, 3 added)."
$ dockswap switch dev                  # already applied → "already applied."; exit 0
$ dockswap switch nope; echo $?        # "preset not found: nope"          → 2
$ dockswap switch dev                  # missing/bad dockutil              → 3
$ dockswap switch 'dev/x'; echo $?     # invalid preset name (usage)       → 1
$ dockswap frobnicate; echo $?         # unknown subcommand (usage)         → 1
$ dockswap list --json                 # machine-readable preset summary
$ dockswap delete dev --quiet; echo $? # silent destroy                     → 0
$ dockswap delete nope; echo $?        #                                    → 2
$ dockswap --generate-completion-script zsh > _dockswap   # zsh completion
```

Back-references: switch semantics 003, dockutil exit/error handling 002, bare-picker entry + preview 005, preset file shape 001.