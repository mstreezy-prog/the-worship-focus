import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

const chordProTypeGroup = XTypeGroup(
  label: 'ChordPro files',
  extensions: ['cho', 'chordpro', 'pro', 'txt'],
  uniformTypeIdentifiers: ['public.plain-text'],
  mimeTypes: ['text/plain'],
);

class ImportedChordPro {
  const ImportedChordPro({required this.fileName, required this.chordPro});

  final String fileName;
  final String chordPro;

  String get suggestedTitle {
    final match = RegExp(
      r'^\s*\{(?:title|t)\s*:\s*(.+?)\s*\}\s*$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(chordPro);
    if (match != null) return match.group(1)!;
    return fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }
}

abstract interface class DocumentGateway {
  Future<ImportedChordPro?> openChordPro();
  Future<String?> saveChordPro({
    required String suggestedName,
    required String chordPro,
  });
}

class FileSelectorDocumentGateway implements DocumentGateway {
  @override
  Future<ImportedChordPro?> openChordPro() async {
    final file = await openFile(acceptedTypeGroups: [chordProTypeGroup]);
    if (file == null) return null;
    return ImportedChordPro(
      fileName: file.name,
      chordPro: await file.readAsString(),
    );
  }

  @override
  Future<String?> saveChordPro({
    required String suggestedName,
    required String chordPro,
  }) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: [chordProTypeGroup],
      suggestedName: suggestedName,
    );
    if (location == null) return null;

    final output = XFile.fromData(
      Uint8List.fromList(utf8.encode(chordPro)),
      mimeType: 'text/plain',
      name: suggestedName,
    );
    await output.saveTo(location.path);
    return location.path;
  }
}

class ChordProDocumentService {
  ChordProDocumentService({DocumentGateway? gateway})
    : _gateway = gateway ?? FileSelectorDocumentGateway();

  final DocumentGateway _gateway;

  Future<ImportedChordPro?> import() => _gateway.openChordPro();

  Future<String?> save({required String title, required String chordPro}) {
    return _gateway.saveChordPro(
      suggestedName: '${_safeFileName(title)}.chordpro',
      chordPro: chordPro,
    );
  }

  static String _safeFileName(String title) {
    final safe = title.trim().replaceAll(RegExp(r'[/\\:*?"<>|]'), '-');
    return safe.isEmpty ? 'Untitled' : safe;
  }
}
