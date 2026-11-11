import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/playback/osd_buttons.dart';
import 'package:moonfin/util/platform_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The tvOS OSD is drawn natively and can't read the preferences itself, so the
// arrangement reaches it as this list of ids. Getting the list wrong is the
// whole setting going missing on that platform.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserPreferences prefs;

  setUp(() async {
    PlatformDetection.setTvMode(true);
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);
  });

  tearDown(() => PlatformDetection.setTvMode(false));

  for (final docked in [false, true]) {
    testWidgets(
      'transport omits unavailable episode navigation (docked=$docked)',
      (tester) async {
        Widget button(OsdTransportButton button, double size, double extent) =>
            SizedBox(width: extent, height: extent, child: Text(button.name));
        Widget transport(bool previous, bool next) => docked
            ? osdDockedTransport(
                landscape: true,
                scale: 1,
                build: button,
                showPrevious: previous,
                showNext: next,
              )
            : osdCenterTransport(
                1,
                button,
                showPrevious: previous,
                showNext: next,
              );

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: transport(false, false))),
        );
        expect(find.text('previous'), findsNothing);
        expect(find.text('next'), findsNothing);
        expect(find.text('playPause'), findsOneWidget);
        expect(find.text('seekBack'), findsOneWidget);
        expect(find.text('seekForward'), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: transport(true, true))),
        );
        expect(find.text('previous'), findsOneWidget);
        expect(find.text('next'), findsOneWidget);
      },
    );
  }

  test('offers every button a TV can draw and no others', () async {
    expect(visibleOsdButtonIds(prefs), [
      OsdButton.restart.id,
      OsdButton.syncPlay.id,
      OsdButton.favorite.id,
      OsdButton.speed.id,
      OsdButton.chapters.id,
      OsdButton.episodes.id,
      OsdButton.subtitles.id,
      OsdButton.audio.id,
      OsdButton.castAndCrew.id,
      OsdButton.quality.id,
      OsdButton.zoom.id,
      OsdButton.info.id,
    ]);
  });

  test('drops the buttons switched off for this kind of device', () async {
    await prefs.set(UserPreferences.hiddenOsdButtonsTv, 'favorite,speed');

    final visible = visibleOsdButtonIds(prefs);
    expect(visible, isNot(contains(OsdButton.favorite.id)));
    expect(visible, isNot(contains(OsdButton.speed.id)));
    expect(visible, contains(OsdButton.subtitles.id));
  });

  test('leaves the phone list to phones', () async {
    await prefs.set(UserPreferences.hiddenOsdButtonsMobile, 'subtitles');

    expect(visibleOsdButtonIds(prefs), contains(OsdButton.subtitles.id));
  });

  test(
    'follows the order the user arranged, carrying the rest along',
    () async {
      await prefs.set(UserPreferences.osdButtonOrderTv, 'info,subtitles');
      await prefs.set(UserPreferences.hiddenOsdButtonsTv, 'favorite,speed');

      expect(visibleOsdButtonIds(prefs), [
        // Never placed and declared before anything that was, so they stay put.
        OsdButton.restart.id,
        OsdButton.syncPlay.id,
        OsdButton.chapters.id,
        OsdButton.episodes.id,
        OsdButton.info.id,
        OsdButton.subtitles.id,
        // These follow the button they were declared after.
        OsdButton.audio.id,
        OsdButton.castAndCrew.id,
        OsdButton.quality.id,
        OsdButton.zoom.id,
      ]);
    },
  );
}
