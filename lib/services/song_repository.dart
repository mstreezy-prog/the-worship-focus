import '../models/song.dart';

class SongRepository {
  final List<Song> _songs = [
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

  Song? getById(String id) {
    return _songs.where((s) => s.id == id).firstOrNull;
  }

  void add(Song song) {
    _songs.add(song);
  }

  void update(Song updated) {
    final index = _songs.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _songs[index] = updated;
    }
  }

  void delete(String id) {
    _songs.removeWhere((s) => s.id == id);
  }
}
