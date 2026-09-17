# OLED Window Guard 1.0.0

The first official stable release of OLED Window Guard for macOS 14.6 or later, supporting Apple silicon and Intel. The app is signed with Developer ID and notarised by Apple.

## Highlights

- Move windows independently on each selected display using Shift position, Swap positions, or Window Layouts groups.
- Give each display its own movement mode, interval, range, group, window limit, and size tolerance.
- Coordinate large Shift position moves across horizontal or vertical order while keeping final positions on-screen and non-overlapping.
- Keep adjacent, similarly sized windows together during swaps.
- Import built-in and custom Window Layouts groups, including the selected Window Layouts app’s padding.
- Preview safe destinations, warn before moving, cancel for recent activity on affected displays, and restore the last verified move.
- Optionally dim unfocused application windows and displays without a focused window, with independent per-display levels, delays, and fades.
- Exclude selected apps from dimming and temporarily restore brightness with Control–Option–Command–B.
- Use the menu-bar panel for per-display movement controls, movement previews, dimming switches, and brightness restoration.
- Optionally show a Dock icon with guarding and brightness commands.
- Check for stable updates from GitHub in About.

## Privacy and safety

OLED Window Guard uses public Accessibility and Core Graphics geometry APIs. It does not capture the screen, read or store typed text, collect telemetry, or use private window-server APIs. It launches paused so settings and previews can be reviewed before guarding begins.

Movement and dimming can reduce how long static content stays unchanged, but cannot guarantee prevention of OLED burn-in or image retention. Keep the display manufacturer’s pixel-care features, suitable brightness, and display sleep enabled.

## Known compatibility issue

Terminal and some other applications quantise window dimensions to character or content increments. A window can therefore extend outside a Window Layouts group zone after macOS accepts the requested size. OLED Window Guard detects this during verification, aborts the group operation, and attempts a safe rollback. Reapply a compatible layout, choose a zone matching the app’s size increments, or exclude that window from the group.

## Install

Download the DMG, open it, and drag **OLED Window Guard.app** to **Applications**. Open it from Applications, grant Accessibility access when requested, select the displays to guard, and preview movement before starting. A ZIP is also provided.

Source is publicly viewable with copyright reserved under the repository’s LICENSE.
