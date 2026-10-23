# OLED Window Guard 1.2.0

Stable release · build 45. Includes signed and Apple-notarised universal macOS app downloads for Apple silicon and Intel.

Install using the DMG: open it and drag OLED Window Guard to Applications. A ZIP download and SHA-256 checksums are also provided.

- Matching Dock and menu-bar panel actions for connected monitors: Move now, Dim now and Restore brightness.
- Pause all guarding cancels a pending warning, pauses both guards and restores brightness without changing settings.
- Dim all available monitors includes their application windows at each monitor's configured display-dimming level.
- Restore one monitor's brightness and restart its delays without changing another monitor's dimming or timers, or restore all available monitors together.
- A single Restore last move action names the monitor of the last successful move. Existing warning and safety checks remain in effect.
- Monitor actions use display UUIDs and names, distinguish identical display names, and reject disconnected or deselected targets without redirecting to another monitor.
- Clicking Dock icons or using their context menus preserves dimming. Explicit brightness restoration and clicking inside application windows or empty desktop space still clear it.
- Whole-display dimming now includes the Dock. Context menus remain readable; window-only dimming leaves the Dock unchanged.

All-monitor actions apply to connected monitors selected for dimming. Move now requires movement guarding to be running; Dim now requires dimming guarding to be running. The app continues to launch with both guards paused.
