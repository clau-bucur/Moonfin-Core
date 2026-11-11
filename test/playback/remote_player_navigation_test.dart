import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:playback_core/playback_core.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/auth/repositories/user_repository.dart';
import 'package:moonfin/auth/repositories/server_repository.dart';
import 'package:moonfin/auth/repositories/session_repository.dart';
import 'package:moonfin/auth/store/authentication_store.dart';
import 'package:moonfin/auth/store/authentication_preferences.dart';
import 'package:moonfin/auth/store/credential_store.dart';
import 'package:moonfin/data/services/socket_handler.dart';
import 'package:moonfin/data/services/plugin_sync_service.dart';
import 'package:moonfin/data/services/cast/cast_service.dart';
import 'package:moonfin/data/services/cast/cast_target.dart';
import 'package:moonfin/data/services/cast/native_airplay_channel.dart';
import 'package:moonfin/data/services/cast/native_cast_channel.dart';
import 'package:moonfin/data/services/cast/native_dlna_channel.dart';
import 'package:moonfin/data/services/media_server_client_factory.dart';
import 'package:moonfin/data/services/theme_music_service.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/platform/pip_service.dart';
import 'package:moonfin/playback/aether_backend.dart';
import 'package:moonfin/playback/playback_lifecycle_handler.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/ui/screens/playback/video_player_screen.dart';
import 'package:moonfin/ui/screensaver/screensaver_controller.dart';
import 'package:moonfin/ui/widgets/playback/next_up_overlay.dart';
import 'package:moonfin/ui/widgets/playback/chapter_filmstrip.dart';
import 'package:moonfin/ui/widgets/playback/trickplay.dart';
import 'package:moonfin/ui/widgets/playback/playback_time_row.dart';
import 'package:moonfin/util/playback_time_label.dart';
import 'package:moonfin/util/platform_detection.dart';

class _AuthStore extends Fake implements AuthenticationStore {}

class _AuthPrefs extends Fake implements AuthenticationPreferences {}

class _Credentials extends Fake implements CredentialStore {}

class _Socket extends Fake implements SocketHandler {}

class _Servers extends Fake implements ServerRepository {}

class _PluginSync extends Fake implements PluginSyncService {}

class _Manager extends PlaybackManager {
  int pauses = 0;
  int resumes = 0;
  int advances = 0;
  final seeks = <Duration>[];
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> resume() async => resumes++;
  @override
  Future<void> seekTo(Duration position) async => seeks.add(position);
  @override
  Future<void> nextInQueue() async => advances++;
  @override
  Future<void> stop({bool userInitiated = true}) async {}
}

class _Client extends Fake implements MediaServerClient {
  @override
  ServerType get serverType => ServerType.emby;
  @override
  TrickplayApi? get trickplayApi => null;
}

class _Factory extends Fake implements MediaServerClientFactory {
  @override
  MediaServerClient? getClientIfExists(String id) => null;
}

class _Cast extends Fake implements CastService {
  @override
  final activeKindNotifier = ValueNotifier<CastTargetKind?>(null);
  @override
  final remoteStateNotifier = ValueNotifier<String?>(null);
  @override
  final remotePositionNotifier = ValueNotifier<int>(0);
  @override
  CastTargetKind? get activeKind => null;
}

class _ThemeMusic extends Fake implements ThemeMusicService {
  @override
  void setExternalAudioActive(bool active) {}
}

class _Screensaver extends Fake implements ScreensaverController {
  @override
  void setPlaybackActive(bool active) {}
}

class _Lifecycle extends Fake implements PlaybackLifecycleHandler {}

