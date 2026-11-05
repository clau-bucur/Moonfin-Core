import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/models/home_row.dart';
import 'package:moonfin/data/repositories/multi_server_repository.dart';
import 'package:moonfin/data/services/home_row_cache_store.dart';
import 'package:moonfin/data/services/plugin_sync_service.dart';
import 'package:moonfin/data/services/row_data_source.dart';
import 'package:moonfin/data/viewmodels/media_bar_view_model.dart';
import 'package:moonfin/preference/home_section_config.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/preference/seerr_preferences.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/home/home_view_model.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements MediaServerClient {}

class _DataSource extends Mock implements RowDataSource {}

class _MediaBar extends Mock implements MediaBarViewModel {}

class _MultiServer extends Mock implements MultiServerRepository {}

class _PluginSync extends Mock implements PluginSyncService {}

class _SeerrPrefs extends Mock implements SeerrPreferences {}

class _Cache extends Fake implements HomeRowCacheStore {
  _Cache(this.cached);

  final List<HomeRow>? cached;

  @override
  Future<List<HomeRow>?> read(String cacheKey) async => cached;

  @override
  Future<void> write(String cacheKey, List<HomeRow> rows) async {}
}

HomeSectionConfig collection(int n) => HomeSectionConfig.pluginDynamic(
  serverId: 'http://server',
  pluginSection: 'collection',
  pluginAdditionalData: 'c$n',
  pluginDisplayText: 'Collection $n',
  order: n,
);

HomeSectionConfig genre(int order) => HomeSectionConfig.pluginDynamic(
  serverId: 'http://server',
  pluginSection: 'genre',
  pluginAdditionalData: 'Drama',
  pluginDisplayText: 'Drama',
  order: order,
  pluginSource: HomeSectionPluginSource.genres,
);

HomeRow populated(String id) => HomeRow(
  id: id,
  title: id,
  rowType: HomeRowType.pluginDynamic,
  items: [
    AggregatedItem(id: '$id-item', serverId: 'server', rawData: {'Name': id}),
  ],
);

