# Android TV video experiment

This branch focuses on streamed video browsing and playback on Android TV. The
regular fork checkout and `main` are kept separate from this worktree.

## First cleanup

- Media3 is the initial Android backend. mpv is constructed only when selected
  or explicitly needed by a trailer; player widgets use the active backend
  without resolving an unused fallback.
- Startup skips offline catalogue warming, download services, offline reconnect
  sync, downloaded-media recovery, achievement services and AirPlay startup.
- Video browsing hides music, audiobook, book, photo and game libraries. Search
  skips their result groups and avoids fetching games and Seerr requests.
- Deep links to non-video playback, games, readers, administration and Seerr
  redirect to Home. Server login, profiles, search, details, video, live TV,
  subtitles, HDR, passthrough, resume and Watch Next remain.
- Automatic previews, theme music and seasonal effects are disabled locally.
  Restricted settings are hidden. Stored preferences are retained, and settings
  sync exports the stored values rather than the experiment's restrictions.
- TV beta shares the TV manifest instead of losing the Leanback requirement.

`VideoAppProfile` defaults to enabled on this branch. Its temporary
`MOONFIN_VIDEO_ONLY=false` opt-out supports tests of retained shared internals during
the staged cleanup. It no longer restores deleted feature routes or packages. The supplied build command explicitly enables the profile
and forces the TV interface.

## Second cleanup

- Removed the iOS, tvOS, macOS, Windows, Linux and web app runners, their build
  helpers, and platform-specific publishing jobs. CI now builds only this TV
  experiment; Android mobile flavors are gone.
- Removed reader/emulator route factories and the EPUB, PDF, MOBI, RAR and
  native archive-extraction implementations and vendored packages.
- Removed the Android libretro JNI build, emulator bridges, Google Cast sender
  framework, DLNA sender and Firebase push integration.
- Removed direct desktop/tvOS dependencies. Android remote keys stay native;
  analog stick navigation uses the existing app channel without the gamepads
  plugin. Desktop window management and Apple remote/parallax hooks are gone.
- Retained server-session remote control; it no longer registers native Cast,
  DLNA or AirPlay discovery/event subscriptions in the TV video profile.

Media3, mpv, subtitle fonts, HDR/audio capability probes, audio focus, media
buttons, Watch Next and video WebView trailers remain. Removing these would
change video compatibility, not merely remove unrelated features.

## Third cleanup and browsing changes

- Removed the offline database/catalog, saved-media screens, media storage
  helpers, download engines, subscriptions, background workers and local
  notification infrastructure. Playback and clients now use the server directly.
- Removed Drift, SQLite FFI/native bindings, background_downloader and local
  notification dependencies, plus the native Media3 Transformer exporter.
  Artwork/theme/message caches remain; flutter_cache_manager still uses sqflite.
- Modern Home cards crop the same wide artwork while collapsed, then reveal it
  as the card expands. The decode size stays fixed through the transition.
- Held D-pad movement keeps the row expanded. Vertical navigation retargets a
  spring using its current velocity; reserved focus space keeps row heights fixed.
- Home coalesces section arrivals within a frame and retains bounded loading.
  Details publish their seasons/episodes or initial collection/playlist members
  with the first ready state. Optional recommendations and ratings still load
  asynchronously, so this does not eliminate every later content update.
- Root Back shows a two-second “Press back again to exit” toast. A second
  separate press exits; changing route clears it. The modal exit prompt is gone.
- Restart is available in the video player's secondary controls for movies and
  episodes. It seeks the current stream to zero and resumes without replacing
  its queue or track selections.
- Media3's initial streaming threshold is 500 ms instead of 1,000 ms. Steady
  state, rebuffer and HDMI mode-switch settling safeguards remain. Diagnostics
  record source-to-audio-track and source-to-audio-position-advancing times;
  these are not a measurement of receiver audibility.

The receiver and perceived-motion improvements remain experimental until tested
on the Shield. Device installation, launch and testing require the user's next
explicit OK. Local builds and unit/widget/JVM checks do not access the Shield.

Some non-video shared Dart models/helpers and transitive platform metadata
remain. No frame-rate or audible-startup improvement is claimed from APK size.

## Build an isolated test app

Use the pinned Flutter SDK (3.47.2), Android SDK/NDK and JDK. This branch fixes
`file_picker`'s Java 17/Kotlin host-JDK target mismatch under AGP 9.

```powershell
.\build-android-tv-video.ps1
```

