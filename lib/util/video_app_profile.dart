/// The experiment defaults to video browsing and streaming. The opt-out is
/// retained during the staged cleanup for inherited tests and comparisons.
abstract final class VideoAppProfile {
  static const enabled = bool.fromEnvironment(
    'MOONFIN_VIDEO_ONLY',
    defaultValue: true,
  );

  static final _gameLibraryName = RegExp(
    'game|rom|emulat',
    caseSensitive: false,
  );

  static bool allowsLibrary(String collectionType, {String name = ''}) {
    if (!enabled) return true;
    final type = collectionType.trim().toLowerCase();
    if (const {
      'music',
      'audiobooks',
      'books',
      'book',
      'photos',
      'games',
      'romm',
    }.contains(type))
      return false;
    // Match the existing ROM-library fallback without fetching game metadata.
    return !const {'', 'mixed', 'unknown'}.contains(type) ||
        !_gameLibraryName.hasMatch(name);
  }

  static bool allowsRoute(String path) =>
      !enabled ||
      !const [
        '/music',
        '/books',
        '/games',
        '/game',
        '/game-player',
        '/romm-account',
        '/admin',
        '/seerr',
        '/player/audio',
        '/player/book',
        '/player/photo',
      ].any((prefix) => path == prefix || path.startsWith('$prefix/'));

  static bool allowsItemType(String type) =>
      !enabled ||
      !const {
        'audio',
        'audiobook',
        'book',
        'musicalbum',
        'musicartist',
        'albumartist',
        'photo',
        'photoalbum',
        'game',
        'gamesystem',
      }.contains(type.toLowerCase());

  /// Effective values only: never write a restricted value back to the
  /// server-synced preferences used by the viewer's other Moonfin clients.
  static Object? preferenceOverride(String key) =>
      enabled ? _overrides[key] : null;

  static bool hidesPreference(String key) =>
      enabled &&
      _overrides.keys.any((base) => key == base || key.startsWith('${base}_'));

  static const _overrides = <String, Object>{
    'themeMusicEnabled': false,
    'episodePreviewEnabled': false,
    'mediaBarTrailerPreview': false,
    'pref_show_seerr_button': false,
    'pref_show_seerr_availability_badges': false,
    'seerr_enabled': false,
    'seasonal_follower': false,
    'mediaPreviewMode': 'off',
    'seasonal_surprise': 'none',
  };
}
