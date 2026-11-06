# Android TV loading performance

This pass targets work that competes with usable Home content, the detail
page's Play button, and the current stream. The changes reduce requests and
decodes; they do not establish a measured startup-time or frame-rate gain.

The TV profile already disables automatic previews, theme music and seasonal
effects, starts with Media3, and constructs the mpv fallback lazily. Those
existing reductions are retained.

## Changes

| Path | Previous behavior | Updated behavior |
| --- | --- | --- |
| Home sections | First eight configurable sections loaded eagerly; many built-in sections could not defer | First three configurable sections load eagerly; supported built-in sections also load near the viewport. Resume and essential navigation rows remain available at startup |
| Deferred Home requests | Each viewport notification could start its own batch of three requests | One shared pool of three workers |
| Home artwork | Up to eight row warmups, two neighboring lead rows, 600 logical pixels of list cache | Two row warmups, one neighboring lead row, 250 logical pixels of list cache; speculative images have low priority |
| Hidden Home | A mounted Home could start refreshes, pagination and artwork warmups behind another page | New browse work is gated on Home visibility |
| Carousel artwork | Four immediate neighbors plus a broad background warming window; gallery warmed the next page | Only immediate previous/next slides, sequentially, at low priority after 500 ms of settled navigation. Gallery loads its visible images directly. Pending warmups are discarded when hidden; reduced mode skips speculative carousel images |
| Carousel ratings | Every slide started an additional-ratings lookup when loaded | Visible current content requests ratings through the existing lazy path; old responses cannot publish into a newer carousel load |
| Details | Ratings, similar titles, reviews, extras and collection/index work all contributed to the loading barrier | Publish ready after the main item and primary navigation/playback data. Optional sections finish afterward, and their failures keep the usable page intact |
| Playback preparation | Next-season lookup began before resolving/opening the current stream; seek-preview metadata could compete with startup | Next-season lookup and preview metadata wait until the current stream opens. Disabled previews skip metadata |
| Seek-preview images | Watching and showing controls could initiate sheet downloads, including a large whole-title sweep | No sheet warmups during ordinary viewing or control display. Actual scrubbing/hover warms a bounded nearby window |

The cache manager cannot safely cancel an already-issued image download shared
by visible and speculative consumers. Cancellation therefore discards pending
work, while a single active speculative carousel download is allowed to finish.

Primary detail data still arrives together: seasons/next episode, the current
season's episodes, or the collection/playlist's first page. Probed plugin media
sources and synchronized series track preferences remain prerequisites for
correct playback choices. Optional sections can appear after the page is ready.

## Further opportunities

### Startup presentation follow-up

The first TV Home visit in each app session now paints behind an opaque
Moonfin logo. It reveals after the initial Home requests and media bar have
finished, the first rows are populated, and Flutter's pending artwork decodes
have settled for 400 ms. Home stays mounted at its real dimensions throughout,
including its navigation and backdrop, so the reveal does not reconstruct it.
There is no reveal fade. An eight-second deadline reveals the normal Home
loading/error state if a server or image stalls. Later refreshes and returns
from details do not show the cover again. Pending image-cache entries can
include nearby artwork warmups; this does not request the whole library.

Three new cover tests and thirteen deferred Home tests passed together.
Targeted analysis reported no errors or warnings (two inherited informational
lints in Home). This follow-up is included in the release APK from the
[upstream integration](android-tv-upstream-integration.md). It has not been
deployed to the Shield.

### Remaining request work

- Auto bitrate now uses a per-server saved measurement for normal stream
  negotiation, measuring only when transcoding is necessary or a live stream
  requires a measurement before opening. Direct play skips the speed probe.
  Successful measurements last 15 minutes; failed probes still fall back
  without caching that failure. A short failure cooldown remains a possible
  follow-up with slow-link and bitrate-selection checks.
- Modern series details request every episode to supply season counts and
  fallback playback targets. Requesting only the selected season could reduce
  large-series responses, but requires preserving counts and next-episode
  behavior when the server's Next Up response is empty.
- Native capability probes, authentication restoration and theme loading remain
  startup prerequisites. Profile them on the target device before changing
  ordering, especially for the first HDR/passthrough playback after boot.

Buffer thresholds, rebuffer protection, HDMI switching and receiver recovery
remain as configured. This pass does not address the previously observed
receiver pause/resume audio delay.

## Verification

Regression coverage includes readiness with a deliberately stalled extras
request, primary-section publication, lazy Home requests and request limits,
selected-slide ratings, cancelled artwork windows, disabled previews, deferred
preview startup, and next-season lookup behind a gated backend open.

Completed focused runs cover **326 tests**, counting each case once:

| Coverage | Passed |
| --- | ---: |
| Home and media-bar view model | 177 |
| Detail view models and loading widget | 45 |
| Modern tab stability | 17 |
| Nouveau details | 20 |
| Artwork queue, scheduler and transport | 35 |
| Banner carousel | 6 |
| Gallery layout | 3 |
| Playback-manager sessions | 20 |
| New player preview-loading regressions | 3 |

Targeted analysis found no errors or warnings; existing informational lints
remain. `git diff --check` passed. Broader runs did not all complete: the full
player widget file includes an obsolete Windows fullscreen expectation against
the Android TV branch's stub helper, and some runs reported tests as
"did not complete" without an assertion failure. The focused groups above
completed successfully in isolated runs/retries. This is not a full inherited
suite pass.

Local validation captures are under the ignored `artifacts` directory,
including `loading-performance-validation.json`.
No APK installation or controlled before/after device measurement is part of
this pass. For device validation, measure time to navigable Home, the detail
Play button, first video frame and first audible output separately. Collect
frame timings during sustained D-pad navigation in a profile/release build,
and repeat with warm and cold artwork caches. Activity launch time alone does
not measure usable content. Flutter's [performance profiling guide](https://docs.flutter.dev/perf/ui-performance)
describes the profile-mode measurement workflow.
