# Preset Schema Design

## Question

What is the exact JSON structure for a dock preset?

Fields to pin:
- Item types: app (path or bundle-id), folder/stack (path + view/display/sort opts), URL, spacer
- Item identity: what survives a path change or app update? (bundle-id preferred, path fallback)
- Positions: explicit index or order-of-list? apps section vs. others (right side of divider)
- Metadata: preset name, created/modified timestamps, macOS/dockutil version snapshot
- Compatibility: forward migration when schema evolves
