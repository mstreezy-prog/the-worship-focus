import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/library_backup.dart';
import 'package:worship_focus_studio/models/music_xml_arrangement.dart';
import 'package:worship_focus_studio/models/score_annotation.dart';
import 'package:worship_focus_studio/models/service_plan.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/services/library_backup_service.dart';

class _MemoryLibraryBackupGateway implements LibraryBackupGateway {
  SelectedLibraryBackupFile? selected;
  String? savedName;
  Uint8List? savedBytes;

  @override
  Future<SelectedLibraryBackupFile?> openBackup() async => selected;

  @override
  Future<String?> saveBackup({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    savedName = suggestedName;
    savedBytes = bytes;
    return '/documents/$suggestedName';
  }
}

void main() {
  test(
    'backup service preserves scores, annotations, and service plans',
    () async {
      final gateway = _MemoryLibraryBackupGateway();
      final service = LibraryBackupService(gateway: gateway);
      final song = Song(
        id: 'grace',
        title: 'Amazing Grace',
        chordPro: '{title: Amazing Grace}\n[G]Amazing grace',
        leadSheet: const MusicXmlArrangement(
          fileName: 'grace.musicxml',
          sourceXml: '<score-partwise/>',
          annotations: [
            ScoreAnnotationStroke(
              points: [ScoreAnnotationPoint(x: 0.2, y: 0.4)],
              color: ScoreAnnotationColor.purple,
              style: ScoreAnnotationStyle.pen,
            ),
          ],
        ),
      );
      final plan = ServicePlan(
        id: 'sunday',
        title: 'Sunday',
        date: DateTime.utc(2026, 8, 9),
        songIds: const ['grace'],
      );

      final path = await service.export(
        songs: [song],
        servicePlans: [plan],
        now: DateTime(2026, 8, 8),
      );
      gateway.selected = SelectedLibraryBackupFile(
        fileName: gateway.savedName!,
        bytes: gateway.savedBytes!,
      );
      final restored = await service.import();

      expect(path, '/documents/Worship-Focus-Backup-2026-08-08.worshipfocus');
      expect(gateway.savedName, 'Worship-Focus-Backup-2026-08-08.worshipfocus');
      expect(restored!.songs.single.leadSheet!.annotations, hasLength(1));
      expect(restored.servicePlans.single.songIds, const ['grace']);
    },
  );

  test('backup codec rejects incompatible files', () {
    expect(
      () => LibraryBackup.fromJson({
        'format': 'some-other-backup',
        'version': 1,
        'createdAt': '2026-08-08T00:00:00.000Z',
        'songs': [],
        'servicePlans': [],
      }),
      throwsFormatException,
    );
  });

  test('backup import reports invalid JSON as a format error', () async {
    final gateway = _MemoryLibraryBackupGateway()
      ..selected = SelectedLibraryBackupFile(
        fileName: 'broken.worshipfocus',
        bytes: Uint8List.fromList(utf8.encode('not json')),
      );

    await expectLater(
      LibraryBackupService(gateway: gateway).import(),
      throwsFormatException,
    );
  });
}
