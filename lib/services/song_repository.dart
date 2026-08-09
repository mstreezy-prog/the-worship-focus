import '../models/song.dart';
import 'song_store.dart';

class SongRepository {
  SongRepository({SongStore? store, Iterable<Song>? seedSongs})
    : _store = store ?? JsonSongStore(),
      _songs = (seedSongs ?? sampleSongs).toList();

  final SongStore _store;
  final List<Song> _songs;

  static final List<Song> sampleSongs = [
    Song(
      id: '1',
      title: 'Amazing Grace',
      chordPro:
          '{title: Amazing Grace}\n[G]Amazing grace how [C]sweet the sound\nThat saved a wretch like [G]me',
    ),
    Song(
      id: '2',
      title: 'Sample Song',
      chordPro:
          '{title: Sample Song}\n[D]This is a [G]sample chord chart\nFor Worship Focus [D]Studio',
    ),
  ];

  List<Song> getAll() => List.unmodifiable(_songs);

  Future<List<Song>> load() async {
    final savedSongs = await _store.readSongs();
    if (savedSongs != null) {
      _songs
        ..clear()
        ..addAll(savedSongs);
    }
    return getAll();
  }

  Future<void> persist() => _store.writeSongs(getAll());

  Song? getById(String id) {
    return _songs.where((song) => song.id == id).firstOrNull;
  }

  void add(Song song) {
    _songs.add(song);
  }

  void update(Song updated) {
    final index = _songs.indexWhere((song) => song.id == updated.id);
    if (index != -1) {
      _songs[index] = updated;
    }
  }

  void delete(String id) {
    _songs.removeWhere((song) => song.id == id);
  }

  void replaceAll(Iterable<Song> songs) {
    _songs
      ..clear()
      ..addAll(songs);
  }
}
