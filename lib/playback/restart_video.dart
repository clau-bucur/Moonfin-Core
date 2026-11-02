import 'package:playback_core/playback_core.dart';

/// Restarts the current stream without replacing its queue, tracks or source.
Future<void> restartCurrentVideo(PlaybackManager manager) async {
  await manager.seekTo(Duration.zero);
  await manager.resume();
}
