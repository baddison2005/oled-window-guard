# Version 1.0.0 — Official stable release

- Promoted the complete, tested 0.1.35 feature set to version 1.0.0 (build 37).
- Terminal can quantise its window dimensions to character-cell increments and extend outside a requested Window Layouts zone. OLED Window Guard detects the mismatch, aborts the group move and safely restores completed steps. This application-specific compatibility limitation is documented for the release.
- All 130 automated tests passed on the 1.0.0 versioned source.
- The universal release app and DMG were signed with Developer ID, accepted by Apple notarisation, stapled, and validated. Gatekeeper accepted the app as a notarised Developer ID build; the DMG checksum verified successfully.
- Distribution artifacts: `OLED-Window-Guard-1.0.0-macOS.dmg`, `OLED-Window-Guard-1.0.0-macOS.zip`, the ZIP digest, and `SHA256SUMS-1.0.0.txt`.

# Local 0.1.35 — Automatic deadlines and movement diagnostics

- 130 tests passed, including repeated polls after an expired deadline, transition to warning, retention of other display deadlines, Dock icon preference, single-window swap explanation/shift, and three-column Cintiq group rotation using captured geometry.
- Root cause of automatic stall: sync rebuilt a deadline using a newer Date than the tick's sampled time, keeping even an overdue clock just beyond the due comparison. The clock now receives the original absolute deadline.
- Initial Cintiq geometry showed Terminal overlapping Excel by 4 points. Updated user arrangement has three non-overlapping columns and the geometry test moves all three. Overlap safety has not been relaxed.
- MacBook first showed maximised Chrome; the user switched to a lone TextEdit window while that display was configured for Swap positions. The user subsequently selected Shift position. Preview now explains the missing swap partner and recommends Shift position.
- Overview lists exclusions/overlaps. Menu panel has expandable display controls, and About offers an optional Dock icon with guarding/brightness actions.
- Signed/notarized universal app and DMG validated; 0.1.35 (build 36) installed. Live automatic guarding reached the MacBook warning, moved TextEdit successfully, incremented the moved-window count to 1 and restarted that display’s timer. LG completed its scheduled check and restarted its timer while its overlapping ChatGPT windows correctly prevented movement. Guarding was paused after verification.
- The current Cintiq columns do not fit Grouping 1: its third-width zones are only two-thirds height. Changed only the Cintiq profile to built-in Thirds; live preview then reported “Ready to move 3 windows.” This was a preview check, not a live three-window move.
- Menu panel visibly lists all three display disclosure controls and dimming switches. About visibly offers the Dock icon option, left off. Dock preference persistence passed automated testing; Dock menu interaction has not been live-tested.

# Local 0.1.34 — Independent movement and Dock obstacles

- 125 tests passed, including independent display settings/persistence, separate deadlines, completion/restart isolation, interval changes, disconnection/reconnection, pause, and Dock desktop versus real Dock geometry.
- Snapshot filtering ignores screen-sized Dock desktop/transition surfaces using the already verified classifier. Real Dock regions and NSScreen.visibleFrame still constrain placement.
- Each display has custom movement settings and a timer. Automatic operations are serialised, snapshot their movement configuration for placement/recovery, and restart only their own interval. Undo retains the operation’s original movement settings.
- Overview manual preview/move target selector; per-display summaries; Movement page per-monitor settings. Shared safety settings and layout-library source are explicit.
- Public NSWorkspace Space notification supplies neither identifiers nor per-display details. No private APIs or unreliable automatic Space profiles added; settings apply to each monitor’s visible Space.
- Signed/notarized app and DMG validated; installed 0.1.34 (build 35). Live UI showed a custom MacBook 4-minute interval independent of the LG 3-minute interval, with simultaneous countdowns of 239s and 179s. Temporary settings removed and original LG-only guarding restored. MacBook snapshot count dropped from two windows to one after filtering the Dock desktop surface. No manual window moves were triggered during this check.

# Local 0.1.33 — Monitor settings, exclusions and brightness restore

- 119 tests passed, including per-monitor selection migration/persistence, custom settings and master switches, bounds, independent monitor timers, visible-only exclusions under both dimming modes, separate movement exclusions and brightness restore timing.
- Monitor selection migrates from movement selection once and is then independent. Each monitor owns its delay/fade state. Master toggles apply to all profiles.
- Global Control–Option–Command–B uses a registered Carbon hotkey with conflict reporting and an enable switch. The same restore action is available in the app and menu; it resets timers immediately and guarantees five seconds of brightness before fades may begin.
- App exclusions use bundle IDs and exempt visible regions only, including during whole-display dimming. Other foreground windows continue to dim even over excluded windows.
- Signed/notarized app and DMG validated; 0.1.33 (build 34) installed. UI verified LG-only selection migration with Built-in Display and Cintiq off, custom LG level changes independent of defaults, restoration of original settings, and the Restore brightness button. User confirmed Control–Option–Command–B restores brightness and restarts dimming delays while another app is active.

