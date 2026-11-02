// Network-free verification. Run directly with Dart; no Flutter setup required.
// Relative imports intentionally avoid requiring Flutter package resolution.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';

import '../lib/services/service_plan_sync.dart';
import '../lib/models/service_plan.dart';

SyncDocument document([String id = 'plan', String title = 'Sunday Worship']) =>
    {
      'schemaVersion': 1,
      'id': id,
      'title': title,
      'date': '2026-11-01',
      'notes': 'Read Psalm 95',
      'items': [
        {
          'id': 'entry',
          'type': 'song',
          'songId': 'behold-god',
          'title': 'Behold Our God',
          'key': 'D',
          'notes': '',
        },
      ],
    };
T clone<T>(T value) => jsonDecode(jsonEncode(value)) as T;
void check(bool condition, String description) {
  if (!condition) throw StateError(description);
}

class Metadata implements CloudSyncMetadata {
  Map<String, Map<String, Object?>> values = {};
  @override
  Map<String, Map<String, Object?>> read() => {
    for (final entry in values.entries)
      entry.key: Map<String, Object?>.from(entry.value),
  };
  @override
  Future<void> write(Map<String, Map<String, Object?>> value) async {
    values = readCopy(value);
  }

  Map<String, Map<String, Object?>> readCopy(
    Map<String, Map<String, Object?>> source,
  ) => {
    for (final entry in source.entries)
      entry.key: Map<String, Object?>.from(entry.value),
  };
}

class Fixture implements CloudPlanLocal, CloudPlanRemote {
  Fixture(this.docs) {
    engine = ServicePlanSync(
      remote: this,
      local: this,
      metadata: metadata,
      idFactory: () => 'copy-${docs.length}',
    );
  }
  List<SyncDocument> docs;
  final rows = <String, CloudPlanRow>{};
  final metadata = Metadata();
  late ServicePlanSync engine;
  bool offline = false;
  void Function()? beforeSave;
  @override
  List<SyncDocument> read() => docs
      .map(
        (doc) => Map<String, Object?>.from(jsonDecode(jsonEncode(doc)) as Map),
      )
      .toList();
  @override
  Future<void> apply(List<SyncDocument> upserts, List<String> deletes) async {
    docs = [
      ...docs.where(
        (doc) =>
            !deletes.contains(doc['id']) &&
            !upserts.any((next) => next['id'] == doc['id']),
      ),
      ...upserts.map(
        (doc) => Map<String, Object?>.from(jsonDecode(jsonEncode(doc)) as Map),
      ),
    ];
  }

  @override
  Future<List<CloudPlanRow>> list() async {
    if (offline) throw StateError('Offline');
    return rows.values.toList();
  }

  @override
  Future<CloudPlanRow> save(
    String id,
    int revision,
    SyncDocument? doc,
    bool deleted,
  ) async {
    if (offline) throw StateError('Offline');
    final action = beforeSave;
    beforeSave = null;
    action?.call();
    final old = rows[id];
    if ((old?.revision ?? 0) != revision) throw const CloudSyncConflict();
    final row = CloudPlanRow(
      id: id,
      revision: revision + 1,
      document: doc ?? old!.document,
      deleted: deleted,
    );
    rows[id] = row;
    return row;
  }
}

Future<void> run(String name, Future<void> Function() body) async {
  await body();
  stdout.writeln('PASS $name');
}

