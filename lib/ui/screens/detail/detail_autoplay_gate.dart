import 'package:flutter/material.dart';

/// Keeps an autoplay detail page mounted so its play action can run, while
/// showing only the loading screen until that action returns from the player.
class DetailAutoplayGate extends StatefulWidget {
  final bool autoPlay;
  final bool failed;
  final Widget loading;
  final Widget child;
  final VoidCallback? onRevealed;

  const DetailAutoplayGate({
    super.key,
    required this.autoPlay,
    required this.failed,
    required this.loading,
    required this.child,
    this.onRevealed,
  });

  static Future<T> run<T>(BuildContext context, Future<T> Function() action) {
    final gate = context.findAncestorStateOfType<_DetailAutoplayGateState>();
    return gate == null ? action() : gate._run(action);
  }

  @override
  State<DetailAutoplayGate> createState() => _DetailAutoplayGateState();
}

class _DetailAutoplayGateState extends State<DetailAutoplayGate> {
  late bool _pending = widget.autoPlay;

  @override
  void didUpdateWidget(DetailAutoplayGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay && !oldWidget.autoPlay) _pending = true;
    // Consuming the route's autoPlay query must not uncover the page while
    // the player is still opening. The play action owns the end of the wait.
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _pending = false);
        widget.onRevealed?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hidden = _pending && !widget.failed;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: hidden,
          child: IgnorePointer(
            ignoring: hidden,
            child: ExcludeSemantics(
              excluding: hidden,
              child: Opacity(opacity: hidden ? 0 : 1, child: widget.child),
            ),
          ),
        ),
        if (hidden)
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
        if (hidden) Positioned.fill(child: widget.loading),
      ],
    );
  }
}
