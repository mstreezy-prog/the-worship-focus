import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/services/song_repository.dart';
import 'package:worship_focus_studio/services/song_store.dart';

class _MemorySongStore implements SongStore {
  List<Song>? savedSongs;

  @override
  Future<List<Song>?> readSongs() async => savedSongs;

  @override
  Future<void> writeSongs(List<Song> songs) async {
    savedSongs = songs.map((song) => Song.fromJson(song.toJson())).toList();
  }
}

void main() {
  test('Song JSON preserves ChordPro and optional metadata', () {
    final song = Song(
      id: 'song-1',
      title: 'Grace',
      artist: 'Writer',
      chordPro: '{title: Grace}\n[C]Lyrics',
      musicXml: '<score-partwise/>',
      key: 'C',
      tempo: 72,
    );

    final decoded = Song.fromJson(song.toJson());

    expect(decoded.id, song.id);
    expect(decoded.title, song.title);
    expect(decoded.artist, song.artist);
    expect(decoded.chordPro, song.chordPro);
    expect(decoded.musicXml, song.musicXml);
    expect(decoded.key, song.key);
    expect(decoded.tempo, song.tempo);
  });

  test('repository restores its persisted library', () async {
    final store = _MemorySongStore();
    final firstRepository = SongRepository(store: store, seedSongs: const []);
    final song = Song(id: 'saved', title: 'Saved Song', chordPro: '[G]Saved');
    firstRepository.add(song);
    await firstRepository.persist();

    final restoredRepository = SongRepository(
      store: store,
      seedSongs: const [],
    );
    await restoredRepository.load();

    expect(restoredRepository.getAll(), hasLength(1));
    expect(restoredRepository.getAll().single.chordPro, '[G]Saved');
  });
}
