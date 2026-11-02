# Restored Modern motion and leading Restart

Date: 2026-11-02. Branch: `experiment/android-tv-video`.

Recovered the original card-motion implementation from local commit
`769a9b64a1c142bcb429f94e1608cbc8bf874711` (`improve/modern-home-card-motion`).
The old remote-tracking ref still existed locally after branch deletion. This
is an adaptation to the video experiment, not a merge of the old branch history.

## Result

- Restart leads the entire TV transport row, before Previous, Seek Back, and
  Play/Pause. It retains its visibility preference, and settings preview matches.
- Replaced Home's RowGlide springs with the old shared card-expansion clock and
  `easeOutCubic` timing. Outgoing and incoming cards transfer one expanded slot.
- Restored exact-width lazy row layout, including widths of recycled cards.
  Kept the newer stable item identities and per-card focus notifications.
- Artwork stays at a constant height. The existing wide-image crop/reveal and
  bounded decode behavior remain. Details fade in a fixed-height slot without
  the newer vertical slide or independent size animation.
- Modern fullscreen rows use the old simple fade instead of translating and
  clipping rows through an overlay band. Vertical scrolling retains forward
  momentum, reverses immediately, and completes within a bounded duration.
- Returning to a row restores its selected card and horizontal position. Focus
  and viewport movement start together; lazy destinations retry focus once
  mounted. Stale work cannot reclaim focus after another move or route change.

## Local verification

173 focused Flutter tests passed across 16 files (individual final runs):

- Original card transitions: 15; fixed artwork/text position: 1; row visibility: 3.
- Exact row layout: 9; navigation handoffs: 12; vertical scrolling: 7;
  row selection memory: 2; stable card keys: 5; variable-width layout: 1.
- Home row visibility geometry: 9; image choice: 81; Modern helpers/library tiles: 15.
- OSD preferences: 4; Restart seek/resume: 1; actual TV player controls: 8.

Targeted analysis: zero errors and warnings; two inherited Home style infos.
`git diff --check` passed.

Some combined Flutter test runs terminated a worker without a Dart assertion;
the listed files subsequently passed in separate runs. The inherited full suite
is not claimed to pass: desktop fullscreen tests expect the window implementation
removed earlier from this Android-only branch, and broader cast/context-action
runs also encountered worker termination.

The pre-existing generated Finnish, Italian, and Chinese localization changes
are preserved in the working tree and excluded from these commits.

## Shield status

This revision has not been installed or tested on the Shield. Device testing
waits for the user's next OK. Visual smoothness and perceived weight still need
the user's assessment; local geometry tests are not frame-time measurements.

Device checks to run after approval: rapid Left/Right and held repeats, immediate
reversals, Up/Down across cached and lazy rows, selection restoration, text and
artwork anchoring, Movie/Episode Restart placement and action, and play/back.
