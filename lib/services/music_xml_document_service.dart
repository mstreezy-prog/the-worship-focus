import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart' hide XFile;
import 'package:xml/xml.dart';

import '../models/music_xml_arrangement.dart';
import 'music_xml_transposer.dart';

const musicXmlTypeGroup = XTypeGroup(
  label: 'MusicXML files',
  extensions: ['musicxml', 'xml', 'mxl'],
  uniformTypeIdentifiers: [
    'com.recordare.musicxml.uncompressed',
    'com.recordare.musicxml',
    'public.xml',
  ],
  mimeTypes: [
    'application/vnd.recordare.musicxml+xml',
    'application/vnd.recordare.musicxml',
    'application/xml',
  ],
);

class SelectedMusicXmlFile {
  const SelectedMusicXmlFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

abstract interface class MusicXmlDocumentGateway {
  Future<SelectedMusicXmlFile?> openMusicXml();
  Future<String?> saveMusicXml({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
  });
}

class FileSelectorMusicXmlGateway implements MusicXmlDocumentGateway {
  @override
  Future<SelectedMusicXmlFile?> openMusicXml() async {
    // File providers frequently assign MusicXML a dynamic UTI, which makes
    // valid files appear disabled when the picker is filtered. The codec still
    // validates the selected document before it reaches the library.
    final file = await openFile();
    if (file == null) return null;
    return SelectedMusicXmlFile(
      fileName: file.name,
      bytes: await file.readAsBytes(),
    );
  }

  @override
  Future<String?> saveMusicXml({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mimeType)],
          fileNameOverrides: [suggestedName],
          title: suggestedName,
        ),
      );
      return result.status == ShareResultStatus.dismissed
          ? null
          : suggestedName;
    }
    final location = await getSaveLocation(
      acceptedTypeGroups: [musicXmlTypeGroup],
      suggestedName: suggestedName,
    );
    if (location == null) return null;
    final output = XFile.fromData(
      bytes,
      mimeType: mimeType,
      name: suggestedName,
    );
    await output.saveTo(location.path);
    return location.path;
  }
}

class MusicXmlDocumentService {
  MusicXmlDocumentService({MusicXmlDocumentGateway? gateway})
    : _gateway = gateway ?? FileSelectorMusicXmlGateway();

  final MusicXmlDocumentGateway _gateway;

  Future<MusicXmlArrangement?> import() async {
    final selected = await _gateway.openMusicXml();
    if (selected == null) return null;
    return MusicXmlDocumentCodec.decode(
      fileName: selected.fileName,
      bytes: selected.bytes,
    );
  }

  Future<String?> save({
    required String songTitle,
    required MusicXmlArrangementType type,
    required MusicXmlArrangement arrangement,
  }) {
    final exportArrangement = arrangement.transposeSemitones == 0
        ? arrangement
        : arrangement.copyWith(
            sourceXml: MusicXmlTransposer.transpose(
              arrangement.sourceXml,
              arrangement.transposeSemitones,
            ),
            transposeSemitones: 0,
          );
    final extension = arrangement.isCompressed ? 'mxl' : 'musicxml';
    final mimeType = arrangement.isCompressed
        ? MusicXmlDocumentCodec.compressedMimeType
        : MusicXmlDocumentCodec.uncompressedMimeType;
    return _gateway.saveMusicXml(
      suggestedName:
          '${_safeFileName(songTitle)}-${type.fileNameSegment}.$extension',
      bytes: MusicXmlDocumentCodec.encode(exportArrangement),
      mimeType: mimeType,
    );
  }

  static String _safeFileName(String title) {
    final safe = title.trim().replaceAll(RegExp(r'[/\\:*?"<>|]'), '-');
    return safe.isEmpty ? 'Untitled' : safe;
  }
}

class MusicXmlDocumentCodec {
  static const compressedMimeType = 'application/vnd.recordare.musicxml';
  static const uncompressedMimeType = 'application/vnd.recordare.musicxml+xml';
  static const _maximumDocumentBytes = 25 * 1024 * 1024;

