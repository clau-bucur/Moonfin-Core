# Logo clarity and placement follow-up

Supersedes title-overlay behavior in `single-background-artwork.md`.

- Selection state, rather than expansion progress, now chooses logo alignment.
  The logo snaps between low center and bottom left; background reveal motion
  is unchanged. Logo size remains fixed during card resizing.
- Selected title/logo bottom inset increases from 12 to 28 logical pixels.
  The progress bar occupies the bottom 6-12 pixels, leaving 16 pixels clearance.
- Logos decode at a fixed 640 pixels, matching the existing server request cap,
  and use high-quality sampling. This avoids undersized decodes on TV logical
  densities and keeps one decode across focus changes. Logo API requests already
  omit the quality-90 setting used by background/thumbnail images. This change
  cannot restore detail absent from the library's original logo asset.
- Text fallback is single-line with ellipsis and no wrapping. When there is no
  logo, the selected title uses the available card width instead of the narrow
  collapsed logo box. This fixes the clipped multi-line 'The Clone' example.

Validation: seven artwork widget tests pass, including instant position changes,
fixed background/decode reuse, progress clearance, and text-only layout. Analysis
has no errors or warnings; two pre-existing Home style info messages remain.
No Shield installation or device testing performed in this follow-up.
