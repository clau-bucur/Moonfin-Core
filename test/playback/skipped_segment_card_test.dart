import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/models/media_segment.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/widgets/playback/next_up_overlay.dart';
import 'package:moonfin/ui/widgets/playback/skip_segment_overlay.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const intro = MediaSegment(
    id: 'intro',
    itemId: 'episode',
    type: MediaSegmentType.intro,
    start: Duration(seconds: 10),
    end: Duration(seconds: 100),
  );
  const recap = MediaSegment(
    id: 'recap',
    itemId: 'episode',
    type: MediaSegmentType.recap,
    start: Duration(seconds: 100),
    end: Duration(seconds: 150),
  );
  late UserPreferences prefs;

  setUp(() async {
    await GetIt.instance.reset();
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);
    GetIt.instance.registerSingleton<UserPreferences>(prefs);
    ThemeRegistry.setActiveById(ThemeRegistry.moonfinId);
  });
  tearDown(() => GetIt.instance.reset());

  Future<void> pumpCard(
    WidgetTester tester, {
    MediaSegment segment = intro,
    FocusNode? playFocus,
    FocusNode? dismissFocus,
    VoidCallback? onPlay,
    VoidCallback? onDismiss,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Stack(
          children: [
            SkipSegmentOverlay(
              segment: segment,
              wasAutoSkipped: true,
              focusNode: playFocus,
              dismissFocusNode: dismissFocus,
              onSkip: onPlay ?? () {},
              onDismiss: onDismiss ?? () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'compact card counts down the configured Next Up duration and expires without replay',
    (tester) async {
      await prefs.set(UserPreferences.nextUpTimeout, 11000);
      var plays = 0;
      var dismissed = 0;
      await pumpCard(
        tester,
        onPlay: () => plays++,
        onDismiss: () => dismissed++,
      );
      expect(tester.getSize(find.byType(NextUpOverlay)).width, 300);
      expect(find.text('Intro skipped'), findsOneWidget);
      expect(find.text('Play Intro'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.text(':11'),
        ),
        findsOneWidget,
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text(':06'), findsOneWidget);
      expect(
        dismissed,
        0,
        reason: 'the previous fixed five-second timeout must be gone',
      );
      await tester.pump(const Duration(milliseconds: 5999));
      expect(dismissed, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(dismissed, 1);
      expect(
        plays,
        0,
        reason: 'expiration keeps the automatically skipped segment skipped',
      );
    },
  );

  testWidgets(
    'leaving Play cancels the timer and replay still works with the remote',
    (tester) async {
      await prefs.set(UserPreferences.nextUpTimeout, 3000);
      final play = FocusNode();
      final dismiss = FocusNode();
      addTearDown(play.dispose);
      addTearDown(dismiss.dispose);
      var plays = 0;
      var dismissed = 0;
      await pumpCard(
        tester,
        playFocus: play,
        dismissFocus: dismiss,
        onPlay: () => plays++,
        onDismiss: () => dismissed++,
      );
      play.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(':02'), findsOneWidget);
      dismiss.requestFocus();
      await tester.pump();
      expect(find.text('Canceled'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(dismissed, 0);
      play.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(plays, 1);
      expect(dismissed, 0);
    },
  );

  testWidgets('Close dismisses without replaying', (tester) async {
    var plays = 0;
    var dismissed = 0;
    await pumpCard(tester, onPlay: () => plays++, onDismiss: () => dismissed++);
    await tester.tap(find.byType(OutlinedButton));
    expect(dismissed, 1);
    expect(plays, 0);
  });

  testWidgets('a new skipped segment starts a fresh countdown', (tester) async {
    await prefs.set(UserPreferences.nextUpTimeout, 7000);
    await pumpCard(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(':02'), findsOneWidget);
    await pumpCard(tester, segment: recap);
    expect(find.text('Recap skipped'), findsOneWidget);
    expect(find.text('Play Recap'), findsOneWidget);
    expect(find.text(':07'), findsOneWidget);
  });

  testWidgets(
    'a disabled Next Up timeout leaves replay available without a timer',
    (tester) async {
      await prefs.set(UserPreferences.nextUpTimeout, 0);
      var dismissed = 0;
      await pumpCard(tester, onDismiss: () => dismissed++);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Play Intro'), findsOneWidget);
      expect(dismissed, 0);
    },
  );
}
