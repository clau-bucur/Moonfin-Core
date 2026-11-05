import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/artwork_prefetch_queue.dart';

void main() {
  test('rapid navigation only starts the final settled artwork window', () {
    fakeAsync((async) {
      final queue = ArtworkPrefetchQueue();
      final fetched = <String>[];
      Future<void> fetch(String url) async => fetched.add(url);

      queue.replace([() => fetch('old-next'), () => fetch('old-previous')]);
      async.elapse(const Duration(milliseconds: 400));
      queue.replace([() => fetch('new-next'), () => fetch('new-previous')]);
      async.elapse(const Duration(milliseconds: 499));
      expect(fetched, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(fetched, ['new-next', 'new-previous']);
    });
  });

  test('leaving Home discards pending work even during an active download', () {
    fakeAsync((async) {
      final queue = ArtworkPrefetchQueue();
      final active = Completer<void>();
      final fetched = <String>[];
      queue.replace([
        () {
          fetched.add('next-backdrop');
          return active.future;
        },
        () async => fetched.add('next-logo'),
        () async => fetched.add('previous-backdrop'),
      ]);
      async.elapse(queue.settleDelay);
      expect(fetched, ['next-backdrop']);

      queue.cancel();
      active.complete();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      expect(fetched, ['next-backdrop']);
    });
  });

  test('a new window never overlaps the existing speculative download', () {
    fakeAsync((async) {
      final queue = ArtworkPrefetchQueue();
      final old = Completer<void>();
      final fetched = <String>[];
      queue.replace([
        () {
          fetched.add('old');
          return old.future;
        },
        () async => fetched.add('obsolete'),
      ]);
      async.elapse(queue.settleDelay);
      queue.replace([() async => fetched.add('new')]);
      async.elapse(queue.settleDelay);
      expect(fetched, ['old']);
      old.complete();
      async.flushMicrotasks();
      expect(fetched, ['old', 'new']);
    });
  });

  test('finishing old work cannot bypass the new window settle delay', () {
    fakeAsync((async) {
      final queue = ArtworkPrefetchQueue();
      final old = Completer<void>();
      final fetched = <String>[];
      queue.replace([() => old.future]);
      async.elapse(queue.settleDelay);
      queue.replace([() async => fetched.add('new')]);
      old.complete();
      async.flushMicrotasks();
      expect(fetched, isEmpty);
      async.elapse(queue.settleDelay);
      expect(fetched, ['new']);
    });
  });

  test(
    'a failed image does not strand later artwork or block cancellation',
    () {
      fakeAsync((async) {
        final queue = ArtworkPrefetchQueue();
        final fetched = <String>[];
        queue.replace([
          () => Future<void>.error(StateError('unavailable')),
          () async => fetched.add('next'),
        ]);
        async.elapse(queue.settleDelay);
        expect(fetched, ['next']);
        queue.replace([() async => fetched.add('hidden')]);
        queue.cancel();
        async.elapse(queue.settleDelay);
        expect(fetched, ['next']);
      });
    },
  );
}
