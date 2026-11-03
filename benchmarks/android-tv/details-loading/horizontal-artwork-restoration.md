# Original horizontal artwork transition — 2026-11-03

The user reported that Left/Right felt less smooth than the first animation
implementation. Comparison with `769a9b64a1c142bcb429f94e1608cbc8bf874711`
showed that its shared expansion clock had been restored earlier, while its
poster-to-landscape artwork renderer had not. The experiment still used a
single landscape image cropped into the collapsed card.

Source `15ec1a0d42e59e030415f53fb196b0d59af62ceb` restores the original
`ModernCardArtwork` and its tests, and reconnects it through MediaCard's artwork
slot. The restored renderer's Git blob is identical to the original:
`8a7b4916c430f496ee1c8535ec130a4ded1420fb`.

- Collapsed cards show their poster. The landscape blends in with the shared
  expansion progress, including immediate reversals.
- Decode sizes come from fixed endpoints, never the interpolated width. The
  poster stays underneath until a landscape frame is ready.
- Selected artwork lookup is settled/debounced; inactive card builds only
  resolve already-known artwork URLs.
- Existing fixed row/card heights, measured vertical row positions, focus
  memory, TV hover guard and details behavior are retained. No animation speed
  preference or horizontal easing curve was changed.

Local checks: 38 tests pass (10 original artwork, 15 shared transition, 1 fixed
frame, 1 TV hover, 6 favorite badge, 5 focus-gap tests). Analysis has no errors or
warnings; two existing Home style infos remain.

Installed Shield release: 66,378,164 bytes. Installed APK hash matches the local
release: `570c0094fbb67b2513fc8d7f3153efff53b2ad910e8965dab78652183f60e7ef`.

The user explicitly allowed switching away from Netflix for the comparison.
Before and after recordings use the same Home row and four Right/four Left
inputs separated by 350 ms. Reviewed frame samples show the restored resting
posters and poster-to-landscape blend through selection, with fixed artwork
height. The final process log contains no matched fatal, unhandled, overflow,
late-initialization or disposed-state errors. Playback was not started.

Private recordings are `C:/Development/temp/mf-horizontal-before.mp4` and
`mf-horizontal-after.mp4`, with reviewed contact sheets and final diagnostics
under the same prefix. Automated inputs finished with Home at its original
selection. The user will assess the new feel later; no subjective approval or
FPS improvement is claimed. This pass restores the original artwork behavior
rather than establishing a measured frame-time improvement.

Main is untouched. Existing generated localization edits are preserved.
