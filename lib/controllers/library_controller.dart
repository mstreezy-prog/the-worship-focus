import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../services/chord_transposer.dart';
import '../services/chordpro_metadata.dart';
import '../services/chordpro_document_service.dart';
import '../services/song_repository.dart';

enum LibrarySection { songs, servicePlans, musicXml }

enum LibrarySaveState { loading, saved, unsaved, saving, error }

enum SongSort { title, artist }

class LibraryController extends ChangeNotifier {
  LibraryController({
    SongRepository? repository,
    this.autosaveDelay = const Duration(milliseconds: 600),
  }) : _repository = repository ?? SongRepository() {
    _songs = _repository.getAll().toList();
    _selectedSong = _songs.firstOrNull;
  }

  final SongRepository _repository;
  final Duration autosaveDelay;
  late final List<Song> _songs;
  final Set<String> _serviceSongIds = <String>{};
  Song? _selectedSong;
  LibrarySection _section = LibrarySection.songs;
  LibrarySaveState _saveState = LibrarySaveState.loading;
  String? _saveError;
  Timer? _autosaveTimer;
  int _revision = 0;
  String _searchQuery = '';
  SongSort _songSort = SongSort.title;
  bool _sortAscending = true;

  List<Song> get songs => List.unmodifiable(_songs);
  Song? get selectedSong => _selectedSong;
  LibrarySection get section => _section;
  LibrarySaveState get saveState => _saveState;
  String? get saveError => _saveError;
  String get searchQuery => _searchQuery;
  SongSort get songSort => _songSort;
  bool get sortAscending => _sortAscending;
  Set<String> get serviceSongIds => Set.unmodifiable(_serviceSongIds);
  List<Song> get serviceSongs => _songs
      .where((song) => _serviceSongIds.contains(song.id))
      .toList(growable: false);
  List<Song> get visibleSongs {
    final query = _searchQuery.trim().toLowerCase();
    final visible = _songs.where((song) {
      if (query.isEmpty) return true;
      return song.title.toLowerCase().contains(query) ||
          (song.artist?.toLowerCase().contains(query) ?? false);
    }).toList();
    visible.sort((first, second) {
      final firstValue = switch (_songSort) {
        SongSort.title => first.title,
        SongSort.artist => first.artist ?? '',
      };
      final secondValue = switch (_songSort) {
        SongSort.title => second.title,
        SongSort.artist => second.artist ?? '',
      };
      final result = firstValue.toLowerCase().compareTo(
        secondValue.toLowerCase(),
      );
      return _sortAscending ? result : -result;
    });
    return visible;
  }

  Future<void> initialize() async {
    _saveState = LibrarySaveState.loading;
    notifyListeners();
    try {
      final selectedId = _selectedSong?.id;
      final loaded = await _repository.load();
      _songs
        ..clear()
        ..addAll(loaded);
      _selectedSong = _songs.where((song) => song.id == selectedId).firstOrNull;
      _selectedSong ??= _songs.firstOrNull;
      _saveState = LibrarySaveState.saved;
      _saveError = null;
    } on Object catch (error) {
      _saveState = LibrarySaveState.error;
      _saveError = 'Library could not be loaded: $error';
    }
    notifyListeners();
  }

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

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  void setSongSort(SongSort value) {
    if (_songSort == value) return;
    _songSort = value;
    notifyListeners();
  }

  void toggleSortDirection() {
    _sortAscending = !_sortAscending;
    notifyListeners();
  }

  void updateChordPro(String value) {
    final song = _selectedSong;
    if (song == null || song.chordPro == value) return;
    _replaceSong(song.copyWith(chordPro: value));
  }

  void updateTitle(String value) {
    final song = _selectedSong;
    if (song == null || song.title == value) return;
    _replaceSong(
      song.copyWith(
        title: value,
        chordPro: ChordProMetadata.setDirective(song.chordPro, 'title', value),
      ),
    );
  }

