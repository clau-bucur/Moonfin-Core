import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';
import 'package:server_emby/server_emby.dart';
import 'package:server_jellyfin/server_jellyfin.dart';
import 'package:server_plex/server_plex.dart';
import 'package:server_silo/server_silo.dart';

import '../../util/platform_detection.dart';
import '../../util/server_url.dart';

class MediaServerClientFactory {
  final DeviceInfo deviceInfo;
  final Map<String, MediaServerClient> _clients = {};

  /// Called when a Jellyfin server answers a request with 403.
  final void Function()? onForbidden;

  MediaServerClientFactory({required this.deviceInfo, this.onForbidden});

  Map<String, MediaServerClient> get clients => Map.unmodifiable(_clients);

  /// The server id [client] was created under, or its base URL for a client
  /// this factory did not create.
  ///
  /// Match the client instance so editing its address does not change its id.
  String serverIdOf(MediaServerClient client) {
    for (final entry in _clients.entries) {
      if (identical(entry.value, client)) return entry.key;
    }
    return client.baseUrl;
  }

  MediaServerClient getClient({
    required String serverId,
    required ServerType serverType,
    required String baseUrl,
  }) {
    final normalizedBaseUrl = normalizeServerBaseUrl(baseUrl);
    return _clients.putIfAbsent(serverId, () {
      return _createClient(
        serverType: serverType,
        baseUrl: normalizedBaseUrl,
      );
    });
  }

  MediaServerClient? getClientIfExists(String serverId) {
    final client = _clients[serverId];
    if (client != null) return client;

    if (serverId.contains('://')) {
      final normalizedInput = normalizeServerBaseUrl(serverId);
      if (normalizedInput.isNotEmpty) {
        for (final activeClient in _clients.values) {
          if (normalizeServerBaseUrl(activeClient.baseUrl) == normalizedInput) {
            return activeClient;
          }
        }
      }
    }
    return null;
  }

  /// The loaded client for [serverId], or the active client when it is empty or
  /// that server is not loaded.
  MediaServerClient clientForServerOrActive(String? serverId) {
    final active = GetIt.instance<MediaServerClient>();
    if (serverId == null || serverId.isEmpty) return active;
    return getClientIfExists(serverId) ?? active;
  }

  MediaServerClient getActiveClient() {
    if (_clients.isEmpty) throw StateError('No active server clients');
    return _clients.values.last;
  }

  MediaServerClient _createClient({
    required ServerType serverType,
    required String baseUrl,
  }) {
    switch (serverType) {
      case ServerType.jellyfin:
        return JellyfinMediaServerClient(
          baseUrl: baseUrl,
          deviceInfo: deviceInfo,
          interceptors: [
            if (onForbidden != null)
              InterceptorsWrapper(
                onError: (error, handler) {
                  if (error.response?.statusCode == 403) onForbidden!();
                  handler.next(error);
                },
              ),
          ],
        );
      case ServerType.emby:
        return EmbyMediaServerClient(
          baseUrl: baseUrl,
          deviceInfo: deviceInfo,
        );
      case ServerType.plex:
        return PlexMediaServerClient(
          baseUrl: baseUrl,
          deviceInfo: deviceInfo,
        );
      case ServerType.silo:
        return SiloMediaServerClient(
          baseUrl: baseUrl,
          deviceInfo: deviceInfo,
          platform: _siloDevicePlatform(),
        );
    }
  }

  void removeClient(String serverId) {
    _clients.remove(serverId)?.dispose();
  }

  void disposeAll() {
    for (final client in _clients.values) {
      client.dispose();
    }
    _clients.clear();
  }
}

/// The platform Silo records for this device (`X-Silo-Device-Platform`),
/// named the same way as the client name in `lib/di/injection.dart`.
String _siloDevicePlatform() {
  if (PlatformDetection.isAppleTV) return 'tvOS';
  if (PlatformDetection.isWeb) return 'Web';
  if (PlatformDetection.isAndroid) {
    return PlatformDetection.isTV ? 'Android TV' : 'Android';
  }
  if (PlatformDetection.isIOS) return 'iOS';
  if (PlatformDetection.isMacOS) return 'macOS';
  if (PlatformDetection.isWindows) return 'Windows';
  if (PlatformDetection.isLinux) return 'Linux';
  return 'Unknown';
}
