import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Retargets D-pad scrolling from its current position and velocity. Repeated
/// row changes therefore do not restart an ease-in animation at zero speed.
class TvScrollController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _TvScrollPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

class _TvScrollPosition extends ScrollPositionWithSingleContext {
  _TvScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) {
    final target = to.clamp(minScrollExtent, maxScrollExtent);
    if (duration == Duration.zero || (target - pixels).abs() < 0.5) {
      jumpTo(target);
      return Future<void>.value();
    }
    final omega =
        4.74 / (duration.inMicroseconds / Duration.microsecondsPerSecond);
    // Cap inherited velocity after a reversal so it cannot run far away from
    // the newly selected row before turning around.
    final limit = math.max(1.0, (target - pixels).abs()) * omega;
    final velocity = (activity?.velocity ?? 0).clamp(-limit, limit);
    final scroll = DrivenScrollActivity.simulation(
      this,
      ScrollSpringSimulation(
        SpringDescription(
          mass: 1,
          stiffness: omega * omega,
          damping: 2 * omega,
        ),
        pixels,
        target,
        velocity,
        tolerance: const Tolerance(distance: 0.25, velocity: 1),
      ),
      vsync: context.vsync,
    );
    beginActivity(scroll);
    return scroll.done;
  }
}
