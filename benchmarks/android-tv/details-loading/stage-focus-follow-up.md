# Stage focus and cold-details follow-up — 2026-11-02

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
  coordinates. Audio, Subtitles and Version have explicit Left/Right links.
- Up from the first full-width section (Cast on the reported movie) returns to
  More on the landscape layout instead of the Directors group beside the poster.

Local validation: 42 tests pass, run as separate Flutter test files because this
host intermittently terminates workers during combined runs:

| Suite | Tests |
| --- | ---: |
| Stage layout and focus (including three track chips, Cast → visible More) | 7 |
| Details extras and delayed ready state | 3 |
| Episode ordering | 9 |
| Lazy row navigation | 12 |
| Row shift geometry | 9 |
| Independent row card/scroll memory | 2 |

Targeted analysis has no errors or warnings; nine existing style infos remain.
The generated Finnish, Italian and Chinese localization edits are preserved
outside this change. `main` is unchanged.

Physical Shield verification is pending: ADB at `shield.gme:5555` was offline,
and reconnect timed out. Required checks are Hellboy II's Version picker,
Cast → More and off-screen More reveal, a previously unopened details item,
and at least six Home rows down/up, including selection memory and details return.
The previous installed build's results do not validate these new changes.
