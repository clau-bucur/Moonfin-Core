# Stage poster and sidebar handoff — 2026-11-03

The user requested that entering details never briefly activate the sidebar,
and that returning from Cast to the actions bring the poster back into view.

Source: `121d29da0de600d4970604c7f17df1f908102922`, on
`experiment/android-tv-video`. Main remains unchanged.

- Details keep navigation hidden until Stage's prepared page has mounted and
  Play has taken focus. The hidden sidebar is excluded from focus traversal.
- Returning to any action scrolls back toward the poster. Play returns to offset
  zero; a wrapped secondary action retains only enough offset to keep its whole
  button visible. Generic section-reveal scrolling no longer competes with this
  action-specific positioning.
- Stage's readiness callback runs after the initial focus request has settled.

Local checks: 21 tests pass (8 Stage, 5 route-focus observer, 8 shared detail
buttons). The Stage regression checks poster visibility after Cast → More and
the exact original poster position after focusing Play. Targeted analysis has
no errors or warnings; 24 style infos remain.

Shield release: 66,366,672 bytes; installed hash verified against the local APK:
`e17ae26124d4c1818f7ab84b8e2acbead74ff7439a1a683a90f3eb05faadc0e2`.

| Shield check | Result |
| --- | --- |
| Hellboy II details entry | No automatic sidebar activation seen in the recorded handoff |
| Fresh Kill Bill details entry | No automatic sidebar activation while data/artwork prepared |
| Deliberate Left from Play | Sidebar opens; Right returns to Play |
| Cast → More | Full poster returns into view, and More and its label remain visible |
| More → actions → Play | Page returns to the original top position with the full poster visible |
| Final log | No matched fatal, unhandled, rendering overflow, late-initialization or disposed-state errors |
| Final device state | Home; playback was not started during these checks |

Entry recordings were reviewed as full-page 5 fps contact sheets and 30 fps
sidebar-region samples around the handoff. These are functional visual checks,
not a frame-time performance benchmark. Captures and raw diagnostics remain
private under `C:/Development/temp`, including `mf-poster-handoff-entry.mp4`,
`mf-poster-handoff-cold.mp4`, `mf-poster-handoff-more`,
`mf-poster-handoff-play-return`, and `mf-poster-handoff-final-logcat.log`.

The existing generated Finnish, Italian and Chinese localization changes remain
uncommitted and preserved.