// Issue #1233: a Home of many collections loads the rows near the screen,
// not every row up front, and Seerr signing in doesn't reload all of them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sectionCount = 12;
  late UserPreferences prefs;
  late _DataSource source;
  late List<String> loaded;
  Completer<void>? gate;

  setUpAll(() => registerFallbackValue(HomeSectionPluginSource.collections));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);
    await prefs.setHomeSectionsConfig([
      for (final cfg in HomeSectionConfig.defaults())
        cfg.copyWith(enabled: false),
      for (var n = 0; n < sectionCount; n++) collection(n),
      genre(sectionCount),
    ]);
    await prefs.set(UserPreferences.displayCollectionsRows, true);
    await prefs.set(UserPreferences.displayGenresRows, false);
    await prefs.set(UserPreferences.enableMultiServerLibraries, false);
    await prefs.set(
      UserPreferences.lastExternalRowsRefreshTime,
      DateTime.now().millisecondsSinceEpoch,
    );

    final pluginSync = _PluginSync();
    when(() => pluginSync.seerrAvailable).thenReturn(false);
    when(() => pluginSync.pluginAvailable).thenReturn(false);
    GetIt.instance.registerSingleton<PluginSyncService>(pluginSync);
    GetIt.instance.registerSingleton<SeerrPreferences>(_SeerrPrefs());

    loaded = [];
    gate = null;
    source = _DataSource();
    when(
      () => source.loadDynamicSection(
        rowId: any(named: 'rowId'),
        section: any(named: 'section'),
        title: any(named: 'title'),
        serverId: any(named: 'serverId'),
        additionalData: any(named: 'additionalData'),
        pluginSource: any(named: 'pluginSource'),
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((invocation) async {
      final id = invocation.namedArguments[#rowId] as String;
      loaded.add(id);
      await gate?.future;
      return populated(id);
    });
  });

  tearDown(() => GetIt.instance.reset());

  HomeViewModel model({List<HomeRow>? cached}) {
    final client = _Client();
    when(() => client.userId).thenReturn('user');
    when(() => client.baseUrl).thenReturn('http://server');
    final mediaBar = _MediaBar();
    when(() => mediaBar.load(force: any(named: 'force')))
        .thenAnswer((_) async {});
    final vm = HomeViewModel(
      dataSource: source,
      prefs: prefs,
      client: client,
      mediaBarViewModel: mediaBar,
      multiServerRepo: _MultiServer(),
      cacheStore: _Cache(cached),
    );
    addTearDown(vm.dispose);
    return vm;
  }

  String idOf(int n) => collection(n).stableId;

  test('loads the first sections and leaves the rest for later', () async {
    final vm = model();
    await vm.load();

    expect(loaded, [for (var n = 0; n < 3; n++) idOf(n)]);
    expect(vm.rows, hasLength(sectionCount));
    expect(vm.rows.skip(3).every((row) => row.isLoading), isTrue);
    expect(vm.hasDeferredSections, isTrue);
  });

  test('loads a deferred section once its row comes near', () async {
    final vm = model();
    await vm.load();
    loaded.clear();

    vm.loadSectionsNear(vm.rows.sublist(7, 10));
    vm.loadSectionsNear(vm.rows.sublist(9, 10));
    await pumpEventQueue();

    expect(loaded, [idOf(7), idOf(8), idOf(9)]);
    expect(vm.rows[9].isLoading, isFalse);
    expect(vm.rows[10].isLoading, isTrue);
  });

  test(
    'built-in rows below the first screen also wait for the viewport',
    () async {
      await prefs.setHomeSectionsConfig([
        for (final cfg in HomeSectionConfig.defaults())
          cfg.copyWith(enabled: false),
        for (var n = 0; n < 3; n++) collection(n),
        const HomeSectionConfig(type: HomeSectionType.genres, order: 3),
      ]);
      await prefs.set(UserPreferences.displayGenresRows, true);
      when(
        () => source.loadGenres(
          'http://server',
          sortBy: any(named: 'sortBy'),
          sortOrder: any(named: 'sortOrder'),
          includeItemTypes: any(named: 'includeItemTypes'),
        ),
      ).thenAnswer(
        (_) async => populated('genres').copyWith(rowType: HomeRowType.genres),
      );
      final vm = model();
      await vm.load();

      expect(vm.rows.last.id, 'genres');
      expect(vm.rows.last.isLoading, isTrue);
      verifyNever(
        () => source.loadGenres(
          'http://server',
          sortBy: any(named: 'sortBy'),
          sortOrder: any(named: 'sortOrder'),
          includeItemTypes: any(named: 'includeItemTypes'),
        ),
      );

      vm.loadSectionsNear([vm.rows.last]);
      await pumpEventQueue();
      expect(vm.rows.last.id, 'genres');
      expect(vm.rows.last.isLoading, isFalse);
    },
  );

  test('repeated viewport changes share three deferred fetch slots', () async {
    final vm = model();
    await vm.load();
    loaded.clear();
    gate = Completer<void>();

    vm.loadSectionsNear(vm.rows.sublist(3, 7));
    vm.loadSectionsNear(vm.rows.sublist(7, 11));
    await pumpEventQueue();
    expect(loaded, [idOf(3), idOf(4), idOf(5)]);

    gate!.complete();
    await pumpEventQueue();
    expect(loaded, [for (var n = 3; n < 11; n++) idOf(n)]);
    expect(vm.rows.sublist(3, 11).every((row) => !row.isLoading), isTrue);
  });

  test(
    'hidden Home retains queued sections without starting requests',
    () async {
      final vm = model();
      await vm.load();
      loaded.clear();
      vm.setDeferredSectionsPaused(true);
      vm.loadSectionsNear(vm.rows.sublist(3, 7));
      await pumpEventQueue();
      expect(loaded, isEmpty);

      vm.setDeferredSectionsPaused(false);
      await pumpEventQueue();
      expect(loaded, [for (var n = 3; n < 7; n++) idOf(n)]);
    },
  );

  test(
    'hiding Home stops queued requests after in-flight requests finish',
    () async {
      final vm = model();
      await vm.load();
      loaded.clear();
      gate = Completer<void>();
      vm.loadSectionsNear(vm.rows.sublist(3, 10));
      await pumpEventQueue();
      vm.setDeferredSectionsPaused(true);
      gate!.complete();
      await pumpEventQueue();
      expect(loaded, [idOf(3), idOf(4), idOf(5)]);

      vm.setDeferredSectionsPaused(false);
      await pumpEventQueue();
      expect(loaded, [for (var n = 3; n < 10; n++) idOf(n)]);
    },
  );

  test(
    'a stale deferred response cannot replace a freshly reloaded section',
    () async {
      final oldResponse = Completer<HomeRow>();
      var requests = 0;
      when(
        () => source.loadDynamicSection(
          rowId: idOf(4),
          section: any(named: 'section'),
          title: any(named: 'title'),
          serverId: any(named: 'serverId'),
          additionalData: any(named: 'additionalData'),
          pluginSource: any(named: 'pluginSource'),
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) {
        requests++;
        return requests == 1
            ? oldResponse.future
            : Future.value(populated(idOf(4)).copyWith(title: 'Fresh'));
      });
      final vm = model();
      await vm.load();
      vm.loadSectionsNear([vm.rows[4]]);
      await pumpEventQueue();

      // Reordering makes this same stable section part of the initial screen.
      await prefs.setHomeSectionsConfig([
        for (final cfg in HomeSectionConfig.defaults())
          cfg.copyWith(enabled: false),
        collection(4).copyWith(order: -1),
        for (var n = 0; n < sectionCount; n++)
          if (n != 4) collection(n),
      ]);
      await vm.refresh();
      expect(vm.rows.firstWhere((row) => row.id == idOf(4)).title, 'Fresh');

      oldResponse.complete(populated(idOf(4)).copyWith(title: 'Stale'));
      await pumpEventQueue();
      expect(vm.rows.firstWhere((row) => row.id == idOf(4)).title, 'Fresh');
    },
  );

  test(
    'a previously empty deferred row remains reachable after refresh',
    () async {
      var empty = true;
      when(
        () => source.loadDynamicSection(
          rowId: idOf(4),
          section: any(named: 'section'),
          title: any(named: 'title'),
          serverId: any(named: 'serverId'),
          additionalData: any(named: 'additionalData'),
          pluginSource: any(named: 'pluginSource'),
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer(
        (_) async => empty
            ? populated(idOf(4)).copyWith(items: const [])
            : populated(idOf(4)),
      );
      final vm = model();
      await vm.load();
      vm.loadSectionsNear([vm.rows.firstWhere((row) => row.id == idOf(4))]);
      await pumpEventQueue();
      expect(vm.rows.any((row) => row.id == idOf(4)), isFalse);

      empty = false;
      await vm.refresh();
      final placeholder = vm.rows.firstWhere((row) => row.id == idOf(4));
      expect(placeholder.isLoading, isTrue);
      vm.loadSectionsNear([placeholder]);
      await pumpEventQueue();
      expect(vm.rows.firstWhere((row) => row.id == idOf(4)).isLoading, isFalse);
    },
  );

  test('a deferred section missing from the cache stays on screen', () async {
    final vm = model(cached: [for (var n = 0; n < 8; n++) populated(idOf(n))]);
    await vm.load();

    expect(vm.rows, hasLength(sectionCount));
    expect(vm.rows.last.id, idOf(sectionCount - 1));
  });

  test('a new sections reload loads only what Home has no rows for', () async {
    final vm = model();
    await vm.load();
    loaded.clear();

    await prefs.set(UserPreferences.displayGenresRows, true);
    await vm.refresh(newSectionsOnly: true);

    expect(loaded, [genre(sectionCount).stableId]);
    expect(vm.rows.last.id, genre(sectionCount).stableId);
    expect(vm.rows, hasLength(sectionCount + 1));
  });

  test(
    'a new sections request during a load waits and stays partial',
    () async {
      final vm = model();
      gate = Completer<void>();
      final first = vm.load();
      await pumpEventQueue();
      await prefs.set(UserPreferences.displayGenresRows, true);
      unawaited(vm.refresh(newSectionsOnly: true));
      gate!.complete();
      await first;

      expect(loaded.where((id) => id == idOf(0)), hasLength(1));
      expect(loaded.last, genre(sectionCount).stableId);
    },
  );

  test('a full request during a load wins over a new sections one', () async {
    final vm = model();
    gate = Completer<void>();
    final first = vm.load();
    await pumpEventQueue();
    unawaited(vm.refresh(newSectionsOnly: true));
    unawaited(vm.refresh());
    gate!.complete();
    await first;

    expect(loaded.where((id) => id == idOf(0)), hasLength(2));
  });

  test('the parsed layout follows the saved one and stays read only', () async {
    expect(() => prefs.homeSectionsConfig.clear(), throwsUnsupportedError);

    await prefs.setHomeSectionsConfig([collection(0)]);
    expect(
      prefs.homeSectionsConfig
          .where((c) => c.isPluginDynamic)
          .map((c) => c.stableId),
      [idOf(0)],
    );
  });
}
