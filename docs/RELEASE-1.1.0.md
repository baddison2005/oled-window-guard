# OLED Window Guard 1.1.0

Live previews and independent movement and dimming controls for macOS. Signed with Developer ID and notarised by Apple, with a drag-install DMG and ZIP download.

- Live Overview monitor layout with current application window positions, focus and proposed destination arrows. Geometry updates while Overview is open.
- Preview safe moves retains its exact proposal for the next manual or automatic move on that display while the desktop and movement settings remain valid.
- Geometry changes clear stale previews or cancel a pending warning. Existing quiet-period, Accessibility, collision and read-back checks continue to apply.
- Empty-desktop clicks can either restart independent window/display dimming timers or keep the clicked display bright until an application window there is clicked. Other monitors retain their own state.
- Independent movement and dimming Start/Pause buttons and status lights. Both guards start paused on launch with settings retained.
- Independent movement/dimming commands in the menu-bar panel and Dock menu.
- Dock shortcuts for Move now and Restore last move, preserving advance warnings and safety checks.
- Dim monitor now in the Dock and panel, with a named display target selected in the panel. While dimming guarding is running, apply the configured monitor dimming level immediately to that screen and its windows, including the focused window. Clear it by interacting on that screen, pausing dimming or restoring brightness. Excluded apps and OWG controls remain bright.

Requires macOS 14.6 or later; supports Intel and Apple silicon. Uses public Accessibility and Core Graphics metadata without screen capture or typed-text collection.
