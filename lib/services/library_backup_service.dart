import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart' hide XFile;

import '../models/library_backup.dart';
import '../models/service_plan.dart';
import '../models/song.dart';

const libraryBackupTypeGroup = XTypeGroup(
  label: 'Worship Focus backup',
  extensions: ['worshipfocus'],
  uniformTypeIdentifiers: ['public.json'],
  mimeTypes: ['application/json'],
);

class SelectedLibraryBackupFile {
  const SelectedLibraryBackupFile({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

abstract interface class LibraryBackupGateway {
  Future<SelectedLibraryBackupFile?> openBackup();
  Future<String?> saveBackup({
    required String suggestedName,
    required Uint8List bytes,
  });
}

class FileSelectorLibraryBackupGateway implements LibraryBackupGateway {
  @override
  Future<SelectedLibraryBackupFile?> openBackup() async {
    // iOS file providers do not consistently advertise custom file types.
    // Validate the document after it is selected instead of disabling it.
    final file = await openFile();
    if (file == null) return null;
    return SelectedLibraryBackupFile(
      fileName: file.name,
      bytes: await file.readAsBytes(),
    );
  }

  @override
  Future<String?> saveBackup({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/json')],
          fileNameOverrides: [suggestedName],
          title: suggestedName,
        ),
      );
      return result.status == ShareResultStatus.dismissed
          ? null
          : suggestedName;
    }
    final location = await getSaveLocation(
      acceptedTypeGroups: [libraryBackupTypeGroup],
      suggestedName: suggestedName,
    );
    if (location == null) return null;
    final output = XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: suggestedName,
    );
    await output.saveTo(location.path);
    return location.path;
  }
}

class LibraryBackupService {
  LibraryBackupService({LibraryBackupGateway? gateway})
    : _gateway = gateway ?? FileSelectorLibraryBackupGateway();

  static const _maximumBackupBytes = 50 * 1024 * 1024;

  final LibraryBackupGateway _gateway;

  Future<String?> export({
    required List<Song> songs,
    required List<ServicePlan> servicePlans,
    DateTime? now,
  }) {
    final backup = LibraryBackup(
      createdAt: now ?? DateTime.now(),
      songs: List.unmodifiable(songs),
      servicePlans: List.unmodifiable(servicePlans),
    );
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(backup.toJson())),
    );
    if (bytes.length > _maximumBackupBytes) {
      throw const FormatException('Library backup is larger than 50 MB');
    }
    return _gateway.saveBackup(
      suggestedName:
          'Worship-Focus-Backup-${_dateSegment(backup.createdAt)}.worshipfocus',
      bytes: bytes,
    );
  }

  Future<LibraryBackup?> import() async {
    final selected = await _gateway.openBackup();
    if (selected == null) return null;
    if (selected.bytes.length > _maximumBackupBytes) {
      throw const FormatException('Library backup is larger than 50 MB');
    }
    try {
      final decoded = jsonDecode(utf8.decode(selected.bytes));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Library backup is not a JSON object');
      }
      return LibraryBackup.fromJson(decoded);
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Could not read library backup: $error');
    }
  }

  static String _dateSegment(DateTime value) {
    final date = value.toLocal();
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
