import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/music_xml_arrangement.dart';
import 'package:worship_focus_studio/services/music_xml_document_service.dart';
import 'package:worship_focus_studio/services/music_xml_transposer.dart';

const _score = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <work><work-title>Test Hymn</work-title></work>
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1"><measure number="1"/></part>
</score-partwise>''';

const _transposableScore = '''<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Music</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><key><fifths>2</fifths><mode>major</mode></key></attributes>
    <note><pitch><step>F</step><alter>1</alter><octave>4</octave></pitch></note>
  </measure></part>
</score-partwise>''';

class _MemoryMusicXmlGateway implements MusicXmlDocumentGateway {
  SelectedMusicXmlFile? selected;
  String? savedName;
  Uint8List? savedBytes;
  String? savedMimeType;

  @override
  Future<SelectedMusicXmlFile?> openMusicXml() async => selected;

  @override
  Future<String?> saveMusicXml({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    savedName = suggestedName;
    savedBytes = bytes;
    savedMimeType = mimeType;
    return '/documents/$suggestedName';
  }
}

void main() {
  test('type group accepts uncompressed and compressed MusicXML', () {
    expect(musicXmlTypeGroup.extensions, ['musicxml', 'xml', 'mxl']);
    expect(
      musicXmlTypeGroup.uniformTypeIdentifiers,
      containsAll([
        'com.recordare.musicxml.uncompressed',
        'com.recordare.musicxml',
      ]),
    );
  });

  test('decodes and inspects an uncompressed score', () {
    final arrangement = MusicXmlDocumentCodec.decode(
      fileName: 'hymn.musicxml',
      bytes: Uint8List.fromList(utf8.encode(_score)),
    );

    expect(arrangement.sourceXml, _score);
    expect(arrangement.scoreTitle, 'Test Hymn');
    expect(arrangement.partCount, 1);
    expect(arrangement.isCompressed, isFalse);
  });

  test('compressed MXL round-trips without changing source XML', () {
    const original = MusicXmlArrangement(
      fileName: 'hymn.mxl',
      sourceXml: _score,
      isCompressed: true,
    );

    final bytes = MusicXmlDocumentCodec.encode(original);
    final decoded = MusicXmlDocumentCodec.decode(
      fileName: original.fileName,
      bytes: bytes,
    );

    expect(decoded.sourceXml, _score);
    expect(decoded.scoreTitle, 'Test Hymn');
    expect(decoded.partCount, 1);
    expect(decoded.isCompressed, isTrue);
  });

  test('detects compressed MXL when iOS drops the file extension', () {
    const original = MusicXmlArrangement(
      fileName: 'hymn.mxl',
      sourceXml: _score,
      isCompressed: true,
    );

    final decoded = MusicXmlDocumentCodec.decode(
      fileName: 'temporary-picker-file',
      bytes: MusicXmlDocumentCodec.encode(original),
    );

    expect(decoded.sourceXml, _score);
    expect(decoded.isCompressed, isTrue);
  });

  test('decodes UTF-16 MusicXML exported by notation applications', () {
    final bytes = BytesBuilder()..add([0xff, 0xfe]);
    for (final codeUnit in _score.codeUnits) {
      bytes.add([codeUnit & 0xff, codeUnit >> 8]);
    }

    final decoded = MusicXmlDocumentCodec.decode(
      fileName: 'utf16.musicxml',
      bytes: bytes.takeBytes(),
    );

    expect(decoded.scoreTitle, 'Test Hymn');
    expect(decoded.partCount, 1);
  });

  test('decodes big-endian UTF-32 MusicXML', () {
    final bytes = BytesBuilder()..add([0x00, 0x00, 0xfe, 0xff]);
    for (final codePoint in _score.runes) {
      bytes.add([
        codePoint >> 24,
        codePoint >> 16 & 0xff,
        codePoint >> 8 & 0xff,
        codePoint & 0xff,
      ]);
    }

    final decoded = MusicXmlDocumentCodec.decode(
      fileName: 'utf32.musicxml',
      bytes: bytes.takeBytes(),
    );

    expect(decoded.scoreTitle, 'Test Hymn');
    expect(decoded.partCount, 1);
  });

  test('rejects XML that is not a MusicXML score', () {
    expect(
      () => MusicXmlDocumentCodec.decode(
        fileName: 'not-a-score.xml',
        bytes: Uint8List.fromList(utf8.encode('<document/>')),
      ),
      throwsFormatException,
    );
  });

  test('explains that Finale projects must be exported first', () {
    expect(
      () => MusicXmlDocumentCodec.decode(
        fileName: 'finale-project.musx',
        bytes: Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('export the score as MusicXML'),
        ),
      ),
    );
  });

  test('service imports and exports using the arrangement format', () async {
    final gateway = _MemoryMusicXmlGateway()
      ..selected = SelectedMusicXmlFile(
        fileName: 'piano.mxl',
        bytes: MusicXmlDocumentCodec.encode(
          const MusicXmlArrangement(
            fileName: 'piano.mxl',
            sourceXml: _score,
            isCompressed: true,
          ),
        ),
      );
    final service = MusicXmlDocumentService(gateway: gateway);

    final arrangement = await service.import();
    final path = await service.save(
      songTitle: 'Grace: Live',
      type: MusicXmlArrangementType.fullPiano,
      arrangement: arrangement!,
    );

    expect(gateway.savedName, 'Grace- Live-Full-Piano.mxl');
    expect(gateway.savedMimeType, MusicXmlDocumentCodec.compressedMimeType);
    expect(gateway.savedBytes, isNotEmpty);
    expect(path, '/documents/Grace- Live-Full-Piano.mxl');
  });

  test(
    'service exports the selected transposition without changing source',
    () async {
      final gateway = _MemoryMusicXmlGateway();
      final service = MusicXmlDocumentService(gateway: gateway);
      const arrangement = MusicXmlArrangement(
        fileName: 'lead.musicxml',
        sourceXml: _transposableScore,
        transposeSemitones: 1,
      );

      await service.save(
        songTitle: 'Transposed Song',
        type: MusicXmlArrangementType.leadSheet,
        arrangement: arrangement,
      );

      final exported = MusicXmlDocumentCodec.decode(
        fileName: gateway.savedName!,
        bytes: gateway.savedBytes!,
      );
      expect(
        MusicXmlTransposer.keySignature(exported.sourceXml)?.label,
        'Eb major',
      );
      expect(exported.sourceXml, contains('<step>G</step>'));
      expect(arrangement.sourceXml, _transposableScore);
      expect(arrangement.transposeSemitones, 1);
    },
  );
}
