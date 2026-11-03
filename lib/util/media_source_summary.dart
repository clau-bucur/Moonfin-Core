import '../data/utils/video_range_label.dart';

num? _positiveMediaNumber(Object? value) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  return number != null && number.isFinite && number > 0 ? number : null;
}

/// Familiar resolution tiers, including films cropped below a tier's height.
String? videoResolutionFromStreams(List<Map<String, dynamic>> streams) {
  final video = streams.where((s) => s['Type'] == 'Video').firstOrNull;
  if (video == null) return null;
  final width = _positiveMediaNumber(video['Width']);
  final height = _positiveMediaNumber(video['Height']);
  if (width == null || height == null) return null;
  final suffix = video['IsInterlaced'] == true ? 'i' : 'p';
  if (width >= 7600 || height >= 4300) return '8K';
  if (width >= 3800 || height >= 2000) return '4K';
  if (width >= 2500 || height >= 1400) return '1440$suffix';
  if (width >= 1800 || height >= 1000) return '1080$suffix';
  if (width >= 1200 || height >= 700) return '720$suffix';
  if (width >= 600 || height >= 400) return '480$suffix';
  return 'SD';
}

/// A compact version label from this source's metadata, never its filename.
/// Missing properties are omitted rather than borrowed from another version.
String mediaSourceVersionLabel(
  Map<String, dynamic> source, {
  required String fallback,
}) {
  final streams = mediaSourceStreams(source);
  final video = streams.where((s) => s['Type'] == 'Video').firstOrNull;
  final resolution = videoResolutionFromStreams(streams);
  final bitrate =
      _positiveMediaNumber(source['Bitrate']) ??
      _positiveMediaNumber(video?['BitRate'] ?? video?['Bitrate']);
  String? range;
  if (video != null) {
    final rawRange =
        [
          video['VideoRangeType'],
          video['ExtendedVideoType'],
          video['VideoRange'],
        ].whereType<String>().firstWhere(
          (v) => v.trim().isNotEmpty,
          orElse: () => '',
        );
    if (rawRange.isNotEmpty) {
      final label = videoRangeLabel(video);
      final token = rawRange.toUpperCase().replaceAll(RegExp(r'[\s_-]'), '');
      if (label != 'SDR' ||
          const {'SDR', 'NONE', 'STANDARDDYNAMICRANGE'}.contains(token)) {
        range = label == 'Dolby Vision' ? 'DoVi' : label;
      }
    }
    if (range == null &&
        _positiveMediaNumber(
              video['DoviProfile'] ?? video['DolbyVisionProfile'],
            ) !=
            null) {
      range = 'DoVi';
    }
  }
  final parts = <String>[
    ?resolution,
    if (bitrate != null)
      '${(bitrate / 1000000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')} Mbps',
    ?range,
  ];
  return parts.isEmpty ? fallback : parts.join(' · ');
}

/// The source's streams as typed maps, or none when the server sent none.
List<Map<String, dynamic>> mediaSourceStreams(
  Map<String, dynamic> mediaSource,
) =>
    (mediaSource['MediaStreams'] as List?)
        ?.whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList() ??
    const [];

/// Whole megabytes up to 999, then gigabytes to two places. Null when the
/// server sent no size.
String? formatMediaSourceSize(int bytes) {
  if (bytes <= 0) return null;
  final mb = bytes / (1024 * 1024);
  if (mb > 999) return '${(mb / 1024).toStringAsFixed(2)} GB';
  return '${mb.toStringAsFixed(0)} MB';
}

/// Codec with its profile, resolution, frame rate, bit depth and range, in
/// that order, skipping what the stream lacks.
List<String> videoStreamSummary(
  Map<String, dynamic> video, {
  required String unknownCodec,
}) {
  final codec = video['Codec']?.toString().toUpperCase() ?? unknownCodec;
  final profile = video['Profile']?.toString();
  final width = video['Width']?.toString();
  final height = video['Height']?.toString();
  final frameRate = video['RealFrameRate'] ?? video['AverageFrameRate'];
  final bitDepth = video['BitDepth'] as int?;
  final videoRange = video['VideoRange']?.toString();
  final videoRangeType = video['VideoRangeType']?.toString();

  final details = <String>[
    profile != null && profile.isNotEmpty ? '$codec ($profile)' : codec,
  ];
  if (width != null && height != null) details.add('$width x $height');
  final fps = frameRate == null ? null : double.tryParse(frameRate.toString());
  if (fps != null) details.add('${fps.toStringAsFixed(3)} fps');
  if (bitDepth != null) details.add('$bitDepth-bit');
  if (videoRange != null && videoRange.isNotEmpty) {
    details.add(
      videoRangeType != null && videoRangeType.isNotEmpty
          ? '$videoRange ($videoRangeType)'
          : videoRange,
    );
  }
  return details;
}

/// A stream's language code in upper case, or [unknown] without one.
String streamLanguageLabel(String? code, {required String unknown}) =>
    code == null || code.isEmpty ? unknown : code.toUpperCase();
