import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/controllers/library_controller.dart';
import 'package:worship_focus_studio/services/chordpro_document_service.dart';

void main() {
  test('editing and transposition update the selected song', () {
    final controller = LibraryController();

    controller.updateChordPro('[C]Grace');
    expect(controller.selectedSong!.chordPro, '[C]Grace');

    controller.transpose(2);
    expect(controller.selectedSong!.chordPro, '[D]Grace');
  });

  test('adds and selects an imported ChordPro document', () {
    final controller = LibraryController();

    final song = controller.addImportedSong(
      const ImportedChordPro(
        fileName: 'fallback.cho',
        chordPro: '{title: Imported Song}\n[C]Lyrics',
      ),
    );

    expect(song.title, 'Imported Song');
    expect(controller.selectedSong, same(song));
    expect(controller.songs, contains(song));
  });
}
