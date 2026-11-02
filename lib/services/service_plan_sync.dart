import 'dart:convert';
import 'dart:math';

typedef SyncDocument = Map<String, Object?>;

String newSyncId() =>
    'sync-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}';

String syncFingerprint(Object? value) {
  if (value is List) return '[${value.map(syncFingerprint).join(',')}]';
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${syncFingerprint(value[key])}').join(',')}}';
  }
  return jsonEncode(value);
}

void validateSyncDocument(SyncDocument doc) {
  final id = doc['id'],
      title = doc['title'],
      date = doc['date'],
      notes = doc['notes'],
      items = doc['items'];
  if (doc['schemaVersion'] != 1 ||
      id is! String ||
      id.isEmpty ||
      id.length > 200 ||
      title is! String ||
      title.length > 150 ||
      date is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
      notes is! String ||
      notes.length > 10000 ||
      items is! List ||
      items.length > 100) {
    throw const FormatException('Invalid cloud service plan');
  }
  final ids = <String>{};
  for (final value in items) {
    if (value is! Map) {
      throw const FormatException('Invalid cloud service entry');
    }
    final id = value['id'],
        type = value['type'],
        title = value['title'],
        notes = value['notes'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 200 ||
        !ids.add(id) ||
        !['song', 'section'].contains(type) ||
        title is! String ||
        title.length > 300 ||
        notes is! String ||
        notes.length > 10000) {
      throw const FormatException('Invalid cloud service entry');
    }
    if (type == 'song') {
      final songId = value['songId'], key = value['key'];
      if (songId is! String ||
          songId.isEmpty ||
          songId.length > 200 ||
          (key != null &&
              (key is! String ||
                  !RegExp(r'^[A-G](?:#|b)?m?$').hasMatch(key)))) {
        throw const FormatException('Invalid cloud song reference');
      }
    }
  }
}

class CloudPlanRow {
  const CloudPlanRow({
    required this.id,
    required this.revision,
    required this.document,
    this.deleted = false,
  });
  final String id;
  final int revision;
  final SyncDocument document;
  final bool deleted;
  factory CloudPlanRow.fromJson(Map<String, dynamic> json) => CloudPlanRow(
    id: json['id'] as String,
    revision: (json['revision'] as num).toInt(),
    document: Map<String, Object?>.from(json['document'] as Map),
    deleted: json['deleted'] as bool,
  );
}

class CloudSyncConflict implements Exception {
  const CloudSyncConflict();
}

abstract interface class CloudPlanRemote {
  Future<List<CloudPlanRow>> list();
  Future<CloudPlanRow> save(
    String id,
    int revision,
    SyncDocument? document,
    bool deleted,
  );
}

abstract interface class CloudPlanLocal {
  List<SyncDocument> read();
  Future<void> apply(List<SyncDocument> upserts, List<String> deletes);
}

abstract interface class CloudSyncMetadata {
  Map<String, Map<String, Object?>> read();
  Future<void> write(Map<String, Map<String, Object?>> value);
}

/// Optimistic revisions prevent one device from silently replacing another.
/// Baselines are acknowledged only after the server commits a write.
class ServicePlanSync {
  ServicePlanSync({
    required this.remote,
    required this.local,
    required this.metadata,
    this.onStatus,
    this.idFactory = newSyncId,
  });
  final CloudPlanRemote remote;
  final CloudPlanLocal local;
  final CloudSyncMetadata metadata;
  final void Function(String state, int conflicts)? onStatus;
  final String Function() idFactory;
  Future<void>? _running;
  bool _again = false, _stopped = false;
  Future<void> stop() async {
    _stopped = true;
    try {
      await _running;
    } on Object {
      /* Pending changes remain local. */
    }
  }

  Future<void> sync() {
    if (_stopped) return Future.value();
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _run().whenComplete(() => _running = null);
  }

  Future<void> _run() async {
    var passes = 0;
    do {
      if (++passes > 4) {
        onStatus?.call('pending', 0);
        throw StateError('Sync is busy. Local edits are preserved.');
      }
      _again = false;
      try {
        await _pass();
      } on Object {
        onStatus?.call('pending', 0);
        rethrow;
      }
    } while (_again && !_stopped);
  }

  Future<void> _pass() async {
    onStatus?.call('syncing', 0);
    final rows = await remote.list();
    if (_stopped) return;
    final cloud = {for (final row in rows) row.id: row};
    final bases = metadata.read();
    final ids = {
      ...local.read().map((doc) => doc['id'] as String),
      ...bases.keys,
      ...cloud.keys,
    };
    var conflicts = 0;
    for (final id in ids) {
      if (_stopped) return;
      final doc = local.read().where((doc) => doc['id'] == id).firstOrNull;
      if (doc != null) validateSyncDocument(doc);
      final row = cloud[id], base = bases[id];
      final localPrint = doc == null ? null : syncFingerprint(doc);
      final dirty = base == null
          ? doc != null
          : localPrint != base['fingerprint'];
      final sameRevision = (row?.revision ?? 0) == (base?['revision'] ?? 0);
      final remotePrint = row == null || row.deleted
          ? null
          : syncFingerprint(row.document);
      Future<void> acknowledge(CloudPlanRow saved) async {
        bases[id] = {
          'revision': saved.revision,
          'fingerprint': saved.deleted ? null : syncFingerprint(saved.document),
        };
        await metadata.write(bases);
      }

      if (!dirty) {
        if (row != null) {
          if (!row.deleted) validateSyncDocument(row.document);
          if (localPrint != remotePrint) {
            await local.apply(
              row.deleted ? [] : [row.document],
              row.deleted ? [id] : [],
            );
          }
          await acknowledge(row);
        }
        continue;
      }
      if (row != null && localPrint == remotePrint) {
        await acknowledge(row);
        continue;
      }
      if (!sameRevision) {
        if (row == null && base != null) {
          throw StateError(
            'Cloud plan unavailable; the local copy is preserved',
          );
        }
        final upserts = <SyncDocument>[];
        if (doc != null) {
          upserts.add({
            ...doc,
            'id': idFactory(),
            'title':
                '${(doc['title'] as String).substring(0, min(130, (doc['title'] as String).length))} (local copy)',
          });
          _again = true;
        }
        if (row != null && !row.deleted) {
          validateSyncDocument(row.document);
          upserts.add(row.document);
        }
        await local.apply(upserts, row?.deleted == true ? [id] : []);
        if (row != null) await acknowledge(row);
        conflicts++;
        continue;
      }
      try {
        final snapshot = doc == null
            ? null
            : Map<String, Object?>.from(jsonDecode(jsonEncode(doc)) as Map);
        final saved = await remote.save(
          id,
          (base?['revision'] as num?)?.toInt() ?? 0,
          snapshot,
          doc == null,
        );
        if (_stopped) return;
        await acknowledge(saved);
        if (syncFingerprint(
              local.read().where((doc) => doc['id'] == id).firstOrNull,
            ) !=
            syncFingerprint(snapshot)) {
          _again = true;
        }
      } on CloudSyncConflict {
        _again = true;
      }
    }
    onStatus?.call('synced', conflicts);
  }
}
