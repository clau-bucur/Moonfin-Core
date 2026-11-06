import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:playback_core/playback_core.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonfin/auth/models/user.dart';
import 'package:moonfin/auth/repositories/user_repository.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/services/cast/cast_service.dart';
import 'package:moonfin/data/services/cast/cast_target.dart';
import 'package:moonfin/data/services/cast/native_airplay_channel.dart';
import 'package:moonfin/data/services/cast/native_cast_channel.dart';
import 'package:moonfin/data/services/cast/native_dlna_channel.dart';
import 'package:moonfin/data/services/media_server_client_factory.dart';
import 'package:moonfin/data/services/theme_music_service.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/platform/pip_service.dart';
import 'package:moonfin/playback/playback_lifecycle_handler.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/playback/video_player_screen.dart';
import 'package:moonfin/ui/screensaver/screensaver_controller.dart';
import 'package:moonfin/ui/widgets/playback/skip_segment_overlay.dart';
import 'package:moonfin/util/platform_detection.dart';

import '../util/media_segment_fakes.dart';

class _Client extends Fake implements MediaServerClient {
  final items = FakeItemsApi();
  final images = _Images();
  TrickplayApi? previews;

  @override
  ServerType get serverType => ServerType.jellyfin;

  @override
  ItemsApi get itemsApi => items;

  @override
  TrickplayApi? get trickplayApi => previews;

  @override
  ImageApi get imageApi => images;
}

class _Images extends Fake implements ImageApi {
  final requestedTrickplaySheets = <int>[];

  @override
  String getTrickplayTileImageUrl(
    String itemId, {
    required int width,
    required int index,
    String? mediaSourceId,
  }) {
    requestedTrickplaySheets.add(index);
    return 'https://example.test/trickplay/$index.jpg';
  }
}

class _Trickplay extends Fake implements TrickplayApi {
  int metadataRequests = 0;

  @override
  Future<TrickplayThumbnailSet?> getThumbnailSet(
    String itemId, {
    required int width,
    String? mediaSourceId,
  }) async {
    metadataRequests++;
    return null;
  }
}

class _Factory extends Fake implements MediaServerClientFactory {
  @override
  MediaServerClient? getClientIfExists(String id) => null;
}

class _Cast extends Fake implements CastService {
  final calls = <String>[];
  @override
  final activeKindNotifier = ValueNotifier<CastTargetKind?>(null);
  @override
  final castItemNotifier = ValueNotifier<AggregatedItem?>(null);
  @override
  final remoteStateNotifier = ValueNotifier<String?>(null);
  @override
  final remotePositionNotifier = ValueNotifier<int>(0);
  @override
  CastTargetKind? get activeKind => activeKindNotifier.value;

  @override
  Stream<CastTarget> discoverTargetsStreamed(AggregatedItem item) =>
      Stream.value(
        const CastTarget(
          id: 'tv',
          kind: CastTargetKind.googleCast,
          title: 'Living Room',
        ),
      );

