import 'package:flutter/widgets.dart';

/// A fixed-height modern card slot. Artwork widens without moving vertically;
/// extra information fades into the reserved space below the title.
class ModernCardFrame extends StatelessWidget {
  const ModernCardFrame({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    required this.progress,
    this.details,
  });

  final Widget card;
  final Widget? details;
  final double width;
  final double height;
  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card,
        if (details != null) ...[
          const SizedBox(height: 4),
          IgnorePointer(
            ignoring: progress < 1,
            child: Opacity(
              opacity: const Interval(0.65, 1).transform(progress.clamp(0, 1)),
              child: details,
            ),
          ),
        ],
      ],
    ),
  );
}
