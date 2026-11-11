import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/preference/bottom_nav_tabs.dart';
import 'package:moonfin/util/video_app_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Seerr stays available on TV and follows the viewer preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PreferenceStore();
      await store.init();
      final prefs = UserPreferences(store);
      addTearDown(prefs.dispose);
      for (final preference in [
        UserPreferences.seerrEnabled,
        UserPreferences.showSeerrButton,
        UserPreferences.showSeerrAvailabilityBadges,
      ]) {
        await prefs.set(preference, true);
        expect(prefs.get(preference), isTrue, reason: preference.key);
        expect(VideoAppProfile.hidesPreference(preference.key), isFalse);
        await prefs.set(preference, false);
        expect(prefs.get(preference), isFalse, reason: preference.key);
      }
      await prefs.set(UserPreferences.showSeerrButton, true);
      expect(
        BottomNavTabGates.fromPreferences(
          prefs,
          seerrAvailable: true,
        ).offers(BottomNavTab.discover),
        isTrue,
      );
      expect(
        BottomNavTabGates.fromPreferences(
          prefs,
          seerrAvailable: false,
        ).offers(BottomNavTab.discover),
        isFalse,
      );
      await prefs.set(UserPreferences.kidsModeEnabled, true);
      expect(
        BottomNavTabGates.fromPreferences(
          prefs,
          seerrAvailable: true,
        ).offers(BottomNavTab.discover),
        isFalse,
      );
    },
  );

  test(
    'runtime restrictions preserve stored preferences for other clients',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PreferenceStore();
      await store.init();
      final prefs = UserPreferences(store);
      await prefs.set(UserPreferences.themeMusicEnabled, true);
      await prefs.set(UserPreferences.episodePreviewEnabled, true);
      await prefs.set(UserPreferences.mediaBarTrailerPreview, true);
      await prefs.set(
        UserPreferences.seasonalSurprise,
        UserPreferences.seasonalSnow,
      );

      expect(
        prefs.get(UserPreferences.themeMusicEnabled),
        !VideoAppProfile.enabled,
      );
      expect(
        prefs.get(UserPreferences.episodePreviewEnabled),
        !VideoAppProfile.enabled,
      );
      expect(prefs.resolveMediaBarTrailerPreview(), !VideoAppProfile.enabled);
      expect(
        prefs.get(UserPreferences.seasonalSurprise),
        VideoAppProfile.enabled ? 'none' : 'snow',
      );
      expect(store.get(UserPreferences.themeMusicEnabled), isTrue);
      expect(prefs.getStored(UserPreferences.themeMusicEnabled), isTrue);
      expect(store.get(UserPreferences.episodePreviewEnabled), isTrue);
      expect(store.get(UserPreferences.mediaBarTrailerPreview), isTrue);
      expect(store.get(UserPreferences.seasonalSurprise), 'snow');
      prefs.dispose();
    },
  );
}
