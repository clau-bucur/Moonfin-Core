import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/detail/detail_autoplay_gate.dart';

void main() {
  Widget page({
    bool autoPlay = true,
    bool failed = false,
    VoidCallback? onRevealed,
    required Widget child,
  }) => MaterialApp(
    home: DetailAutoplayGate(
      autoPlay: autoPlay,
      failed: failed,
      onRevealed: onRevealed,
      loading: const Center(child: Text('Loading playback')),
      child: child,
    ),
  );

  testWidgets(
    'autoplay mounts its actions without painting or focusing details',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var tapped = false;
      late BuildContext actionContext;
      final child = Builder(
        builder: (context) {
          actionContext = context;
          return Center(
            child: ElevatedButton(
              focusNode: focus,
              onPressed: () => tapped = true,
              child: const Text('Details'),
            ),
          );
        },
      );
      await tester.pumpWidget(page(child: child));
      expect(actionContext.mounted, isTrue);
      expect(find.text('Loading playback').hitTestable(), findsOneWidget);
      expect(find.text('Details').hitTestable(), findsNothing);
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      await tester.tap(find.text('Details'), warnIfMissed: false);
      expect(tapped, isFalse);
      final background = tester.widget<ColoredBox>(
        find.byType(ColoredBox).last,
      );
      expect(background.color, Colors.black);
    },
  );

  testWidgets(
    'consuming autoPlay keeps details hidden until the play action returns',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      late BuildContext actionContext;
      final child = Builder(
        builder: (context) {
          actionContext = context;
          return Center(
            child: ElevatedButton(
              focusNode: focus,
              onPressed: () {},
              child: const Text('Details'),
            ),
          );
        },
      );
      await tester.pumpWidget(page(child: child));
      final playback = Completer<void>();
      final launch = DetailAutoplayGate.run(
        actionContext,
        () => playback.future,
      );

      // The detail route consumes its autoPlay query before pushing the player.
      await tester.pumpWidget(
        page(
          autoPlay: false,
          onRevealed: () => WidgetsBinding.instance.addPostFrameCallback(
            (_) => focus.requestFocus(),
          ),
          child: child,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Details').hitTestable(), findsNothing);
      expect(find.text('Loading playback').hitTestable(), findsOneWidget);

      // Playback has ended, or startup was canceled before the player opened.
      playback.complete();
      await launch;
      await tester.pump();
      await tester.pump();
      expect(find.text('Details').hitTestable(), findsOneWidget);
      expect(find.text('Loading playback'), findsNothing);
      expect(focus.hasFocus, isTrue);
    },
  );

  testWidgets('a startup exception reveals details for retry', (tester) async {
    late BuildContext actionContext;
    await tester.pumpWidget(
      page(
        child: Builder(
          builder: (context) {
            actionContext = context;
            return const Center(child: Text('Details'));
          },
        ),
      ),
    );
    await expectLater(
      DetailAutoplayGate.run<void>(
        actionContext,
        () async => throw StateError('startup failed'),
      ),
      throwsStateError,
    );
    await tester.pump();
    expect(find.text('Details').hitTestable(), findsOneWidget);
    expect(find.text('Loading playback'), findsNothing);
  });

  testWidgets('metadata errors and blocked titles remain visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(child: const Center(child: Text('Cannot play'))),
    );
    await tester.pumpWidget(
      page(failed: true, child: const Center(child: Text('Cannot play'))),
    );
    expect(find.text('Cannot play').hitTestable(), findsOneWidget);
    expect(find.text('Loading playback'), findsNothing);
  });

  testWidgets(
    'normal details are visible and a later autoplay request is hidden',
    (tester) async {
      const child = Center(child: Text('Details'));
      await tester.pumpWidget(page(autoPlay: false, child: child));
      expect(find.text('Details').hitTestable(), findsOneWidget);
      await tester.pumpWidget(page(child: child));
      expect(find.text('Details').hitTestable(), findsNothing);
      expect(find.text('Loading playback').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('leaving during autoplay safely finishes the pending action', (
    tester,
  ) async {
    late BuildContext actionContext;
    await tester.pumpWidget(
      page(
        child: Builder(
          builder: (context) {
            actionContext = context;
            return const Text('Details');
          },
        ),
      ),
    );
    final playback = Completer<void>();
    final launch = DetailAutoplayGate.run(actionContext, () => playback.future);
    await tester.pumpWidget(const SizedBox.shrink());
    playback.complete();
    await launch;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
