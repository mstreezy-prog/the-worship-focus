import '../models/service_plan.dart';
import '../models/song.dart';
import 'service_plan_sync.dart';

class CloudPlanCodec {
  static SyncDocument encode(
    ServicePlan plan,
    List<Song> songs,
    Map<String, String> songIds,
  ) {
    final byId = {for (final song in songs) song.id: song};
    final date = plan.date;
    final doc = <String, Object?>{
      'schemaVersion': 1,
      'id': plan.cloudPlanId ?? plan.id,
      'title': plan.title,
      'date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'notes': plan.notes,
      'items': [
        for (final item in plan.items)
          if (item.isSection)
            {
              'id': item.id,
              'type': 'section',
              'title': item.title,
              'notes': item.notes,
            }
          else
            {
              ...item.cloudData,
              'id': item.id,
              'type': 'song',
              'songId':
                  item.cloudSongId ??
                  songIds.putIfAbsent(item.songId!, newSyncId),
              'title': item.title.isNotEmpty
                  ? item.title
                  : (byId[item.songId]?.title ?? 'Song unavailable'),
              'key': item.planningKey ?? byId[item.songId]?.key,
              'notes': item.notes,
              if (!item.cloudData.containsKey('bpm'))
                'bpm': byId[item.songId]?.tempo,
            },
      ],
    };
    validateSyncDocument(doc);
    return doc;
  }

  static (ServicePlan, List<Song>) decode(
    SyncDocument doc,
    String churchId,
    List<Song> songs, {
    String? localPlanId,
    Map<String, String> linkedSongs = const {},
  }) {
    validateSyncDocument(doc);
    final added = <Song>[];
    final items = <ServicePlanItem>[];
    for (final value in doc['items'] as List) {
      final item = Map<String, Object?>.from(value as Map);
      if (item['type'] == 'section') {
        items.add(
          ServicePlanItem.section(
            id: item['id'] as String,
            title: item['title'] as String,
            notes: item['notes'] as String,
          ),
        );
        continue;
      }
      final cloudSongId = item['songId'] as String;
      final localId = linkedSongs[cloudSongId] ?? 'cloud-song:$cloudSongId';
      if (!songs.any((song) => song.id == localId) &&
          !added.any((song) => song.id == localId)) {
        final title = item['title'] as String;
        final cleanTitle = title.replaceAll(RegExp(r'[{}\r\n]'), ' ');
        added.add(
          Song(
            id: localId,
            title: title,
            key: item['key'] as String?,
            tempo: (item['bpm'] as num?)?.toInt(),
            chordPro:
                '{title: $cleanTitle}\n{comment: Synced service reference. Link your local chart in the service plan, or add your arrangement here.}',
          ),
        );
      }
      final metadata = Map<String, Object?>.from(item)
        ..removeWhere(
          (key, _) =>
              ['id', 'type', 'songId', 'title', 'key', 'notes'].contains(key),
        );
      items.add(
        ServicePlanItem.song(
          id: item['id'] as String,
          songId: localId,
          title: item['title'] as String,
          notes: item['notes'] as String,
          planningKey: item['key'] as String?,
          cloudSongId: cloudSongId,
          cloudData: metadata,
        ),
      );
    }
    return (
      ServicePlan(
        id: localPlanId ?? 'cloud:$churchId:${doc['id']}',
        cloudPlanId: doc['id'] as String,
        title: doc['title'] as String,
        date: DateTime.parse(doc['date'] as String),
        notes: doc['notes'] as String,
        cloudChurchId: churchId,
        items: items,
      ),
      added,
    );
  }
}
