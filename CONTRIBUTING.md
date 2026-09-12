# Contributing to DockSwap

## Manual QA Checklist

Before releasing, verify:

1. **Preset schema**
   - [ ] Save a preset with all item types (app, folder, URL, spacer)
   - [ ] Switch to it and verify the Dock layout matches
   - [ ] Edit a preset file manually and verify it applies correctly
   - [ ] Try switching to a non-existent preset and verify the error

2. **CLI surface**
   - [ ] Run `dockswap --help` and verify all subcommands are listed
   - [ ] Run `dockswap --version` and verify it matches the release
   - [ ] Run `dockswap switch --dry-run <preset>` and verify the diff output
   - [ ] Run `dockswap list --json` and verify the output is valid JSON

3. **TUI picker**
   - [ ] Open the picker with `dockswap` and verify it shows all presets
   - [ ] Use arrow keys to navigate and verify the selection changes
   - [ ] Press Enter to apply a preset and verify it switches
   - [ ] Press q/Esc to cancel and verify the picker closes

4. **Edge cases**
   - [ ] Try switching to a preset that is already applied and verify no changes are made
   - [ ] Try saving a preset with the same name and verify it overwrites
   - [ ] Try deleting a preset and verify it is removed from the list
   - [ ] Try running `dockswap` with no presets and verify it shows a message

## Development

1. Install dependencies:

    ```sh
    brew install dockutil
    ```

2. Build and run:

    ```sh
    swift build
    .build/debug/dockswap
    ```

3. Run tests:

    ```sh
    swift test
    ```
