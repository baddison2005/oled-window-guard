# Demonstration media

Recorded from OLED Window Guard running on macOS on September 14, 2026,
using the author's prepared 5120 × 2160 desktop. Captions are added outside
the captured desktop; window motion is actual recorded behavior.

- `layout-group-rotation.gif`: four-window rotation through Grouping 1.
- `grouped-window-swap.gif`: four adjacent Finder windows stay together while
  swapping positions alongside a differently sized Firefox window.
- `restore-last-move.gif`: warned restore returns the previous arrangement.
- `overview.png`: the app's Overview with the current product wording.

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
