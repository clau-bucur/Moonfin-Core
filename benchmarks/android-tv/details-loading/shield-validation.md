# Shield validation — 2026-11-02

Installed and verified the final experiment build from
`8a6b1f14ad272344f75710a79700e5e251da7593`. Its installed APK hash matches the
local release: `4696ce63651d07885ef8196d1502bde45374caaab3444bf8a85d46d9e29f2028`.
Package: `org.moonfin.androidtv.videoexperiment`; size: 66,371,232 bytes.
Sign-in was preserved. `main` remains at `f95909b13187c0d7168c96ac0e3e09982b2ac96b`.

| Check | Result |
| --- | --- |
| Card expansion, rapid reversals, injected long-press repeat | Passed; no artwork-height bounce observed in reviewed captures |
| Up/Down navigation across three Home rows | Passed; headings remain visible |
| Independent selected card and horizontal position per row | Restored on revisits |
| Movie/series details open and Back | Returned to the selected Home card |
| Parked pointer plus remote navigation/details return | Passed after the hover fix; no second hover selection |
| Movie Restart | Leftmost transport control; paused nonzero position → playing at zero, same item |
| Episode Restart | Leftmost transport control; paused nonzero position → playing at zero, same episode |
| Final state | Home, playback stopped; no crash or logged layout exception observed |

Two issues found during device testing were fixed on the experiment branch:

- `9c26a707e`: a parked virtual mouse could keep hover styling or expand another
  card as the layout moved beneath it. TV hover callbacks now require genuine
  pointer movement and end when the remote takes over. The new regression failed
  before the fix; 19 relevant checks passed afterward, with clean analysis.
- `8a6b1f14a`: cached vertical offsets counted internal row padding twice, causing
  increasing overscroll of lower headings. The offsets now sum the actual fixed
  sliver extents. 23 row geometry/navigation/memory checks passed; targeted
  analysis reported only two inherited style infos.

Restart was repeated after the hover fix. The final build's only subsequent
change was the Home offset calculation; affected Home navigation and details
return were then checked again on that installed build. The movie was restored
near its original four-minute resume position, and the test episode was restored
to zero. Other apps were not replaced or stopped.

Fast LAN details requests showed no skeleton-control flashes. They completed
before the delayed loading indicator appeared, so the 600 ms slow-loading path
was not exercised on the Shield; its timing, dismissal, and settings remain
covered by the preceding 44 local checks.

These are functional checks and visual review, without an FPS/frame-time
benchmark. Results use an uninterrupted scripted pass after the user left the
remote idle; earlier mixed manual/scripted recordings were excluded. Screenshots,
recordings, and raw diagnostics stay private under `C:/Development/temp`.
The final navigation recording is `mf-aligned-navigation.mp4`.

See [machine-readable results](shield-validation.json). The pre-existing generated
Finnish, Italian, and Chinese localization changes remain uncommitted and preserved.
