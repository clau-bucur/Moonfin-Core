import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Paint Home at its real size behind a cover until startup work settles.
/// Offstage/opacity would prevent the underlying first paint we are waiting for.
class HomeStartupCover extends StatefulWidget {
  const HomeStartupCover({
    super.key,
    required this.enabled,
    required this.changes,
    required this.contentReady,
    required this.onRevealed,
    required this.child,
    this.pendingArtwork,
    this.timeout = const Duration(seconds: 8),
  });

  final bool enabled;
  final Listenable changes;
  final bool Function() contentReady;
  final VoidCallback onRevealed;
  final Widget child;
  final int Function()? pendingArtwork;
  final Duration timeout;

  @override
  State<HomeStartupCover> createState() => _HomeStartupCoverState();
}

class _HomeStartupCoverState extends State<HomeStartupCover> {
  late bool _covered = widget.enabled;
  Timer? _poll;
  Timer? _deadline;
  Duration? _quietSince;

  @override
  void initState() {
    super.initState();
    if (!_covered) return;
    widget.changes.addListener(_changed);
    _deadline = Timer(widget.timeout, _reveal);
    _poll = Timer.periodic(const Duration(milliseconds: 100), (_) {
      // Inspect after layout/paint: newly mounted image providers must first
      // have a chance to register their pending decode in Flutter's cache.
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  void _changed() => _quietSince = null;

  void _check() {
    if (!mounted || !_covered) return;
    final pending =
        widget.pendingArtwork?.call() ??
        PaintingBinding.instance.imageCache.pendingImageCount;
    if (!widget.contentReady() || pending != 0) {
      _quietSince = null;
      return;
    }
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    _quietSince ??= now;
    // Includes the debounced initial backdrop selection and focus expansion.
    if (now - _quietSince! >= const Duration(milliseconds: 400)) {
      _reveal();
    }
  }

  void _reveal() {
    if (!mounted || !_covered) return;
    _poll?.cancel();
    _deadline?.cancel();
    widget.changes.removeListener(_changed);
    setState(() => _covered = false);
    widget.onRevealed();
  }

  @override
  void didUpdateWidget(HomeStartupCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_covered && oldWidget.changes != widget.changes) {
      oldWidget.changes.removeListener(_changed);
      widget.changes.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _deadline?.cancel();
    if (_covered) widget.changes.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      AbsorbPointer(absorbing: _covered, child: widget.child),
      if (_covered)
        Positioned.fill(
          child: BlockSemantics(
            child: ColoredBox(
              key: const ValueKey('home-startup-cover'),
              color: Colors.black,
              child: Center(
                child: Image.asset(
                  'assets/images/logo_and_text.png',
                  height: 80,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