  @override
  Future<void> playToTarget(
    CastTarget target, {
    required AggregatedItem item,
    List<AggregatedItem>? queueItems,
    int? startPositionTicks,
    String? mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {
    castItemNotifier.value = item;
    activeKindNotifier.value = target.kind;
    remotePositionNotifier.value = startPositionTicks ?? 0;
  }

  @override
  Future<void> play(CastTargetKind kind) async => calls.add('play');

  @override
  Future<void> pause(CastTargetKind kind) async => calls.add('pause');

  @override
  Future<void> seek(CastTargetKind kind, {required int positionTicks}) async =>
      calls.add('seek ${positionTicks ~/ 10000000}s');
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

class _Users extends Fake implements UserRepository {
  @override
  User? get currentUser => null;
}

class _Manager extends PlaybackManager {
  final transport = <String>[];
  final seeks = <Duration>[];
  int stopCalls = 0;
  int nextInQueueCalls = 0;
  PlaybackBringupState bringup = const PlaybackBringupState.idle();
  bool controlBringupStream = false;
  final bringupChanges = StreamController<PlaybackBringupState>.broadcast();

  @override
  PlaybackBringupState get bringupState => bringup;

  @override
  Stream<PlaybackBringupState> get bringupStateStream =>
      controlBringupStream ? bringupChanges.stream : super.bringupStateStream;

  @override
  void dispose() {
    bringupChanges.close();
    super.dispose();
  }

  // The real calls run too, since they record the viewer's pause.
  @override
  Future<void> pause() async {
    transport.add('pause');
    await super.pause();
  }

  @override
  Future<void> resume() async {
    transport.add('resume');
    await super.resume();
  }

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    await super.seekTo(position);
  }

  @override
  Future<void> stop({bool userInitiated = true}) async {
    stopCalls++;
  }

  @override
  Future<void> nextInQueue() async {
    nextInQueueCalls++;
    queueService.next();
  }
}

void main() {
  late _Manager manager;
  late _Client client;
  late PipService pip;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    manager = _Manager();
    GetIt.instance.registerSingleton<PlaybackManager>(manager);
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
    client = _Client();
    GetIt.instance.registerSingleton<MediaServerClient>(client);
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
    GetIt.instance.registerSingleton<UserRepository>(_Users());
  });

  tearDown(() async {
    manager.dispose();
    pip.dispose();
    await GetIt.instance.reset();
  });

