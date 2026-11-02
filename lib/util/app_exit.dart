import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../playback/mpv_player_registry.dart';
import 'platform_detection.dart';

class AppExit {
  static const MethodChannel _platformChannel = MethodChannel(
    'org.moonfin.androidtv/platform',
  );

  static const MethodChannel _appleTvSystemChannel = MethodChannel(
    'moonfin/appletv_system',
  );

  static Future<void>? _teardown;

  /// Releases native players before process exit. Safe across all exit paths.
  static Future<void> prepareForExit() => _teardown ??= _tearDown();

  static Future<void> _tearDown() async {
    await MpvPlayerRegistry.instance.disposeAll();
  }

  static Future<void> closeApp() async {
    await prepareForExit();

    if (PlatformDetection.isAndroid) {
      try {
        final handled =
            await _platformChannel.invokeMethod<bool>('exitApp') ?? false;
        if (handled) return;
      } catch (e, st) {
        debugPrint('[AppExit] Android platform channel error: $e\n$st');
      }
    }

    if (PlatformDetection.isAppleTV) {
      try {
        await _appleTvSystemChannel.invokeMethod('exitApp');
        return;
      } catch (e, st) {
        debugPrint('[AppExit] Apple TV exit channel error: $e\n$st');
      }
    }

    await SystemNavigator.pop();
  }
}
