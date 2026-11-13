import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/media_bar_slide_item.dart';
import 'package:moonfin/data/models/media_bar_state.dart';
import 'package:moonfin/data/repositories/mdblist_repository.dart';
import 'package:moonfin/data/repositories/media_bar_repository.dart';
import 'package:moonfin/data/services/plugin_sync_service.dart';
import 'package:moonfin/data/viewmodels/media_bar_view_model.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends Mock implements MediaBarRepository {}

class _MdbList extends Mock implements MdbListRepository {}

class _Client extends Mock implements MediaServerClient {}

class _Sync extends ChangeNotifier implements PluginSyncService {
  bool available = false;

  @override
  bool get pluginAvailable => available;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late UserPreferences prefs;
  late _Repository repository;
  late _Sync sync;
  late _MdbList mdbList;
  late List<Completer<MediaBarState>> loads;

  setUpAll(() => registerFallbackValue(<MediaBarSlideItem>[]));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);
    sync = _Sync();
    GetIt.instance.registerSingleton<PluginSyncService>(sync);
    loads = [];
    repository = _Repository();
    mdbList = _MdbList();
    when(() => repository.loadItems()).thenAnswer((_) {
      final load = Completer<MediaBarState>();
      loads.add(load);
      return load.future;
    });
    when(
      () => repository.loadNewReleases(any()),
    ).thenAnswer((_) async => const {});
  });

  tearDown(() => GetIt.instance.reset());

  MediaBarViewModel create() =>
      MediaBarViewModel(repository, mdbList, prefs, _Client());

  const slides = [
    MediaBarSlideItem(
      itemId: 'first',
      serverId: 'server',
      title: 'First',
      tmdbId: '1',
    ),
    MediaBarSlideItem(
      itemId: 'second',
      serverId: 'server',
      title: 'Second',
      tmdbId: '2',
    ),
  ];

  test(
    'loading slides waits for a selected slide before fetching ratings',
    () async {
      await prefs.set(UserPreferences.mediaBarEnableAdditionalRatings, true);
      final viewModel = create();
      addTearDown(viewModel.dispose);
      final loading = viewModel.load();
      loads.single.complete(const MediaBarReady(slides));
      await loading;

      verifyZeroInteractions(mdbList);
      when(
        () => mdbList.resolveTmdbId(
          itemId: 'second',
          serverId: null,
          knownTmdbId: '2',
        ),
      ).thenAnswer((_) async => '2');
      final ratings = Completer<Map<String, double>?>();
      when(() => mdbList.getRatings(tmdbId: '2', mediaType: 'Movie'))
          .thenAnswer((_) => ratings.future);
      final selected = viewModel.ensureRatings('second');
      await pumpEventQueue();
      await viewModel.ensureRatings('second');
      ratings.complete({'imdb': 8.5});
      await selected;
      await viewModel.ensureRatings('second');

      verify(() => mdbList.getRatings(tmdbId: '2', mediaType: 'Movie'))
          .called(1);
      expect(viewModel.ratingsFor('second'), {'imdb': 8.5});
      expect(viewModel.ratingsFor('first'), isEmpty);
    },
  );

  test(
    'an old selected-slide ratings response cannot update a new load',
    () async {
      await prefs.set(UserPreferences.mediaBarEnableAdditionalRatings, true);
      final viewModel = create();
      addTearDown(viewModel.dispose);
      final loading = viewModel.load();
      loads.single.complete(const MediaBarReady(slides));
      await loading;
      when(
        () => mdbList.resolveTmdbId(
          itemId: 'first',
          serverId: null,
          knownTmdbId: '1',
        ),
      ).thenAnswer((_) async => '1');
      final ratings = Completer<Map<String, double>?>();
      when(() => mdbList.getRatings(tmdbId: '1', mediaType: 'Movie'))
          .thenAnswer((_) => ratings.future);
      final selected = viewModel.ensureRatings('first');
      await pumpEventQueue();
      final reload = viewModel.load(force: true);
      loads.last.complete(MediaBarReady([slides[1]]));
      await reload;
      ratings.complete({'imdb': 8.5});
      await selected;

      expect(viewModel.ratingsFor('first'), isEmpty);
    },
  );

  test('a source change made during a load runs once that load ends', () async {
    final viewModel = create();
    unawaited(viewModel.load());
    await prefs.set(UserPreferences.mediaBarLibraryIds, 'lib');
    expect(loads, hasLength(1));

    loads.first.complete(const MediaBarDisabled());
    await pumpEventQueue();

    expect(loads, hasLength(2));
  });

  test('the bar shows before its new release labels, which follow', () async {
    const series = MediaBarSlideItem(
      itemId: 'series',
      serverId: 'server',
      title: 'Show',
      itemType: 'Series',
    );
    const movie = MediaBarSlideItem(
      itemId: 'movie',
      serverId: 'server',
      title: 'Film',
    );
    final labels = Completer<Map<String, MediaBarNewReleaseInfo>>();
    when(
      () => repository.loadNewReleases(any()),
    ).thenAnswer((_) => labels.future);
    final viewModel = create();
    unawaited(viewModel.load());
    loads.first.complete(const MediaBarReady([series, movie]));
    await pumpEventQueue();

    expect(viewModel.state, isA<MediaBarReady>());
    expect(viewModel.items.map((item) => item.newRelease), [null, null]);

    labels.complete({
      'series': const MediaBarNewReleaseInfo(
        kind: MediaBarNewRelease.newSeason,
        season: 2,
      ),
    });
    await pumpEventQueue();

    expect(viewModel.items.first.newRelease?.kind, MediaBarNewRelease.newSeason);
    expect(viewModel.items.last.newRelease, isNull);
    viewModel.dispose();
  });

  test('picked lists load again once Moonbase answers', () async {
    await prefs.set(
      UserPreferences.mediaBarExternalLists,
      'imdb_top_250_movies',
    );
    final viewModel = create();
    unawaited(viewModel.load());
    loads.first.complete(const MediaBarDisabled());
    await pumpEventQueue();

    sync
      ..available = true
      ..notifyListeners();
    await pumpEventQueue();

    expect(loads, hasLength(2));
    viewModel.dispose();
  });

  test('seeding hideWatchedInRecentRows reloads the media bar when changed', () async {
    final viewModel = create();
    unawaited(viewModel.load());
    loads.first.complete(const MediaBarReady([]));
    await pumpEventQueue();
    expect(loads, hasLength(1));

    prefs.seedHideWatchedFromServer(const UserConfiguration(hidePlayedInLatest: true));
    await pumpEventQueue();

    expect(loads, hasLength(2));
    viewModel.dispose();
  });
}
