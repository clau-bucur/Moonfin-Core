import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/util/media_source_selection.dart';

Map<String, dynamic> _source(
  String id, {
  Object width = 3840,
  Object height = 2160,
  String range = 'SDR',
  Object bitrate = 20000000,
  Map<String, dynamic> videoFields = const {},
}) => {
  'Id': id,
  'Bitrate': bitrate,
  'MediaStreams': [
    {
      'Type': 'Video',
      'Width': width,
      'Height': height,
      'VideoRangeType': range,
      ...videoFields,
    },
  ],
};

AggregatedItem _movie(
  List<Map<String, dynamic>> sources, {
  String id = 'film',
}) => AggregatedItem(
  id: id,
  serverId: 'server',
  rawData: {'Id': id, 'Type': 'Movie', 'MediaSources': sources},
);

void main() {
  final versions = [
    _source('1080-sdr', width: 1920, height: 1080),
    _source('4k-sdr'),
    _source('4k-hdr10', range: 'HDR10'),
    _source('4k-hlg', range: 'HLG'),
    _source('4k-hdr10plus', range: 'HDR10Plus'),
    _source('4k-dovi', range: 'DOVI'),
  ];

  String? pick(
    List<Map<String, dynamic>> sources, {
    Size? resolution = const Size(3840, 2160),
    List<String> hdr = const [],
  }) => bestMediaSourceForDisplay(
    sources,
    displayResolution: resolution,
    displayHdrTypes: hdr,
  )?['Id']?.toString();

  group('bestMediaSourceForDisplay', () {
    test('matches each display HDR format independently', () {
      expect(pick(versions), '4k-sdr');
      expect(pick(versions, hdr: ['HDR10']), '4k-hdr10');
      expect(pick(versions, hdr: ['HLG']), '4k-hlg');
      expect(pick(versions, hdr: ['HDR10_PLUS']), '4k-hdr10plus');
      expect(pick(versions, hdr: ['DOLBY_VISION']), '4k-dovi');
      expect(
        pick(versions, hdr: ['HDR10', 'HDR10_PLUS', 'DOLBY_VISION']),
        '4k-dovi',
      );
    });

    test('a 1080p HDR display does not select a 4K HDR source', () {
      expect(
        pick(
          [
            ...versions,
            _source('1080-hdr', width: 1920, height: 1080, range: 'HDR10'),
          ],
          resolution: const Size(1920, 1080),
          hdr: ['HDR10', 'DOLBY_VISION'],
        ),
        '1080-hdr',
      );
      expect(
        pick(
          versions,
          resolution: const Size(1920, 1080),
          hdr: ['DOLBY_VISION'],
        ),
        '1080-sdr',
      );
    });

    test('chooses the highest fitting resolution before HDR and bitrate', () {
      expect(
        pick(
          [
            _source(
              '1080-dovi',
              width: 1920,
              height: 1080,
              range: 'DOVI',
              bitrate: 90000000,
            ),
            _source('4k-sdr'),
          ],
          hdr: ['DOLBY_VISION'],
        ),
        '4k-sdr',
      );
      final sources = [
        _source('4k'),
        _source('1080', width: 1920, height: 1080),
        _source('720', width: 1280, height: 720),
        _source('480', width: 720, height: 480),
      ];
      expect(pick(sources, resolution: const Size(1280, 720)), '720');
      expect(pick(sources, resolution: const Size(720, 480)), '480');
      expect(pick(sources, resolution: const Size(2560, 1440)), '1080');
    });

    test('SDR wins over unsupported HDR even at a lower resolution', () {
      expect(pick([versions.last, versions.first]), '1080-sdr');
      expect(pick([versions.last, versions[2]], hdr: ['HDR10']), '4k-hdr10');
      expect(pick([versions[4], versions[2]], hdr: ['HDR10']), '4k-hdr10');
    });

    test(
      'recognizes Emby ranges, Dolby profiles, and combined range types',
      () {
        final sources = [
          _source('sdr'),
          _source(
            'emby-hdr',
            range: '',
            videoFields: {'ExtendedVideoType': 'HDR 10'},
          ),
          _source(
            'emby-dovi',
            range: '',
            videoFields: {'ExtendedVideoType': 'DolbyVision'},
          ),
          _source('combined', range: 'DOVIWithHDR10Plus'),
        ];
        expect(pick(sources, hdr: ['HDR10']), 'emby-hdr');
        expect(pick(sources, hdr: [' dolby_vision ']), 'emby-dovi');
        final profileOnly = _source(
          'profile',
          range: '',
          videoFields: {'DoviProfile': '8'},
        );
        expect(pick([profileOnly, sources.first]), 'sdr');
        expect(
          pick([sources.first, profileOnly], hdr: ['DOLBY_VISION']),
          'profile',
        );
      final codecOnly = _source(
        'codec-tag',
        range: '',
        videoFields: {'CodecTagString': 'dvh1'},
      );
      expect(pick([codecOnly, sources.first]), 'sdr');
      expect(
        pick([sources.first, codecOnly], hdr: ['DOLBY_VISION']),
        'codec-tag',
      );
      },
    );

    test('recognizes cropped and DCI 4K sources on a UHD panel', () {
      expect(
        pick([
          versions.first,
          _source(
            'cropped',
            width: '3840',
            height: '1608',
            bitrate: '50000000',
          ),
          _source('8k', width: 7680, height: 4320),
        ]),
        'cropped',
      );
      expect(pick([versions.first, _source('dci', width: 4096)]), 'dci');
      expect(
        pick([
          versions[1],
          _source('8k', width: 7680, height: 4320),
        ], resolution: const Size(7680, 4320)),
        '8k',
      );
    });

    test(
      'uses bitrate to break equivalent quality ties and keeps stable ties',
      () {
        final low = _source('low');
        final high = _source('high', bitrate: 40000000);
        expect(pick([low, high]), 'high');
        expect(pick([high, _source('tie', bitrate: 40000000)]), 'high');
        expect(
          pick([
            low,
            _source(
              'stream-bitrate',
              bitrate: 0,
              videoFields: {'BitRate': 50000000},
            ),
          ]),
          'stream-bitrate',
        );
      },
    );

    test(
      'chooses the smallest excess when every version is above the display',
      () {
        expect(
          pick([versions[1], versions[0]], resolution: const Size(1280, 720)),
          '1080-sdr',
        );
      },
    );

    test('handles unknown, invalid and absent metadata without reordering', () {
      final unknown = <String, dynamic>{'Id': 'unknown'};
      expect(pick([]), isNull);
      expect(pick([unknown]), 'unknown');
      expect(
        pick([
          unknown,
          {'Id': 'other'},
        ]),
        'unknown',
      );
      expect(pick([unknown, versions[1]]), '4k-sdr');
      expect(pick([versions[1]], resolution: null), '4k-sdr');
      expect(
        pick([_source('invalid', width: -1, height: double.nan), versions[1]]),
        '4k-sdr',
      );
      expect(
        pick([
          {'MediaStreams': versions.last['MediaStreams']},
          versions.first,
        ]),
        '1080-sdr',
      );
    });
  });

  group('MediaSourceSelection', () {
    test(
      'improves the automatic choice when capabilities or sources arrive',
      () {
        final selection = MediaSourceSelection();
        selection.update(
          _movie([
            {'Id': 'placeholder'},
          ]),
          displayResolution: null,
          displayHdrTypes: [],
        );
        expect(selection.selectedId, 'placeholder');
        selection.update(
          _movie(versions),
          displayResolution: const Size(1920, 1080),
          displayHdrTypes: [],
        );
        expect(selection.selectedId, '1080-sdr');
        selection.update(
          _movie(versions),
          displayResolution: const Size(3840, 2160),
          displayHdrTypes: ['DOLBY_VISION'],
        );
        expect(selection.selectedId, '4k-dovi');
      },
    );

    test('preserves a manual choice through refreshes and display changes', () {
      final selection = MediaSourceSelection();
      selection.update(
        _movie(versions),
        displayResolution: const Size(3840, 2160),
        displayHdrTypes: ['DOLBY_VISION'],
      );
      selection.select('1080-sdr');
      selection.update(
        _movie(versions.reversed.toList()),
        displayResolution: const Size(7680, 4320),
        displayHdrTypes: ['DOLBY_VISION', 'HDR10_PLUS'],
      );
      expect(selection.selectedId, '1080-sdr');
    });

    test(
      'chooses again if the selected source disappears or the item changes',
      () {
        final selection = MediaSourceSelection();
        selection.update(
          _movie(versions),
          displayResolution: const Size(3840, 2160),
          displayHdrTypes: [],
        );
        selection.select('1080-sdr');
        selection.update(
          _movie([versions[1]]),
          displayResolution: const Size(3840, 2160),
          displayHdrTypes: [],
        );
        expect(selection.selectedId, '4k-sdr');
        selection.select('1080-sdr');
        selection.update(
          _movie(versions, id: 'another'),
          displayResolution: const Size(3840, 2160),
          displayHdrTypes: ['DOLBY_VISION'],
        );
        expect(selection.selectedId, '4k-dovi');
      },
    );
  });
}
