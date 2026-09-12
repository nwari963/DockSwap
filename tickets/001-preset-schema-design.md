# Preset Schema Design

## Question

What is the exact JSON structure for a dock preset?

Fields to pin:
- Item types: app (path or bundle-id), folder/stack (path + view/display/sort opts), URL, spacer
- Item identity: what survives a path change or app update? (bundle-id preferred, path fallback)
- Positions: explicit index or order-of-list? apps section vs. others (right side of divider)
- Metadata: preset name, created/modified timestamps, macOS/dockutil version snapshot
- Compatibility: forward migration when schema evolves

## Resolution

**Design decisions**

- **Identity**: every dockable item option (app/folder/URL) carries `bundleId` (best-effort) *and* `path`. `bundleId` is the primary identity (survives path moves + app updates); `path` is the authoritative apply target and the fallback identity when `bundleId` is absent. This mirrors dockutil and Dock semantics.
- **Positions**: order-of-list, not explicit indices. Two arrays encode the Dock's two sides:
  - `apps` → items left of the divider,
  - `others` → items right of the divider (mounted volumes, downloads, trash, etc.).
  Sparse indices invite drift and merge conflicts; a plain array is the shortest correct representation and maps 1:1 to dockutil's ordered `--add`/`--remove` calls.
- **Item types**: discriminated by `type`. Each item is the union of a few fixed shapes (see schema). `spacer` has no identity fields.
- **Folder options are optional**: `view`/`display`/`sort` are omitted when unknown (capture from `--list` cannot see them — ticket 002 fidelity limit); dockutil applies its defaults on add. Writer emits them only when known (hand-authored or future CFPreferences capture).
- **Metadata**: preset `name` (file-name/label), `createdAt`/`updatedAt` (ISO-8601), `schemaVersion` (integer, current = `1`), `dockutilVersion` + `macOSVersion` snapshot. No settable `position`.
- **Compatibility**: forward migration is driven by `schemaVersion`. On mismatch, the tool refuses or upgrades in place; unknown fields are ignored and preserved on rewrite (never silently dropped) so future writes from an older client can't destroy data. `bundleId`/`path` both present gives lenient downgrade — an older reader can still apply via `path` if it ignores `bundleId`.

### JSON Schema (`preset-v1`)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://dockswap.local/preset-v1.json",
  "title": "DockSwap Preset",
  "type": "object",
  "required": ["name", "schemaVersion", "apps", "others"],
  "additionalProperties": false,
  "properties": {
    "name":         { "type": "string", "minLength": 1 },
    "schemaVersion":{ "const": 1 },
    "createdAt":    { "type": "string", "format": "date-time" },
    "updatedAt":    { "type": "string", "format": "date-time" },
    "dockutilVersion": { "type": "string" },
    "macOSVersion": { "type": "string" },

    "apps":   { "type": "array", "items": { "$ref": "#/definitions/dockItem" } },
    "others": { "type": "array", "items": { "$ref": "#/definitions/dockItem" } }
  },

  "definitions": {
    "identity": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "bundleId": { "type": "string" },
        "path":     { "type": "string" }
      },
      "anyOf": [ { "required": ["bundleId"] }, { "required": ["path"] } ]
    },

    "app": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type", "identity"],
      "properties": {
        "type": { "const": "app" },
        "identity": { "$ref": "#/definitions/identity" }
      }
    },

    "folder": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type", "path"],
      "properties": {
        "type":    { "const": "folder" },
        "path":    { "type": "string" },
        "view":    { "enum": ["grid", "fan", "list", "auto"] },
        "display": { "enum": ["folder", "stack"] },
        "sort":    { "enum": ["name", "dateadded", "datemodified", "datecreated", "kind"] }
      }
    },

    "url": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type", "title", "url"],
      "properties": {
        "type":  { "const": "url" },
        "title": { "type": "string" },
        "url":   { "type": "string", "format": "uri" }
      }
    },

    "spacer": {
      "type": "object",
      "additionalProperties": false,
      "required": ["type"],
      "properties": { "type": { "const": "spacer" } }
    },

    "dockItem": {
      "oneOf": [
        { "$ref": "#/definitions/app" },
        { "$ref": "#/definitions/folder" },
        { "$ref": "#/definitions/url" },
        { "$ref": "#/definitions/spacer" }
      ]
    }
  }
}
```

### Example (`~/.dockswap/presets/dev.json`)

```json
{
  "name": "dev",
  "schemaVersion": 1,
  "createdAt": "2026-09-06T14:30:00Z",
  "updatedAt": "2026-09-06T15:00:00Z",
  "dockutilVersion": "3.1.1",
  "macOSVersion": "14.5",

  "apps": [
    { "type": "spacer" },
    { "type": "app", "identity": { "bundleId": "com.googlecode.iterm2", "path": "/Applications/iTerm.app" } },
    { "type": "app", "identity": { "bundleId": "com.microsoft.VSCode", "path": "/Applications/Visual Studio Code.app" } },
    { "type": "folder", "path": "~/Projects", "view": "grid", "display": "stack", "sort": "name" },
    { "type": "app", "identity": { "path": "/Applications/Downloaded App.app" } }
  ],

  "others": [
    { "type": "folder", "path": "/Applications", "view": "fan", "display": "folder", "sort": "name" },
    { "type": "url", "title": "Home", "url": "https://example.com/" }
  ]
}
```

### Notes

- `spacer` inside `apps` left of the divider, and `apps`/`others` are both allowed to be empty (`[]`) — an empty side means "no items here".
- **Capture rule**: `--list` rows with empty label AND empty url AND empty bundleId are captured as `{ "type": "spacer" }`; spacers are positional, not identity-matched (003). A capture fixture from a real `dockutil --list` run must be recorded before the parser is frozen.
- Missing running-dock edge cases (trash, recent apps, minimized dock) are *not* captured; they're preserved automatically by dockutil during switch and are handled in [002-dockutil-integration.md](002-dockutil-integration.md) / [003-switch-semantics.md](003-switch-semantics.md).
- Migration: bumping `schemaVersion` and adding required fields is a breaking change (requires a v1→v2 migrator); additive optional fields keep `schemaVersion` unchanged.
- Strictness split: the schema (with `additionalProperties: false`) is the contract for files **dockswap writes and validates as v1**; the *reader* is lenient — it ignores and preserves unknown fields on rewrite within the same `schemaVersion`, so a future `schemaVersion` bump or a hand-edited file never gets silently truncated.
