import 'dart:async';
import 'dart:collection';

/// Keeps speculative artwork outside the network queue until navigation settles.
///
/// A cache-manager download cannot be cancelled once issued. Starting one at a
/// time leaves connections and decode capacity for visible images, while
/// [replace] and [cancel] discard work that has not started yet.
class ArtworkPrefetchQueue {
  ArtworkPrefetchQueue({this.settleDelay = const Duration(milliseconds: 500)});

  final Duration settleDelay;
  final Queue<Future<void> Function()> _pending = Queue();
  Timer? _settleTimer;
  bool _running = false;

  void replace(Iterable<Future<void> Function()> requests) {
    cancel();
    _pending.addAll(requests);
    if (_pending.isEmpty) return;
    _settleTimer = Timer(settleDelay, () {
      _settleTimer = null;
      unawaited(_drain());
    });
  }

  void cancel() {
    _settleTimer?.cancel();
    _settleTimer = null;
    _pending.clear();
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_settleTimer == null && _pending.isNotEmpty) {
        final request = _pending.removeFirst();
        try {
          await request();
        } catch (_) {
          // A failed speculative image must not block the remaining window.
        }
      }
    } finally {
      _running = false;
    }
  }
}
