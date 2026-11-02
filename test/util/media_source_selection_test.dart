import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/util/media_source_selection.dart';

/// Shaped like the server responses for a movie with a 1080p and a 720p
/// version. Jellyfin's source Id is the version's own item id. Emby
/// prefixes it and names the item in ItemId. The top level MediaStreams are
/// the item's own file, which on Emby isn't its default first source.
Map<String, dynamic> _source(
  String id, {
  String? itemId,
  required String container,
  required int size,
  required int subtitleIndex,
}) => {
  'Id': id,
  'ItemId': ?itemId,
  'Container': container,
  'Size': size,
  'MediaStreams': [
    {'Type': 'Video', 'Index': 0},
    {'Type': 'Subtitle', 'Index': subtitleIndex},
  ],
};

AggregatedItem _movie(
  String id,
  List<Map<String, dynamic>> sources, {
  int ownSource = 0,
}) => AggregatedItem(
  id: id,
  serverId: 's1',
  rawData: {
    'Id': id,
    'Name': 'Version Test',
    'Type': 'Movie',
    'MediaSources': sources,
    'MediaStreams': sources[ownSource]['MediaStreams'],
  },
);

final _jellyfin = _movie('jf1080', [
  _source('jf1080', container: 'mp4', size: 55122, subtitleIndex: 2),
  _source('jf720', container: 'webm', size: 7785066, subtitleIndex: 3),
]);

final _emby = _movie('23', [
  _source(
    'mediasource_24',
    itemId: '24',
    container: 'webm',
    size: 7785066,
    subtitleIndex: 3,
  ),
  _source(
    'mediasource_23',
    itemId: '23',
    container: 'mp4',
    size: 55122,
    subtitleIndex: 2,
  ),
], ownSource: 1);

int _subtitleIndex(AggregatedItem item) =>
    item.mediaStreams.firstWhere((s) => s['Type'] == 'Subtitle')['Index']
        as int;

void main() {
  group('withPreferredMediaSource', () {
    test('moves the picked version to the front', () {
      final picked = withPreferredMediaSource(_jellyfin, 'jf720');

      expect(picked.mediaSources.map((s) => s['Id']), ['jf720', 'jf1080']);
      expect(picked.id, 'jf1080');
      expect(picked.serverId, 's1');
    });

    test('size and the top level streams follow the picked version', () {
      final picked = withPreferredMediaSource(_jellyfin, 'jf720');

      expect(
        picked.mediaSources.first['Size'],
        7785066,
      );
      expect(_subtitleIndex(picked), 3);
    });

    test('an Emby default pick takes its streams from the first source', () {
      final picked = withPreferredMediaSource(_emby, 'mediasource_24');

      expect(picked.mediaSources.map((s) => s['Id']), [
        'mediasource_24',
        'mediasource_23',
      ]);
      expect(_subtitleIndex(_emby), 2);
      expect(_subtitleIndex(picked), 3);
    });

    test('leaves the item alone for a single source or an unknown id', () {
      final single = _movie('solo', [
        _source('solo', container: 'mkv', size: 1, subtitleIndex: 2),
      ]);

      expect(
        identical(withPreferredMediaSource(single, 'solo'), single),
        isTrue,
      );
      expect(
        identical(withPreferredMediaSource(_jellyfin, 'missing'), _jellyfin),
        isTrue,
      );
      expect(
        identical(withPreferredMediaSource(_jellyfin, null), _jellyfin),
        isTrue,
      );
    });

    test("doesn't change the original item", () {
      withPreferredMediaSource(_emby, 'mediasource_23');

      expect(_emby.mediaSources.first['Id'], 'mediasource_24');
    });
  });


}
