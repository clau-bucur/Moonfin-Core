# Android TV video: first-round results

The [second cleanup results](second-cleanup/README.md) cover runner removal,
dependency/native pruning and the updated Shield checks. This page retains
the original first-round measurements for comparison.

Measured on 2026-11-02. This is a staged runtime cleanup, with isolated test
applications. It is not yet a fully pruned Android-only source tree.

## Revisions and build

- Original fork `main`: `f95909b13187c0d7168c96ac0e3e09982b2ac96b`.
- Baseline: `50b3fe07676dfafb9e87201fdfc72d850fed0fde`, adding only the
  `file_picker` Java/Kotlin target alignment required to build locally.
- Experiment APK: `87dd6fa67c318e216a58113695aedb817f26824b`.
- Flutter 3.47.2, Dart 3.13.2, JDK 21.0.12; release `androidTv` flavor,
  `--target-platform=android-arm64`, TV forced, `android_tv_apk` distribution.
- Baseline package: `org.moonfin.androidtv.videobaseline` (Moonfin Test).
  Experiment: `org.moonfin.androidtv.videoexperiment` (Moonfin Video Experiment).

Both builds use the same dependency lockfile and inherited ABI filters.
Flutter AOT code is ARM64, but support JNI libraries for ARMv7 and x86_64 are
still included. These are not yet ARM64-only APKs. Build commands and local
toolchain notes are in [the experiment guide](../../docs/android-tv-video.md).

## APK size

| Release artifact | Bytes | MiB |
| --- | ---: | ---: |
| Baseline | 82,209,327 | 78.40 |
| Video experiment | 80,459,967 | 76.73 |
| Reduction | 1,749,360 | 1.67 (2.13%) |

Raw sizes, SHA-256 checksums, ZIP groups and native-library inventories:
[baseline](baseline-apk.json), [experiment](experiment-apk.json).
The APK measurement script was corrected to expose ZIP entries as PowerShell
objects before grouping; group sums were checked against the native inventory.
The APK files themselves were unchanged by this measurement correction.

The ARM64 native group shrank by 3,801,088 uncompressed bytes, chiefly Dart AOT
code eliminated by the video profile. Native dependencies and fonts remain in
the archive. APK size alone does not establish smoother navigation or lower
frame times.

## Device checks

Device: NVIDIA SHIELD Android TV, Android 11, ARM64 userspace. HDMI output was
3840 x 2160 at 59.94 Hz, with an existing Android logical-size override of
1920 x 1080. Renderer: default auto policy, Skia on this Shield. Both release
APKs installed alongside the regular application, with separate app data.

After manual sign-in to an Emby server, the experiment displayed the signed-in
Home screen and populated video rows. D-pad navigation to episode details,
resume playback, visible SubRip subtitles, and Back to details worked. The
download action was absent and restricted settings entries were hidden.
Settings were inspected without changing the viewer's preferences.

This was one H.264/EAC3 stereo episode. HDR, Dolby Vision, multichannel
passthrough, live TV, seeking, mpv fallback, reconnect and sustained navigation
frame times still need dedicated device checks. No FPS improvement is claimed.

## Startup and memory

Both apps were then manually connected to the same Emby account. Five
baseline/experiment pairs were collected in alternating order, with both
test packages force-stopped before each sample. Each app was left for 15
seconds after Activity launch before capturing PSS. Both apps reached Home;
there was no deliberate data/cache clearing or renderer/display change.
Separate app caches and the first-run/cache effects remain uncontrolled.

| Signed-in Home, five samples each | Baseline | Experiment |
| --- | ---: | ---: |
| Median Activity launch time | 1,307 ms | 1,155 ms |
| Activity launch range | 1,153–2,109 ms | 1,118–1,190 ms |
| Median settled process PSS | 322.5 MiB | 320.1 MiB |
| Settled PSS range | 317.8–338.1 MiB | 310.3–425.7 MiB |
| Mean settled process PSS | 325.4 MiB | 338.9 MiB |

Raw captures: [baseline](baseline-startup-signed-in.json),
[experiment](experiment-startup-signed-in.json). `Sequence` preserves the
cross-app order. All samples, including the experiment's first memory
outlier, are retained. The lower median Activity time is a preliminary
observation from one small run; overlapping memory ranges and the higher
experiment mean do not establish a memory improvement. This run measures
neither navigation frame times nor playback efficiency.

[The initial baseline capture](baseline-startup-signed-out.json) contains five
force-stop launches while signed out, at Add Server, with PSS captured after
15 seconds. It is retained as an initial diagnostic, not a signed-in browsing
baseline. The interrupted experiment run at that stage did not produce a
complete capture.

Activity launch time from `am start -W` ends before the application necessarily
has a usable Home screen. It is not a measurement of first usable content.
PSS is a point-in-time process measurement, not peak or playback memory.
No application data or artwork caches were cleared.

## Automated validation

- Both release APKs built successfully using the same toolchain.
- Analyzer: zero errors with `--no-fatal-infos --no-fatal-warnings`; 431
  warnings/information diagnostics remain. This is not a warning-free check.
- Default video profile: 251 tests passed in the focused serial run (profile,
  startup DI, preferences, library filtering, settings sync, Home, focus and
  Media3 delay/live-window behavior). One additional focus file failed to load;
  all three of its tests passed when rerun alone, for 254 passing tests across
  that run and retry.
- Seven inherited files covering authentication, EPUB images, Seerr sliders,
  playback limits, alphabet navigation and game filtering passed serially:
  47 tests using `MOONFIN_VIDEO_ONLY=false`.
- The full inherited suite with that compatibility flag did **not** pass as a
  complete run: 5,651 passed, two skipped, seven loader failures, and unfinished
  cases at runner shutdown. The observed loader failures reported connection
  closure before loading. Their isolated retries passed (the profile file is
  covered by the focused run), but the whole-suite completion problem remains
  unresolved. A full green regression run is still required.

Generated localization refreshes from Flutter were excluded from the branch's
commits. Server addresses, credentials, viewing titles and screenshots are
not included in these benchmark artifacts.

## Next decisions

Keep this experiment separate from `main`. Next collect sustained
D-pad/frame-time traces and repeat startup measurements. Then prune unused runners,
reader/game/native packages, Cast and downloader dependencies in small steps,
checking the video compatibility matrix after each change. Preserve subtitle
fonts, codec fallback and platform capability detection until device evidence
supports removing them.
