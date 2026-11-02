// Android TV uses immersive system UI rather than a desktop window.
Future<bool> isFullscreen() async => false;
Future<void> setFullscreen(bool value) async {}
