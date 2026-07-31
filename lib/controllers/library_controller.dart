import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../services/chordpro_document_service.dart';
import '../services/chord_transposer.dart';
import '../services/song_repository.dart';

enum LibrarySection { songs, servicePlans, musicXml }

class LibraryController extends ChangeNotifier {
  LibraryController({SongRepository? repository})
    : _repository = repository ?? SongRepository() {
    _songs = _repository.getAll().toList();
    _selectedSong = _songs.firstOrNull;
  }

  final SongRepository _repository;
  late final List<Song> _songs;
  final Set<String> _serviceSongIds = <String>{};
  Song? _selectedSong;
  LibrarySection _section = LibrarySection.songs;

  List<Song> get songs => List.unmodifiable(_songs);
  Song? get selectedSong => _selectedSong;
  LibrarySection get section => _section;
  Set<String> get serviceSongIds => Set.unmodifiable(_serviceSongIds);
  List<Song> get serviceSongs => _songs
      .where((song) => _serviceSongIds.contains(song.id))
      .toList(growable: false);

  void selectSection(LibrarySection value) {
    if (_section == value) return;
    _section = value;
    notifyListeners();
  }

  void selectSong(Song song) {
    if (_selectedSong?.id == song.id) return;
    _selectedSong = song;
    notifyListeners();
  }

  void updateChordPro(String value) {
    final song = _selectedSong;
    if (song == null || song.chordPro == value) return;
    _replaceSong(song.copyWith(chordPro: value));
  }

  void transpose(int semitones) {
    final song = _selectedSong;
    if (song == null) return;
    _replaceSong(
      song.copyWith(
        chordPro: ChordTransposer.transposeChordPro(song.chordPro, semitones),
      ),
    );
  }

  void toggleServiceSong(Song song) {
    _serviceSongIds.contains(song.id)
        ? _serviceSongIds.remove(song.id)
        : _serviceSongIds.add(song.id);
    notifyListeners();
  }

  Song addImportedSong(ImportedChordPro document) {
    final song = Song(
      id: 'import-${DateTime.now().microsecondsSinceEpoch}',
      title: document.suggestedTitle,
      chordPro: document.chordPro,
    );
    _repository.add(song);
    _songs.add(song);
    _selectedSong = song;
    _section = LibrarySection.songs;
    notifyListeners();
    return song;
  }

  void _replaceSong(Song updated) {
    final index = _songs.indexWhere((song) => song.id == updated.id);
    if (index == -1) return;
    _songs[index] = updated;
    _selectedSong = updated;
    _repository.update(updated);
    notifyListeners();
  }
}
