# OLED Window Guard 1.1.1

Fixes window and display dimming when switching macOS Desktops (Spaces).

- Switching Desktops restores brightness on the affected monitor and restarts its window and display dimming delays.
- Previous desktop-click brightness holds and manual dimming overrides no longer carry into a different Desktop.
- A fresh dimming overlay is created for the newly visible Space; stale window focus from the previous Space is rejected.
- Other monitors retain their existing dimming state and timers. Switching MacBook Desktops leaves LG dimming unchanged.

Verified through 142 automated tests and user testing on the LG and MacBook displays.

Requires macOS 14.6 or later. Universal Apple silicon/Intel app, signed with Developer ID, notarised by Apple, and supplied as a drag-install DMG and ZIP. Existing settings are retained; both guards start paused when the app launches.
