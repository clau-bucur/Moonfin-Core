import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/util/focus/gamepad/gamepad_navigation_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.moonfin.androidtv/gamepad');
  final navigationRequests = <bool>[];
  late UserPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    preferences = UserPreferences(store);
    GetIt.instance.registerSingleton<UserPreferences>(preferences);
    navigationRequests.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setNavigationEnabled') {
            navigationRequests.add((call.arguments as Map)['enabled'] as bool);
          }
          return true;
        });
  });

  tearDown(() async {
    await GetIt.instance.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('TV navigation preference reaches the native stick bridge', (
    tester,
  ) async {
    await preferences.set(UserPreferences.gamepadNavigationEnabled, false);
    await tester.pumpWidget(const GamepadNavigationScope(child: SizedBox()));
    await tester.pump();
    expect(navigationRequests, [false]);

    await preferences.set(UserPreferences.gamepadNavigationEnabled, true);
    await tester.pump();
    expect(navigationRequests, [false, true]);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('native D-pad input reaches the focused video UI once', (
    tester,
  ) async {
    var downEvents = 0;
    final focus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: GamepadNavigationScope(
          child: Focus(
            autofocus: true,
            focusNode: focus,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                downEvents++;
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(downEvents, 1);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
