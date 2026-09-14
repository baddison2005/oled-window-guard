# OLED Window Guard 0.1.20 — Public beta

First public beta for macOS 14.6 or later, supporting Apple silicon and Intel.
The app is signed with Developer ID and notarised by Apple.

- Shift windows within a user-selected movement range.
- Swap differently sized windows while preserving their sizes.
- Keep adjacent, similarly sized windows together during swaps.
- Rotate windows through Window Layouts groups, including imported padding.
- Preview safe destinations, give advance warnings, skip moves during activity
  on affected displays, and restore the previous arrangement.
- Check for and install verified GitHub beta updates from About.
- Allow Finder window animations to settle before validating the next move.
- Explain which application or safety check caused a rollback.

Download the macOS DMG, open it and drag OLED Window Guard.app onto the
Applications shortcut. A ZIP is also available. Grant Accessibility access, select a display and preview moves
before starting. The app launches paused.

The beta is free for evaluation and testing. A future stable version may be paid.
Source is publicly viewable with copyright reserved; see LICENSE.

## Known limitations

Some applications enforce their own window sizes or provide incomplete
Accessibility support. A move may be skipped, or a failed move may trigger a
best-effort rollback. Packed layouts may have no safe destinations. Group swaps
can briefly overlap during placement. Full-screen and maximised windows are
skipped. Dimming and exposure heatmaps are not included in this beta.

Movement varies static content placement; it does not guarantee prevention of
burn-in. Keep manufacturer OLED care, suitable brightness and display sleep
settings enabled.

## Updates

This build follows public beta releases. About → Check for updates performs a
manual check. Pause guarding before installing an update. Earlier local preview
builds have no repository configured and need this first beta installed manually.

## Validation

74 automated tests passed, including beta/stable release selection and existing
movement geometry tests. Please report application-specific issues with your
macOS version, display scaling, movement settings and app version.