# Local 0.1.32 — Finder virtual desktop focus

- Instrumented a user Control-arrow reproduction. Finder reported AX focused geometry `(-1239, -2160, 5120, 3856)`, spanning both monitors. This made the selected LG display ineligible and reset its activation delay despite correct MacBook interaction scope.
- Finder focus now requires a matching ordinary layer-zero Finder window from the desktop-excluded CG window list. The virtual desktop is treated as desktop focus; real and spanning Finder windows remain valid.
- Regression tests cover the captured virtual-desktop geometry, retained 30-second eligibility, and genuine Finder/spanning window focus.
- User confirmed Control-arrow switches on the MacBook now leave the LG dimmed. The live trace confirms Finder virtual-desktop focus resolves to nil, the MacBook scope remains active, and LG eligibility/readiness stay intact.
- Final 0.1.32 app and DMG signed, notarized and validated; installed locally.
- 111 tests passed with diagnostic tracing removed from final source. Temporary diagnostic capture disabled; local logs are excluded from Git.

# Local 0.1.31 — Space transition timing

- Captured window geometry during the reported Control-arrow reproduction. Dock created sliding layer-4 surfaces sized 5120×2160 at x=-4193, 1183 and 3871; the previous overlap-based filter missed these partially visible surfaces. Finder became frontmost during the transition and the LG overlay disappeared.
- Classify Dock desktop/transition surfaces by their full size, including partially off-screen surfaces. A regression uses the captured geometry.
- Anchor interaction scope immediately on Control-left/right, and when moving Dock surfaces first appear, before delayed Space notifications or transient Finder focus can reset eligibility timers.
- Overlay panels explicitly use stationary collection behaviour so Mission Control does not treat them as transient floating panels.
- 109 tests passed. Signed/notarized app and DMG validated; 0.1.31 (build 32) installed locally. User testing found the delay still reset; the subsequent 0.1.32 diagnostic identified Finder virtual-desktop focus as the remaining cause.

# Local 0.1.30 — Desktop and Space interaction tracking

- 108 automated tests passed, including stale Finder focus after desktop clicks, persistent display scope across polls, Space changes preserving dimming delay/fade progress, return to genuine window interaction, and Dock desktop-surface filtering.
- Desktop click location now overrides stale AX focus until the next window/keyboard interaction. Space notifications anchor focus to the display under the pointer, rejecting windows reported on another display. Control-arrow navigation retains the anchor.
- Live CG metadata revealed a screen-sized Dock layer-20 surface. These desktop/transition surfaces are excluded from click hit testing and overlay masks; ordinary Dock/menu panels remain protected. Missing window-list data preserves existing dimming instead of clearing timers.
- Physical two-display desktop/Space behaviour still requires user confirmation; automated tests reproduce the stale-focus inputs rather than synthesising macOS Spaces.

# Local 0.1.29 — Display-local dimming and fades

- 103 tests passed before packaging, including display-local desktop scope, independent fades, retained fade progress on unrelated displays, zero fade, settings rounding/persistence, focused-window masks and blending window dimming into display dimming without a flash.
- Removed the all-display dimming reset on Space changes. Missing AX focus is scoped using recent clicks and the last focused window, rather than globally brightening windows. Momentarily unavailable frontmost application preserves existing overlays.
- Separate 0–3 second fade-in sliders in 0.5-second increments; defaults remain immediate. Returning to focus clears dimming promptly. Fade refreshes use the existing lightweight timer at 0.05 seconds while animating or moving.
- Installed signed and notarized 0.1.29 (build 30); app and DMG validation passed. Verified both fade sliders increment by 0.5 seconds in the installed app, then restored their immediate defaults. Existing 40% levels and 0s/30s activation delays were retained.
- Packaging uses Xcode’s lipo and checks each architecture separately for compatibility with the updated toolchain.
- Local testing only. Physical multi-monitor desktop/Space behaviour still needs user verification.

# Local 0.1.28 — Continuous dimming during movement

