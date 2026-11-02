import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/widgets/back_to_exit.dart';

void main() {
  test('two separate presses within the window exit; expired and duplicate presses do not', () {
    var now = DateTime(2026);
    final controller = BackExitController(now: () => now);
    expect(controller.press(), isFalse);
    now = now.add(const Duration(milliseconds: 30));
    expect(controller.press(), isFalse);
    now = now.add(const Duration(milliseconds: 400));
    expect(controller.press(), isTrue);
    expect(controller.press(), isFalse);
    now = now.add(const Duration(seconds: 3));
    expect(controller.press(), isFalse);
    controller.reset();
    now = now.add(const Duration(milliseconds: 400));
    expect(controller.press(), isFalse);
  });

  testWidgets('first Back displays a toast without a dialog; second exits', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var exits = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('org.moonfin.androidtv/platform'),
          (call) async {
            if (call.method == 'exitApp') exits++;
            return true;
          },
        );
    addTearDown(() {
      resetBackToExit();
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('org.moonfin.androidtv/platform'),
            null,
          );
    });
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            page = context;
            return const Scaffold();
          },
        ),
      ),
    );
    await requestBackToExit(Navigator.of(page).overlay!.context);
    await tester.pump();
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(exits, 0);
    // Controller uses wall time, since Android root Back delivery is outside
    // the widget animation clock. Unit coverage above tests the entire window.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 180)),
    );
    await requestBackToExit(page);
    await tester.pump();
    expect(exits, 1);
    expect(find.text('Press back again to exit'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
