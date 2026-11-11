# Android TV upstream integration - 2026-11-11

This sync integrates 194 upstream commits after
`f4f2899451a7e26e45d935cf4d5648235d8f9149`, through
`d31a38f8bd8cd9c1b15f6a4e6a1831187fc53b7f`. It retains real upstream merge
ancestry for the next update.

Pending local work was committed and pushed first as `9e13e0bb1`: TV chapter
filmstrips and transport navigation, replay of automatically skipped segments,
Next Up countdown cancellation on focus departure, and the detail autoplay
loading gate. Their localization and regression tests were included.

## Included upstream changes

- Subtitle bold, outline/shadow, downloadable font support and direct-play ASS
  sizing; Media3 MOV_TEXT placement fixes and recovery from container-reader
  failures. Track matching preserves the chosen subtitle across episodes.
- Configurable control hiding and HDR dimming, playback speed choices and TV
  sleep handling that waits for the playback stop report.
- Expanded Moonbase watch parties, rooms, voting, invitations, chat/reactions
  and synchronized playback, adapting the retained Flutter playback path.
- Detail action rows settle together, episode lists start at the current
  episode, richer season/episode cast, HDR format badges, and poster-label
  coverage in search, folders and details.
- Home row sorting/reload fixes, See All cards for latest/collection rows,
  library matches for external lists, and corrected server-side random media
  bar selection. The shared artwork helpers were imported while retaining
  this branch's card motion and rendering policy.
- Settings live previews, localized section headers and date formatting,
  responsive account picking, TV voice-search focus, Watch Next updates,
  Plex/Moonbase diagnostics and retained shared API/localization changes.

## Preserved Android TV behavior

Android TV remains the only app runner/build target. Removed downloads,
offline storage, push, native Cast/DLNA sender, reader and emulator stacks
remain removed. Newly introduced After Hours arcade code, assets and entry
points are excluded. Apple/desktop/web runner changes and the upstream
multi-platform CI workflows are excluded; the existing TV workflow and pinned
Flutter 3.47.2 SDK remain. Root dependencies and their lockfile are unchanged.
Shared models and widgets for excluded library types do not enable those
libraries or routes in the video profile.

Home retains its bounded/deferred work, startup cover, finite Modern card
motion, stable decode sizes and independent background/title artwork.
Seerr/Watching Now rows and automatic previews remain disabled in the TV
profile. Modern remains the default details layout. Display-aware version
selection and manual overrides remain shared by all nine detail layouts.

The detail view model still waits for its primary playback/navigation choices
before publishing ready. The new action-row settling timeout applies to the
remaining optional action inputs. Upstream concurrency tests were adapted to
start controlled pending loads without awaiting them before their responses
are supplied; they retain their stale-response assertions.

Playback retains hidden initial controls, Restart, the 750 ms Back grace
period, deferred preview metadata and disabled speculative preview downloads.
The local chapter filmstrip and skip-replay behavior are combined with the
upstream outro completion and track-selector remote-key fixes.

## Verification evidence

Logs, test results and deployment evidence are stored under the ignored
`artifacts/upstream-sync-2026-11-11` directory in the regular TV checkout.
The integration worktree is `.sync-1111` inside that checkout. Selected checks
are used; a complete inherited application-suite pass is not claimed.

Initial combined Windows widget runs stopped with incomplete cases before
the merge. Their logs are retained. Asynchronous upstream detail tests also
initially timed out under the retained TV readiness barrier; the adapted
tests are rerun separately. Final counts and release/device results are
recorded below after validation.