- Live move test moved all three LG windows and verified final positions with existing dimming settings retained. Restore then returned all three windows to their original positions, verified by the app. About text was checked in the installed app.
- 96 automated tests passed, including moving-window masks with retained activation-delay eligibility.
- Dimming remains active during warnings, movement and restore/recovery. Moving-window geometry is refreshed after position writes and every 0.1 seconds while placement is in progress; normal polling remains half-second.
- Warning/control cut-outs and exclusion of dimming overlays from movement snapshots remain in place. Sleep, session, update and unavailable-focus suspension are unchanged.
- About now describes window/display dimming, independent levels and delays, and menu-bar controls.
- Local testing build; no GitHub commit or release.

# Local 0.1.26 — Dimming delays and menu controls

- 95 tests passed, including independent effect delays, per-window resets, zero-delay activation, delay changes, suspension resets, persistence and pending-window occlusion.
- Each window and display has its own continuous-eligibility timer using monotonic system uptime; enabling a mode does not borrow elapsed time from the other mode.
- Menu panel shows the selected movement mode and explicit On/Off state for both dimming effects, with editable controls bound to the same saved preferences as the dashboard.
- Window dimming clears when no application window has focus; documentation qualifies the desktop-click behaviour when separate display dimming is enabled.
- Local build only; no commit or GitHub release.

# Local 0.1.25 — Window and display dimming

- Live LG checks verified window-only dimming, whole-display dimming and turning both options off. Focus-switch behaviour across third-party apps still needs user testing.
- 90 automated tests passed: focused-window masking, background occlusion, non-stacking amounts, whole-display priority, system-control holes, spanning focus, negative display coordinates, defaults and persistence/clamping.
- Uses public window metadata and Accessibility focus only. Click-through, nonactivating overlay panels are excluded from movement snapshots.
- Independent opt-in switches use selected monitors; dimming works while movement is paused. Hides for warning/move/sleep/session/update/permission conditions.
- Rectangular bounds and a half-second polling interval are explicit limitations; the amount is overlay opacity, not calibrated luminance.
- Public release remains 0.1.23 pending local testing of 0.1.24 reordering and 0.1.25 dimming.

# Local 0.1.24 — Coordinated Shift position

- 83 automated tests passed, including packed unequal-width horizontal exchanges, vertical exchanges, disabled axes, maximum range, exclusions, window limits and settings migration.
- Optional horizontal/vertical order changes trigger on larger Gaussian samples. Candidate distances follow the existing Gaussian preference within 20–100% of the maximum; a plan requires at least one move of 40% or more of that maximum.
- Final containment and non-overlap remain mandatory. Enabling an axis permits brief overlap during coordinated placement, explicitly described in the UI. The existing controller checks the complete final layout and uses its existing rollback handling.
- Public release remains 0.1.23; this build is for local testing.

# Stable 0.1.23 — September 15, 2026

- 80 automated tests passed with the built bundle configured for stable updates.
- Developer ID signed universal app and DMG passed Apple notarization, stapling and package verification.
- Two live Shift position cycles each moved all three prepared LG windows; all final positions verified. The movement code is unchanged from tested 0.1.22.
- Added author-provided screenshot gallery and a Shift position GIF with completed moves and shortened idle time.

# Local beta 0.1.22 — Roaming Shift position

- 80 tests passed. Successive shifts can leave the original area while respecting the maximum distance on every move. A full-height window can reach an exact distant slot beyond its old anchor limit across 30 seeds.
- Shift position measures its range from the current position. Group-zone drift retains its original anchor limits.
- Fallback sampling now covers larger distances up to the maximum as well as smaller distances. Gaussian sampling remains the first preference; containment, sizes and collision checks remain strict.
- This fixes a planner restriction that could confine TextMate; the user's specific live arrangement still needs testing.

# Local beta 0.1.21 — Gaussian Shift position

- 79 tests passed, including 100,000 deterministic distribution samples, capped tails/mean, direction diversity, crowded-space minimum relaxation, fully blocked layouts, and multi-window collision/maximum-distance checks. Existing repeated-excursion and reversal tests also pass.
- Replaced the furthest-of-random-shortlist selection in Shift position with Gaussian magnitude sampling and independent random directions. Kept group-zone drift unchanged.
- Preferred range is 20–100% of maximum, centred at 60%, with sigma 80%/3. Initial tails clamp to the boundaries. Logical-point rounding and safety filtering mean successful moves need not reproduce the exact sampling distribution.
- Intermediate and final layouts remain collision-free through sequential planning against the updated world. Limited space can relax the minimum, never the maximum; preview explains smaller moves.
- No settings migration is needed; the existing maximum range and original-position anchors are retained.

