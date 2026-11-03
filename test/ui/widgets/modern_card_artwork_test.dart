import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/modern_card_artwork.dart';

class _ControlledImage extends ImageProvider<_ControlledImage> {
  final List<Completer<ImageInfo>> _frames = [];
  Completer<ImageInfo> get frame => _frames.last;
  int loads = 0;

  @override
  Future<_ControlledImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _ControlledImage key,
    ImageDecoderCallback decode,
  ) {
    loads++;
    _frames.add(Completer<ImageInfo>.sync());
    return OneFrameImageStreamCompleter(frame.future);
  }

  Future<void> complete(Color color) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(color, BlendMode.src);
    frame.complete(
      ImageInfo(image: await recorder.endRecording().toImage(2, 2)),
    );
  }
}

void main() {
  late _ControlledImage background;
  late _ControlledImage logo;
  late List<(String, int)> requests;
  late ImageProvider Function(String, int) providerBuilder;

  setUp(() {
    background = _ControlledImage();
    logo = _ControlledImage();
    requests = [];
    providerBuilder = (url, width) {
      requests.add((url, width));
      return url == 'background' ? background : logo;
    };
  });

  Widget artwork(
    double progress, {
    bool withLogo = true,
    String? title = 'A movie',
    String? url = 'background',
  }) => MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Center(
        child: SizedBox(
          key: const ValueKey('card'),
          width: 200 + 333 * progress,
          height: 300,
          child: ModernCardArtwork(
            imageUrl: url,
            logoImageUrl: withLogo ? 'logo' : null,
            fallbackTitle: title,
            collapsedWidth: 200,
            expandedWidth: 533,
            imageHeight: 300,
            expansionProgress: progress,
            placeholder: const Text('Artwork unavailable'),
            imageProviderBuilder: providerBuilder,
          ),
        ),
      ),
    ),
  );

  testWidgets('one background and decode survive expansion and reversal', (
    tester,
  ) async {
    await tester.pumpWidget(artwork(0));
    await tester.runAsync(() => background.complete(Colors.blue));
    await tester.runAsync(() => logo.complete(Colors.red));
    await tester.pump();
    final original = tester
        .renderObject<RenderImage>(find.byType(RawImage).first)
        .image;
    for (final progress in [0.25, 0.7, 1.0, 0.6, 0.1, 0.8, 0.0]) {
      await tester.pumpWidget(artwork(progress));
      expect(
        tester.renderObject<RenderImage>(find.byType(RawImage).first).image,
        same(original),
      );
      expect(tester.getSize(find.byType(RawImage).first), const Size(533, 300));
      expect(tester.getSize(find.byKey(const ValueKey('card'))).height, 300);
    }
    expect(background.loads, 1);
    expect(logo.loads, 1);
    expect(requests, [('background', 960), ('logo', 360)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('title stays inside every crop and moves to bottom left', (
    tester,
  ) async {
    double? firstBottom;
    for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      await tester.pumpWidget(artwork(progress, withLogo: false));
      final card = tester.getRect(find.byKey(const ValueKey('card')));
      final title = tester.getRect(
        find.byKey(const ValueKey('modern-card-title')),
      );
      expect(title.left, greaterThanOrEqualTo(card.left + 12));
      expect(title.right, lessThanOrEqualTo(card.right - 12));
      expect(title.bottom, lessThanOrEqualTo(card.bottom - 12));
      firstBottom ??= title.bottom - card.top;
      if (progress == 0) expect(title.center.dx, closeTo(card.center.dx, 0.01));
      if (progress == 1) {
        expect(title.left, closeTo(card.left + 12, 0.01));
        expect(title.bottom, closeTo(card.bottom - 12, 0.01));
        expect(title.bottom - card.top, greaterThan(firstBottom));
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('late logo does not replace or reload the background', (
    tester,
  ) async {
    await tester.pumpWidget(artwork(0));
    await tester.runAsync(() => background.complete(Colors.blue));
    await tester.pump();
    await tester.pumpWidget(artwork(1));
    expect(find.text('A movie'), findsOneWidget);
    await tester.runAsync(() => logo.complete(Colors.red));
    await tester.pump();
    expect(background.loads, 1);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Artwork unavailable'), findsNothing);
  });

  testWidgets('missing or failed logo uses readable title', (tester) async {
    await tester.pumpWidget(artwork(0));
    logo.frame.completeError(StateError('Unavailable logo'));
    await tester.pump();
    expect(find.text('A movie'), findsOneWidget);
    await tester.pumpWidget(artwork(1, withLogo: false));
    expect(find.text('A movie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thumbnail fallback has no duplicate title overlay', (
    tester,
  ) async {
    await tester.pumpWidget(artwork(0, withLogo: false, title: null));
    expect(find.byKey(const ValueKey('modern-card-title')), findsNothing);
    expect(requests, [('background', 960)]);
    await tester.pumpWidget(
      artwork(1, withLogo: false, title: null, url: null),
    );
    expect(find.text('Artwork unavailable'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
