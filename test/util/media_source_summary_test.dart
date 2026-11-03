import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/media_source_summary.dart';

void main() {
  group('mediaSourceVersionLabel', () {
    test(
      'describes a cropped 4K Dolby Vision version without its filename',
      () {
        expect(
          mediaSourceVersionLabel({
            'Name': 'A.very.long.filename.2160p.REMUX.mkv',
            'Bitrate': 61600000,
            'MediaStreams': [
              {
                'Type': 'Video',
                'Width': 3840,
                'Height': 1600,
                'VideoRangeType': 'DOVI',
                'BitRate': 59000000,
              },
            ],
          }, fallback: 'Version 1'),
          '4K · 61.6 Mbps · DoVi',
        );
      },
    );

    test('uses Emby range metadata and recognizes cropped 1080p', () {
      expect(
        mediaSourceVersionLabel({
          'Bitrate': 17500000,
          'MediaStreams': [
            {
              'Type': 'Video',
              'Width': 1920,
              'Height': 800,
              'ExtendedVideoType': 'None',
            },
          ],
        }, fallback: 'Version 2'),
        '1080p · 17.5 Mbps · SDR',
      );
    });

    for (final (raw, label) in [
      ('HDR 10', 'HDR10'),
      ('Hdr10Plus', 'HDR10+'),
      ('HyperLogGamma', 'HLG'),
    ]) {
      test('normalizes $raw and numeric string metadata', () {
        expect(
          mediaSourceVersionLabel({
            'Bitrate': '6000000',
            'MediaStreams': [
              {
                'Type': 'Video',
                'Width': '1280',
                'Height': '720',
                'ExtendedVideoType': raw,
              },
            ],
          }, fallback: 'Version 1'),
          '720p · 6 Mbps · $label',
        );
      });
    }

    test('falls back to video bitrate and Dolby Vision profile', () {
      expect(
        mediaSourceVersionLabel({
          'Bitrate': 0,
          'MediaStreams': [
            {
              'Type': 'Video',
              'Width': 3840,
              'Height': 2160,
              'DoviProfile': 8,
              'BitRate': 24000000,
            },
          ],
        }, fallback: 'Version 1'),
        '4K · 24 Mbps · DoVi',
      );
    });

    test('omits unknown properties and never falls back to a filename', () {
      expect(
        mediaSourceVersionLabel({
          'Name': 'movie.filename.mkv',
        }, fallback: 'Version 2'),
        'Version 2',
      );
      expect(
        mediaSourceVersionLabel({
          'Bitrate': double.nan,
          'MediaStreams': [
            {'Type': 'Video', 'Width': -1},
          ],
        }, fallback: 'Version 3'),
        'Version 3',
      );
      expect(
        mediaSourceVersionLabel({'Bitrate': 10000000}, fallback: 'Version 1'),
        '10 Mbps',
      );
      expect(
        mediaSourceVersionLabel({
          'MediaStreams': [
            {
              'Type': 'Video',
              'Width': 1280,
              'Height': 720,
              'VideoRangeType': 'Unknown',
              'BitDepth': 10,
            },
          ],
        }, fallback: 'Version 1'),
        '720p',
      );
    });

    test('retains interlaced resolution and 8K tiers', () {
      expect(
        videoResolutionFromStreams([
          {
            'Type': 'Video',
            'Width': 1920,
            'Height': 1080,
            'IsInterlaced': true,
          },
        ]),
        '1080i',
      );
      expect(
        videoResolutionFromStreams([
          {'Type': 'Video', 'Width': 7680, 'Height': 4320},
        ]),
        '8K',
      );
    });
  });

  group('formatMediaSourceSize', () {
    test('prints whole megabytes below a gigabyte', () {
      expect(formatMediaSourceSize(734 * 1024 * 1024), '734 MB');
    });

    test('switches to gigabytes past 999 MB', () {
      expect(formatMediaSourceSize(5583457484), '5.20 GB');
    });

    test('has no answer for a missing size', () {
      expect(formatMediaSourceSize(0), isNull);
    });
  });

  group('videoStreamSummary', () {
    test('lists codec, resolution, frame rate, bit depth and range', () {
      expect(
        videoStreamSummary({
          'Codec': 'hevc',
          'Profile': 'Main 10',
          'Width': 3840,
          'Height': 2160,
          'RealFrameRate': 23.976,
          'BitDepth': 10,
          'VideoRange': 'HDR',
          'VideoRangeType': 'DOVI',
        }, unknownCodec: 'Unknown'),
        ['HEVC (Main 10)', '3840 x 2160', '23.976 fps', '10-bit', 'HDR (DOVI)'],
      );
    });

    test('skips what the stream lacks', () {
      expect(
        videoStreamSummary({
          'Width': 1920,
          'Height': 1080,
        }, unknownCodec: 'Unknown'),
        ['Unknown', '1920 x 1080'],
      );
    });
  });

  test('streamLanguageLabel upper cases a code and names a missing one', () {
    expect(streamLanguageLabel('eng', unknown: 'Unknown'), 'ENG');
    expect(streamLanguageLabel(null, unknown: 'Unknown'), 'Unknown');
    expect(streamLanguageLabel('', unknown: 'Unknown'), 'Unknown');
  });

  test('mediaSourceStreams types the server maps and tolerates none', () {
    expect(mediaSourceStreams({}), isEmpty);
    expect(
      mediaSourceStreams({
        'MediaStreams': [
          {'Type': 'Video'},
          'not a map',
        ],
      }),
      [
        {'Type': 'Video'},
      ],
    );
  });
}
