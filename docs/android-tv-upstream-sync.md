# Android TV upstream synchronization assessment

Investigated on 2026-11-05. This is a source and Git merge assessment; no
upstream application changes have been integrated or built.

## Conclusion

Keeping the Android TV branch current is feasible. Its largest divergence is
the deliberate removal of unrelated platforms and features, rather than a
replacement of the shared application architecture. The new detail screens
can use the retained view model, playback controls and server packages.

Use a reviewed upstream merge on an isolated integration branch, preserving
the TV branch's product restrictions and measured behavior. Git's automatic
resolutions still need review. Replacing our files wholesale with upstream,
or choosing one side for every conflict, would lose important behavior.

## Audited revisions

| Revision | Commit | Meaning |
| --- | --- | --- |
| Shared base | `f95909b13187c0d7168c96ac0e3e09982b2ac96b` | Added Stage details screen; also the fork's current local `main` |
| TV branch | `eccda6b6c8faf17925a932e5ed3136e9367491b9` | `experiment/android-tv-video` at investigation time |
| Upstream main | `9d256720f972d09a76e8f65d005ca10d6fa83a99` | Fetched directly from Moonfin-Client/Moonfin-Core |

The histories have 28 TV-only commits and 137 upstream-only commits. These
counts include documentation, translations and merge commits, so they do not
represent 137 independent features.

Relative to the base, the TV branch changes 1,053 paths, with 13,051 insertions
and 285,545 deletions. Upstream changes 370 paths, with 82,301 insertions and
5,160 deletions. Generated translations contribute heavily to upstream's size.
Upstream touches 100 retained paths that our committed branch also changes,
and modifies 29 paths that our branch deletes.

The checkout already had 26 modified tracked files and six untracked files.
They include loading, artwork, startup-cover, HDR/source-selection and playback
work. The merge simulation uses the committed TV tip. Pending changes were
inspected separately and must be incorporated into the integration baseline
before doing a real merge. None were changed by this investigation.

