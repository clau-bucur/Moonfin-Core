import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../preference/user_preferences.dart';
import '../../platform_detection.dart';
import 'android_gamepad_channel.dart';

/// Android delivers D-pad buttons as native key events. Only analog stick
/// navigation needs the app's channel; no desktop gamepad plugin is required.
class GamepadNavigationScope extends StatefulWidget {
  const GamepadNavigationScope({super.key, required this.child});
  final Widget child;
  static bool get isConfigurable => PlatformDetection.isAndroid;

  @override
  State<GamepadNavigationScope> createState() => _GamepadNavigationScopeState();
}

class _GamepadNavigationScopeState extends State<GamepadNavigationScope> {
  late final UserPreferences _prefs;
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    AndroidGamepadChannel.ensureInstalled();
    _prefs = GetIt.instance<UserPreferences>();
    _prefs.addListener(_sync);
    _sync();
  }

  void _sync() {
    final enabled = _prefs.get(UserPreferences.gamepadNavigationEnabled);
    if (_enabled == enabled) return;
    _enabled = enabled;
    unawaited(
      AndroidGamepadChannel.setNavigationEnabled(enabled)
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _prefs.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
