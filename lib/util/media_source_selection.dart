import 'dart:ui';

import '../data/models/aggregated_item.dart';
import '../data/utils/video_range_label.dart';
import '../playback/hdr_stream_capability.dart';
import 'media_source_summary.dart';

/// The highest resolution the display can use, then its best supported range,
/// then bitrate. Unsupported HDR formats lose to a compatible SDR version.
/// Ties preserve the server's ordering, and missing metadata stays unknown.
Map<String, dynamic>? bestMediaSourceForDisplay(
  List<Map<String, dynamic>> sources, {
  required Size? displayResolution,
  required Iterable<String> displayHdrTypes,
}) {
  final hdrTypes = displayHdrTypes.map((s) => s.trim().toUpperCase()).toSet();
  final displayTier = displayResolution == null
      ? null
      : _resolutionTier(
          displayResolution.longestSide,
          displayResolution.shortestSide,
        );
  Map<String, dynamic>? best;
  List<num>? bestRank;
  for (final source in sources) {
    if (source['Id'] == null || source['Id'].toString().isEmpty) continue;
    final video = mediaSourceStreams(source)
        .where((s) => s['Type']?.toString().toUpperCase() == 'VIDEO')
        .firstOrNull;
    final width = _positiveNumber(video?['Width']);
    final height = _positiveNumber(video?['Height']);
    final tier = width == null || height == null
        ? null
        : _resolutionTier(width, height);
    final range = video == null ? -1 : _supportedRangeRank(video, hdrTypes);
    final fits = tier != null && (displayTier == null || tier <= displayTier);
    final rank = <num>[
      if (range >= 0) 1 else 0,
      if (fits) 2 else if (tier == null) 1 else 0,
      if (tier != null) (fits ? tier : -tier) else 0,
      range,
      if (video == null)
        0
      else
        _positiveNumber(source['Bitrate'] ?? source['BitRate']) ??
            _positiveNumber(video['BitRate'] ?? video['Bitrate']) ??
            0,
    ];
    if (bestRank == null || _compareRanks(rank, bestRank) > 0) {
      best = source;
      bestRank = rank;
    }
  }
  return best ?? sources.firstOrNull;
}

int _supportedRangeRank(Map<String, dynamic> video, Set<String> hdrTypes) {
  final hasDoviProfile =
      _positiveNumber(video['DoviProfile'] ?? video['DolbyVisionProfile']) !=
      null;
  final range =
      hasDoviProfile || HdrStreamCapability.isDolbyVisionVideoStream(video)
      ? 'Dolby Vision'
      : HdrStreamCapability.isHdr10PlusVideoStream(video)
      ? 'HDR10+'
      : videoRangeLabel(video);
  return switch (range) {
    'Dolby Vision' => hdrTypes.contains('DOLBY_VISION') ? 4 : -1,
    'HDR10+' => hdrTypes.contains('HDR10_PLUS') ? 3 : -1,
    'HDR10' || 'HDR' =>
      hdrTypes.contains('HDR10') || hdrTypes.contains('HDR10_PLUS') ? 2 : -1,
    'HLG' => hdrTypes.contains('HLG') ? 2 : -1,
    _ => 0,
  };
}

// Match the familiar tiers used by version labels, including cropped films
// and DCI 4K files on a UHD panel.
int _resolutionTier(num width, num height) {
  if (width >= 7600 || height >= 4300) return 4320;
  if (width >= 3800 || height >= 2000) return 2160;
  if (width >= 2500 || height >= 1400) return 1440;
  if (width >= 1800 || height >= 1000) return 1080;
  if (width >= 1200 || height >= 700) return 720;
  if (width >= 600 || height >= 400) return 480;
  return height.toInt();
}

num? _positiveNumber(Object? value) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  return number != null && number.isFinite && number > 0 ? number : null;
}

int _compareRanks(List<num> a, List<num> b) {
  for (var i = 0; i < a.length; i++) {
    final comparison = a[i].compareTo(b[i]);
    if (comparison != 0) return comparison;
  }
  return 0;
}

/// Keeps an explicit version choice through metadata refreshes and display
/// changes. Automatic choices can improve as the server probes more sources.
class MediaSourceSelection {
  String? _itemId;
  String? _serverId;
  String? _selectedId;
  bool _manual = false;

  String? get selectedId => _selectedId;

  void select(String? id) {
    _selectedId = id;
    _manual = true;
  }

  void update(
    AggregatedItem item, {
    required Size? displayResolution,
    required Iterable<String> displayHdrTypes,
  }) {
    if (_itemId != item.id || _serverId != item.serverId) {
      _itemId = item.id;
      _serverId = item.serverId;
      _manual = false;
    }
    if (_manual &&
        item.mediaSources.any((s) => s['Id']?.toString() == _selectedId)) {
      return;
    }
    _manual = false;
    _selectedId = bestMediaSourceForDisplay(
      item.mediaSources,
      displayResolution: displayResolution,
      displayHdrTypes: displayHdrTypes,
    )?['Id']?.toString();
  }
}

AggregatedItem withPreferredMediaSource(
  AggregatedItem item,
  String? mediaSourceId,
) {
  final sources = item.mediaSources;
  if (mediaSourceId == null || sources.length < 2) return item;
  final index = sources.indexWhere(
    (source) => source['Id']?.toString() == mediaSourceId,
  );
  if (index < 0) return item;
  final picked = sources[index];
  return AggregatedItem(
    id: item.id,
    serverId: item.serverId,
    rawData: {
      ...item.rawData,
      'MediaSources': [
        picked,
        ...sources.take(index),
        ...sources.skip(index + 1),
      ],
      if (picked['MediaStreams'] is List)
        'MediaStreams': picked['MediaStreams'],
    },
  );
}
