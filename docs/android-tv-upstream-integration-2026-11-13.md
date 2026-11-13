# Android TV upstream integration - 2026-11-13

Integrates 94 upstream commits after
`d31a38f8bd8cd9c1b15f6a4e6a1831187fc53b7f`, through
`8efeff43664f50c2b19ff3c35f45a68befabd921`, retaining upstream merge ancestry.
The TV branch was clean before this sync.

## Included features and fixes

- Carousel Home rows with a shared details panel, available as a row-style
  option. Modern remains this branch's default, and existing choices remain
  effective. The carousel uses the branch's finite card motion, fixed decode
  sizes and independent title/logo artwork. Its panel replaces inline card
  details instead of drawing both.
- MDBList, JustWatch and TMDB discovery rows, grouped outside-list choices,
  recently released/added row settings, and the row editor opening before
  empty-row checks finish.
- Correct official MDBList pagination/filtering, Emby merged Continue Watching
  ordering, Silo row captions and ending Moonbase rooms with Silo watch parties.
- Seerr discovery row spacing follows Home's row padding and expansion
  settings. Translation and calendar/layout updates are included.

## TV adaptations

Seerr remains required and enabled according to account/server capabilities,
Kids Mode and stored preferences. Its routes, navigation, search, requests,
Home rows, badges, integration settings, CI guards and AGENTS.md requirements
remain intact.

The upstream Android mobile/TV package merger is adapted to this TV-only
branch. The Android TV flavors, Leanback requirement, local package suffix
support, renderer policy, existing signing mechanism and TV build workflow
remain. Mobile/Cast/Firebase setup and deleted platform/offline files stay
excluded. Shared fold-layout helpers remain inert on ordinary TVs. Root
dependencies and their lockfile are unchanged.

The main release uses `org.moonfin.androidtv`, label Moonfin, version `3.1.0`,
TV build `2000024`. TV version metadata is retained explicitly instead of
jumping to the mobile version-code range. The main APK includes ARM32, ARM64
and x86-64 Flutter runtimes so one artifact can serve all three target TVs.

Home retains the deferred loading pool and startup cover. The locked focus
row keeps exact animated widths, while adding upstream's fixed variable-width
scrolling support. Hidden initial playback controls, Restart, Back grace,
deferred seek-preview metadata and display-aware version selection remain.

## Validation and deployment evidence

Evidence is under `artifacts/upstream-sync-2026-11-13` in the regular TV
checkout. Full analysis passes with zero errors and 11 existing warnings.
Native app/video tests pass: 47 app cases and 516 video cases.
The successful selected Flutter runs contain 264 cases, giving 827 passing
cases across Flutter and native tests. Seerr profile, route, preference,
navigation and search checks are included.

Selected Flutter regressions cover new carousel/row behavior, Seerr, primary
TV behavior, Home loading, display selection, settings, calendar, watch-party
cleanup and playback. Some combined Windows widget batches ended with cases
marked "did not complete" without a Dart assertion failure; separate runs
are recorded alongside them. A full inherited-suite pass is not claimed.

The universal main release built successfully from source commit
`1c12319d03c6f4eb7e132f2dc88ee40581cc97ce`. Package metadata, signing
certificate and the ARM32/ARM64/x86-64 native libraries were verified.

- Artifact: `release-main-universal/moonfin-main-universal.apk` under the
  evidence directory; 108,719,385 bytes.
- SHA-256: `4418151540c7330dd4e4eb393dfbf5ee8b358de2b778e37cf40a6c6ce8c1a363`.
- Signing certificate SHA-256:
  `3af2f489977eec2dd8d1382d655e79e8f2b68ebf806275e87a9f859bf9ee3f82`.

Initial ADB connection attempts and the post-build TCP checks at 15:41 UTC
on November 13 timed out for all three targets. The user selected this chat
for the availability alert, which was posted here. Deployment resumed when
the user reported the devices available later the same day.

Bedroom accepted an in-place update with its existing local signing key.
Shield and the living room TV had a different signing certificate, so both
were initially left unchanged. The user then explicitly approved replacing
both main apps and resetting their local data. Their original APKs were
backed up and verified before the approved replacements.

| Target | Result |
| --- | --- |
| Shield (`shield.gme:5555`) | Installed; approved data reset; Add Server screen verified |
| Living room TV (`tvliving.gme:5555`) | Installed; approved data reset; Add Server screen verified |
| Bedroom (`mitvbedroom.gme:5555`) | Updated in place; data preserved; Home and Seerr navigation verified |

All three installed APK checksums match the verified release, and all three
running main apps report version `3.1.0`, build `2000024`. The living room TV
is a Philips 2021/22 UHD Android TV. Shield's display had returned to sleep
after its initial successful launch; waking it again confirmed the setup
screen and resumed main activity. No playback or Seerr request was started.

Shield and the living room TV require server/account setup again after
their approved resets. Bedroom retains its prior setup. Future updates can
use the same local signing key for in-place installs on all three devices.
APK verification, final device results and launch checks are saved as
`release-verification.json`, `deployment-results.json` and
`launch-verification.json` alongside the device screenshots.
