# Switch Semantics

## Question

What exactly happens on `dockswap switch <name>`?

- Diff-based apply (remove only what's not in target, add missing) vs. teardown-and-rebuild
- Should switching close running apps not in the target preset? (DockFlow does)
- Should it launch apps in the target preset? (DockFlow does)
- Missing apps on disk: skip with warning, or fail?
- Preserve: recent apps section, trash, minimized windows?
- Order: remove → add → single dock restart
