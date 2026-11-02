import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small application caches for artwork, themes and server messages.
/// Streamed media is never stored here.
class StoragePathService {
  Future<Directory> _directory(String name) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      [support.path, 'Moonfin', name].join(Platform.pathSeparator),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> getImageCacheDir() => _directory('images');
  Future<Directory> getThemeCacheDir() => _directory('themes');
  Future<Directory> getMessageCacheDir() => _directory('messages');
}
