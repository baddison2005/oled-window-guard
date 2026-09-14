# Validation checklist

## Automated

Run `./Scripts/test.sh`. The XCTest suite verifies:

- Window containment, touching edges, existing overlaps, immovable obstacles, exclusions and maximised/full-screen geometry.
- Percentage movement boundaries at 1× / 2× scales and monitor layouts with negative coordinates, repeated varied positions and avoidance of immediate reversal.
- Bounded drift over 500 cycles and 300 randomized crowded desktops.
- Two- and three-window swaps, dissimilar-size rejection, empty staging requirements and explicit transient-overlap opt-in.
- Group containment, ambiguous group membership, exact zone fill and Window Layouts schema/padding validation.
- Fresh intervals on restart, no repeated applying state, preference validation and stale-plan rejection when windows, focus or affected displays change.
- Exclusion of the app's transient warning/menu-bar windows, safe handling of temporary same-app matching ambiguity and isolation from unrelated activity on other displays.
- Joint Grouping 1 assignments with mixed wide/tall snapped windows over 100 seeds, empty destinations, excluded obstacles, movement caps and unequal rounded third widths on a 5120-point display.
- Activity cutoff boundaries, held mouse buttons and a quiet period longer than the warning (including an already-idle desktop that can still move).

## Live macOS checks before public release

Use disposable windows; record OS version, display mode and app versions. Automated geometry tests do not prove that every third-party app honors Accessibility writes.

The signed 0.1.2 build has completed a three-window Window Layouts group rotation, warning/Skip checks and exact warned restore on the selected LG display. See `VALIDATION.md` for the recorded bounds and remaining coverage.

1. Install the exact notarized build in Applications on a fresh macOS account. Confirm Gatekeeper opens it normally and Accessibility starts denied. Denial must leave all windows still; granting access enables discovery.
2. With two ordinary windows separated by clear space, preview and use Move after warning. Verify the notice, countdown, optional sound and Skip. Check the windows retain their sizes, focus and z-order. Try macOS Focus mode with system notifications disabled.
3. Test gentle drift for several intervals on 1× and Retina displays, including scaled modes and a monitor placed above/left of the primary. Verify the Dock/menu bar remain outside the usable area. Manually move a window and verify the drift origin resets.
4. Test a two-window and three-window swap with staging space. Tightly tile the monitor: strict swaps should skip. Explicitly enable transient overlap and confirm the final tiling is safe and sizes are preserved.
5. Maximise, full-screen, minimise and close a planned window during its countdown. Open a sheet/dialog, move another obstacle, drag a window, switch Spaces or disconnect a monitor. Each must cancel the plan safely. Test sleep, display sleep, screen lock and fast user switching. Resume with a fresh interval.
6. Try Finder, Safari, Terminal, an Electron app, a non-resizable utility and an app that rejects positioning. Verify a failure pauses guarding; check recovery messaging and actual positions.
7. Save custom groups in Window Layouts, reload, and compare the zone preview and padding. Try windows smaller than their zones, exactly filling their zones, overlapping alternative zones and mixed-shape rotation between zones. Verify the library is byte-for-byte unchanged by OLED Window Guard. Group rotation permits intermediate overlap automatically; final rectangles must remain disjoint. Reproduce the four-window Grouping 1 example, including moving the wide window to an empty compatible zone.
8. Restore a successful move. Then manually move or close a participating window and try restore again: it must refuse a stale restore. Try excluded apps as stationary obstacles.
9. Run two copies and confirm the second exits. Enable login launch after installation, sign out/in, and confirm the app starts paused. Check accessibility labels, keyboard navigation, light/dark appearance and small window sizes.
10. Keep typing as a scheduled interval expires: the warning must still appear. Continue within the final quiet-period seconds: no move, a cancellation panel appears for six seconds, and the next regular interval starts. Stop early enough and the move may proceed. Repeat with a 15-second quiet period and 10-second warning, both after recent activity and on an already-idle desktop. Confirm the warning explains the cutoff and settings explain the longer quiet period.
11. Guard only LG while typing in a focused MacBook-screen window or clicking/scrolling on that screen: the LG plan should proceed. Repeat on LG: it should cancel. Test a focused window spanning displays, unknown focus, held mouse buttons, and returning the pointer after earlier activity; attribution must stay with the original event's display. Observe physical input, since Accessibility-driven UI actions may not produce global input events.
12. Check all six built-in groups against Window Layouts, including internal padding. Run drift at 1%, 10% and 50% with enough free space, verifying variety and no immediate reversal when alternative positions fit. Completely tiled or zone-filling windows can still have no legal drift.
13. Test Shift position at 100% with an isolated window and verify destinations beyond half the screen remain on-screen. In Swap positions, place a full-height two-thirds-width window beside a one-third-width/two-thirds-height window. Allow brief overlap and verify both change sides without resizing, with varied vertical positions for the small window. Disable brief overlap: a layout without staging space must skip. Repeat with two smaller windows and verify all three can participate. Physical execution of these new layouts remains a manual compatibility check.

