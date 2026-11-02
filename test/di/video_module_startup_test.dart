import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/services/achievements_service.dart';
import 'package:moonfin/data/services/background_download_coordinator.dart';
import 'package:moonfin/data/services/download_notification_service.dart';
import 'package:moonfin/data/services/media_server_client_factory.dart';
import 'package:moonfin/data/services/remove_watched_service.dart';
import 'package:moonfin/data/services/sync_service.dart';
import 'package:moonfin/di/modules/app_module.dart';
import 'package:moonfin/di/modules/playback_module.dart';
import 'package:moonfin/di/modules/server_module.dart';
import 'package:moonfin/platform/pip_service.dart';
import 'package:moonfin/playback/media3_player_backend.dart';
import 'package:moonfin/playback/media_kit_player_backend.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/util/video_app_profile.dart';
import 'package:playback_core/playback_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ClientFactory extends Mock implements MediaServerClientFactory {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final getIt = GetIt.instance;
  const events = MethodChannel('moonfin/media3_video_events');
  const control = MethodChannel('moonfin/media3_video_control');

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    getIt.registerSingleton<UserPreferences>(UserPreferences(store));
    for (final channel in [events, control]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
    }
  });

  tearDown(() async {
    if (getIt.isRegistered<PlaybackManager>())
      getIt<PlaybackManager>().dispose();
    if (getIt.isRegistered<PipService>()) getIt<PipService>().dispose();
    await getIt.reset();
    debugDefaultTargetPlatformOverride = null;
    for (final channel in [events, control]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test('Media3 startup leaves the native mpv fallback unconstructed', () async {
    getIt.registerSingleton<MediaServerClientFactory>(_ClientFactory());
    registerPlaybackModule();
    await Future<void>.delayed(Duration.zero);

    expect(getIt<PlaybackManager>().backend, isA<Media3PlayerBackend>());
    expect(getIt.isRegistered<MediaKitPlayerBackend>(), isTrue);
    expect(
      getIt.checkLazySingletonInstanceExists<MediaKitPlayerBackend>(),
      isFalse,
    );
  });

  test('video startup excludes download and achievement services', () {
    registerServerModule();
    registerAppModule();
    expect(getIt.isRegistered<BackgroundDownloadCoordinator>(), isFalse);
    expect(getIt.isRegistered<DownloadNotificationService>(), isFalse);
    expect(getIt.isRegistered<SyncService>(), isFalse);
    expect(getIt.isRegistered<RemoveWatchedService>(), isFalse);
    expect(getIt.isRegistered<AchievementsService>(), isFalse);
  }, skip: !VideoAppProfile.enabled);
}