The default builds the ARM64 Flutter release, application id
`org.moonfin.androidtv.videoexperiment`, named **Moonfin Video Experiment**.
It installs alongside the regular/beta applications. Outputs and APK size JSON
go under the ignored `artifacts/android-tv-video` directory.

The inherited Gradle ABI filters still package support JNI libraries for
ARM64, ARMv7 and x86_64. `--target-platform=android-arm64` selects Flutter's
AOT output; it does not yet make this an ARM64-only archive. Both measured
APKs use the same ABI policy. Other architecture builds are not yet validated.

For other supported Android userspace architectures or Flutter profiling:

```powershell
.\build-android-tv-video.ps1 -Architecture android-arm
.\build-android-tv-video.ps1 -Configuration profile
```

This machine needed `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\Development\temp`
to avoid a Windows Java selector socket error. That is a local build workaround,
not an application requirement or a renderer setting.

## Reproducible baseline

The baseline revision is `50b3fe07676dfafb9e87201fdfc72d850fed0fde`: upstream
`f95909b13187c0d7168c96ac0e3e09982b2ac96b` plus only the `file_picker` build fix.
Build it in a detached worktree, with the same SDK, lockfile, architecture,
release mode, renderer policy and distribution define as the experiment:

```powershell
$env:MOONFIN_TEST_ID_SUFFIX = '.videobaseline'
flutter pub get --enforce-lockfile
flutter build apk --release --flavor androidTv `
  --target-platform=android-arm64 --analyze-size `
  --dart-define=MOONFIN_FORCE_TV=true `
  --dart-define=DISTRIBUTION_CHANNEL=android_tv_apk
```

Never install the baseline over the regular app or clear the regular app's data.
The baseline has a separate package id. Keep both build outputs; a later build
in the same directory overwrites Flutter's standard APK path.

Allow the build's pub/tooling preparation to run. With this Flutter version,
running a release build with `--no-pub` immediately after a plain `pub get` can
leave the generated Android registrant referencing the dev-only integration
test plugin, although Gradle correctly excludes that plugin from release.

## Measurements

See [the first-round results](../benchmarks/android-tv/README.md) and
[second cleanup results](../benchmarks/android-tv/second-cleanup/README.md)
for measured APK sizes, device checks and unresolved validation work.

```powershell
.\scripts\measure-apk.ps1 -ApkPath <apk> -SourceRevision <commit> `
  -OutputPath <apk-size.json>

.\scripts\measure-android-tv-startup.ps1 -Serial <adb-device> `
  -PackageName org.moonfin.androidtv.videobaseline `
  -OutputPath <baseline-startup.json>
```

Repeat the startup command for `org.moonfin.androidtv.videoexperiment`.
The startup script only accepts those two experimental package ids. It stops
and launches that package without clearing data, records Android Activity
launch time and process PSS after a fixed settling period, and saves raw
measurement outputs. It does not reset caches, change renderer preferences,
uninstall apps or clear logcat.

**Activity launch time is not time to usable Home.** Record the current route,
sign-in state, server/account, artwork/cache state, active renderer and display
mode alongside samples. Compare like-for-like states and alternate app order.
Initial sign-in-screen results validate startup and idle resource use, not
library navigation or playback performance.

Signed-in follow-up: profile sustained D-pad movement, row changes, detail
open/back, browse/play/back cycles and warm/cold artwork. Use Flutter DevTools
in profile mode, Perfetto for native/graphics work and Media3 playback metrics.
Check subtitles, HDR/Dolby Vision, passthrough, seek/resume, HDMI changes and
server reconnect on actual TVs. Preserve subtitle fonts and codec fallback
behavior until that compatibility matrix passes.

## Checks

The new video-profile tests run with the default profile. The inherited suite
can also exercise the retained shared implementation with its compatibility
profile, because many inherited tests deliberately assert reader/game/preview
behavior in the remaining shared code. Deleted feature tests are removed alongside
the implementations; the opt-out cannot recover deleted readers or emulators:

```powershell
flutter test --no-pub test/util/video_app_profile_test.dart `
  test/di/video_module_startup_test.dart `
  test/preference/video_app_profile_preference_test.dart `
  test/data/repositories/user_views_repository_test.dart `
  test/data/services/plugin_sync_service_loop_test.dart

flutter test --no-pub --dart-define=MOONFIN_VIDEO_ONLY=false
flutter analyze --no-pub
```

Local server/playback packages have their own test development dependencies.
Run `dart pub get` in those package directories before analyzing their tests;
the root Flutter dependency resolution does not install nested dev dependencies.
Generated localization files should not be committed merely because the
current Flutter generator refreshes them during a build.