## Known preview limits

For 0.1.14, verify TextMate at 1703 × 1440 can move into four-point padded thirds requiring 1698 × 1436. Source recognition now allows padding plus two points, capped at 32; shrink allowance is twice padding plus two, also capped at 32. Verify the displayed allowance, separate AX size/position readbacks, strict final zone containment and exact warned Restore. Unresizable windows and changes beyond the computed allowance remain unsupported. Swap and Shift position must preserve sizes.

For 0.1.12, install both Window Layouts editions with different library padding values. With only Experimental running, Automatic must select its schema-6 library; manually selecting Standard must show its own padding. Both running or neither running with both installed must require an explicit choice. Check malformed/unavailable selected libraries do not fall back to zero padding. Change the running source or padding during a warning and verify cancellation. Confirm padded final rectangles and internal-edge gaps in built-in and custom groups. The separate libraries must remain unchanged by import.

For 0.1.10, run Move after warning in Grouping 1 with a source window extending 1–2 points beyond its rounded zone. Preflight must allow this while retaining strict screen and overlap checks. Verify group-only size reductions of at most two points per dimension, separate readback after resizing and moving, and exact original size/position after warned Restore. Test a window that refuses resizing and a window changed during the warning: these must pause/cancel safely. Source membership tolerance also applies when restoring the original rounded layout; forward final destinations remain strictly contained.

For 0.1.9, test Grouping 1 on a 5120-point-wide display with Excel at 3413 × 720 and tall windows at 1706–1707 × 1440. A middle-third source window extending one point beyond its zone must participate in rotation. Across repeated plans Excel should be able to reach both bottom wide zones when other windows can rearrange. A source discrepancy exceeding one point remains ineligible, and a destination narrower than the window remains forbidden.

For 0.1.8, reproduce four Finder windows in a two-by-two block beside a much taller Chrome window, leaving free space elsewhere on the display. With grouping enabled, preview repeated plans: Finder must preserve its relative offsets while Chrome uses independent destinations. Exclude one Finder member: the Finder block must stay still while Chrome can still move into suitable empty space. Check About's display-care and qualified legal notice, including the non-excludable consumer-rights clause.

For 0.1.7, enable **Keep adjacent similar-sized windows together** in Swap positions. Test a two-by-two block of equal windows alongside a larger window with brief overlap enabled and a window limit of at least five. Verify the block keeps its spacing; excluding one member or lowering the limit must not split it. Verify the About page's version/build and disabled update state before repository configuration. After configuring GitHub, test an actual upgrade/restart, unchanged Accessibility permission, offline checks, invalid metadata, a tampered ZIP, and an unwritable Applications folder. Confirm failed verification leaves the installed app intact and a successful replacement retains its backup.

- No public atomic multi-window positioning; brief overlap requires opt-in. Unresponsive or self-positioning apps can defeat a requested position; reversal is best effort and must not fight user changes.
- Only the current on-screen windows are considered. No movement between monitors or Spaces. Ambiguous Accessibility/WindowServer matches are skipped.
- Built-in layout groups and custom groups are supported; persistent per-app assignments and Window menu actions are not. No automatic layout resizing is performed.
- No presentation/screen-sharing detection in this preview. Pause guarding before a presentation, game, screen share or recording. Full-screen and maximised windows themselves are always skipped.
- The check interval is global for all selected monitors. Settings save immediately. Automatic guarding is not restored on launch.