Future<void> main() async {
  await run('uploads new services', () async {
    final f = Fixture([document()]);
    await f.engine.sync();
    check(f.rows['plan']?.revision == 1, 'Plan not uploaded');
  });
  await run('downloads remote services', () async {
    final f = Fixture([]);
    f.rows['plan'] = CloudPlanRow(
      id: 'plan',
      revision: 1,
      document: document(),
    );
    await f.engine.sync();
    check(f.docs.length == 1, 'Plan not downloaded');
  });
  await run('offline edits remain pending and retry', () async {
    final f = Fixture([document()]);
    await f.engine.sync();
    f.docs[0]['notes'] = 'Offline edit';
    f.offline = true;
    try {
      await f.engine.sync();
    } on StateError {
      /* expected */
    }
    check(
      f.metadata.values['plan']!['fingerprint'] != syncFingerprint(f.docs[0]),
      'Unsent edit acknowledged',
    );
    f.offline = false;
    await f.engine.sync();
    check(
      f.rows['plan']?.document['notes'] == 'Offline edit',
      'Offline edit lost',
    );
  });
  await run('concurrent edits preserve both copies', () async {
    final f = Fixture([document()]);
    await f.engine.sync();
    f.docs[0]['title'] = 'Local';
    f.rows['plan'] = CloudPlanRow(
      id: 'plan',
      revision: 2,
      document: document('plan', 'Remote'),
    );
    await f.engine.sync();
    check(
      f.docs.any((doc) => doc['title'] == 'Local (local copy)'),
      'Local edit lost',
    );
    check(
      f.rows['plan']?.document['title'] == 'Remote',
      'Remote edit overwritten',
    );
    check(f.rows.length == 2, 'Copy not uploaded');
  });
  await run('edits while upload is in flight survive', () async {
    final f = Fixture([document()]);
    f.beforeSave = () => f.docs[0]['notes'] = 'In-flight edit';
    await f.engine.sync();
    check(
      f.rows['plan']?.document['notes'] == 'In-flight edit',
      'In-flight edit lost',
    );
  });
  await run('remote tombstones remove clean downloaded services', () async {
    final f = Fixture([document()]);
    await f.engine.sync();
    f.rows['plan'] = CloudPlanRow(
      id: 'plan',
      revision: 2,
      document: document(),
      deleted: true,
    );
    await f.engine.sync();
    check(f.docs.isEmpty, 'Deleted plan retained');
  });
  await run('stale writes retry without overwriting remote changes', () async {
    final f = Fixture([document()]);
    await f.engine.sync();
    f.docs[0]['notes'] = 'Local';
    f.beforeSave = () => f.rows['plan'] = CloudPlanRow(
      id: 'plan',
      revision: 2,
      document: {...document(), 'notes': 'Remote'},
    );
    await f.engine.sync();
    check(
      f.rows['plan']?.document['notes'] == 'Remote',
      'Remote edit overwritten',
    );
    check(f.rows.length == 2, 'Local edit not preserved');
  });
  await run(
    'model retains notes, planning keys and cloud references',
    () async {
      final original = ServicePlan(
        id: 'local',
        cloudPlanId: 'shared',
        cloudChurchId: 'church',
        title: 'Sunday',
        date: DateTime(2026, 11, 1),
        notes: 'Team note',
        items: const [
          ServicePlanItem.section(
            id: 'reading',
            title: 'Scripture',
            notes: 'Luke 2',
          ),
          ServicePlanItem.song(
            id: 'song',
            songId: 'local-chart',
            title: 'Behold Our God',
            planningKey: 'Eb',
            cloudSongId: 'behold-god',
            cloudData: {'sample': true},
            notes: 'Repeat chorus',
          ),
        ],
      );
      final restored = ServicePlan.fromJson(original.toJson());
      check(
        restored.cloudPlanId == 'shared' && restored.notes == 'Team note',
        'Plan metadata lost',
      );
      check(
        restored.items.last.planningKey == 'Eb' &&
            restored.items.last.cloudSongId == 'behold-god',
        'Song reference lost',
      );
      check(restored.items.first.isSection, 'Section lost');
    },
  );
  await run('invalid cloud entries are rejected', () async {
    var rejected = false;
    try {
      validateSyncDocument({
        ...document(),
        'items': [
          {'id': 'bad'},
        ],
      });
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'Invalid data accepted');
  });
  stdout.writeln('9 service-sync checks passed.');
}
