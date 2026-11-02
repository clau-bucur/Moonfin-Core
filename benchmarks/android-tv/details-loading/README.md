# Details loading and PR verification

Date: 2026-11-02. Branch: `experiment/android-tv-video`.

## PR #1541

Ported [PR #1541](https://github.com/Moonfin-Client/Moonfin-Core/pull/1541), source
commit `d047833b43753800fe3d996c80070b60819803cc`. GitHub's API confirmed the PR
head is `e3d49e2945c3d5a1b6ffcdeb0bc90a3192a930a1`; its only later commit retries CI.

Detail pages show no placeholder controls while loading. If a request takes
600 ms, the configured Moonfin loading animation appears. Ready content replaces
it immediately; there is no mandatory minimum loading duration. Image, size,
speed, position, bouncing position, and None preferences remain supported.
Leaving the page cancels the timer. Existing ready-content loading coordination
from the video cleanup is retained.

The shared loading widget covers all six current detail styles. Removed the
obsolete placeholder-layout assertions and updated the Nouveau transition test.
No platform runners, non-video features, or dependencies are restored.

44 focused tests passed: 43 loading/skeleton checks and one Nouveau loading-to-
content check. Targeted analysis found no issues; `git diff --check` passed.

## PR #1542

GitHub's API confirmed that [PR #1542](https://github.com/Moonfin-Client/Moonfin-Core/pull/1542)
ends at `769a9b64a1c142bcb429f94e1608cbc8bf874711`, exactly the animation commit
recovered before the user supplied the link. The following restored files have
identical Git blob hashes to that PR:

| File | Git blob |
| --- | --- |
| `lib/ui/widgets/modern_card_transition.dart` | `632bd896c6d28efa49dfe493a90adb838d2040e2` |
| `lib/ui/widgets/focus/modern_row_navigation.dart` | `e948eeeaaf62d53afdd419a08378fa8c551befe3` |
| `lib/ui/widgets/modern_row_visibility.dart` | `ab7b59ab40aec6a713b58e2bdaf462c1a49463fd` |

The row scroll simulation and exact-width sliver were adapted to the current
controller API and stable per-card focus widgets. Home uses the original shared
timing and row fading. Its wide-image crop/reveal and fixed-height, stationary
text fade retain the newer video-branch requirements instead of restoring the
old poster-to-backdrop image swap. See the [motion report](../restored-motion/README.md)
for 173 preceding focused checks.

Each Home row remembers its selected card and horizontal position during the
current app session, including row changes and returns from details. This memory
is not written to disk across app restarts.

## Shield gate

The combined Android TV ARM64 release build passed for source commit
`31bce8df1f79b323e5185981d1b69391b3edfde9`. APK signature verification and package
identity checks passed. The APK at
`artifacts/android-tv-video/release-android-arm64/moonfin-video-experiment.apk`
contains 66,372,384 bytes (63.30 MiB). SHA-256:
`07d5a11ae7c06cdd1800b55bf2456891a14a314ba4f054d86efef098a3450a5c`.

See [validation results](local-validation.json) and [APK inventory](experiment-apk.json).

The combined revision has not been installed or tested on the Shield. Wait for
the user's next OK, then check card bounce, text anchoring, row transitions,
selection restoration, details loading, and Movie/Episode Restart.
