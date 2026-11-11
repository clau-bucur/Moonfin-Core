# Seerr restoration on Android TV

Seerr is a required feature of this branch, per the user's explicit instruction
after the November 11 MiBedroom deployment. Preserve it in future upstream
merges and cleanup work; the branch requirements are in [AGENTS.md](../AGENTS.md).

The TV profile now honors the viewer's Seerr enabled/navigation/badge settings
instead of overriding them. Both TV navigation layouts and bottom-tab gates
use the normal availability and Kids Mode checks. Integration settings and
their search entries are offered on supported signed-in servers.

Restored all six upstream route factories: discovery, requests/issues, browse,
media, collection and person. Media and person navigation reuse the shared
detail screens, including Quick Look. Search returns requestable Seerr titles
again. Seerr Home rows and linked Watching Now rows follow their saved settings
and the existing deferred-loading policy.

The user can still hide the button or disable features. Server capabilities,
account permissions and Kids Mode still apply. This does not restore the
removed downloads, native push, readers, games or non-Android app runners.

CI covers route resolution, the TV profile's Seerr preferences, real search
results and button visibility in the TV toolbar/sidebar. Feature regression
and build/deployment logs are under `artifacts/seerr-restoration`.

Validation before the release build: 31 route/profile/preference/search/Home
cases, two toolbar/sidebar visibility cases and 57 authentication, permissions,
request/status and Home-settings cases passed (90 total). Full static analysis
passed with zero errors and the same 11 existing warnings.

## MiBedroom release and deployment

Built and installed source `3e07c9e18dff516ee048392c5e13db092511fcf6` as the
main `org.moonfin.androidtv` app for 32-bit ARM. The release is 69,454,043 bytes,
SHA-256 `61e3b9771f216bf2d8608bc082d5a322215814ed665ba20b384dc2c3566b1f16`.
Its signing certificate matches the existing local main installation.

Used `adb install -r` on `mitvbedroom.gme:5555`, preserving app data. The
first-install timestamp remains `2026-11-11 23:01:15`; the update timestamp is
`2026-11-11 23:45:11` (device local time). The on-device checksum matches the
release, the app remains running, and startup logs contain no fatal entries.

Visual checks confirmed the existing signed-in Home library, the restored
Seerr top-navigation entry, and discovery populated with existing Recent
Requests. Screenshots and logs are in the evidence directory. The separate
Requests route is covered by automated tests; an on-device attempt to open
it did not establish that page's result. A later navigation check briefly
resumed Fargo; playback was exited and the detail drawer dismissed. No Seerr
requests were submitted during verification.
