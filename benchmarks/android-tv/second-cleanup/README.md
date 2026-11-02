# Second cleanup: runners and non-video engines

Measured on 2026-11-02. Runtime APK revision:
`de19c5803cd91ff822673b7b1dfbdc36a2d9af7a`. Subsequent changes retire obsolete
emulator tests and record these results; they do not change the runtime code.
The fork's `main` remains at `f95909b13187c0d7168c96ac0e3e09982b2ac96b`.

## Removed

- iOS, tvOS, macOS, Windows, Linux and web app runners, their build/publishing
  helpers and Android mobile flavors. CI now targets the Android TV experiment.
- EPUB/PDF/MOBI/comic reader implementations and assets, native archive/RAR
  extraction, emulator player screens, core downloading and the libretro JNI
  build/bridge.
- Firebase push integration, native Google Cast/DLNA sender integrations, desktop
  window management and Apple remote/parallax hooks. Server-session remote
  control remains available without native sender discovery subscriptions.
- Tests belonging to deleted features. The replacement Android input tests
  cover native D-pad delivery and stick-navigation preference forwarding.

[Dependency inventory](dependency-diff.json): 293 resolved packages became
241, with **52 removals, no additions and no retained-version changes**.
`archive`, `dbus` and `webview_flutter_wkwebview` changed from direct to
transitive dependencies; they were not removed entirely. Seven Android plugin
registrations disappeared, as listed in [the artifact audit](artifact-audit.json).

Removing Cast exposed the app's direct use of the `audio_service` superclass.
The app now declares `androidx.media:media:1.7.0` explicitly, matching the
existing audio plugin dependency, so video media-session controls remain.

## APK size and native verification

| ARM64 Flutter release, same support-JNI ABI policy | Bytes | MiB |
| --- | ---: | ---: |
| Original runtime baseline (`50b3fe0`) | 82,209,327 | 78.40 |
| First cleanup (`87dd6fa`) | 80,459,967 | 76.73 |
| Second cleanup (`de19c58`) | 69,424,326 | 66.21 |

This cleanup saves **11,035,641 bytes / 10.52 MiB / 13.72%** versus the first
cleanup. Total reduction from the original runtime baseline is 12.19 MiB.

The APK was inspected after a successful release build: no `libpdfium.so`,
`librar_native.so` or `libmoonfin_libretro.so` remains. ARM64 mpv, libass and
libasskt remain. The package is still `org.moonfin.androidtv.videoexperiment`,
with a required Leanback feature. [The APK report](experiment-apk.json) records
its SHA-256, size groups and full native library inventory.

This retains the first round's toolchain and ABI policy: Flutter 3.47.2 / Dart
3.13.2, JDK 21.0.12, release `androidTv`, forced TV/video profile, ARM64 AOT,
and support JNI libraries for ARM64, ARMv7 and x86_64. Size savings therefore
do not include a switch to ARM64-only packaging.

## Verification

- Release APK built successfully. It updated only the separate experiment app
  on the Shield, preserving its sign-in and application data.
- **256 Flutter tests passed:** the same 254 video-profile, Home, focus and
  Media3 checks as the first round, plus two replacement Android input checks.
- **47 Android native tests passed**, zero failures/skips. The available task
  is `:app:testAndroidTvDebugUnitTest`; this configuration has no release
  unit-test task. [Native suite summary](native-tests.json).
- `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings` completed
  with zero errors. Warnings and information diagnostics remain.
- The full inherited Flutter suite was not rerun; its previous runner/
  completion issue remains unresolved. These results do not claim a fully
  green inherited suite or complete compatibility coverage.

On NVIDIA SHIELD Android TV / Android 11, the updated app loaded signed-in
Home and video rows. Video search returned movie, series and episode groups;
opening a result displayed its details. A 720p H.264 source with DTS 5.1 audio
rendered, remote seeking advanced into dialogue, SubRip subtitles were visible,
media play/pause worked, and Back returned to details showing a saved resume
position. This does not verify the physical audio output format or passthrough.

The existing HDMI mode was 3840 x 2160 / 59.94 Hz with a 1920 x 1080 logical
size override. The TV renderer policy remains unchanged (Skia on this device).
No viewer settings were changed. Screenshots, titles, server addresses and
credentials are excluded from the committed artifacts.

## Repeated startup and memory check

The unchanged original-runtime baseline (`50b3fe0`) and this cleanup were
measured in five alternating pairs. Both test packages were force-stopped
before each launch; PSS was captured after 15 seconds. Both retained the same
signed-in account, existing caches and default renderer policy. No settings
were changed and no caches/data were cleared.

| Signed-in Home, five samples each | Original-runtime baseline | Second cleanup |
| --- | ---: | ---: |
| Median Activity launch time | 1,029 ms | 895 ms |
| Activity launch range | 994–1,271 ms | 858–954 ms |
| Median settled process PSS | 308.9 MiB | 272.2 MiB |
| Settled PSS range | 295.3–329.3 MiB | 270.3–321.9 MiB |
| Mean settled process PSS | 309.9 MiB | 283.1 MiB |

Raw [baseline](baseline-startup-signed-in.json) and
[experiment](experiment-startup-signed-in.json) captures preserve every sample
and cross-app order. These are preliminary observations from one small run.
Separate caches, metadata/artwork warming, system state and first-run effects
remain uncontrolled, and the memory ranges overlap. Do not compare these
numbers directly with the first round's historical run as an isolated measure
of this cleanup; the concurrently repeated baseline is the comparison here.

Activity launch time ends before Home is necessarily usable; it is not time
to usable content. PSS measures one idle process moment, not peak/playback
memory. Neither metric measures scrolling frame times or playback efficiency.

## Remaining work

Shared offline/download/settings code still retains the background downloader,
local notifications and SQLite/Drift dependencies behind disabled paths. These
need an extraction from shared item/connectivity/settings code before their
plugins can be removed. Some non-video pure Dart models/helpers also remain.

HDR/Dolby Vision, passthrough, live TV, reconnect, mpv fallback, and sustained
D-pad frame-time traces need further device coverage. APK size and Activity
launch measurements do not establish a scrolling/FPS improvement.
