import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/modern_card_frame.dart';

void main() {
  testWidgets(
    'artwork and text stay anchored while details appear and reverse',
    (tester) async {
      const artworkKey = ValueKey('artwork');
      const titleKey = ValueKey('title');
      const detailsKey = ValueKey('details');
      Rect? artwork;
      Offset? title;
      Offset? details;
      for (final progress in [0.0, 0.5, 0.7, 0.85, 1.0, 0.85, 0.7, 0.0]) {
        final width = 100 + 150 * progress;
        await tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: ModernCardFrame(
                width: width,
                height: 300,
                progress: progress,
                card: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(key: artworkKey, width: width, height: 160),
                    const SizedBox(
                      key: titleKey,
                      height: 30,
                      child: Text('Title'),
                    ),
                  ],
                ),
                details: progress > 0.65
                    ? const SizedBox(
                        key: detailsKey,
                        height: 60,
                        child: Text('Overview'),
                      )
                    : null,
              ),
            ),
          ),
        );
        final currentArtwork = tester.getRect(find.byKey(artworkKey));
        final currentTitle = tester.getTopLeft(find.byKey(titleKey));
        artwork ??= currentArtwork;
        title ??= currentTitle;
        expect(currentArtwork.top, artwork.top);
        expect(currentArtwork.height, artwork.height);
        expect(currentTitle.dy, title.dy);
        expect(tester.getSize(find.byType(ModernCardFrame)).height, 300);
        if (progress > 0.65) {
          final currentDetails = tester.getTopLeft(find.byKey(detailsKey));
          details ??= currentDetails;
          expect(currentDetails.dy, details.dy);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
