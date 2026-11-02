import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/video_app_profile.dart';

void main() {
  test('video libraries include mixed libraries and music videos', () {
    for (final type in [
      '',
      'movies',
      'tvshows',
      'boxsets',
      'homevideos',
      'musicvideos',
      'livetv',
    ]) {
      expect(VideoAppProfile.allowsLibrary(type), isTrue, reason: type);
    }
    for (final type in [
      'music',
      'Audiobooks',
      ' books ',
      'photos',
      'games',
      'romm',
    ]) {
      expect(
        VideoAppProfile.allowsLibrary(type),
        !VideoAppProfile.enabled,
        reason: type,
      );
    }
  });

  test('deep links to removed features are excluded at segment boundaries', () {
    for (final path in [
      '/home',
      '/search',
      '/item/123',
      '/library/123',
      '/live-tv/guide',
      '/player/video',
      '/player/trailer',
    ]) {
      expect(VideoAppProfile.allowsRoute(path), isTrue, reason: path);
    }
    for (final path in [
      '/books/123',
      '/games/123',
      '/game/123/456',
      '/game-player/123/456',
      '/admin',
      '/seerr/discover',
      '/player/audio',
      '/player/book/123',
      '/player/photo/123',
    ]) {
      expect(
        VideoAppProfile.allowsRoute(path),
        !VideoAppProfile.enabled,
        reason: path,
      );
    }
    expect(VideoAppProfile.allowsRoute('/library/music-videos'), isTrue);
  });

  test('profile restrictions leave playback preferences alone', () {
    expect(
      VideoAppProfile.preferenceOverride('themeMusicEnabled'),
      VideoAppProfile.enabled ? false : null,
    );
    expect(
      VideoAppProfile.preferenceOverride('seasonal_surprise'),
      VideoAppProfile.enabled ? 'none' : null,
    );
    for (final key in [
      'hardware_decoding',
      'playback_engine_preference',
      'default_audio_language',
      'subtitle_mode',
    ]) {
      expect(VideoAppProfile.preferenceOverride(key), isNull, reason: key);
    }
  });

  test('audio cannot enter a video queue, while music videos can', () {
    expect(VideoAppProfile.allowsItemType('Audio'), !VideoAppProfile.enabled);
    expect(VideoAppProfile.allowsItemType('AudioBook'), !VideoAppProfile.enabled);
    expect(VideoAppProfile.allowsItemType('MusicVideo'), isTrue);
    expect(VideoAppProfile.allowsLibrary('mixed', name: 'ROM games'), !VideoAppProfile.enabled);
    expect(VideoAppProfile.allowsLibrary('movies', name: 'Game films'), isTrue);
  });
}