# Public beta 0.1.20 — release configuration

- Live Grouping 1 rotation moved all four prepared windows (Finder, Excel, TextMate and PowerPoint), verified final positions, and restored all four original positions. Recorded the complete warning and movement for the release GIF.

- Added an explicit Config/Info.plist merged with generated bundle metadata. Xcode had omitted arbitrary INFOPLIST_KEY updater settings from the generated plist. Both tests and packaging now require the actual built bundle to contain the official repository and beta channel.
- The 74-test suite includes the built-bundle check. Movement logic is unchanged from the successful 0.1.18 live swap and restore.

# Public beta 0.1.19 — September 14, 2026

- Live grouped swap on the LG display moved all five windows (four adjacent Finder windows plus Firefox). All final positions verified; the Finder cluster retained its relative arrangement and window sizes.
- Warned restore returned all five windows to the original arrangement and passed final verification. The 450 ms settling interval resolved the observed Finder-animation rollback.
- Updated the sidebar, Overview description and About wording to “Keep your windows moving. Care for your OLED.” and the requested explanation of shifting/rotating content.
- The universal app and drag-install DMG were signed, notarised and stapled. The DMG checksum, embedded app signature/ticket and Applications shortcut were verified by a read-only mount.
- Public source is copyright reserved at the author's request; no open-source reuse licence is asserted.

# Public beta validation — September 13, 2026

## Version 0.1.18 — beta updates and Finder animation settling

- Connected manual update checks to `baddison2005/oled-window-guard`, with an explicit beta channel that accepts GitHub prereleases. Draft releases, invalid numeric versions, unexpected asset URLs and missing digests remain rejected. Stable-channel checks still exclude prereleases.
- 73 tests passed before release packaging, including newest-version selection independent of release ordering, draft filtering, and prerelease asset validation.
- Recording the prepared five-window Finder/Firefox layout exposed a timing issue: Accessibility reported the destination while WindowServer bounds traversed intermediate positions for roughly 300 ms. The previous 120 ms wait misidentified this animation as an external move. Placement/recovery waits are now 450 ms, followed by the same strict geometry, reference, activity and final collision validation.
- Rollback notices now identify the affected application or safety condition without logging document titles or content.
- User reported successful TextMate group rotation after reboot with larger padding and no padding before this public beta preparation.

## Earlier preview validation — September 6–12, 2026

## Versions 0.1.14–0.1.15 — padding-aware resize allowance

- Imported padding 4 requires TextMate (1703 × 1440) to shrink up to 5 points in width and 4 in height for Grouping 1. Group-only shrink allowance is now min(32, 2 × padding + 2) per dimension, displayed in the UI. Source recognition allows min(32, padding + 2). Final destinations and overlaps remain strictly checked; reverse operations preserve the original allowance.
- 72 tests passed, including 50 plans using the observed four-window layout, all four participants, padded final containment, bounded size changes and exact reverse geometry. Added partial dimension response/recovery cases.
- 0.1.14 live move encountered TextMate accepting width 1698 but retaining height 1440 after a request for 1436. Other windows returned to their original geometry; TextMate initially remained five points narrower. 0.1.15 adds one retry only after full affected-desktop, handle and activity validation, recording bounded partial resize geometry for recovery. This retry has not yet been validated live on TextMate.
- Inspecting TextMate via computer use introduced a 66 × 20 screen-sharing indicator over it, plus a computer-use pointer overlay; these are rightly treated as obstacles and prevent a clean retry test. Manual edge recovery returned TextMate to width 1702 (one point below its initial 1703), with its original origin (-1239, -1440) and height 1440. Remaining live verification requires ending TextMate's computer-use sharing. App left paused.
- Installed 0.1.15 / build 16, universal signed and notarized. Apple accepted `06a7e2be-8f47-48d3-9262-a3fbc788c29a`; installed signature/Gatekeeper checks passed. Backups retained at `/private/tmp/OLED Window Guard 0.1.13 before-padding-resize.app` and `/private/tmp/OLED Window Guard 0.1.14 before-resize-retry.app`.

## Version 0.1.13 — imported padding label

- Overview in group mode and Layout groups now share a dynamic imported-padding description, replacing the static four-point example. Unavailable libraries show an unavailable message.
- Release build succeeded; universal Developer ID signing, notarization (`8d1bc65a-b853-47d3-98b0-a93eb5a8319c`), stapling and installed Gatekeeper/signature checks passed. Version/build: 0.1.13 / 14.
- Installed Overview verified “Window Layouts padding: 4 logical points per internal edge (8-point gap between adjacent padded zones), read from the active layout source.” App remains paused. UI-only change; no new movement tests or live moves were needed. Backup: `/private/tmp/OLED Window Guard 0.1.12 before-padding-label.app`.

