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
