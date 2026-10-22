# Collapse icon

`collapse.svg` is the only icon source: graphite, ash and a small amber cursor.
The mark stays inside the central 80% maskable safe circle. Platform masks supply
the outer shape; the source has no baked-in rounded corners or transparent edges.

On macOS, run `swift tool/generate_icons.swift` from the repository root.
The script uses system AppKit, reads iOS sizes from its existing asset catalog,
and replaces the existing iOS, Android and web PNGs, including the favicon.
All outputs are opaque RGB, including the 1024px App Store icon. No package or
external renderer is required. The SVG is a build source, not a runtime asset.
