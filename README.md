# Moonfin Android TV video experiment

This branch of Moonfin focuses on streamed video browsing and playback on
Android TV. Work stays on `experiment/android-tv-video`; the fork's `main`
retains the original multi-platform application.

Build the isolated test application with:

```powershell
.\build-android-tv-video.ps1
```

The default package is `org.moonfin.androidtv.videoexperiment`, named
**Moonfin Video Experiment**. It installs alongside the regular application.

See [the build and cleanup guide](docs/android-tv-video.md) and
[the measured baseline](benchmarks/android-tv/README.md). The first runtime
cleanup and this dependency cleanup preserve Media3, mpv video fallback,
subtitles, Android media sessions, TV remote input and Watch Next.

Only Android app runners remain. Removed features include book/comic readers,
game playback, mobile push messaging and native Cast/DLNA sender integration.
Shared offline/settings code still exists; this is an experiment in stages.
APK size and startup timings do not by themselves demonstrate smoother UI.

Based on [Moonfin Core](https://github.com/Moonfin-Client/Moonfin-Core).
See the [upstream integration report](docs/android-tv-upstream-integration-2026-11-06.md)
for imported features, TV adaptations and validation.
The existing [license](LICENSE) applies.