  static MusicXmlArrangement decode({
    required String fileName,
    required Uint8List bytes,
  }) {
    if (bytes.length > _maximumDocumentBytes) {
      throw const FormatException('MusicXML file is larger than 25 MB');
    }
    if (fileName.toLowerCase().endsWith('.musx')) {
      throw const FormatException(
        'Finale .musx projects are not MusicXML. In Finale, export the score as MusicXML or compressed MXL first.',
      );
    }
    final compressed =
        fileName.toLowerCase().endsWith('.mxl') || _looksLikeZip(bytes);
    final sourceXml = compressed
        ? _decodeCompressed(bytes)
        : _decodeXmlBytes(bytes);
    final summary = _inspect(sourceXml);
    return MusicXmlArrangement(
      fileName: fileName,
      sourceXml: sourceXml,
      isCompressed: compressed,
      scoreTitle: summary.title,
      partCount: summary.partCount,
    );
  }

  static Uint8List encode(MusicXmlArrangement arrangement) {
    final sourceBytes = Uint8List.fromList(utf8.encode(arrangement.sourceXml));
    if (!arrangement.isCompressed) return sourceBytes;

    const scorePath = 'score.musicxml';
    const containerXml =
        '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="$scorePath" media-type="$uncompressedMimeType"/>
  </rootfiles>
</container>''';
    final mimeBytes = ascii.encode(compressedMimeType);
    final archive = Archive()
      ..add(ArchiveFile.noCompress('mimetype', mimeBytes.length, mimeBytes))
      ..add(ArchiveFile.string('META-INF/container.xml', containerXml))
      ..add(ArchiveFile.bytes(scorePath, sourceBytes));
    return ZipEncoder().encodeBytes(archive);
  }

  static String _decodeCompressed(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final mimeEntry = archive.findFile('mimetype');
    final mimeBytes = mimeEntry?.readBytes();
    if (mimeBytes != null &&
        ascii.decode(mimeBytes, allowInvalid: true).trim() ==
            'application/vnd.makemusic.notation') {
      throw const FormatException(
        'Finale .musx projects are not MusicXML. In Finale, export the score as MusicXML or compressed MXL first.',
      );
    }
    final container = archive.findFile('META-INF/container.xml');
    String? scorePath;
    if (container != null) {
      final containerBytes = container.readBytes();
      if (containerBytes != null) {
        final document = XmlDocument.parse(_decodeXmlBytes(containerBytes));
        final rootFile = document.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'rootfile')
            .firstOrNull;
        scorePath = rootFile?.getAttribute('full-path');
      }
    }
    scorePath ??= archive
        .where(
          (file) =>
              file.name.toLowerCase().endsWith('.musicxml') ||
              file.name.toLowerCase().endsWith('.xml') &&
                  file.name.toLowerCase() != 'meta-inf/container.xml',
        )
        .firstOrNull
        ?.name;
    if (scorePath == null) {
      throw const FormatException('Compressed MusicXML has no score document');
    }
    final score = archive.findFile(scorePath);
    if (score == null || score.size > _maximumDocumentBytes) {
      throw const FormatException('Compressed MusicXML score is invalid');
    }
    final scoreBytes = score.readBytes();
    if (scoreBytes == null) {
      throw const FormatException(
        'Compressed MusicXML score could not be read',
      );
    }
    return _decodeXmlBytes(scoreBytes);
  }

  static bool _looksLikeZip(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
      return false;
    }
    return (bytes[2] == 0x03 && bytes[3] == 0x04) ||
        (bytes[2] == 0x05 && bytes[3] == 0x06) ||
        (bytes[2] == 0x07 && bytes[3] == 0x08);
  }

  static String _decodeXmlBytes(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf) {
      return utf8.decode(bytes.sublist(3));
    }
    if (bytes.length >= 4) {
      if (bytes[0] == 0x00 &&
          bytes[1] == 0x00 &&
          bytes[2] == 0xfe &&
          bytes[3] == 0xff) {
        return _decodeUtf32(bytes, 4, Endian.big);
      }
      if (bytes[0] == 0xff &&
          bytes[1] == 0xfe &&
          bytes[2] == 0x00 &&
          bytes[3] == 0x00) {
        return _decodeUtf32(bytes, 4, Endian.little);
      }
      if (bytes[0] == 0x00 &&
          bytes[1] == 0x00 &&
          bytes[2] == 0x00 &&
          bytes[3] == 0x3c) {
        return _decodeUtf32(bytes, 0, Endian.big);
      }
      if (bytes[0] == 0x3c &&
          bytes[1] == 0x00 &&
          bytes[2] == 0x00 &&
          bytes[3] == 0x00) {
        return _decodeUtf32(bytes, 0, Endian.little);
      }
    }
    if (bytes.length >= 2) {
      if (bytes[0] == 0xff && bytes[1] == 0xfe) {
        return _decodeUtf16(bytes, 2, Endian.little);
      }
      if (bytes[0] == 0xfe && bytes[1] == 0xff) {
        return _decodeUtf16(bytes, 2, Endian.big);
      }
    }
    if (bytes.length >= 4) {
      if (bytes[0] == 0x3c &&
          bytes[1] == 0x00 &&
          bytes[2] == 0x3f &&
          bytes[3] == 0x00) {
        return _decodeUtf16(bytes, 0, Endian.little);
      }
      if (bytes[0] == 0x00 &&
          bytes[1] == 0x3c &&
          bytes[2] == 0x00 &&
          bytes[3] == 0x3f) {
        return _decodeUtf16(bytes, 0, Endian.big);
      }
    }
    try {
      return utf8.decode(bytes);
    } on FormatException catch (error) {
      final signature = bytes
          .take(12)
          .map((value) => value.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      throw FormatException(
        'Unsupported MusicXML encoding (first bytes: $signature; $error)',
      );
    }
  }

  static String _decodeUtf16(Uint8List bytes, int offset, Endian endian) {
    final length = bytes.length - offset;
    if (length.isOdd) {
      throw const FormatException('Invalid UTF-16 MusicXML document');
    }
    final data = ByteData.sublistView(bytes, offset);
    return String.fromCharCodes([
      for (var index = 0; index < data.lengthInBytes; index += 2)
        data.getUint16(index, endian),
    ]);
  }

  static String _decodeUtf32(Uint8List bytes, int offset, Endian endian) {
    final length = bytes.length - offset;
    if (length % 4 != 0) {
      throw const FormatException('Invalid UTF-32 MusicXML document');
    }
    final data = ByteData.sublistView(bytes, offset);
    final codePoints = <int>[];
    for (var index = 0; index < data.lengthInBytes; index += 4) {
      final codePoint = data.getUint32(index, endian);
      if (codePoint > 0x10ffff || codePoint >= 0xd800 && codePoint <= 0xdfff) {
        throw const FormatException('Invalid UTF-32 MusicXML document');
      }
      codePoints.add(codePoint);
    }
    return String.fromCharCodes(codePoints);
  }

  static _MusicXmlSummary _inspect(String sourceXml) {
    final document = XmlDocument.parse(sourceXml);
    final rootName = document.rootElement.name.local;
    if (rootName != 'score-partwise' && rootName != 'score-timewise') {
      throw const FormatException(
        'MusicXML must contain a score-partwise or score-timewise document',
      );
    }
    String? title;
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local == 'work-title' ||
          element.name.local == 'movement-title') {
        final value = element.innerText.trim();
        if (value.isNotEmpty) {
          title = value;
          break;
        }
      }
    }
    final partCount = document.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'score-part')
        .length;
    return _MusicXmlSummary(title: title, partCount: partCount);
  }
}

class _MusicXmlSummary {
  const _MusicXmlSummary({required this.title, required this.partCount});

  final String? title;
  final int partCount;
}
