# Android TV upstream integration - 2026-11-05

This integration brings upstream main through
`9d256720f972d09a76e8f65d005ca10d6fa83a99` into the Android TV video branch.
The starting TV revision is `3adf18107ff7baa0f262c65793ea64c9d578c55b`, which
preserves the previously pending loading, startup and display-selection work.
The integration retains upstream merge ancestry for subsequent updates.

## Included changes

- Premiere, Quick Look and Frost details, their settings and previews, shared
  presentation helpers and later upstream fixes. Quick Look opens over the
  previous page and can open the full Modern page.
- Stage's expandable overview, adapted to the TV branch's existing focus,
  presentation-ready callback, action-group and track-dialog behavior. Short
  overviews without a Read More control are skipped as focus targets.
- Android ASS subtitle bitmap pooling/dialogue queue fixes, decoder/source
  recovery, cadence evidence, display-rate matching and playback diagnostics.
- Dolby Vision Profile 5 transcoding constraints and smaller trickplay sheet
  decoding with bounded directional scrub lookahead.
- Live TV favorites, guide focus/loading fixes and dedicated remote shortcuts.
- Search corrections and smart search, retaining video-only result filtering.
- Calendar Agenda/Countdown/month views, navigation/settings/sync integration,
  upcoming-row See All cards, next-air-date cards and media-bar release labels.
- Shared server/playback, Watch Party, preference and translation updates.

## TV adaptations

The Android-only runners, build flavors and isolated application identity are
retained. Deleted offline/download, reader/emulator, push and native Cast/DLNA
sender infrastructure stays deleted. Server-session remote control remains.

Modern remains the default detail style. Existing stored style choices remain
valid and the new styles are available in Settings. The branch's generic
loading presentation is retained rather than restoring the upstream detail
skeleton implementations.

Home keeps its finite Modern card motion, independent logo/title artwork,
bounded image queue, visibility gating, three-worker deferred pool and first
visit cover. Preview metadata and next-season lookups remain behind current
stream startup. Ambient/whole-title seek-preview image prefetch is omitted;
scrubbing still requests a bounded window.

Automatic media-version selection continues to consider the actual display's
resolution/HDR support, while retaining explicit user choices through updates.
The initial 500 ms Media3 threshold, lazy mpv fallback, Restart action and
HDMI/audio settling safeguards are retained.

Watching Now is disabled in the TV profile because its external-title cards
open excluded Seerr request routes. Its shared implementation remains available
to compatibility tests. Stored preferences are preserved. Calendar is available
when the server/plugin supports it; phone reminders remain hidden on TV. The
Calendar integrations page tolerates the intentionally absent achievements
service. The shared Watching Now timer also respects Home visibility/disposal.

## Automated validation

Validation logs are under the ignored `artifacts/upstream-sync` directory.
The selected Flutter batches cover new/existing details, TV profile/startup,
Home/media-bar loading and artwork, display selection, playback recovery,
trickplay, search, guide/remote navigation, calendar, settings and Watch Party.
Search also runs with `MOONFIN_VIDEO_ONLY=false` to check retained compatibility
behavior. Upstream test fixtures were adapted to the removed offline stack;
video-only and compatibility expectations are both asserted.

The selected Flutter runs passed **761 cases**, counting each selected case
and application-profile configuration once. This includes **65** card-motion,
row/prefetch/navigation and Back-to-exit cases.

The native Android suite passed **512 tests across 51 suites**, with no
failures, errors or skips. The complete Silo playback, Silo server and Plex
server package suites passed **102**, **719** and **82** tests respectively.

Full analysis, after preparing nested packages' development dependencies,
reported **zero errors**. Its **11 warnings** match the pre-integration
baseline. Informational lints remain. This is selected application regression
coverage, not a claim that the entire inherited application suite passed.

## Device validation

No installation or physical-device playback check is part of this integration.
The release APK still needs Shield checks for the new layouts and focus return,
HDR/Dolby Vision, ASS subtitles, passthrough, HDMI rate changes, seek/resume and
first audible output. The previously observed receiver pause/resume audio gap
is not claimed fixed, and no measured navigation/startup speedup is claimed.
