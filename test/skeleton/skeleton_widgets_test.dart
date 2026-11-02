import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/util/platform_detection.dart';
import 'package:moonfin/ui/widgets/playback/loading_animation_widget.dart';
import 'package:moonfin/ui/widgets/skeleton/skeleton_detail_screen.dart';
import 'package:moonfin/ui/widgets/skeleton/skeleton_home_row.dart';
import 'package:moonfin/ui/widgets/skeleton/skeleton_library_grid.dart';
import 'package:moonfin/ui/widgets/skeleton/skeleton_music_browse.dart';
import 'package:moonfin/ui/widgets/skeleton/skeleton_shimmer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Skeleton UI Widgets', () {
    testWidgets('SkeletonHomeRow renders both classic and modern variants', (
      tester,
    ) async {
      // 1. Classic layout
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonHomeRow(
              cardWidth: 150,
              imageHeight: 225,
              leadingPadding: 16,
              itemSpacing: 14,
              isModern: false,
              count: 6,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonHomeRow), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);

      // 2. Modern layout
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonHomeRow(
              cardWidth: 260,
              imageHeight: 390,
              leadingPadding: 32,
              itemSpacing: 18,
              isModern: true,
              count: 6,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonHomeRow), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('detail loading keeps legacy style support without skeletons', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DetailScreenSkeleton(isModern: false)),
        ),
      );
      expect(
        tester
            .widget<DetailScreenSkeleton>(find.byType(DetailScreenSkeleton))
            .isModern,
        isFalse,
      );
      expect(find.byType(SkeletonBox), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SkeletonBox), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'SkeletonLibraryGrid renders vertical, horizontal, and song layouts without overflow',
      (tester) async {
        // 1. Vertical grid layout
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SkeletonLibraryGrid(cardWidth: 150, aspectRatio: 2 / 3),
            ),
          ),
        );
        expect(find.byType(SkeletonLibraryGrid), findsOneWidget);
        expect(find.byType(SkeletonBox), findsWidgets);

        // 2. Horizontal row layout
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SkeletonLibraryGrid(
                isHorizontal: true,
                cardWidth: 150,
                aspectRatio: 2 / 3,
              ),
            ),
          ),
        );
        expect(find.byType(SkeletonLibraryGrid), findsOneWidget);

        // 3. Audio/Songs list layout
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: SkeletonLibraryGrid(isSongs: true)),
          ),
        );
        expect(find.byType(SkeletonLibraryGrid), findsOneWidget);

        // 4. Music browse landing page layout
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SkeletonMusicBrowse())),
        );
        expect(find.byType(SkeletonMusicBrowse), findsOneWidget);
        expect(find.byType(SkeletonBox), findsWidgets);
      },
    );

    // MaterialApp draws fade transitions of its own for the route, so these
    // count only the ones inside the shimmer.
    Finder shimmerFades() => find.descendant(
      of: find.byType(SkeletonShimmer).first,
      matching: find.byType(FadeTransition),
    );

    testWidgets('a shimmer on its own breathes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonShimmer(child: SkeletonBox(width: 10, height: 10)),
          ),
        ),
      );

      expect(shimmerFades(), findsOneWidget);
    });

    testWidgets('a nested shimmer stands aside', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonShimmer(
              child: SkeletonShimmer(child: SkeletonBox(width: 10, height: 10)),
            ),
          ),
        ),
      );

      expect(shimmerFades(), findsOneWidget);
      expect(find.byType(SkeletonBox), findsOneWidget);
    });
  });

  group('Detail loading form factors', () {
    // The delayed loading state must fit every supported viewport and style.
    const surfaces = <String, Size>{
      'phone portrait': Size(390, 844),
      'tablet portrait': Size(820, 1180),
      'desktop landscape': Size(1920, 1080),
      'tv': Size(960, 540),
    };

    for (final entry in surfaces.entries) {
      for (final style in DetailScreenStyle.values) {
        testWidgets('${style.name} loading fits a ${entry.key} screen', (
          tester,
        ) async {
          final isTv = entry.key == 'tv';
          if (isTv) {
            PlatformDetection.setTvMode(true);
            addTearDown(() => PlatformDetection.setTvMode(false));
          }
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: DetailScreenSkeleton(style: style)),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));

          expect(tester.takeException(), isNull);
          expect(find.byType(SkeletonBox), findsNothing);
          expect(find.byType(LoadingAnimationWidget), findsNothing);
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(LoadingAnimationWidget), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  });
}
