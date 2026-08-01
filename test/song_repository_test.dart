import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/music_xml_arrangement.dart';
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
  test('Song JSON preserves ChordPro, arrangements, and metadata', () {
    final song = Song(
      id: 'song-1',
      title: 'Grace',
      artist: 'Writer',
      chordPro: '{title: Grace}\n[C]Lyrics',
      leadSheet: const MusicXmlArrangement(
        fileName: 'Grace-Lead-Sheet.musicxml',
        sourceXml: '<score-partwise/>',
        scoreTitle: 'Grace',
        partCount: 1,
      ),
      fullPiano: const MusicXmlArrangement(
        fileName: 'Grace-Full-Piano.mxl',
        sourceXml: '<score-partwise/>',
        isCompressed: true,
        partCount: 2,
        transposeSemitones: 2,
      ),
      key: 'C',
      tempo: 72,
    );

    final decoded = Song.fromJson(song.toJson());

    expect(decoded.id, song.id);
    expect(decoded.title, song.title);
    expect(decoded.artist, song.artist);
    expect(decoded.chordPro, song.chordPro);
    expect(decoded.leadSheet!.sourceXml, song.leadSheet!.sourceXml);
    expect(decoded.leadSheet!.scoreTitle, 'Grace');
    expect(decoded.fullPiano!.isCompressed, isTrue);
    expect(decoded.fullPiano!.transposeSemitones, 2);
    expect(decoded.key, song.key);
    expect(decoded.tempo, song.tempo);
  });

  test('legacy MusicXML migrates into the lead-sheet slot', () {
    final song = Song.fromJson({
      'id': 'legacy',
      'title': 'Legacy',
      'chordPro': '[C]Legacy',
      'musicXml': '<score-partwise/>',
    });

    expect(song.leadSheet!.sourceXml, '<score-partwise/>');
    expect(song.fullPiano, isNull);
    expect(song.toJson(), isNot(contains('musicXml')));
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
