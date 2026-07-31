import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/controllers/library_controller.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/services/chordpro_document_service.dart';
import 'package:worship_focus_studio/services/song_repository.dart';
import 'package:worship_focus_studio/services/song_store.dart';

class _MemorySongStore implements SongStore {
  List<Song>? savedSongs;

  @override
  Future<List<Song>?> readSongs() async => savedSongs;

  @override
  Future<void> writeSongs(List<Song> songs) async {
    savedSongs = List.of(songs);
  }
}

void main() {
  test('editing and transposition update the selected song', () async {
    final controller = LibraryController(
      repository: SongRepository(store: _MemorySongStore()),
      autosaveDelay: const Duration(days: 1),
    );

    controller.updateChordPro('[C]Grace');
    expect(controller.selectedSong!.chordPro, '[C]Grace');

    controller.transpose(2);
    expect(controller.selectedSong!.chordPro, '[D]Grace');
    await controller.flushPendingSave();
    controller.dispose();
  });

  test('adds and selects an imported ChordPro document', () async {
    final controller = LibraryController(
      repository: SongRepository(store: _MemorySongStore()),
      autosaveDelay: const Duration(days: 1),
    );

    final song = controller.addImportedSong(
      const ImportedChordPro(
        fileName: 'fallback.cho',
        chordPro: '{title: Imported Song}\n[C]Lyrics',
      ),
    );

    expect(song.title, 'Imported Song');
    expect(controller.selectedSong, same(song));
    expect(controller.songs, contains(song));
    await controller.flushPendingSave();
    controller.dispose();
  });

  test('autosaves edits and restores them in a new controller', () async {
    final store = _MemorySongStore();
    final repository = SongRepository(store: store);
    final controller = LibraryController(
      repository: repository,
      autosaveDelay: Duration.zero,
    );
    await controller.initialize();

    controller.updateChordPro('[F]Persisted edit');
    await controller.flushPendingSave();

    expect(controller.saveState, LibrarySaveState.saved);
    expect(store.savedSongs!.first.chordPro, '[F]Persisted edit');

    final restored = LibraryController(
      repository: SongRepository(store: store),
    );
    await restored.initialize();
    expect(restored.selectedSong!.chordPro, '[F]Persisted edit');
    controller.dispose();
    restored.dispose();
  });
}
