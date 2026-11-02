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
`MOONFIN_VIDEO_ONLY=false` opt-out supports inherited regression tests during
the staged cleanup. The supplied build command explicitly enables the profile
and forces the TV interface.

This round does **not** yet delete every unused source package, platform runner,
native game bridge, Cast dependency or the PDF engine. The lazy offline database
registration also remains for existing shared callers; streaming bypasses the
offline client/resolver wrappers. Package and native pruning follow measured
validation of this first runtime reduction. No frame-rate gain is assumed.

## Build an isolated test app

Use the pinned Flutter SDK (3.47.2), Android SDK/NDK and JDK. This branch fixes
`file_picker`'s Java 17/Kotlin host-JDK target mismatch under AGP 9.

```powershell
.\build-android-tv-video.ps1
```

The default is an ARM64 release APK, application id
`org.moonfin.androidtv.videoexperiment`, named **Moonfin Video Experiment**.
It installs alongside the regular/beta applications. Outputs and APK size JSON
go under the ignored `artifacts/android-tv-video` directory.

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
behavior that this branch removes:

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