## Version 0.1.12 — Experimental source and padding

- Diagnosed fixed Standard-library import: Standard schema 5 had padding 0; Experimental schema 6 had padding 4 in its separate Application Support folder. Schema 6's imported zone/group/padding fields retain the same representation; unrelated experimental settings are ignored.
- Added persisted Automatic/Standard/Experimental selection. Automatic chooses a sole running edition, then a sole installed edition if none runs; ambiguity requires explicit selection. A failed library read no longer supplies built-in zones with zero padding. Pending group moves compare source identity as well as group geometry/padding.
- 70 tests passed, including source selection/ambiguity, persisted defaults, schema 6, four-point internal padding and padded final group positions.
- Installed 0.1.12 / build 13, universal signed release; notarization accepted `e9b8c72d-444b-443a-99ef-5790e789c6e0`. Installed signature and Gatekeeper checks passed. Backup: `/private/tmp/OLED Window Guard 0.1.11 before-layout-source.app`.
- Live UI verified Automatic selected Experimental with 4-point padding and 6 built-in/2 custom groups. Manual Standard override showed its 0-point padding and own groups. Returned to Automatic, app paused. No physical moves were executed in this validation; geometry coverage is automated.

## Version 0.1.11 — grouping status and action help

- Reported cluster splitting corresponded to `keepSwapGroups: false` in the saved preferences and the unchecked live Movement toggle. Re-enabled it through the UI. No planner change was needed. Overview now shows On/Off grouping status with a Movement settings shortcut.
- Added visible descriptions and hover help for immediate Move after warning countdowns and warned Restore of previous positions and adjusted sizes, with cancellation conditions.
- Build and five grouped-swap regression tests passed. Universal Developer ID release, version/build 0.1.11 / 12; notarization accepted `8b491d5b-e279-4535-a783-6b14739385a8`. Installed signature and Gatekeeper checks passed. Backup: `/private/tmp/OLED Window Guard 0.1.10 before-control-help.app`.
- Installed UI verified grouping On and both descriptions. Live warned swap moved five windows. Finder IDs 113/112/115/114 each translated by (-3413, +720) points, preserving their 2×2 arrangement and 853–854 × 720 sizes; Chrome moved independently to the right side. Warned Restore verified all five original positions. App left paused with grouping enabled.

## Version 0.1.10 — group execution and bounded resizing

- Fixed a mismatch left in 0.1.9: source-zone recognition allowed rounding but the post-warning `safePositions` check required exact zone containment. Both now allow up to two points of source edge discrepancy, with strict screen containment and overlap checks. Forward final destinations remain exactly contained; Restore may return to the original rounded source.
- Group rotation can shrink AX-resizable windows by at most two logical points per dimension. Each resize and position write is a separate readback-verified step, with reversible size metadata. Other movement modes preserve size. Failed or partial writes enter conservative recovery.
- 65 tests passed, including source preflight versus final containment, collision rejection, bounded source discrepancies, unavailable resizing, excessive shrink rejection, and reversible size operations.
- Live installed-app test completed the warning and reported “Moved 4 windows. All final positions verified.” Excel moved to (468, -720), size 3413 × 720 (bottom-right). TextMate moved to (468, -2160), narrowing from 1707 to 1706 points, height 1440. Finder windows moved to (-1239, -1440), size 1707 × 1440, and (2175, -2160), size 1706 × 1440. Warned Restore then reported “Restored 4 windows. All original positions verified.” This includes size readback; app left paused.
- Version/build: 0.1.10 / 11. Universal Developer ID build; notarization accepted `791158c3-bda9-4034-83fd-be8f9dc4b0d2`; stapled ticket and installed signature/Gatekeeper verification passed. Prior app retained at `/private/tmp/OLED Window Guard 0.1.9 before-rounding-resize.app`.
- ZIP SHA-256: `ba4cdba7de750bc19c6f17a10e3fecc00204948a79e5a56e7c4c2a5233c01b1a`.

## Version 0.1.9 — Grouping 1 source rounding