  void updateArtist(String value) {
    final song = _selectedSong;
    if (song == null || song.artist == value) return;
    _replaceSong(
      song.copyWith(
        artist: value,
        clearArtist: value.trim().isEmpty,
        chordPro: ChordProMetadata.setDirective(song.chordPro, 'artist', value),
      ),
    );
  }

  void updateKey(String value) {
    final song = _selectedSong;
    if (song == null || song.key == value) return;
    _replaceSong(
      song.copyWith(
        key: value,
        clearKey: value.trim().isEmpty,
        chordPro: ChordProMetadata.setDirective(song.chordPro, 'key', value),
      ),
    );
  }

  void updateTempo(String value) {
    final song = _selectedSong;
    if (song == null) return;
    final trimmed = value.trim();
    final tempo = int.tryParse(trimmed);
    if (trimmed.isNotEmpty && (tempo == null || tempo <= 0)) return;
    if (song.tempo == tempo) return;
    _replaceSong(
      song.copyWith(
        tempo: tempo,
        clearTempo: tempo == null,
        chordPro: ChordProMetadata.setDirective(
          song.chordPro,
          'tempo',
          tempo?.toString(),
        ),
      ),
    );
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
    _scheduleAutosave();
    return song;
  }

  Song createSong() {
    final title = _uniqueTitle('Untitled Song');
    final song = Song(
      id: 'song-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      chordPro: '{title: $title}\n',
    );
    _repository.add(song);
    _songs.add(song);
    _selectedSong = song;
    _section = LibrarySection.songs;
    _scheduleAutosave();
    return song;
  }

  Song? duplicateSong(Song song) {
    if (!_songs.any((candidate) => candidate.id == song.id)) return null;
    final title = _uniqueTitle('${song.title} Copy');
    final duplicate = song.copyWith(
      id: 'song-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      chordPro: ChordProMetadata.setDirective(song.chordPro, 'title', title),
    );
    _repository.add(duplicate);
    _songs.add(duplicate);
    _selectedSong = duplicate;
    _scheduleAutosave();
    return duplicate;
  }

  void deleteSong(Song song) {
    final index = _songs.indexWhere((candidate) => candidate.id == song.id);
    if (index == -1) return;
    _repository.delete(song.id);
    _songs.removeAt(index);
    _serviceSongIds.remove(song.id);
    if (_selectedSong?.id == song.id) {
      if (_songs.isEmpty) {
        _selectedSong = null;
      } else {
        final nextIndex = index < _songs.length ? index : _songs.length - 1;
        _selectedSong = _songs[nextIndex];
      }
    }
    _scheduleAutosave();
  }

  Future<void> flushPendingSave() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    if (_saveState == LibrarySaveState.unsaved ||
        _saveState == LibrarySaveState.error) {
      await _persist();
    }
  }

  void _replaceSong(Song updated) {
    final index = _songs.indexWhere((song) => song.id == updated.id);
    if (index == -1) return;
    _songs[index] = updated;
    _selectedSong = updated;
    _repository.update(updated);
    _scheduleAutosave();
  }

  String _uniqueTitle(String preferred) {
    var title = preferred;
    var suffix = 2;
    final existing = _songs.map((song) => song.title.toLowerCase()).toSet();
    while (existing.contains(title.toLowerCase())) {
      title = '$preferred $suffix';
      suffix++;
    }
    return title;
  }

  void _scheduleAutosave() {
    _revision++;
    _autosaveTimer?.cancel();
    _saveState = LibrarySaveState.unsaved;
    _saveError = null;
    notifyListeners();
    _autosaveTimer = Timer(autosaveDelay, () {
      _autosaveTimer = null;
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    final savingRevision = _revision;
    _saveState = LibrarySaveState.saving;
    notifyListeners();
    try {
      await _repository.persist();
      _saveState = savingRevision == _revision
          ? LibrarySaveState.saved
          : LibrarySaveState.unsaved;
      _saveError = null;
    } on Object catch (error) {
      _saveState = LibrarySaveState.error;
      _saveError = 'Changes could not be saved: $error';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    if (_saveState == LibrarySaveState.unsaved) {
      unawaited(_repository.persist());
    }
    super.dispose();
  }
}
