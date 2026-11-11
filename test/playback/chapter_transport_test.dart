import 'package:flutter_test/flutter_test.dart';
import 'package:playback_core/playback_core.dart';

class _TestBackend extends Fake implements PlayerBackend {
  final List<Duration> seeks = <Duration>[];
  int stopCalls = 0;
  Duration currentPosition = Duration.zero;

  @override
  Duration get position => currentPosition;

  @override
  bool get isPlaying => true;

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get bufferStream => const Stream<Duration>.empty();

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get bufferingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get completedStream => const Stream<bool>.empty();

  @override
  Stream<Map<String, dynamic>>? get errorStream => null;

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    currentPosition = position;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

const _chapters = [Duration.zero, Duration(minutes: 5), Duration(minutes: 10)];

void main() {
  late _TestBackend backend;
  late PlaybackManager manager;

  setUp(() {
    backend = _TestBackend();
    manager = PlaybackManager()..setBackend(backend);
    manager.state.setDuration(const Duration(minutes: 20));
  });

  test('next steps to the following chapter, not the next item', () async {
    manager.queueService.setQueue(['a', 'b'], startIndex: 0);
    manager.setChapterStarts(_chapters);
    manager.state.setPosition(const Duration(minutes: 2));

    await manager.next();

    expect(backend.seeks, [const Duration(minutes: 5)]);
    expect(manager.queueService.currentIndex, 0);
  });

  test('previous steps back through chapters', () async {
    manager.queueService.setQueue(['a'], startIndex: 0);
    manager.setChapterStarts(_chapters);
    manager.state.setPosition(const Duration(minutes: 7));

    await manager.previous();

    expect(backend.seeks, [const Duration(minutes: 5)]);
  });

  test('previousInQueue ignores chapters and elapsed playback', () async {
    manager.queueService.setQueue(['a', 'b'], startIndex: 1);
    manager.setChapterStarts(_chapters);
    manager.state.setPosition(const Duration(minutes: 7));

    // The fake backend cannot resolve the preceding item, but the queue must
    // have advanced before resolution, without seeking within this episode.
    try {
      await manager.previousInQueue();
    } catch (_) {}

    expect(manager.queueService.currentIndex, 0);
    expect(backend.seeks, isEmpty);
    expect(backend.stopCalls, 1);
  });

  test(
    'previousInQueue at the first episode ignores chapters and restarts',
    () async {
      manager.queueService.setQueue(['a'], startIndex: 0);
      manager.setChapterStarts(_chapters);
      manager.state.setPosition(const Duration(minutes: 7));

      await manager.previousInQueue();

      expect(backend.seeks, [Duration.zero]);
      expect(backend.stopCalls, 0);
    },
  );

  test('past the last chapter with nothing next it runs to the end', () async {
    manager.queueService.setQueue(['only'], startIndex: 0);
    manager.setChapterStarts(_chapters);
    manager.state.setPosition(const Duration(minutes: 12));

    await manager.next();

    expect(backend.seeks, [const Duration(minutes: 20)]);
    expect(backend.stopCalls, 0);
  });

  // Chapter transport callers must still reach the end without stopping on
  // a dead player when the item has no chapters.
  test('a lone item with no chapters runs to the end too', () async {
    manager.queueService.setQueue(['only'], startIndex: 0);
    manager.state.setPosition(const Duration(minutes: 12));

    await manager.next();

    expect(backend.seeks, [const Duration(minutes: 20)]);
    expect(backend.stopCalls, 0);
  });

  // Play Next and the media session mean the next item however far into a
  // chapter the position sits.
  test('nextInQueue ignores chapters', () async {
    manager.queueService.setQueue(['only'], startIndex: 0);
    manager.setChapterStarts(_chapters);
    manager.state.setPosition(const Duration(minutes: 2));

    await manager.nextInQueue();

    expect(backend.seeks, [const Duration(minutes: 20)]);
  });

  test('nextInQueue advances an episode even from within a chapter', () async {
    manager.queueService.setQueue(['a', 'b'], startIndex: 0);
    manager.setChapterStarts(_chapters);
    manager.state.setPosition(const Duration(minutes: 2));

    try {
      await manager.nextInQueue();
    } catch (_) {}

    expect(manager.queueService.currentIndex, 1);
    expect(backend.seeks, isEmpty);
    expect(backend.stopCalls, 1);
  });

  // A track or quality switch restarts the same item without a queue change,
  // and the chapters have to survive it.
  test('a mid-item restart keeps the chapters', () async {
    manager.queueService.setQueue(['movie'], startIndex: 0);
    manager.setChapterStarts(_chapters);

    try {
      await manager.startQueuedPlayback();
    } catch (_) {}
    backend.seeks.clear();
    manager.state.setPosition(const Duration(minutes: 2));

    await manager.next();

    expect(backend.seeks, [
      const Duration(minutes: 5),
    ], reason: 'a restart mid item dropped back to queue stepping');
  });

  // One manager serves the audio screens too, and they never set chapters.
  test('chapter starts do not outlive the item they were set for', () async {
    manager.queueService.setQueue(['movie'], startIndex: 0);
    manager.setChapterStarts(_chapters);
    manager.state.setPosition(const Duration(minutes: 2));

    // The fake backend can't finish a real start, but the queue has moved
    // on, and that is what the starts are keyed to.
    manager.queueService.setQueue(['song'], startIndex: 0);
    try {
      await manager.playFromQueue(0);
    } catch (_) {}
    backend.seeks.clear();
    manager.state.setPosition(const Duration(minutes: 2));

    await manager.next();

    expect(
      backend.seeks,
      isNot(contains(const Duration(minutes: 5))),
      reason: 'a song stepped to the last movie chapter',
    );
  });
}
