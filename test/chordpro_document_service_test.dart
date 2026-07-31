import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/services/chordpro_document_service.dart';

class _FakeGateway implements DocumentGateway {
  ImportedChordPro? imported;
  String? savedName;
  String? savedContent;

  @override
  Future<ImportedChordPro?> openChordPro() async => imported;

  @override
  Future<String?> saveChordPro({
    required String suggestedName,
    required String chordPro,
  }) async {
    savedName = suggestedName;
    savedContent = chordPro;
    return '/documents/$suggestedName';
  }
}

void main() {
  test('declares native picker types for ChordPro and plain text', () {
    expect(chordProTypeGroup.extensions, ['cho', 'chordpro', 'pro', 'txt']);
    expect(
      chordProTypeGroup.uniformTypeIdentifiers,
      containsAll(['com.theworshipfocus.chordpro', 'public.plain-text']),
    );
  });

  test('derives imported song title from metadata or file name', () {
    expect(
      const ImportedChordPro(
        fileName: 'filename.cho',
        chordPro: '{title: Metadata Title}\n[C]Lyrics',
      ).suggestedTitle,
      'Metadata Title',
    );
    expect(
      const ImportedChordPro(
        fileName: 'File Name.chordpro',
        chordPro: '[C]Lyrics',
      ).suggestedTitle,
      'File Name',
    );
  });

  test('saves unchanged ChordPro with a safe suggested name', () async {
    final gateway = _FakeGateway();
    final service = ChordProDocumentService(gateway: gateway);

    final path = await service.save(
      title: 'Grace: Live/Acoustic',
      chordPro: '{title: Grace}\n[C]Lyrics',
    );

    expect(gateway.savedName, 'Grace- Live-Acoustic.chordpro');
    expect(gateway.savedContent, '{title: Grace}\n[C]Lyrics');
    expect(path, '/documents/Grace- Live-Acoustic.chordpro');
  });
}