Source: [upstream changes since the shared base](https://github.com/Moonfin-Client/Moonfin-Core/compare/f95909b13187c0d7168c96ac0e3e09982b2ac96b...9d256720f972d09a76e8f65d005ca10d6fa83a99).

## Merge evidence

`git merge-tree --write-tree --name-only` simulated a three-way merge without
changing the checkout, index or branch. It returned 47 conflicted paths:

| Conflict type | Paths | Interpretation |
| --- | ---: | --- |
| Modified upstream, deleted here | 29 | Apple/web runners, removed downloads and the removed local-first playback resolver and related tests |
| Content conflicts | 18 | README, 16 production source files and one Stage test file |

The 16 production source files with content conflicts are:

- `lib/app.dart`
- `lib/data/services/synced_fields.dart`
- `lib/data/viewmodels/search_view_model.dart`
- `lib/ui/navigation/app_router.dart`
- `lib/ui/screens/detail/item_detail_screen.dart`
- `lib/ui/screens/detail/stage/stage_detail_content.dart`
- `lib/ui/screens/detail/stage/stage_track_chips.dart`
- `lib/ui/screens/home/home_screen.dart`
- `lib/ui/screens/playback/video_player_screen.dart`
- `lib/ui/screens/settings/panel/navigation_category_screen.dart`
- `lib/ui/screens/settings/panel/settings_search_index.dart`
- `lib/ui/screens/settings/settings_side_panel.dart`
- `lib/ui/screens/setup/setup_wizard_previews.dart`
- `lib/ui/widgets/skeleton/skeleton_detail_screen.dart`
- `packages/moonfin_native_video/android/src/main/kotlin/org/moonfin/nativevideo/Media3VideoView.kt`
- `packages/playback_core/lib/src/playback_manager.dart`

The test conflict is
`test/ui/screens/detail/stage/stage_detail_content_test.dart`.

Retaining intentional deletions resolves the product decision behind the 29
modify/delete conflicts. Relevant fixes within deleted wrappers may still need
adaptation elsewhere. Newly added upstream Apple/photo files can also enter
the merge without conflicts, so the deletion list alone is not a scope filter.

Upstream has no changes to the root or package dependency manifests, root
lockfile, or audited Android Gradle dependency configuration in this range.
There is no required upstream dependency/toolchain upgrade in this snapshot.

## New details screens

Stage is already present in our shared base. The new styles since that base
are Premiere, Quick Look and Frost.

| Style | Portability | Required integration |
| --- | --- | --- |
| Premiere | Good; mostly additive presentation | Shared `DetailPage` mixin, centered metadata/actions, section configuration, style selection, skeleton and previews |
| Quick Look | Good, with navigation work | Shared helpers plus non-opaque drawer routes, `full=true` full-page navigation, background ownership and focus return |
| Frost | Good, with more UI validation | Shared helpers, frosted action controls, tabs, rating/Seerr presentation helpers, skeleton and previews |

The new screen files are about 740, 816 and 2,945 lines respectively. Their
direct relative imports already exist in our branch except for two new shared
files: `detail_page.dart` and `scroll_edge_arrows.dart`. The new `DetailPage`
mixin's direct relative imports all exist here. This is a direct-import check,
not a proof that all method signatures and runtime dependencies are compatible.

Crucially, upstream does not change
`lib/data/viewmodels/item_detail_view_model.dart` in the audited range. The
screens therefore do not require replacing our loading implementation with an
upstream view model. Our primary-data readiness barrier, deferred optional
sections and pending loading changes can be retained.

Integration extends beyond copying the three screen files:

- Add the enum values, section availability and settings choices, including
  exhaustive switches in skeletons and setup/settings previews.
- Adapt the shared controls in `item_detail_screen.dart`: centered metadata,
  centered/frosted actions and weighted crew/studio groups.
- Include companion widget changes used by the new styles, such as track-chip
  layout, rating display and episode-row helpers.
- Adapt Quick Look's router/page behavior and full-page escape. Check Back,
  initial Play focus, drawer dismissal and Home focus/scroll restoration.
- Preserve our Stage focus fixes. Upstream moves substantial Stage behavior
  into `DetailPage`; taking its refactor wholesale would bypass the branch's
  tested focus, action-group and poster/navigation handoff fixes.

Upstream makes Frost the default on TV/desktop. Keep the existing branch
default during initial integration and expose the new styles as options until
device validation supports changing it. Frost uses a blurred artwork filter;
its rendering cost on the Shield is not established by this investigation.

Relevant starting commits, with subsequent fixes included when porting:

- [Premiere: `2a266e862`](https://github.com/Moonfin-Client/Moonfin-Core/commit/2a266e862)
- [Quick Look: `abf829ac4`](https://github.com/Moonfin-Client/Moonfin-Core/commit/abf829ac4)
- [Frost: `022556b7f`](https://github.com/Moonfin-Client/Moonfin-Core/commit/022556b7f)
- Frost follow-ups include `6656f9b35`, `bf0c6fdf2`, `53bd8c5a8` and preview
  fixes in `d201773d1`; taking only the introduction commits misses fixes.

## Other worthwhile upstream changes

These are source-based integration estimates, not measured implementation times.

| Update | Expected adaptation | Priority |
| --- | --- | --- |
| ASS subtitle memory/loader fixes | Native overlay bitmap pooling and Matroska dialogue queue; preserve our Media3 edits and include follow-ups/tests | High |
| Dolby Vision Profile 5 transcode color fix | Device-profile constraints and Media3 capability flag; validate alongside pending HDR/source-selection work | High |
| Server picker D-pad focus fixes | Small auth-screen changes and regression checks | High |
| Search fixes and smart search | Keep video-only result filtering while adapting view model/repository changes | Medium |
| Live TV favorites, guide focus and remote shortcuts | Guide/player changes, in-flight loading protection and remote-key tests; exclude Apple-only host behavior | Medium |
| Trickplay decode-size and end-sheet fixes | Retain smaller decoding/bounded scrubbing behavior while reviewing prefetch policy separately | Medium |
| Watching Now row and new-season/episode labels | Adapt Home/media-bar loading, row overlays, cache/filter behavior and refresh visibility | Medium |
| Calendar with Agenda, Countdown and month grid | Add repository/screens, routes, settings, navigation and sync fields; keep mobile reminders out of TV UI | Optional |
| Native frame-rate/cadence decisions and playback recovery | Coupled Kotlin/backend/core/resolver changes affecting HDMI/audio/stream lifecycle | Separate high-risk validation stage |
| Watch Party resume and synchronized-start fixes | Retained feature; inspect queue/session and timing interactions | Feature-dependent |

Useful concrete commits include:

- [ASS pooling/queue: `732641ef6`](https://github.com/Moonfin-Client/Moonfin-Core/commit/732641ef6),
  plus the later overlay churn fixes merged by `44eef2e3a`.
- [Dolby Vision Profile 5: `a4311f50a`](https://github.com/Moonfin-Client/Moonfin-Core/commit/a4311f50a).
- [Trickplay decode sizing: `2838ee91f`](https://github.com/Moonfin-Client/Moonfin-Core/commit/2838ee91f).
- [Native cadence work: `ec6331f8a`](https://github.com/Moonfin-Client/Moonfin-Core/commit/ec6331f8a).
- [Calendar: `02c44a9f1`](https://github.com/Moonfin-Client/Moonfin-Core/commit/02c44a9f1).

Calendar reminders are server-backed and gated by `useMobileUi` upstream; the
calendar itself does not require restoring the deleted local notification or
offline stack. Its server/plugin capabilities still need validation.

## Changes that need explicit adaptation

Textual merge success is insufficient in these areas:

1. **Seek-preview policy.** Upstream `c800c9e2d` adds the current sheet to
   ambient playback prefetch. Our pending work removes ambient downloads and
   defers metadata until the stream opens. Preserve our policy while importing
   compatible decoding and scrub-boundary fixes.
2. **Home/media-bar work.** Upstream adds rows, label lookups and timers. Keep
   the shared three-worker deferred pool, visibility gating, bounded artwork
   queue and startup cover. Audit automatically merged view-model changes.
3. **Details focus/loading.** Preserve the branch's initial Play handoff,
   nested-row traversal, track-dialog return and readiness semantics across
   the new shared helper refactor.
4. **Playback and credentials.** Upstream modifies the deleted
   `LocalFirstMediaStreamResolver` to forward credential renewal. Our playback
   registration uses server resolvers directly; inspect that path and adapt
   relevant renewal behavior without restoring local-first/offline playback.
5. **Android output behavior.** Preserve our 500 ms initial buffer threshold,
   Restart action, lazy mpv, HDR/source preferences and HDMI/audio settling
   protections while adapting native cadence/recovery changes.
6. **Product restrictions.** Keep Android-only runners/builds, streamed-video
   libraries and routes, disabled previews/theme music/seasonal effects, and
   removed download, reader, game, push and native Cast/DLNA sender stacks.
   Preserve stored/synced preferences as documented in the branch guide.

## Integration workflow

1. Finish and preserve the pending TV work as a coherent integration baseline.
   Do the upstream work on a separate branch/worktree so the active checkout
   and its uncommitted files remain available.
2. Fetch a fixed upstream SHA and repeat the merge simulation. Review its
   complete diff, including automatically merged files and new files.
3. Resolve the integration by feature area: small correctness fixes; shared
   detail helpers and new screens; search/guide; Home/media bar/calendar; then
   native cadence/recovery. Validate each area as it becomes coherent.
4. Keep deleted feature/platform files deleted and adapt relevant behavior
   into retained components. Regenerate localization from the combined ARB
   sources with the pinned Flutter SDK rather than hand-merging generated Dart.
5. Finish with a real merge retaining the upstream parent. This advances the
   common ancestor for the next sync. Selective early ports can be useful, but
   cherry-picking forever leaves the upstream merge base behind. An `ours`
   strategy merge would incorrectly record skipped updates as integrated.
6. Record the upstream SHA, intentional exclusions, adapted behavior and test
   evidence with each completed sync.

Validation must cover new detail styles and existing Stage/Modern navigation,
movie/series/season/episode playback, versions/tracks, Back/focus return,
deferred loading, Home card motion and startup visibility. Run the retained
profile/startup tests, relevant feature tests, analysis and isolated TV build.
Native playback changes also need Kotlin tests and Shield checks for
subtitles, Dolby Vision/HDR, passthrough, frame-rate switches, seek/resume,
first audible output and stream recovery. The known receiver resume-audio
delay remains a separate issue unless a controlled check proves otherwise.

No application test suite, APK build or device deployment was performed during
this assessment. The positive feasibility finding rests on shared ancestry,
the simulated merge, source review and dependency/import inspection.

## Reproduce the structural check

```powershell
git fetch --no-tags https://github.com/Moonfin-Client/Moonfin-Core.git main
$upstreamRevision = git rev-parse FETCH_HEAD
$sharedBase = git merge-base HEAD $upstreamRevision
git rev-list --left-right --count "HEAD...$upstreamRevision"
git diff --shortstat $sharedBase HEAD
git diff --shortstat $sharedBase $upstreamRevision
git merge-tree --write-tree --name-only HEAD $upstreamRevision
```

The final command returns exit code 1 when conflicts are found. It writes Git
objects for the simulated tree, but does not update the working tree or index.
`FETCH_HEAD` can change on later fetches; use the recorded full SHA when
reproducing this particular assessment.
