# Demonstration media

Recorded from OLED Window Guard running on macOS on September 14, 2026,
using the author's prepared 5120 × 2160 desktop. Captions are added outside
the captured desktop; window motion is actual recorded behavior.

- `layout-group-rotation.gif`: four-window rotation through Grouping 1.
- `grouped-window-swap.gif`: four adjacent Finder windows stay together while
  swapping positions alongside a differently sized Firefox window.
- `restore-last-move.gif`: warned restore returns the previous arrangement.
- `OWG_*.png` and `Preview_safe_window_moves.png`: author-provided feature screenshots captured during beta testing; version labels may differ from the stable release.

GIFs are cropped in time to show the warning and movement, sampled at three
frames per second (six for the fresh group-rotation recording) and resized to
1280 pixels wide. Playback is accelerated to approximately 1.5×, as labelled
in each GIF, with an extra 1.5-second hold on the completed arrangement (two seconds for
the group rotation).
The group-rotation clip was re-recorded in full after the interrupted session.
Raw recordings are retained locally under `build/demo-captures` and are not
committed. `Scripts/create-demo-gif.py` adds the captions to extracted PNG frames.

The developer retains copyright in the app and these recordings. Third-party
application interfaces and logos remain the property of their respective owners;
the recordings do not imply endorsement.

Group-rotation timing refinement: the long intermediate hold is shortened to
0.5 seconds. The two completed-layout frames hold for 1.5 and 2.5 seconds,
respectively. Recorded frame images are unchanged; idle timing is edited.

Shift position recording (September 15, 2026): `shift-position.gif` shows two
verified three-window movement cycles at a 50% maximum range. Captured on the
prepared LG display using 0.1.22; movement code is identical in 0.1.23. Frames
6–19s and 29–41s from the 60-second recording are played at approximately 1.5×
speed, with idle time removed and a 2.5-second extra hold on the final arrangement.
The source is `build/demo-captures/shift-position-sep15.mov` (not committed).

The Shift position GIF uses exact video timestamps, reduced frame sampling and
960-pixel width to keep the download compact; playback timing is preserved.

Window and display dimming recording (September 18, 2026):
`window-and-display-dimming.gif` shows Finder dimming while Word remains active,
Word dimming after switching to Finder, then the LG display dimming when focus
moves to the MacBook. Recorded with version 1.0.0 and the author's prepared empty
Finder folder and Word document. Window dimming is 40% with a 5-second delay;
display dimming is 50% with a 10-second delay; both fades take 2 seconds.
The desktop wallpaper changes automatically during the recording.

The GIF uses seconds 14–23, 28–37 and 37–49 of
`build/demo-captures/dimming-manual-sep18.mov`, sampled at 3 fps and resized to
960 pixels wide. Captions sit outside the captured screen. Idle time is trimmed;
the fades retain their recorded speed, with an extra 2-second hold at the end.
The raw recording and review frames remain local and are not committed.
`OWG_window_and_screen_dimming.png` is the author's supplied settings screenshot.
