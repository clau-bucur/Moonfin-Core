import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/repositories/item_mutation_repository.dart';
import 'package:moonfin/data/repositories/mdblist_repository.dart';
import 'package:moonfin/data/repositories/tmdb_repository.dart';
import 'package:moonfin/data/services/row_data_source.dart';
import 'package:moonfin/data/services/plugin_sync_service.dart';
import 'package:moonfin/data/viewmodels/item_detail_view_model.dart';
import 'package:moonfin/auth/repositories/user_repository.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/preference/seerr_preferences.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/auth/repositories/session_repository.dart';
import 'package:moonfin/ui/screens/detail/stage/stage_detail_content.dart';
import 'package:moonfin/ui/screens/detail/stage/stage_track_chips.dart';
import 'package:moonfin/ui/screens/detail/item_detail_screen.dart';
import 'package:moonfin/ui/widgets/focus/focusable_button.dart';
import 'package:moonfin/ui/navigation/focus_route_observer.dart';
import 'package:moonfin/util/platform_detection.dart';
import 'package:moonfin/ui/screens/detail/modern/modern_detail_content.dart';
import 'package:moonfin/ui/theme/app_theme.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:playback_core/playback_core.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements MediaServerClient {}

class _ItemsApi extends Mock implements ItemsApi {}

class _UserLibraryApi extends Mock implements UserLibraryApi {}

class _ImageApi extends Mock implements ImageApi {}

class _PluginSync extends Mock implements PluginSyncService {}

class _SessionRepository extends Mock implements SessionRepository {}

class _PlaybackManager extends Mock implements PlaybackManager {}

class _QueueService extends Mock implements QueueService {}

