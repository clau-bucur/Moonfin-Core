import '../data/models/aggregated_item.dart';

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
