# OLED Window Guard 0.1.23 — Stable release

Keep your windows moving. Care for your OLED.

The first stable release brings more varied Shift position movement, a refreshed screenshot gallery, and a real Shift position demonstration.

## What changed

- Shift position uses a clamped Gaussian distribution with independent random directions. At a 50% maximum, the preferred minimum is 10%, the centre is 30%, and the maximum is 50% of the display dimensions.
- Each move measures its range from the current position, so windows can explore the display over successive moves instead of remaining tied to their original location.
- When a sampled move cannot fit, shorter and longer safe alternatives are considered up to the maximum. Crowded layouts can use moves below the preferred minimum, explained in the preview.
- Window sizes, screen containment and collision checks remain protected.
- Stable releases now check for stable updates. Previous beta builds can update to this release.
- The README includes feature screenshots and a new Shift position GIF alongside group rotation, grouped swaps and restore demonstrations.

## Download and install

Requires macOS 14.6 or later; supports Apple silicon and Intel. The app and DMG are Developer ID signed and notarized by Apple.

Download the DMG, open it, and drag OLED Window Guard.app to Applications. A ZIP and SHA-256 checksums are also provided. Existing users can use About → Check for updates. The app launches paused.

This release is free to use. Source is publicly viewable with copyright reserved. Future releases or additional features may be paid.

## Validation and limitations

80 automated tests passed, including the Gaussian distribution, repeated roaming, crowded layouts, collision safety and release selection. Two consecutive live Shift position cycles moved all three demonstration windows and verified their final positions.

Application-specific positioning rules can prevent a move. Packed displays may have no available space; Shift position cannot exchange occupied destinations as Swap positions can. Full-screen and maximised windows are skipped. Dimming and heatmaps are not included.

Movement does not guarantee prevention of burn-in. Keep your display's OLED care, suitable brightness and sleep settings enabled.