Future<UserPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({});
  final store = PreferenceStore();
  await store.init();
  return UserPreferences(store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Client client;
  late _ItemsApi itemsApi;
  late UserPreferences prefs;

  setUp(() async {
    PlatformDetection.setTvMode(true);
    await GetIt.instance.reset();
    client = _Client();
    itemsApi = _ItemsApi();
    prefs = await _preferences();
    final userLibrary = _UserLibraryApi();
    when(() => userLibrary.supportsNumericUserRatings).thenReturn(false);

    final plugin = _PluginSync();
    when(() => plugin.seerrAvailable).thenReturn(false);
    when(() => plugin.pluginAvailable).thenReturn(false);
    GetIt.instance.registerSingleton<PluginSyncService>(plugin);
    GetIt.instance.registerSingleton<UserPreferences>(prefs);
    GetIt.instance.registerSingleton<UserRepository>(UserRepository());
    GetIt.instance.registerSingleton<PlaybackManager>(_PlaybackManager());
    final playback = GetIt.instance<PlaybackManager>();
    when(() => playback.queueService).thenReturn(_QueueService());
    final seerrStore = PreferenceStore();
    await seerrStore.init();
    GetIt.instance.registerSingleton<SeerrPreferences>(
      SeerrPreferences(seerrStore, _SessionRepository()),
    );

    when(() => client.itemsApi).thenReturn(itemsApi);
    when(() => client.userLibraryApi).thenReturn(userLibrary);
    final imageApi = _ImageApi();
    when(
      () => imageApi.getPrimaryImageUrl(
        any(),
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        tag: any(named: 'tag'),
      ),
    ).thenReturn('http://test-server/primary');
    when(
      () => imageApi.getLogoImageUrl(
        any(),
        maxWidth: any(named: 'maxWidth'),
        tag: any(named: 'tag'),
      ),
    ).thenReturn('http://test-server/logo');
    when(
      () => imageApi.getBackdropImageUrl(
        any(),
        maxWidth: any(named: 'maxWidth'),
        index: any(named: 'index'),
        tag: any(named: 'tag'),
      ),
    ).thenReturn('http://test-server/backdrop');
    when(() => client.imageApi).thenReturn(imageApi);
    when(() => client.baseUrl).thenReturn('http://test-server');
    when(() => client.serverType).thenReturn(ServerType.jellyfin);
    GetIt.instance.registerSingleton<RowDataSource>(RowDataSource(client));
    GetIt.instance.registerSingleton<MediaServerClient>(client);
  });

  tearDown(() async {
    PlatformDetection.setTvMode(false);
    await GetIt.instance.reset();
  });

  Map<String, dynamic> itemData(String type) => {
    'Id': 'item-1',
    'Name': '$type title',
    'Type': type,
    'Overview': 'A useful detail overview',
    'ProviderIds': const {},
  };

  ItemDetailViewModel viewModel(String type, {Map<String, dynamic>? data}) {
    final vm = ItemDetailViewModel(
      itemId: 'item-1',
      client: client,
      mutations: ItemMutationRepository(client),
      mdbListRepository: MdbListRepository(client, TmdbRepository(client)),
      tmdbRepository: TmdbRepository(client),
    );
    final raw = data ?? itemData(type);
    when(() => itemsApi.getItem('item-1')).thenAnswer((_) async => raw);
    when(
      () => itemsApi.getItem(
        'item-1',
        mediaSourceId: any(named: 'mediaSourceId'),
      ),
    ).thenAnswer((_) async => raw);
    return vm;
  }

  Future<void> pumpContent(
    WidgetTester tester,
    ItemDetailViewModel vm, {
    Size size = const Size(1920, 1080),
  }) async {
    // The surface as well as the MediaQuery. A faked MediaQuery alone steers
    // which layout the screen picks but leaves it laying out against the
    // default view, so anything sized from its own constraints gets measured
    // at a size no test asked for.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final playFocus = FocusNode();
    addTearDown(playFocus.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await vm.load();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          navigatorObservers: [FocusRouteObserver()],
          theme: AppTheme.buildTheme(ThemeRegistry.active),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // The detail screen rebuilds this whenever either one changes.
            body: ListenableBuilder(
              listenable: Listenable.merge([vm, prefs]),
              builder: (context, _) => StageDetailContent(
                viewModel: vm,
                prefs: prefs,
                backdropUrl: ValueNotifier<String?>(null),
                selectedMediaSourceId: null,
                initialFocusNode: playFocus,
                onSelectedMediaSourceChanged: (_) {},
                actionsExpanded: false,
                onActionsExpandedChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Map<String, dynamic> movieWithTracks() {
    const streams = [
      {'Type': 'Video', 'Index': 0, 'Codec': 'hevc'},
      {
        'Type': 'Audio',
        'Index': 1,
        'DisplayTitle': 'English TrueHD 7.1',
        'Language': 'eng',
        'IsDefault': true,
      },
      {
        'Type': 'Audio',
        'Index': 2,
        'DisplayTitle': 'Spanish EAC3 5.1',
        'Language': 'spa',
      },
      {
        'Type': 'Subtitle',
        'Index': 3,
        'DisplayTitle': 'English SDH',
        'Language': 'eng',
      },
    ];
    return {
      ...itemData('Movie'),
      'MediaStreams': streams,
      'MediaSources': [
        {'Id': 'source-1', 'Name': '4K', 'MediaStreams': streams},
      ],
    };
  }

  testWidgets('a movie leads with its poster', (tester) async {
    final vm = viewModel('Movie', data: movieWithTracks());
    await pumpContent(tester, vm);

    expect(find.byKey(const ValueKey('stage-poster')), findsOneWidget);
    expect(find.text('Movie title'), findsOneWidget);
  });

  testWidgets('a movie with tracks to pick between shows them as chips', (
    tester,
  ) async {
    final vm = viewModel('Movie', data: movieWithTracks());
    await pumpContent(tester, vm);
    await tester.pump();

    expect(find.byType(StageTrackChips), findsOneWidget);
    expect(find.text('English TrueHD 7.1'), findsOneWidget);
  });

  testWidgets('remote reaches Version and returns through every track chip', (
    tester,
  ) async {
    final raw = movieWithTracks();
    (raw['MediaSources'] as List).add({'Id': 'source-2', 'Name': '1080p'});
    await pumpContent(tester, viewModel('Movie', data: raw));
    await tester.pumpAndSettle();
    final chips = tester
        .widgetList<FocusableButton>(
          find.descendant(
            of: find.byType(StageTrackChips),
            matching: find.byType(FocusableButton),
          ),
        )
        .toList();
    expect(chips, hasLength(3));
    chips.first.focusNode!.requestFocus();
    await tester.pump();
    for (var i = 1; i < chips.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(chips[i].focusNode!.hasPrimaryFocus, isTrue);
    }
    for (var i = chips.length - 2; i >= 0; i--) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(chips[i].focusNode!.hasPrimaryFocus, isTrue);
    }
    chips.last.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Select Version'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(chips.last.focusNode!.hasPrimaryFocus, isTrue);
  });

  testWidgets('Up from first actor returns to visible More, not Directors', (
    tester,
  ) async {
    final raw = movieWithTracks();
    raw['People'] = [
      {'Id': 'actor-1', 'Name': 'First actor', 'Type': 'Actor'},
      {'Id': 'director-1', 'Name': 'Director', 'Type': 'Director'},
    ];
    await pumpContent(
      tester,
      viewModel('Movie', data: raw),
      size: const Size(1280, 720),
    );
    await tester.pumpAndSettle();
    final actions = tester.widget<DetailActionButtons>(
      find.byType(DetailActionButtons),
    );
    final more = actions.actionRowRightFocusNode!;
    more.requestFocus();
    await tester.pumpAndSettle();
    expect(more.hasPrimaryFocus, isTrue);
    final moreBox = more.context!.findRenderObject() as RenderBox;
    expect(
      moreBox.localToGlobal(Offset.zero).dy + moreBox.size.height,
      lessThanOrEqualTo(720),
    );
    final cast = tester.widget<DetailCastRow>(find.byType(DetailCastRow));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(cast.firstItemFocusNode!.hasPrimaryFocus, isTrue);
    final actorBox =
        cast.firstItemFocusNode!.context!.findRenderObject() as RenderBox;
    expect(
      actorBox.localToGlobal(Offset.zero).dy + actorBox.size.height,
      lessThanOrEqualTo(720),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(more.hasPrimaryFocus, isTrue);
    final box = more.context!.findRenderObject() as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    expect(top, greaterThanOrEqualTo(0));
    expect(top + box.size.height, lessThanOrEqualTo(720));
  });

  testWidgets('hiding the Audio button hides its chip too', (tester) async {
    for (final hidden in [
      UserPreferences.hiddenDetailButtonsTv,
      UserPreferences.hiddenDetailButtonsMobile,
      UserPreferences.hiddenDetailButtonsDesktop,
    ]) {
      await prefs.set(hidden, 'audio');
    }
    final vm = viewModel('Movie', data: movieWithTracks());
    await pumpContent(tester, vm);
    await tester.pump();

    // The subtitle chip stays, since only Audio was hidden.
    expect(find.text('English TrueHD 7.1'), findsNothing);
    expect(find.text('English SDH'), findsOneWidget);
  });

  testWidgets('a movie with one audio track and no subtitles has no chips', (
    tester,
  ) async {
    final vm = viewModel('Movie');
    await pumpContent(tester, vm);
    await tester.pump();

    expect(find.byType(StageTrackChips), findsNothing);
  });

  testWidgets('a playlist goes to Modern', (tester) async {
    final vm = viewModel('Playlist');
    await pumpContent(tester, vm);

    expect(find.byType(ModernDetailContent), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-poster')), findsNothing);
  });
}
