# Stage focus and cold-details follow-up — 2026-11-02/03

This follows user reports after the earlier three-row Shield check. That check
did not cover the progressive drift after four or five rows, cold details
assembly, or Hellboy II's three track pickers.

Changes on `experiment/android-tv-video`:

- Home uses measured, untransformed row slots for navigation and idle snapping,
  with an estimate only while a lazy destination is unmounted. It remeasures
  after mounting rather than accumulating estimated offsets down the list.
- Details prepare primary and secondary sections concurrently and stay loading
  until both finish, including probed streams and series track selections.
- Stage mounts its action state behind the loader, warms the poster and logo,
  and reveals the prepared page together. Artwork errors are tolerated; artwork
  preparation has a six-second limit. The logo reserves its final space even
  when an image fails or arrives after that limit.
- Stage reveals off-screen focused controls using the scroll viewport's own
  coordinates, including targets inside horizontal rows. Individual actions and
  the action group's focus handler no longer reset Stage's scroll to zero.
  Audio, Subtitles and Version have explicit Left/Right links; closing a picker
  restores its chip's focus. Already-visible chips do not recenter the page.
- Up from the first full-width section (Cast on the reported movie) returns to
  More on the landscape layout instead of the Directors group beside the poster.

The enlarged resumable-movie regression reproduced the group-level reset:
More's bottom ended at 801.6 in a 720-high viewport before the guard. It passes
afterward. Resume text also truncates within a narrow Play pill instead of
overflowing the row.

Local validation: 53 tests pass, run in focused Flutter test files because this
host intermittently terminates workers during combined runs:

| Suite | Tests |
| --- | ---: |
| Stage layout and focus (including three track chips, Cast → visible More) | 7 |
| Details extras and delayed ready state | 3 |
| Episode ordering | 9 |
| Lazy row navigation | 12 |
| Row shift geometry | 9 |
| Independent row card/scroll memory | 2 |
| Shared detail buttons | 8 |
| Action-button marquee | 3 |

Targeted analysis has no errors or warnings; 31 existing style infos remain
across the expanded set of analyzed files.
The generated Finnish, Italian and Chinese localization edits are preserved
outside this change. `main` is unchanged.

Final Shield release: `2d1f48168c88ff30d0c54e9e0a5533afd4feff79`, 66,367,196 bytes.
Installed APK SHA-256 matches the local artifact:
`961d812db57dbdc0585031acadd09c09c1da56b1f201c232dab5481ffd0cc029`.

| Physical check | Result |
| --- | --- |
| Six Home rows down, then back up | All selected rows and headings remain visible; every downward landing reviewed |
| Independent row selection | Hellboy II in Continue Watching and Fargo in Recently Added Movies restored independently |
| Details → Home | Selected Hellboy II card restored |
| Hellboy II: Down to More | Button and label brought fully on-screen |
| More → first actor → Up | Actor revealed; Up returns to visible More without scrolling to zero |
| Audio → Subtitles → Version | All reachable with D-pad; Version picker opens |
| Dismiss Version picker | Focus returns to Version; no selection changed |
| Fresh Verity details on final release | Populated controls, poster and logo appear together; no control rearrangement seen in reviewed 5 fps samples |
| Fresh Count of Monte Cristo details on preceding release | Same populated-page behavior; loading code unchanged in final release |
| Final app log | No matched fatal, unhandled, overflow, late-initialization or disposed-state errors |
| Final device state | Home with Hellboy II selected; playback was never started during this follow-up |

ADB initially timed out until the user woke the Shield. An earlier pass was
interrupted by an HDMI-CEC lost-active-source sleep event; queued input then
produced Android's no-focused-window ANR. The app was relaunched after waking,
and the final tests above ran on a fresh process. This interruption is excluded
from functional passes, not represented as a clean uninterrupted first attempt.

These are functional and visual checks, not frame-time or FPS benchmarks.
Private captures and logs remain under `C:/Development/temp`, including
`mf-stage-confirmed-fresh.mp4`, `mf-confirmed-down-1` through `-6`,
`mf-confirmed-cast-up-more`, and `mf-stage-confirmed-final-logcat.log`.
See [machine-readable results](stage-focus-follow-up.json).