- Current LG geometry showed TextMate at x=468, width=1707, while its middle-third source zone ends at x=2174 (width=1706). Strict source containment kept it stationary, blocking Excel's bottom destinations.
- Reproduction before the fix moved only three windows and found neither bottom Excel destination across 100 seeds. With one-point source recognition tolerance, all four windows moved in each tested plan and both bottom-left and bottom-right Excel destinations appeared. Destination containment, size preservation and final non-overlap were verified. Additional tests reject source discrepancies over one point and undersized destinations.
- Full suite: 63 tests passed. Version/build: 0.1.9 / 10. Universal signed build; Apple notarization accepted `3fe38f42-5d10-4ea3-a91c-621da563e8c8`; stapling and installed Gatekeeper/signature validation passed.
- ZIP SHA-256: `260c77442c47235e45f75a5930c4da3460a61e38ef5da098ef8d22844e0fa0f0`.
- Installed with backup at `/private/tmp/OLED Window Guard 0.1.8 before-group-rounding.app`. Accessibility and preferences retained. Live preview changed from three to four safe moves; app left paused, without executing physical moves.

## Version 0.1.8 — independent grouped destinations

- Read-only LG geometry confirmed four Finder windows of 853–854 × 720 points beside Chrome at 1706 × 2160 points. Size grouping already kept Chrome separate; the old swap destination filter required overlap with another block's original space. Grouped mode now also considers empty destinations and permits an individual block/window to move without a swap partner.
- 61 tests passed. Thirty seeded plans using these LG measurements preserved Finder offsets, moved all five windows safely, and produced varied Chrome/Finder relative positions and vacant-space destinations. Excluding a Finder member kept the block stationary while Chrome moved independently. A single group without a swap partner also passed.
- Version/build 0.1.8 / 9. Apple notarization accepted: `02b52086-f399-47ce-883b-76e8fdea6026`. Universal build, stapled ticket, installed signature and Gatekeeper checks passed.
- ZIP SHA-256: `c8829b1a6c7dc201c085b78dad7e6f122dd784f31c5f53ce3505423e616a0ab1`.
- Installed with 0.1.7 backup at `/private/tmp/OLED Window Guard 0.1.7 before-independent-groups.app`. Accessibility and settings retained. Live preview reported five safe moves; no physical movement was executed. About verified version/build, display-care guidance and qualified legal notice. App left paused.

## Version 0.1.7 — September 10, 2026

- 59 automated tests passed, including grouped swap spacing, size preservation, final collisions, exclusions and window limits; version comparison, release asset validation and archive path/link rejection.
- The actual packaged release ZIP passed the updater's archive preflight.
- Version/build: 0.1.7 / 8, universal Developer ID build. Apple notarization accepted: `04bda835-1a25-4201-9d02-bc2ae9c86490`. Stapling and Gatekeeper assessment passed.
- ZIP SHA-256: `f3d2ecca3777179fbd806c7cc646df927ea0ee588a80f9076103714abf381874`.
- Installed in Applications; previous 0.1.6 copy retained at `/private/tmp/OLED Window Guard 0.1.6 before-group-about.app`. Installed signature and Gatekeeper verification passed. Relaunched paused with Accessibility intact.
- UI inspection confirmed the new tagline, About page with version/build and disabled unconfigured update controls, and the optional grouped-swap checkbox (off by default). Existing settings retained; no application windows were moved during this validation.
- Repository not created yet. Live GitHub checking, update download, replacement and restart remain unverified until releases exist. Physical grouped swaps remain an app-compatibility check; automated tests verify the planner.

## Shift position and mixed-size swaps — September 10, 2026

Version 0.1.6/build 7 renames Gentle drift to Shift position and extends the percentage range to 1–100%, preserving saved preferences and the internal mode identifier. At 100%, any fitting position on the usable display is within the movement envelope; collisions and group restrictions still apply.

Apple accepted notarization `f13795da-a706-4911-a67c-01310ca4d6e9`. The package passed signature, universal architecture, stapling and Gatekeeper checks; the ZIP checksum passed. The installed app retained Accessibility access, 50% range and five-minute interval. Live Swap positions preview reported “Ready to move 2 windows” for the current LG desktop. No moves were executed; Shift position was reselected and guarding left paused.

Swap positions now supplements similar-size exchanges with a bounded joint search without predefined zones. Mixed-size arrangements are selected when they move more windows. Candidate positions use screen/window edges, reflected positions and vertical offsets. Sizes are preserved, stationary obstacles and movement limits are respected, and strict mode requires a valid staging sequence. The existing brief-overlap setting permits tightly packed side swaps; it is not enabled automatically.

