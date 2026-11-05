import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/home/home_startup_cover.dart';

void main() {
  final cover = find.byKey(const ValueKey('home-startup-cover'));

  testWidgets('Home lays out behind logo; reveal waits for data and artwork', (
    tester,
  ) async {
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);
    var ready = false;
    var pending = 1;
    var revealed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeStartupCover(
          enabled: true,
          changes: changes,
          contentReady: () => ready,
          pendingArtwork: () => pending,
          onRevealed: () => revealed++,
          child: const Center(
            child: SizedBox(
              key: ValueKey('home-content'),
              width: 100,
              height: 100,
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('home-content'))),
      const Size(100, 100),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(cover, findsOneWidget);
    ready = true;
    changes.notifyListeners();
    await tester.pump(const Duration(seconds: 1));
    expect(cover, findsOneWidget);
    pending = 0;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(cover, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(cover, findsNothing);
    expect(revealed, 1);
    ready = false;
    changes.notifyListeners();
    await tester.pump(const Duration(seconds: 1));
    expect(cover, findsNothing);
  });

  testWidgets('stalled data or artwork cannot trap the app behind the logo', (
    tester,
  ) async {
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeStartupCover(
          enabled: true,
          changes: changes,
          contentReady: () => false,
          pendingArtwork: () => 1,
          onRevealed: () {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 8));
    expect(cover, findsNothing);
  });

  testWidgets('disabled cover is immediate and leaving cancels the timers', (
    tester,
  ) async {
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);
    Widget home(bool enabled) => MaterialApp(
      home: HomeStartupCover(
        key: ValueKey(enabled),
        enabled: enabled,
        changes: changes,
        contentReady: () => false,
        onRevealed: () {},
        child: const SizedBox.expand(),
      ),
    );
    await tester.pumpWidget(home(false));
    expect(cover, findsNothing);
    await tester.pumpWidget(home(true));
    expect(cover, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });
}
