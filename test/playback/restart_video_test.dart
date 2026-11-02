import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/restart_video.dart';
import 'package:playback_core/playback_core.dart';

class _Playback extends Fake implements PlaybackManager {
  final calls = <String>[];
  @override
  Future<void> seekTo(Duration position) async =>
      calls.add('seek:' + position.inMilliseconds.toString());
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> next() async => calls.add('next');
}

void main() {
  test(
    'Restart seeks the current video to zero before resuming; keeps the queue',
    () async {
      final playback = _Playback();
      await restartCurrentVideo(playback);
      expect(playback.calls, ['seek:0', 'resume']);
    },
  );
}
