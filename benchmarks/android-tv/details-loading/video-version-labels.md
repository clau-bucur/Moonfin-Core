# Video version labels — 2026-11-03

Source `7b5e67df5bd73d7a213d89da1f49d13b299eb667` on
`experiment/android-tv-video` replaces filenames in Stage's Version chip and
the Version picker with compact source-specific video summaries, for example
`4K · 61.6 Mbps · DoVi` or `1080p · 17.5 Mbps · SDR`.

Resolution tiers use width as well as height so cropped films retain the proper
4K/1080p tier. Bitrate uses the source bitrate, with the video stream's bitrate
as a fallback. Dynamic range accepts Jellyfin and Emby fields; unknown metadata
is omitted. No filename parsing or extra server requests are needed. The picker
shows codec and container underneath, and numbers otherwise identical summaries.
When no details exist, the existing localized Version number is used.

Local checks: 32 tests pass (15 source-summary, 8 Stage, 9 video-range tests).
They include cropped resolution, SDR/HDR10/HDR10+/HLG/DoVi, numeric metadata,
unknown values, the chip and picker labels, and picker focus restoration.
Targeted analysis has no errors or warnings; 22 existing style infos remain.

Shield release: 66,374,568 bytes; installed APK hash matches the local release:
`d08fe1537d16304cccecd60ab6a09e578e932001cf222fde0d27226af9cca847`.

| Shield check | Result |
| --- | --- |
| Hellboy II chip and picker | `4K · 61.6 Mbps · HDR10` and `1080p · 17.2 Mbps · SDR`, no filename or truncation |
| Select 1080p | Chip updates to the matching summary; picker checkmark follows selection |
| Restore original 4K | Original selection restored; resume position left unchanged |
| Dismiss picker | Focus returns to Version |
| Kill Bill chip and picker | `4K · 88.5 Mbps · DoVi` and `1080p · 30.8 Mbps · SDR` |
| Codec/container | HEVC/H264 and MKV shown below picker entries |
| Runtime/layout log | No matched fatal, unhandled, overflow, late-initialization or disposed-state errors |
| Final state | Home; playback was not started during these checks |

Private screenshots and diagnostics remain under `C:/Development/temp`, using
the `mf-version-labels-` prefix. These are functional and visual checks, not a
frame-time performance benchmark.

Main is untouched. The pre-existing generated Finnish, Italian and Chinese
localization edits remain uncommitted and preserved.
