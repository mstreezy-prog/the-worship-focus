import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../services/chord_transposer.dart';
import '../services/chordpro_document_service.dart';
import '../services/song_repository.dart';

enum LibrarySection { songs, servicePlans, musicXml }

enum LibrarySaveState { loading, saved, unsaved, saving, error }

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

  List<Song> get songs => List.unmodifiable(_songs);
  Song? get selectedSong => _selectedSong;
  LibrarySection get section => _section;
  LibrarySaveState get saveState => _saveState;
  String? get saveError => _saveError;
  Set<String> get serviceSongIds => Set.unmodifiable(_serviceSongIds);
  List<Song> get serviceSongs => _songs
      .where((song) => _serviceSongIds.contains(song.id))
      .toList(growable: false);

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
    _scheduleAutosave();
    return song;
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
