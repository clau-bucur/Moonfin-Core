import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/focus/tv_scroll_controller.dart';

void main() {
  testWidgets(
    'repeated row scrolls retain velocity and settle at the new row',
    (tester) async {
      final scroll = TvScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ListView(
            controller: scroll,
            itemExtent: 100,
            children: List.generate(50, (i) => Text('Row $i')),
          ),
        ),
      );
      const frame = Duration(milliseconds: 16);
      const duration = Duration(milliseconds: 300);
      scroll.animateTo(500, duration: duration, curve: Curves.easeOutCubic);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final before = scroll.offset;
      await tester.pump(frame);
      final previousStep = scroll.offset - before;
      final atRetarget = scroll.offset;
      scroll.animateTo(1000, duration: duration, curve: Curves.easeOutCubic);
      expect(scroll.offset, atRetarget);
      await tester.pump();
      await tester.pump(frame);
      expect(scroll.offset - atRetarget, greaterThan(previousStep * 0.6));
      expect(scroll.position.isScrollingNotifier.value, isTrue);
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(1000, 0.5));
      expect(scroll.position.isScrollingNotifier.value, isFalse);

      scroll.animateTo(100000, duration: duration, curve: Curves.linear);
      await tester.pumpAndSettle();
      expect(scroll.offset, scroll.position.maxScrollExtent);
      scroll.animateTo(0, duration: duration, curve: Curves.linear);
      await tester.pump();
      scroll.jumpTo(100);
      await tester.pumpAndSettle();
      expect(scroll.offset, 100);
    },
  );
}
