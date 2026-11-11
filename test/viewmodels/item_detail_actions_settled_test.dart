import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/repositories/item_mutation_repository.dart';
import 'package:moonfin/data/repositories/mdblist_repository.dart';
import 'package:moonfin/data/repositories/tmdb_repository.dart';
import 'package:moonfin/data/services/plugin_sync_service.dart';
import 'package:moonfin/data/services/user_data_sync.dart';
import 'package:moonfin/data/viewmodels/item_detail_view_model.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements MediaServerClient {}

class _ItemsApi extends Mock implements ItemsApi {}

class _PluginSyncService extends Mock implements PluginSyncService {}

void main() {
  late _Client client;
  late _ItemsApi itemsApi;

  setUp(() async {
    await GetIt.instance.reset();
    userDataSync.reset();
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
    final pluginSync = _PluginSyncService();
    when(() => pluginSync.seerrAvailable).thenReturn(false);
    GetIt.instance.registerSingleton<PluginSyncService>(pluginSync);

    client = _Client();
    itemsApi = _ItemsApi();
    when(() => client.itemsApi).thenReturn(itemsApi);
    when(() => client.baseUrl).thenReturn('http://server');
    when(
      () => itemsApi.getItem(
        'series-1',
        mediaSourceId: any(named: 'mediaSourceId'),
      ),
    ).thenAnswer((_) async => {'Id': 'series-1', 'Type': 'Series'});
  });

  tearDown(() async {
    userDataSync.reset();
    await GetIt.instance.reset();
  });

  void answerNextUp(Future<Map<String, dynamic>> Function() answer) {
    when(
      () => itemsApi.getNextUp(
        seriesId: 'series-1',
        limit: 1,
        fields: any(named: 'fields'),
      ),
    ).thenAnswer((_) => answer());
  }

  ItemDetailViewModel createSeries() {
    final vm = ItemDetailViewModel(
      itemId: 'series-1',
      client: client,
      mutations: ItemMutationRepository(client),
      mdbListRepository: MdbListRepository(client, TmdbRepository(client)),
      tmdbRepository: TmdbRepository(client),
    );
    addTearDown(vm.dispose);
    return vm;
  }

  test(
    'primary Next Up stays loading until its playback choice arrives',
    () async {
      final nextUp = Completer<Map<String, dynamic>>();
      answerNextUp(() => nextUp.future);
      final vm = createSeries();
      final loading = vm.load();
      await pumpEventQueue();
      await Future<void>.delayed(
        ItemDetailViewModel.actionsWaitCap + const Duration(milliseconds: 100),
      );
      expect(vm.state, ItemDetailState.loading);
      expect(vm.actionsSettled, isFalse);
      nextUp.complete({'Items': <dynamic>[]});
      await loading;
      await pumpEventQueue();
      expect(vm.state, ItemDetailState.ready);
      expect(vm.actionsSettled, isTrue);
    },
  );

  test(
    'a series waits for its seasons before publishing its actions',
    () async {
      answerNextUp(() async => {'Items': <dynamic>[]});
      final seasons = Completer<Map<String, dynamic>>();
      when(() => itemsApi.getSeasons('series-1', fields: any(named: 'fields')))
          .thenAnswer((_) => seasons.future);
      final vm = createSeries();
      final loading = vm.load();
      await pumpEventQueue();
      expect(vm.state, ItemDetailState.loading);
      expect(vm.actionsSettled, isFalse);
      seasons.complete({'Items': <dynamic>[]});
      await loading;
      await pumpEventQueue();
      expect(vm.state, ItemDetailState.ready);
      expect(vm.actionsSettled, isTrue);
    },
  );

  test(
    'optional action inputs stop holding the row after the wait cap',
    () async {
      answerNextUp(() async => {'Items': <dynamic>[]});
      final features = Completer<List<Map<String, dynamic>>>();
      when(() => itemsApi.getSpecialFeatures('series-1'))
          .thenAnswer((_) => features.future);
      final vm = createSeries();
      final loading = vm.load();
      await pumpEventQueue();
      expect(vm.state, ItemDetailState.ready);
      expect(vm.actionsSettled, isFalse);
      await Future<void>.delayed(
        ItemDetailViewModel.actionsWaitCap + const Duration(milliseconds: 100),
      );
      expect(vm.actionsSettled, isTrue);
      features.complete([]);
      await loading;
    },
  );
}
