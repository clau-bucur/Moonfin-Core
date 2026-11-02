import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/marquee_text.dart';
import 'package:moonfin/ui/widgets/media_card.dart';
import 'package:moonfin/util/focus/input_mode_tracker.dart';
import 'package:moonfin/util/platform_detection.dart';

void main() {
  setUp(() => PlatformDetection.setTvMode(true));
  tearDown(() => PlatformDetection.setTvMode(false));

  testWidgets('parked TV pointers cannot select cards moved under them', (
    tester,
  ) async {
    final starts = <String>[];
    final ends = <String>[];
    var shifted = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: InputModeTracker(
          child: Align(
            alignment: Alignment.topLeft,
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                Widget card(String id, double left) => Positioned(
                  left: left,
                  top: 0,
                  child: MediaCard(
                    key: ValueKey('card-$id'),
                    title: id,
                    width: 100,
                    aspectRatio: 1,
                    externalIsFocused: id == 'C',
                    cardFocusExpansion: false,
                    onHoverStart: () => starts.add(id),
                    onHoverEnd: () => ends.add(id),
                  ),
                );
                return SizedBox(
                  width: 400,
                  height: 250,
                  child: Stack(
                    children: [
                      card('A', shifted ? 130 : 0),
                      card('B', shifted ? 0 : 130),
                      card('C', 260),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    Finder marquee(String id) => find.descendant(
      of: find.byKey(ValueKey('card-$id')),
      matching: find.byType(MarqueeText),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(390, 240));
    await mouse.moveTo(const Offset(50, 50));
    await tester.pump();
    expect(starts, ['A']);
    expect(marquee('A'), findsOneWidget);

    // A remote key ends pointer styling even though the mouse has not moved.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    expect(marquee('A'), findsNothing);
    expect(ends, ['A']);

    // Navigation/route restoration moves another card under the parked mouse.
    rebuild(() => shifted = true);
    await tester.pump();
    await tester.pump();
    expect(starts, ['A']);
    expect(marquee('B'), findsNothing);

    // A real mouse movement can take over again on the same card.
    await mouse.moveTo(const Offset(51, 50));
    await tester.pump();
    await tester.pump();
    expect(starts, ['A', 'B']);
    expect(marquee('B'), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