All **53 tests pass**. The full-height two-thirds-width window and smaller one-third-width/two-thirds-height window exchange sides over 50 seeds, with multiple vertical destinations for the smaller window. Tests also cover 100% shifts beyond half a display, three-window mixed arrangements, exclusions, movement caps and rejection without staging space. These are geometry regressions; execution against those particular third-party window arrangements remains a real-use check.

## Percentage drift and monitor activity — September 10, 2026

Version 0.1.5/build 6 adds six stable built-in layout groups using the geometry inspected in Window Layouts' FixedLayout, MenuGroupIdentifier and WindowFillGroupCatalog: Halves, Horizontal Halves, Vertical Halves, Quarters, Thirds and Two Thirds. Saved padding applies to internal edges. Window actions are not geometry groups. Custom IDs and preferences remain intact; missing/invalid custom libraries leave built-ins available with zero padding and an explanatory status.

Drift now samples randomized destinations using 1–50% of each display's usable width/height, constrained by both the original position and each step, with a default of 10% for legacy settings. Immediate reversal is avoided when another sampled safe destination exists. Existing pixel settings remain decodable but no longer control drift. No window resizing or collision relaxation was introduced.

Local/global AppKit event monitors record per-display activity timestamps without reading key contents. Keyboard activity uses the focused window's intersecting displays; pointer activity uses the event location. Unknown keyboard focus conservatively marks all displays active. Only timestamps for affected displays are consulted before and during movement; a held mouse button on another display does not veto the move.

All **51 tests passed**, including 100 varied drift cycles, 1% and 50% bounds, 500 bounded cycles, obstacle tests, built-in geometry and stable IDs, legacy-settings migration and independent display activity histories. Physical multi-display typing/scrolling still requires real-use validation. The installed UI shows the 10% control and six built-in/two custom groups with Grouping 1 retained. No LG windows were visible during this check, so no live drift was executed. The app remains paused.

Apple notarization accepted submission `598dd806-36a3-46d3-9b7b-fdbb0508803b`; the package passed signing, universal architecture, staple and Gatekeeper checks. The 0.1.5 ZIP checksum passed and the update was installed in Applications.

## Activity warning update — September 9, 2026

Version 0.1.4/build 5 removes the pre-warning idle gate. Scheduled plans warn during activity, then require the configured quiet period at countdown expiry and during execution. The panel, dashboard and optional notification explain the cutoff. Activity cancellation shows a six-second nonactivating notice. Settings explain why a quiet period longer than the warning can cancel a move after activity before the warning, while an already-idle desktop can still move.

All **46 tests pass**, including cutoff boundaries, mouse-button holds, zero quiet time and quiet time exceeding the warning. Developer ID signing, Apple notarization, ticket stapling and Gatekeeper assessment passed; the ZIP checksum was verified. Version 0.1.4 is installed with Accessibility retained.

Live UI inspection confirmed the updated warning and longer-quiet-period settings explanation. The automation-driven input did not trigger the activity cutoff, so the attempted cancellation check instead completed a four-window move. A warned restore then reported all four original positions verified. The quiet setting was restored to five seconds, the warning remains ten seconds, and the app is paused. Cancellation from physical keyboard/mouse input and scheduled warnings under continuous physical input remain manual checks; no live cancellation success is claimed for this run.

## Group assignment update — September 9, 2026

Version 0.1.3/build 4 replaces group-only position cycles with a bounded joint assignment search across alternative zones. Different window shapes participate in one arrangement, and empty compatible zones can be destinations. Every completed assignment is checked against stationary obstacles and other assigned rectangles. Sizes are preserved. Group rotation permits brief intermediate overlap without requiring staging space; ordinary Swap positions retains its separate policy.

All **45 XCTest tests pass**. The screenshot-shaped four-window Grouping 1 fixture moves all four windows over 100 seeds. Additional cases verify excluded obstacles, empty destinations, the movement cap, and unequal rounded thirds on a 5120-point display.

The installed notarized 0.1.3 app retained Accessibility permission and Grouping 1 preferences. Its live preview reports **Ready to move 4 windows** against the user's current four-window LG arrangement, where 0.1.2 had reported two. This update was previewed without executing moves on those working windows; the app was left paused with the preview visible. Previous 0.1.2 movement/restore validation below remains historical evidence, not a live execution test of this new assignment planner.

Apple accepted submission `8a9657e2-1c8c-46df-97b8-ac2b462f21b9`. The package script verified the universal executable, Developer ID signature, stapled ticket and Gatekeeper assessment. The final 0.1.3 ZIP checksum passed. Artifacts are in `dist/0.1.3/` and `dist/OLED-Window-Guard-0.1.3-macOS.zip`.