void main() {
  late _Manager manager;
  late PipService pip;
  late SessionRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    manager = _Manager();
    manager.state.setPlaying(true);
    manager.state.setDuration(const Duration(minutes: 30));
    GetIt.instance.registerSingleton<PlaybackManager>(manager);
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
    GetIt.instance.registerSingleton<UserRepository>(UserRepository());
    GetIt.instance.registerSingleton<MediaServerClient>(_Client());
    GetIt.instance.registerSingleton<MediaServerClientFactory>(_Factory());
    GetIt.instance.registerSingleton<CastService>(_Cast());
    GetIt.instance.registerSingleton<NativeCastChannel>(NativeCastChannel());
    GetIt.instance.registerSingleton<NativeDlnaChannel>(NativeDlnaChannel());
    GetIt.instance.registerSingleton<NativeAirPlayChannel>(
      NativeAirPlayChannel(),
    );
    pip = PipService();
    GetIt.instance.registerSingleton<PipService>(pip);
    GetIt.instance.registerSingleton<PlaybackLifecycleHandler>(_Lifecycle());
    GetIt.instance.registerSingleton<ThemeMusicService>(_ThemeMusic());
    GetIt.instance.registerSingleton<ScreensaverController>(_Screensaver());
    repository = SessionRepository(
      _AuthStore(),
      _AuthPrefs(),
      _Credentials(),
      _Factory(),
      _Socket(),
      _Servers(),
      GetIt.instance<UserRepository>(),
      _PluginSync(),
    );
  });

  tearDown(() async {
    repository.dispose();
    manager.dispose();
    pip.dispose();
    await GetIt.instance.reset();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const VideoPlayerScreen(),
      ),
    );
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String command) async {
    await repository.handleRemoteCommandForTest(
      GeneralCommandMessage(name: command),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> showNextUp(WidgetTester tester) async {
    manager.queueService.setQueue([
      const AggregatedItem(
        id: 'one',
        serverId: 'server',
        rawData: {'Type': 'Episode', 'Name': 'One'},
      ),
      const AggregatedItem(
        id: 'two',
        serverId: 'server',
        rawData: {'Type': 'Episode', 'Name': 'Two'},
      ),
    ]);
    await tester.pump();
    manager.state.setPosition(
      const Duration(minutes: 29, seconds: 59, milliseconds: 800),
    );
    await tester.pump();
    await tester.pump();
  }

  group('TV chapter navigation', () {
    setUp(() => PlatformDetection.setTvMode(true));
    tearDown(() => PlatformDetection.setTvMode(false));

    void setMovie({bool chapters = true}) {
      manager.queueService.setQueue([
        AggregatedItem(
          id: 'movie',
          serverId: 'server',
          rawData: {
            'Type': 'Movie',
            'Name': 'Movie',
            'Chapters': chapters
                ? [
                    {'Name': 'Opening', 'StartPositionTicks': 0},
                    {'Name': 'Arrival', 'StartPositionTicks': 3000000000},
                    {'Name': 'Finale', 'StartPositionTicks': 6000000000},
                  ]
                : [],
          },
        ),
      ]);
      manager.state.setPosition(const Duration(minutes: 7));
    }

    Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('Up browses chapters and Select seeks and resumes', (
      tester,
    ) async {
      setMovie();
      await open(tester);
      await tester.pump(const Duration(seconds: 10));
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(find.byType(ChapterFilmstrip), findsOneWidget);
      final selected = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(ChapterFilmstrip),
              matching: find.byType(Semantics),
            ),
          )
          .where((widget) => widget.properties.selected == true)
          .single;
      expect(selected.properties.label, 'Arrival, 5:00');
      expect(manager.seeks, isEmpty);
      expect(manager.pauses, 0);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.select);
      expect(manager.seeks, [const Duration(minutes: 10)]);
      expect(manager.resumes, 1);
      expect(find.byType(ChapterFilmstrip), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Back dismisses chapters without changing playback', (
      tester,
    ) async {
      setMovie();
      await open(tester);
      await tester.pump(const Duration(seconds: 10));
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ChapterFilmstrip), findsNothing);
      expect(manager.seeks, isEmpty);
      expect(manager.resumes, 0);
      expect(manager.pauses, 0);
      expect(find.byType(VideoPlayerScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('chapter browsing previews progress and all position labels', (
      tester,
    ) async {
      final prefs = GetIt.instance<UserPreferences>();
      await prefs.set(
        UserPreferences.playbackTimeAboveLeft,
        PlaybackTimeSlot.elapsed,
      );
      await prefs.set(
        UserPreferences.playbackTimeAboveCenter,
        PlaybackTimeSlot.timeRemaining,
      );
      await prefs.set(
        UserPreferences.playbackTimeAboveRight,
        PlaybackTimeSlot.endsAt,
      );
      setMovie();
      await open(tester);
      await tester.pump(const Duration(seconds: 10));
      await key(tester, LogicalKeyboardKey.arrowUp);
      PlaybackTimeRow labels() => tester
          .widgetList<PlaybackTimeRow>(find.byType(PlaybackTimeRow))
          .where((row) => row.bold)
          .single;
      expect(tester.widget<Slider>(find.byType(Slider)).value, 300000);
      expect(labels().left, '5:00');
      expect(labels().center, '-25:00');
      final firstEnd = labels().right;
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 600000);
      expect(labels().left, '10:00');
      expect(labels().center, '-20:00');
      expect(labels().right, isNot(firstEnd));
      expect(
        labels().right,
        formatPlaybackEndsAt(
          tester.element(find.byType(VideoPlayerScreen)),
          position: const Duration(minutes: 10),
          duration: const Duration(minutes: 30),
          use24Hour: prefs.get(UserPreferences.use24HourClock),
        ),
      );
      manager.state.setPosition(const Duration(minutes: 8));
      await tester.pump();
      expect(labels().left, '10:00');
      expect(manager.seeks, isEmpty);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 480000);
      expect(labels().left, '8:00');
      expect(labels().center, '-22:00');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'chapter previews sit above the controls and follow trickplay settings',
      (tester) async {
        final prefs = GetIt.instance<UserPreferences>();
        await prefs.set(UserPreferences.trickPlayMode, TrickplayMode.strip);
        await prefs.set(UserPreferences.trickPlayPreviewScalePercent, 10);
        await prefs.set(UserPreferences.trickPlayFollowScrubPosition, false);
        await prefs.set(UserPreferences.trickPlayVerticalPositionPercent, 0);
        setMovie();
        await open(tester);
        await tester.pump(const Duration(seconds: 10));
        await key(tester, LogicalKeyboardKey.arrowUp);
        final chapterStrip = find.byType(ChapterFilmstrip);
        Trickplay preview() => tester.widget<Trickplay>(
          find.descendant(of: chapterStrip, matching: find.byType(Trickplay)),
        );
        TrickplayPreviewArea area() => tester.widget<TrickplayPreviewArea>(
          find.descendant(
            of: chapterStrip,
            matching: find.byType(TrickplayPreviewArea),
          ),
        );
        final small = preview();
        expect(small.leftCount + small.rightCount, greaterThan(0));
        expect(
          tester.getBottomLeft(find.text('Arrival')).dy,
          lessThan(tester.getTopLeft(find.byType(Slider)).dy),
        );
        expect(find.byIcon(Icons.restart_alt), findsOneWidget);
        expect(area().plan.verticalTravel, 0);
        final smallCount = small.leftCount + small.rightCount;
        await key(tester, LogicalKeyboardKey.escape);

        await prefs.set(UserPreferences.trickPlayPreviewScalePercent, 70);
        await prefs.set(UserPreferences.trickPlayVerticalPositionPercent, 50);
        await key(tester, LogicalKeyboardKey.arrowUp);
        expect(preview().tileWidth, greaterThan(small.tileWidth));
        expect(
          preview().leftCount + preview().rightCount,
          lessThan(smallCount),
        );
        expect(area().plan.verticalTravel, greaterThan(0));
        expect(
          tester.getBottomLeft(find.text('Arrival')).dy,
          lessThan(tester.getTopLeft(find.byType(Slider)).dy),
        );
        await key(tester, LogicalKeyboardKey.escape);

        await prefs.set(UserPreferences.trickPlayMode, TrickplayMode.single);
        await key(tester, LogicalKeyboardKey.arrowUp);
        expect(preview().leftCount, 0);
        expect(preview().rightCount, 0);
        expect(manager.seeks, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'chapter browsing stops at both ends and resumes paused playback',
      (tester) async {
        setMovie();
        await open(tester);
        await tester.pump(const Duration(seconds: 10));
        manager.state.setPlaying(false);
        await tester.pump();
        await key(tester, LogicalKeyboardKey.arrowUp);
        for (var i = 0; i < 5; i++) {
          await key(tester, LogicalKeyboardKey.arrowLeft);
        }
        await key(tester, LogicalKeyboardKey.select);
        expect(manager.seeks, [Duration.zero]);
        expect(manager.resumes, 1);
        await key(tester, LogicalKeyboardKey.arrowUp);
        for (var i = 0; i < 5; i++) {
          await key(tester, LogicalKeyboardKey.arrowRight);
        }
        await key(tester, LogicalKeyboardKey.select);
        expect(manager.seeks, [Duration.zero, const Duration(minutes: 10)]);
        expect(manager.resumes, 2);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('Next Up takes focus from an open chapter strip', (
      tester,
    ) async {
      setMovie();
      final movie = manager.queueService.currentItem as AggregatedItem;
      manager.queueService.setQueue([
        AggregatedItem(
          id: movie.id,
          serverId: movie.serverId,
          rawData: {...movie.rawData, 'Type': 'Episode'},
        ),
        const AggregatedItem(
          id: 'next',
          serverId: 'server',
          rawData: {'Type': 'Episode', 'Name': 'Next'},
        ),
      ]);
      await open(tester);
      await tester.pump(const Duration(seconds: 10));
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(find.byType(ChapterFilmstrip), findsOneWidget);
      manager.state.setPosition(
        const Duration(minutes: 29, seconds: 59, milliseconds: 800),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(ChapterFilmstrip), findsNothing);
      final nextUp = tester.widget<NextUpOverlay>(find.byType(NextUpOverlay));
      expect(nextUp.focusNode?.hasFocus, isTrue);
      expect(manager.seeks, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    for (final fromChapters in [false, true]) {
      testWidgets(
        'Down focuses the first action${fromChapters ? ' from chapters' : ''}',
        (tester) async {
          setMovie();
          await open(tester);
          await tester.pump(const Duration(seconds: 10));
          if (fromChapters) await key(tester, LogicalKeyboardKey.arrowUp);
          await key(tester, LogicalKeyboardKey.arrowDown);
          expect(find.byType(ChapterFilmstrip), findsNothing);
          expect(
            FocusManager.instance.primaryFocus?.debugLabel,
            'video_player_tv_transport_first',
          );
          expect(manager.seeks, isEmpty);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets('Up without chapters reveals the normal controls', (
      tester,
    ) async {
      setMovie(chapters: false);
      await open(tester);
      await tester.pump(const Duration(seconds: 10));
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(find.byType(ChapterFilmstrip), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'video_player_tv_seekbar',
      );
      expect(manager.seeks, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 60));
    });
  });

  testWidgets(
    'normal player remote reveals mounted controls and Select runs once',
    (tester) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 10));
      await tap(tester, 'MoveDown');
      final primary = FocusManager.instance.primaryFocus;
      expect(primary?.context, isNotNull);
      expect(
        tester
            .widgetList<IconButton>(find.byType(IconButton))
            .where((button) => button.focusNode == primary),
        hasLength(1),
      );
      for (var i = 0; i < 2; i++) {
        await tap(tester, 'MoveRight');
        expect(FocusManager.instance.primaryFocus, isNot(primary));
        await tap(tester, 'MoveLeft');
        expect(FocusManager.instance.primaryFocus, primary);
      }
      expect(
        manager.seeks,
        isEmpty,
        reason: 'remote arrows navigate rather than seek',
      );
      await tap(tester, 'Select');
      expect(manager.pauses, 1);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
    }),
  );

  testWidgets(
    'Next Up owns remote focus ahead of normal playback controls',
    (tester) async {
      await open(tester);
      await tap(tester, 'MoveDown');
      await showNextUp(tester);
      expect(find.byType(NextUpOverlay), findsOneWidget);
      final nextUp = tester.widget<NextUpOverlay>(find.byType(NextUpOverlay));
      expect(nextUp.focusNode?.hasFocus, isTrue);
      await tap(tester, 'MoveRight');
      await tester.pump(const Duration(milliseconds: 100));
      expect(nextUp.dismissFocusNode?.hasFocus, isTrue);
      await tap(tester, 'MoveLeft');
      expect(nextUp.focusNode?.hasFocus, isTrue);
      await tap(tester, 'Select');
      expect(manager.advances, 1);
      expect(manager.pauses, 0);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
    }),
  );

  testWidgets(
    'Next Up close button dismisses the card and keeps the episode playing',
    (tester) async {
      await open(tester);
      await showNextUp(tester);
      expect(find.byType(NextUpOverlay), findsOneWidget);
      expect(manager.suppressAutoNext, isTrue);

      await tester.tap(
        find.descendant(
          of: find.byType(NextUpOverlay),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      // On touch layouts the tap only lands once the double tap window ends.
      await tester.pump(kDoubleTapTimeout);
      await tester.pump();

      expect(find.byType(NextUpOverlay), findsNothing);
      expect(
        manager.suppressAutoNext,
        isFalse,
        reason: 'the episode ends on its own once the card is dismissed',
      );
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
    }),
  );

  testWidgets(
    'Play and Pause from Now Playing reach the engine-backed Flutter player',
    (tester) async {
      const control = MethodChannel('moonfin/ios_aether_control');
      const events = MethodChannel('moonfin/ios_aether_events');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(control, (_) async => null);
      messenger.setMockMethodCallHandler(events, (_) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(control, null);
        messenger.setMockMethodCallHandler(events, null);
      });
      final engine = AetherBackend(GetIt.instance<UserPreferences>());
      GetIt.instance.registerSingleton<AetherBackend>(engine);
      manager.setBackend(engine);
      await open(tester);

      Future<void> remote(String event) async {
        await messenger.handlePlatformMessage(
          events.name,
          const StandardMethodCodec().encodeSuccessEnvelope({'event': event}),
          (_) {},
        );
        await tester.pump();
      }

      await remote('pause');
      expect(manager.pauses, 1);
      manager.state.setPlaying(false);
      await remote('play');
      expect(manager.resumes, 1);
      manager.state.setPlaying(true);
      await remote('play');
      expect(manager.resumes, 1, reason: 'already playing');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
