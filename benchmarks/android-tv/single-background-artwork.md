# Single-background card artwork

Replaces the poster/landscape blend restored in `15ec1a0d4`. The shared row
animation clock, expansion timing, fixed card height and selection memory stay
in place; only artwork composition changes.

Modern video cards prefer an own/parent backdrop over a Thumb. The same decoded
image remains on a fixed expanded-size canvas, centered behind the changing card
crop. There is no poster-to-thumbnail crossfade or focus-triggered image load.
Separate own/parent Logo artwork sits outside that crop and moves from low center
to bottom left using the card expansion progress. Decode sizes stay fixed across
expansion and reversal (background <=960 pixels, logo <=640 pixels).

A missing, pending or failed logo uses the item/series title as text. Overlays
are enabled for backdrop-backed cards only: Thumb/Primary fallback artwork can
already have a title embedded in its pixels. The episode-specific-image preference
is preserved. No server artwork, metadata or library files are modified.

Emby exposes Backdrop and Logo separately, and row queries already request Logo
and parent-logo metadata. The presence of a Backdrop does not guarantee that its
pixels are text-free. If a library has titles embedded in its backdrops, replacing
those assets with clean backdrops is necessary to avoid duplicate titles. Embedded
text cannot be independently moved by the client.

Validation:
- 33 focused widget tests passed: artwork, shared motion, card frame, TV pointer
  focus, focus clearance and favorite badges.
- Final artwork rerun: 5 passed, including late-logo text fallback.
- Dart analysis: no errors/warnings; two existing Home style info diagnostics.
- No Shield installation or device input in this follow-up. Remote assessment is
  still pending; local geometry tests do not establish device smoothness.
