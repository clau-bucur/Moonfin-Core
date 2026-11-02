import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../l10n/app_localizations.dart';
import '../../../preference/user_preferences.dart';
import '../../../util/tv_image_cache_stub.dart'
    if (dart.library.io) '../../../util/tv_image_cache_io.dart';
import '../../widgets/focus/request_initial_focus.dart';
import 'settings_app_bar.dart';

/// Artwork caching remains useful for streamed video; media downloads do not.
class CacheSettingsScreen extends StatelessWidget {
  const CacheSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = GetIt.instance<UserPreferences>();
    final l10n = AppLocalizations.of(context);
    return RequestInitialFocus(
      child: Scaffold(
        appBar: buildSettingsAppBar(context, Text(l10n.imageCacheLimit)),
        body: ListenableBuilder(
          listenable: preferences,
          builder: (context, _) => ListView(
            children: [
              for (final limit in const [0, 100, 200, 350, 500, 1024, 2048])
                RadioListTile<int>(
                  autofocus:
                      limit ==
                      preferences.get(UserPreferences.imageCacheLimitMb),
                  title: Text(limit == 0 ? l10n.noLimit : l10n.mbValue(limit)),
                  value: limit,
                  groupValue: preferences.get(
                    UserPreferences.imageCacheLimitMb,
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    unawaited(
                      preferences.set(UserPreferences.imageCacheLimitMb, value),
                    );
                    unawaited(enforceImageCacheBudget(value * 1024 * 1024));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(l10n.clearImageCache),
                onTap: () async {
                  await clearImageDiskCache();
                  PaintingBinding.instance.imageCache.clear();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.imageCacheCleared)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
