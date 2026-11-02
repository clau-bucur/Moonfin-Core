import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import '../../data/services/access_schedule_service.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/media_server_client_factory.dart';
import '../../playback/server_transcode_capabilities.dart';

final _getIt = GetIt.instance;

void registerServerModule() {
  _getIt.registerLazySingleton<MediaServerClientFactory>(
    () => MediaServerClientFactory(
      deviceInfo: _getIt<DeviceInfo>(),
      onForbidden: () => _getIt<AccessScheduleService>().noteRefused(),
    ),
  );
  if (!_getIt.isRegistered<ServerTranscodeCapabilities>()) {
    _getIt.registerLazySingleton<ServerTranscodeCapabilities>(
      () => ServerTranscodeCapabilities(),
    );
  }
}

void setActiveServerClient(MediaServerClient client) {
  if (_getIt.isRegistered<MediaServerClient>())
    _getIt.unregister<MediaServerClient>();
  _getIt.registerSingleton<MediaServerClient>(client);
  unawaited(_getIt<ServerTranscodeCapabilities>().refresh(client));
  if (_getIt.isRegistered<ConnectivityService>()) {
    unawaited(
      _getIt<ConnectivityService>().onServerClientReady(
        _getIt<MediaServerClientFactory>().serverIdOf(client),
      ),
    );
  }
}
