# First-Run & Config — RESOLVED

## Question

What happens on first invocation with no `~/.dockswap/`?

- Auto-create dirs, or require explicit init?
- dockutil detection: `which dockutil` → prompt `brew install dockutil`
- Config file: `~/.dockswap/config.json` (dockutil path, preset dir, switch behavior defaults)
- Should `save` capture live dock or accept a manual item list?

## Resolution (2026-09-06)

**Lazy init, no `init` command, no config file. dockutil detected lazily and only on the two commands that need it.**

Research:
- 002 pins the resolver (PATH → config'd path → `brew install dockutil` message, exit 3) and the capture path (`dockutil --list`). Reference-host reality (research/dockutil-integration.md, live check): dockutil is **not installed** here and `~/.dockswap` does not exist — detection on first run is a real path, not theoretical.
- Switch behaviors already have fixed defaults (003: no `--no-restart` by default); preset dir is already pinned (`~/.dockswap/presets`, WAYFINDER "Storage"). Nothing in MVP *needs* a settable knob.

Decisions:

**Lazy initialization (auto-create dirs; delete `init`).**
- No `dockswap init` subcommand. It's ceremony: an extra command, an extra "you must run init first" failure state, and a second code path, for zero payoff.
- One idempotent helper `ensureWorkspace()` runs once at startup: `FileManager.createDirectory(at: …, withIntermediateDirectories: true)` for `~/.dockswap/presets` when missing. `list`/`delete` on a fresh machine just work — no setup bar, no error to explain, and nothing is created on machines that already have (or never need) the dir.

**dockutil detection is lazy and command-scoped.**
- Resolve dockutil **only inside commands that shell out — `save` and `switch`** (`list`/`delete` never touch it, so they run identically on a dockutil-less machine). Resolution order per 002: PATH → `$DOCKSWAP_DOCKUTIL_PATH`.
- Detection is one `dockutil --version` call, cached for process lifetime; reuse 002's version gate (>= 3.0, 3.1.3 practical minimum).
- Missing/too-old: print the actionable one-liner from 002 (`dockutil not found — install with \`brew install dockutil\``) and exit 3. **No install prompt.** Prompting-and-auto-running `brew install` is a heavyweight side effect (network, Xcode CLT requirements) for a CLI whose job is dock switching; a message + exit code is the smallest actionable path and stays scriptable in both directions.

**No config file in the MVP.**
- Everything a `~/.dockswap/config.json` would hold has a working default *at the decision that matters*: dockutil = PATH (the normal case — brew puts it there); preset dir = `~/.dockswap/presets`; switch behaviors = fixed by 003. A file whose every value is the default is pure surface: parsing, schema, validation, ignore-if-missing, precedence ladder — all YAGNI.
- The one real override 002 wants (a dockutil path when it's not on PATH) becomes an **env var, not a file**: `DOCKSWAP_DOCKUTIL_PATH`. That's the lazy "config" — a `ProcessInfo.environment` read, no parser, nothing to merge or version — and it slots directly into 002's resolver.
- Defer `config.json` to post-MVP, when a genuine default override exists (e.g., a `--no-restart` default flag from 003, a switch-affinity default, a custom preset dir). Env var keeps that seam open; the future file's schema is out of scope here.

**`save` captures the live dock; manual item lists are not an MVP feature.**
- `dockswap save <name>` parses `dockutil --list` and writes the preset, exactly as 001/002 already specify. Accepting a manual item list on the CLI would ship a mini-DSL (item types, identities, folder view opts, section assignment) for zero MVP users.
- Hand-built presets remain supported without a flag: they are just JSON files in `~/.dockswap/presets/`. `cat >` or edit one, and `switch` treats it identically to a captured preset. Editing-the-file *is* the manual path; no input grammar needed.