## Automated and build checks

- **42 XCTest tests passed with zero failures** on the local Apple silicon Mac using Xcode 26.6.
- The suite includes 500 successive drift cycles, 300 seeded crowded-desktop scenarios and 100 group-drift scenarios, plus focused coverage for containment, collisions, staging, Accessibility read-back, stale plans, mixed display coordinates and Window Layouts parsing.
- Regression coverage now verifies that OLED Window Guard's transient menu-bar and warning windows are excluded, temporary same-application frame ambiguity is tolerated only for participating windows, and activity on an unrelated display does not invalidate a selected-display plan. Windows spanning onto an affected display remain obstacles.
- Release archives compile as a universal executable containing `x86_64` and `arm64`.

## Live macOS checks

- Accessibility access was enabled for the Developer ID build. The installed app detected the built-in display and LG ULTRAGEAR+, preserved the existing display/group preferences and remained paused until explicitly operated.
- Preview identified three equal-size disposable windows in the Window Layouts “Thirds Bottom” group on the selected LG display. A visible ten-second warning appeared before movement, and the Skip action had already been verified to cancel the move and restart the interval.
- The three 1546 × 920 point windows rotated between distinct positions on the LG display. Original X coordinates were `-1159`, `547` and `2254`; after movement they were `2254`, `-1159` and `547`. All retained Y coordinate `-1000` and their original size. The app reported that all final positions were verified.
- An unrelated ChatGPT window changing on the built-in display did not cancel the selected-LG move. This behavior is intentionally scoped to affected displays while retaining intersecting/spanning obstacles.
- Restore displayed its own warning, returned all three windows exactly to their recorded coordinates, reported that the original positions were verified and disabled the consumed restore action.
- Live testing exposed and resolved three edge cases: the app's own transient status-item window invalidating a warning, same-application windows becoming temporarily ambiguous during an opted-in overlapping rotation, and unrelated activity on another display cancelling a valid plan.
- Window Layouts integration found five saved custom groups and read the selected group without modifying the Window Layouts app or its library.

The optional warning sound was enabled during the live cycle, but audio output was not independently measured. Broader application compatibility, fresh-account onboarding, strict no-overlap staging, Retina drift and sleep/Space/display-change scenarios remain in the manual matrix in `TESTING.md` before a public release.

## Accessibility registration repair

An earlier development build shared the Release bundle identifier and left a stale Accessibility code requirement. Targeted TCC logs reported “Failed to match existing code requirement” for `com.astrobrett.OLEDWindowGuard`. Only that app's Accessibility registration was reset, after which the user re-added the signed app and macOS granted access.

Debug builds now use `com.astrobrett.OLEDWindowGuard.Development` and the display name “OLED Window Guard Development”. Release builds retain `com.astrobrett.OLEDWindowGuard`, preventing future development signatures from replacing the installed release's Accessibility identity.

## Version 0.1.2 distribution

- Apple notarization status: **Accepted**
- Submission ID: `e6de5d3c-9edc-4af7-94c6-68451048178b`
- App version/build: `0.1.2` / `3`
- ZIP SHA-256: `5654d76feb075772f027d85c70e9e2226d98de9acea8d86963b48855a5b55e51`
- Architectures: `x86_64 arm64`

The copied distribution app and the installed `/Applications/OLED Window Guard.app` both passed strict Developer ID signature validation, stapled-ticket validation and Gatekeeper assessment (`source=Notarized Developer ID`). Their executable SHA-256 values match: `df8c64270870332841e489e9b93d05939825eeb251140a97f5cc31f5a8decba7`. The installed notarized app opens as version 0.1.2, retains Accessibility access and starts paused.

## GitHub release and end-to-end updater verification — September 14

- Published `v0.1.20` as a prerelease with DMG, ZIP and SHA256SUMS. GitHub's asset digests matched the local downloads.
- Installed a signed/notarised local test baseline reporting 0.1.19, using the same beta updater configuration. This baseline was not published.
- About → Check for updates detected v0.1.20. Install update and restart downloaded the actual GitHub asset, verified it, replaced the app and launched `/Applications/OLED Window Guard.app` with `--updated-relaunch`.
- The running app reported Version 0.1.20 / Build 21 and remained paused. Accessibility access and selected display/group settings were retained. A second update check reported “You’re up to date (0.1.20).”
- Installed executable SHA-256 matched the packaged release. Strict codesign verification and Gatekeeper assessment passed outside the tool sandbox: Notarized Developer ID. Earlier validation notes that called end-to-end testing outstanding are superseded by this result.
