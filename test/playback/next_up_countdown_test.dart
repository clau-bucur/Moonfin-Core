import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/widgets/playback/next_up_overlay.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
    ThemeRegistry.setActiveById(ThemeRegistry.moonfinId);
  });

  tearDown(() => GetIt.instance.reset());

  for (final minimal in [false, true]) {
    testWidgets(
      'countdown is on Play next and cancels on blur (minimal=$minimal)',
      (tester) async {
        final playFocus = FocusNode();
        final dismissFocus = FocusNode();
        addTearDown(playFocus.dispose);
        addTearDown(dismissFocus.dispose);
        var timeouts = 0;
        var plays = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Stack(
              children: [
                NextUpOverlay(
                  nextItem: const AggregatedItem(
                    id: 'ep2',
                    serverId: 'server',
                    rawData: {'Name': 'Next Episode', 'Type': 'Episode'},
                  ),
                  timeoutMs: 5000,
                  isMinimal: minimal,
                  focusNode: playFocus,
                  dismissFocusNode: dismissFocus,
                  onPlayNext: () => plays++,
                  onDismiss: () {},
                  onTimeout: () => timeouts++,
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        // The delayed focus assignment must not cancel the initial countdown.
        expect(find.text('Canceled'), findsNothing);
        playFocus.requestFocus();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.descendant(
            of: find.byType(ElevatedButton),
            matching: find.text(':03'),
          ),
          findsOneWidget,
        );
        dismissFocus.requestFocus();
        await tester.pump();
        expect(
          find.descendant(
            of: find.byType(ElevatedButton),
            matching: find.text('Canceled'),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 6));
        expect(timeouts, 0);
        playFocus.requestFocus();
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        expect(find.text('Canceled'), findsOneWidget);
        expect(timeouts, 0);
        await tester.tap(find.byType(ElevatedButton));
        expect(plays, 1);
      },
    );
  }

  testWidgets('focused Play next still times out once', (tester) async {
    var timeouts = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Stack(
          children: [
            NextUpOverlay(
              nextItem: const AggregatedItem(
                id: 'ep2',
                serverId: 's',
                rawData: {'Name': 'Next'},
              ),
              timeoutMs: 2000,
              onPlayNext: () {},
              onDismiss: () {},
              onTimeout: () => timeouts++,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(timeouts, 1);
  });
}
