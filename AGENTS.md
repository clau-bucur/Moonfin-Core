# Android TV branch requirements

Seerr integration is a required feature of this branch. The user explicitly
requested that it be restored and not removed again. Preserve it during
cleanup, performance work and upstream merges unless the user explicitly
changes that requirement.

Keep Seerr navigation (top bar, sidebar and available bottom tabs), discovery,
requests/issues, media/person/collection routes, search results, Home rows,
availability badges and integration settings. Respect normal server
capabilities, account permissions, Kids Mode and the user's preferences;
do not disable Seerr through `VideoAppProfile` or remove its route factories.

Run the Seerr route, TV profile/preference, navigation visibility and search
regressions when changing these areas. Keep Android TV streaming restrictions
for the unrelated removed platforms, downloads, readers and games.

For MiBedroom deployment, the target is `mitvbedroom.gme:5555` (MiTV-AYFR0,
32-bit `armeabi-v7a` Android). Update the main package `org.moonfin.androidtv`
in place with the existing local signing key. Never uninstall or clear app data
without explicit user approval for that operation.