  Future<void> revealControls(WidgetTester tester) async {
    final item = manager.queueService.currentItem;
    if (item is Map && item['__moonfinIsPreroll'] == true) return;
    await tester.sendKeyEvent(PlatformDetection.isTV
        ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.enter);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> mountPlayer(WidgetTester tester, {
    bool settle = true, bool reveal = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const VideoPlayerScreen(),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    if (reveal) await revealControls(tester);
  }

  testWidgets('startup and stream preparation never reveal controls', (tester) async {
    PlatformDetection.setTvMode(true);
    addTearDown(() => PlatformDetection.setTvMode(false));
    manager.controlBringupStream = true;
    manager.bringup = const PlaybackBringupState(phase: PlaybackBringupPhase.resolving);
    await mountPlayer(tester, reveal: false, settle: false);
    expect(find.byType(Slider), findsNothing);
    for (final phase in [PlaybackBringupPhase.opening, PlaybackBringupPhase.ready]) {
      manager.bringup = PlaybackBringupState(phase: phase);
      manager.bringupChanges.add(manager.bringup);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Slider), findsNothing);
    }
    await revealControls(tester);
    expect(find.byType(Slider), findsOneWidget);
    manager.queueService.setQueue([{'Id': 'next', 'Type': 'Episode'}]);
    await tester.pump();
    await tester.pump();
    expect(find.byType(Slider), findsNothing,
        reason: 'the next item also starts without controls');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('early controls request waits for resolved stream buttons', (tester) async {
    PlatformDetection.setTvMode(true);
    addTearDown(() => PlatformDetection.setTvMode(false));
    manager.controlBringupStream = true;
    manager.bringup = const PlaybackBringupState(phase: PlaybackBringupPhase.resolving);
    await mountPlayer(tester, reveal: false, settle: false);
    await revealControls(tester);
    expect(find.byType(Slider), findsNothing);
    expect(find.byIcon(Icons.subtitles_outlined), findsNothing);
    manager.queueService.setQueue([{
      'Id': 'video', 'Type': 'Movie', 'MediaStreams': [{'Type': 'Subtitle', 'Index': 2}],
    }]);
    await tester.pump();
    // Queue changes are a new playback start, so explicitly request its controls.
    await revealControls(tester);
    manager.bringup = const PlaybackBringupState(phase: PlaybackBringupPhase.ready);
    manager.bringupChanges.add(manager.bringup);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byIcon(Icons.subtitles_outlined), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('seek-preview metadata waits for the current stream to open', (
    tester,
  ) async {
    final previews = _Trickplay();
    client.previews = previews;
    manager.controlBringupStream = true;
    manager.bringup = const PlaybackBringupState(
      phase: PlaybackBringupPhase.resolving,
    );
    manager.queueService.setQueue([
      {'Id': 'video', 'Type': 'Movie'},
    ]);
    await mountPlayer(tester, settle: false);
    expect(previews.metadataRequests, 0);

    manager.bringup = const PlaybackBringupState(
      phase: PlaybackBringupPhase.ready,
    );
    manager.bringupChanges.add(manager.bringup);
    await tester.pump();
    await tester.pump();
    expect(previews.metadataRequests, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disabled seek previews make no metadata request', (
    tester,
  ) async {
    final previews = _Trickplay();
    client.previews = previews;
    final prefs = GetIt.instance<UserPreferences>();
    await prefs.set(UserPreferences.trickPlayMode, TrickplayMode.disabled);
    manager.queueService.setQueue([
      {'Id': 'video', 'Type': 'Movie'},
    ]);
    await mountPlayer(tester);
    expect(previews.metadataRequests, 0);

    // Enabling previews from the player still makes them available.
    await prefs.set(UserPreferences.trickPlayMode, TrickplayMode.single);
    await tester.pump();
    expect(previews.metadataRequests, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('watching without seeking downloads no trickplay sheets', (
    tester,
  ) async {
    PlatformDetection.setTvMode(true);
    addTearDown(() => PlatformDetection.setTvMode(false));
    manager.queueService.setQueue([
      {
        'Id': 'video',
        'Type': 'Movie',
        'Trickplay': {
          'source': {
            '320': {
              'Width': 320,
              'Height': 180,
              'TileWidth': 10,
              'TileHeight': 10,
              'Interval': 1000,
            },
          },
        },
      },
    ]);
    manager.state.setDuration(const Duration(hours: 2));
    await mountPlayer(tester);
    expect(client.images.requestedTrickplaySheets, isEmpty);

    manager.state.setPlaying(true);
    await tester.pump(const Duration(seconds: 10));
    for (final second in [60, 180, 600, 1800]) {
      manager.state.setPosition(Duration(seconds: second));
      await tester.pump();
    }
    expect(client.images.requestedTrickplaySheets, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  for (final type in ['Movie', 'Episode']) {
    testWidgets('TV Restart leads the entire transport row for $type', (
      tester,
    ) async {
      PlatformDetection.setTvMode(true);
      addTearDown(() => PlatformDetection.setTvMode(false));
      manager.queueService.setQueue([
        AggregatedItem(
          id: 'video',
          serverId: 'server',
          rawData: {'Id': 'video', 'Type': type, 'RunTimeTicks': 36000000000},
        ),
      ]);
      await mountPlayer(tester);
      final restart = find.byIcon(Icons.replay_rounded);
      final previous = find.byIcon(Icons.skip_previous_rounded);
      expect(restart, findsOneWidget);
      expect(
        tester.getCenter(restart).dx,
        lessThan(tester.getCenter(previous).dx),
      );
      expect(tester.getCenter(restart).dy, tester.getCenter(previous).dy);

      // Enter the row at Play/Pause, then walk left through Seek and Previous.
      Focus.of(tester.element(find.byIcon(Icons.play_arrow_rounded)))
          .requestFocus();
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
      }
      expect(Focus.of(tester.element(restart)).hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(manager.seeks, [Duration.zero]);
      expect(manager.transport, contains('resume'));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('TV Restart still respects its visibility preference', (
    tester,
  ) async {
    PlatformDetection.setTvMode(true);
    addTearDown(() => PlatformDetection.setTvMode(false));
    await GetIt.instance<UserPreferences>().set(
      UserPreferences.hiddenOsdButtonsTv,
      'restart',
    );
    manager.queueService.setQueue([
      AggregatedItem(
        id: 'video',
        serverId: 'server',
        rawData: const {'Id': 'video', 'Type': 'Movie'},
      ),
    ]);
    await mountPlayer(tester);
    expect(find.byIcon(Icons.replay_rounded), findsNothing);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('moving the mouse after the X keeps Cinema Skip hidden', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        if (call.method == 'isVisible') return true;
        return call.method.startsWith('is') ? false : null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null));
    await GetIt.instance<UserPreferences>()
        .set(UserPreferences.cinemaModeSkipEnabled, true);
    manager.queueService.setQueue([
      {'Id': 'trailer', '__moonfinIsPreroll': true, 'RunTimeTicks': 900000000},
    ]);
    await mountPlayer(tester);
    final skip = find.byType(SkipSegmentOverlay);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(skip, findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(100, 300));
    await tester.pump(const Duration(seconds: 2));
    await mouse.moveTo(const Offset(300, 300));
    await tester.pump();
    expect(skip, findsNothing);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('with Cinema Skip off, Escape in a pre-roll still exits', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        if (call.method == 'isFullScreen' || call.method == 'isVisible') {
          return true;
        }
        return call.method.startsWith('is') ? false : null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null));
    // Leaving playback resets the orientations, which waits on this channel.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    manager.queueService.setQueue([
      {'Id': 'trailer', '__moonfinIsPreroll': true, 'RunTimeTicks': 900000000},
    ]);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/play', builder: (_, _) => const VideoPlayerScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
      ),
    );
    router.push('/play');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(manager.stopCalls, 1);
    expect(find.byType(VideoPlayerScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Back hides, Right reveals, Select and Fast Forward advance', (
    tester,
  ) async {
    PlatformDetection.setTvMode(true);
    addTearDown(() => PlatformDetection.setTvMode(false));
    await GetIt.instance<UserPreferences>().set(
      UserPreferences.cinemaModeSkipEnabled,
      true,
    );
    manager.queueService.setQueue([
      {'Id': 'first', '__moonfinIsPreroll': true, 'RunTimeTicks': 900000000},
      {'Id': 'second', '__moonfinIsPreroll': true, 'RunTimeTicks': 450000000},
      {'Id': 'short', '__moonfinIsPreroll': true, 'RunTimeTicks': 50000000},
    ]);
    await mountPlayer(tester);
    final button = find.byType(SkipSegmentOverlay);
    expect(
      tester.widget<SkipSegmentOverlay>(button).focusNode!.hasPrimaryFocus,
      isTrue,
    );
    await tester.sendKeyEvent(
      LogicalKeyboardKey.goBack,
      physicalKey: PhysicalKeyboardKey.escape,
    );
    await tester.pumpAndSettle();
    expect(button, findsNothing);
    expect(manager.queueService.currentIndex, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(button, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(manager.queueService.currentIndex, 1);
    expect(tester.widget<SkipSegmentOverlay>(button).segment.itemId, 'second');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaFastForward);
    await tester.pump();
    expect(manager.queueService.currentIndex, 2);
    await tester.pumpWidget(const SizedBox());
  });

  // Issue #1886: on TV, Up from the seek bar never reached the skip button
  // sitting just above it.
  testWidgets('on TV, Up from the seek bar reaches the skip button', (
    tester,
  ) async {
    PlatformDetection.setTvMode(true);
    addTearDown(() => PlatformDetection.setTvMode(false));
    client.items.segments = [
      segmentJson(id: 'intro', type: 'Intro', startMs: 0, endMs: 90000),
    ];
    manager.queueService.setQueue([
      AggregatedItem(
        id: 'ep1',
        serverId: 'server',
        rawData: const {'Id': 'ep1', 'Type': 'Episode'},
      ),
    ]);
    await mountPlayer(tester);
    manager.state.setPosition(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump();
    final skip = tester
        .widget<SkipSegmentOverlay>(find.byType(SkipSegmentOverlay))
        .focusNode!;

    // Focus moves wait for a frame and retry a moment later, so this keeps
    // frames coming the way playing video does.
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      for (var i = 0; i < 3; i++) {
        tester.binding.scheduleFrame();
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    expect(skip.hasPrimaryFocus, isTrue);
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowLeft);
    expect(skip.hasPrimaryFocus, isFalse);
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowUp);
    expect(skip.hasPrimaryFocus, isFalse, reason: 'the seek bar comes first');
    await press(LogicalKeyboardKey.arrowUp);
    expect(skip.hasPrimaryFocus, isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('short Cinema pre-roll blocks ordinary intro/outro actions', (
    tester,
  ) async {
    final prefs = GetIt.instance<UserPreferences>();
    await prefs.set(UserPreferences.cinemaModeSkipEnabled, true);
    await prefs.set(UserPreferences.mediaSegmentActions, 'intro:skip,outro:skip');
    (GetIt.instance<MediaServerClient>() as _Client).items.segments = [
      segmentJson(id: 'intro', type: 'Intro', startMs: 1000, endMs: 2000),
      segmentJson(id: 'outro', type: 'Outro', startMs: 3000, endMs: 4000),
    ];
    manager.queueService.setQueue([
      const AggregatedItem(
        id: 'short',
        serverId: 'server',
        rawData: {
          'Id': 'short',
          '__moonfinIsPreroll': true,
          'RunTimeTicks': 50000000,
          'Chapters': [{'StartPositionTicks': 0}],
        },
      ),
    ]);
    await mountPlayer(tester);
    expect(find.byType(SkipSegmentOverlay), findsNothing);
    manager.state.setPosition(const Duration(milliseconds: 1500));
    await tester.pump();
    manager.state.setPosition(const Duration(milliseconds: 3500));
    await tester.pump();
    expect(manager.seeks, isEmpty);
    expect(manager.stopCalls, 0);
    await prefs.set(UserPreferences.cinemaModeSkipEnabled, false);
    manager.state.setPosition(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(manager.seeks, [const Duration(seconds: 2)]);
    await tester.pumpWidget(const SizedBox());
  });

  // Issue #1688: a resume that takes longer than the hide delay to start
  // playing left the controls up until a key was pressed.
  testWidgets('controls hide after a start slower than the hide delay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const VideoPlayerScreen(),
      ),
    );
    await tester.pump();
    await revealControls(tester);
    expect(find.byType(Slider), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(
      find.byType(Slider),
      findsOneWidget,
      reason: 'nothing is playing yet, so the controls stay',
    );

    manager.state.setPlaying(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(Slider), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  for (final back in ['remote', 'system']) {
    testWidgets('$back Back has a 750ms grace period after controls auto-hide',
        (tester) async {
      PlatformDetection.setTvMode(true);
      addTearDown(() => PlatformDetection.setTvMode(false));
      await GetIt.instance<UserPreferences>().set(
          UserPreferences.playbackEnginePreference, PlaybackEnginePreference.mpv);
      final router = GoRouter(initialLocation: '/details', routes: [
        GoRoute(path: '/details', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/play', builder: (_, _) => const VideoPlayerScreen()),
      ]);
      addTearDown(router.dispose);
      manager.state.setPlaying(true);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
      ));
      router.push('/play');
      await tester.pumpAndSettle();
      await revealControls(tester);
      expect(find.byType(Slider), findsOneWidget);

      // Stop at the actual auto-hide frame so the grace period starts here.
      for (var i = 0; i < 60 && find.byType(Slider).evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(Slider), findsNothing);

      Future<void> pressBack() async {
        if (back == 'system') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.goBack,
              physicalKey: PhysicalKeyboardKey.escape);
        }
        await tester.pump();
      }

      await pressBack();
      expect(manager.stopCalls, 0);
      await tester.pump(const Duration(milliseconds: 500));
      await pressBack();
      expect(manager.stopCalls, 0);
      expect(manager.state.isPlaying, isTrue);
      expect(find.byType(Slider), findsNothing);

      await tester.pump(const Duration(milliseconds: 300));
      await pressBack();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(manager.stopCalls, 1,
          reason: 'ignored Back presses do not extend the grace period');
      expect(router.state.uri.path, '/details');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('controls stay up while a dialog covers the player', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const VideoPlayerScreen(),
      ),
    );
    await tester.pump();
    await revealControls(tester);
    manager.state.setPlaying(true);
    await tester.pump();

    final player = tester.element(find.byType(VideoPlayerScreen));
    showDialog<void>(context: player, builder: (_) => const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(Slider), findsOneWidget);

    Navigator.of(player).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(Slider), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  // Issue #1751: the unlock prompt sits at the end of the top bar, where the
  // lock button was, instead of over the middle of the picture.
  for (final direction in TextDirection.values) {
    testWidgets('locking puts the unlock prompt at the top end in $direction', (
      tester,
    ) async {
      await GetIt.instance<UserPreferences>().set(
        UserPreferences.osdLockEnabled,
        true,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          builder: (context, child) =>
              Directionality(textDirection: direction, child: child!),
          home: const VideoPlayerScreen(),
        ),
      );
      await tester.pump();
    await revealControls(tester);

      // The player holds a single tap until its double-tap timeout runs out.
      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pump(const Duration(milliseconds: 500));

      final prompt = tester.getRect(find.text('Long press to unlock'));
      final screen = tester.getRect(find.byType(VideoPlayerScreen));
      expect(prompt.top, lessThan(screen.height / 4));
      if (direction == TextDirection.ltr) {
        expect(prompt.left, greaterThan(screen.width / 2));
      } else {
        expect(prompt.right, lessThan(screen.width / 2));
      }

      await tester.pumpWidget(const SizedBox());
    });
  }

  // Issue #1804: the double-tap skip held every OSD button back until its
  // timeout ran out.
  testWidgets('a mobile OSD button answers its tap at once', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const VideoPlayerScreen(),
      ),
    );
    await tester.pump();
    await revealControls(tester);

    await tester.tap(find.byIcon(Icons.audiotrack_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Audio Track'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a mobile surface tap still waits out a double-tap skip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const VideoPlayerScreen(),
      ),
    );
    await tester.pump();
    await revealControls(tester);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tapAt(const Offset(100, 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(Slider),
      findsOneWidget,
      reason: 'a second tap could still make it a skip',
    );
    await tester.pump(kDoubleTapTimeout);
    expect(find.byType(Slider), findsNothing);

    await tester.tapAt(const Offset(700, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(700, 300));
    await tester.pump();
    expect(find.text('30 seconds'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byType(Slider),
      findsNothing,
      reason: 'a double tap leaves the controls as they were',
    );

    await tester.pumpWidget(const SizedBox());
  });

  // Issue #1804: the button also waited out the debounce meant for a
  // buffering blip after a pause the viewer asked for.
  testWidgets('a pause the viewer asked for shows play at once', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const VideoPlayerScreen(),
      ),
    );
    await tester.pump();
    await revealControls(tester);
    // The playing stream delivers after the first frame, so the rebuild
    // lands on the second.
    Future<void> setPlaying(bool playing) async {
      manager.state.setPlaying(playing);
      await tester.pump();
      await tester.pump();
    }

    await setPlaying(true);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await setPlaying(false);
    expect(
      find.byIcon(Icons.pause_rounded),
      findsOneWidget,
      reason: 'a drop nobody asked for waits in case it is a blip',
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(Icons.pause_rounded), findsNothing);

    await setPlaying(true);
    await manager.pause();
    await setPlaying(false);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);

    // An engine that reports its own intent is believed over the manager.
    await manager.resume();
    await setPlaying(true);
    manager.state.setPlayWhenReady(false);
    await setPlaying(false);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  // Issue #1869: after a cast took over, the player's controls still drove
  // the paused copy on the phone.
  testWidgets('once cast, the controls drive the receiver', (tester) async {
    final cast = GetIt.instance<CastService>() as _Cast;
    manager.queueService.setQueue([
      const AggregatedItem(
        id: 'movie',
        serverId: 'server',
        rawData: {'Id': 'movie', 'Type': 'Movie'},
      ),
    ]);
    await mountPlayer(tester);
    manager.state.setDuration(const Duration(minutes: 10));
    manager.state.setPosition(const Duration(seconds: 20));
    manager.state.setPlaying(true);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.cast));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Living Room'));
    await tester.pump();
    expect(manager.transport, ['pause'], reason: 'the phone hands off');
    manager.state.setPlaying(false);
    await tester.pumpAndSettle();
    expect(find.text('Casting to Google Cast'), findsOneWidget);

    cast.remoteStateNotifier.value = 'playing';
    cast.remotePositionNotifier.value = 60 * 10000000;
    await tester.pump();
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(cast.calls, ['pause']);

    cast.remoteStateNotifier.value = 'paused';
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pump();
    expect(cast.calls, ['pause', 'play']);

    await tester.tapAt(const Offset(700, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(700, 300));
    await tester.pump();
    expect(cast.calls.last, 'seek 90s', reason: 'skips start from the cast');

    cast.activeKindNotifier.value = null;
    await tester.pumpAndSettle();
    expect(find.text('Casting to Google Cast'), findsNothing);
    expect(manager.hasTransportInterceptor, isFalse);

    await tester.pumpWidget(const SizedBox());
  });

  // Issue #1305: off TV the transport sits where the paused description card
  // goes, so the card waits for the controls, which still hide while paused.
  group('play buttons', () {
    double playButtonY(WidgetTester tester) =>
        tester.getCenter(find.byIcon(Icons.play_arrow_rounded)).dy;

    testWidgets('sit in the middle of the video by default', (tester) async {
      await mountPlayer(tester);
      final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(playButtonY(tester), closeTo(height / 2, height * 0.1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('dock into the bottom bar when set to', (tester) async {
      await GetIt.instance<UserPreferences>().set(
        UserPreferences.playerTransportPosition,
        PlayerTransportPosition.docked,
      );
      await mountPlayer(tester);
      final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(playButtonY(tester), greaterThan(height * 0.75));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('paused description card', () {
    Future<void> pumpPlayer(WidgetTester tester) async {
      await GetIt.instance<UserPreferences>().set(
        UserPreferences.showDescriptionOnPause,
        true,
      );
      manager.queueService.setQueue([
        {'Name': 'Movie', 'Overview': 'A quiet story.'},
      ]);
      manager.bringup = const PlaybackBringupState(
        phase: PlaybackBringupPhase.ready,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: const VideoPlayerScreen(),
        ),
      );
      await tester.pump();
    await revealControls(tester);
    }

    double cardOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.text('A quiet story.'),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;

    testWidgets('waits for the controls to hide', (tester) async {
      await pumpPlayer(tester);
      expect(find.byType(Slider), findsOneWidget);
      expect(cardOpacity(tester), 0);

      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(Slider), findsNothing);
      expect(cardOpacity(tester), 1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows a couple of seconds after a pause', (tester) async {
      await pumpPlayer(tester);
      manager.state.setPlaying(true);
      await tester.pump();
      await tester.pump();
      manager.state.setPlaying(false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.byType(Slider), findsNothing);
      expect(cardOpacity(tester), 1);

      await tester.pumpWidget(const SizedBox());
    });
  });

  // Issue #1305: with the controls hidden, a keyboard seek only shows how far
  // it went.
  testWidgets('arrow keys seek without bringing the controls up', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const VideoPlayerScreen(),
      ),
    );
    manager.state.setPlaying(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(Slider), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.byType(Slider), findsNothing);
    expect(find.text('30 seconds'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('30 seconds'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  // Issue #1335: S, or Enter while the skip button shows, skips the intro.
  for (final key in [LogicalKeyboardKey.keyS, LogicalKeyboardKey.enter]) {
    testWidgets('${key.keyLabel} skips the intro on offer', (tester) async {
      client.items.segments = [
        segmentJson(id: 'intro', type: 'Intro', startMs: 0, endMs: 90000),
      ];
      manager.queueService.setQueue([
        AggregatedItem(
          id: 'ep1',
          serverId: 'server',
          rawData: const {'Id': 'ep1', 'Type': 'Episode'},
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: const VideoPlayerScreen(),
        ),
      );
      manager.state.setPlaying(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(Slider), findsNothing);

      manager.state.setPosition(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Skip'), findsOneWidget);

      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(manager.seeks, [const Duration(seconds: 90)]);
      expect(manager.transport, isEmpty);

      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
