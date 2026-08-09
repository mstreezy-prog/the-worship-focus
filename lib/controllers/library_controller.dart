import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/music_xml_arrangement.dart';
import '../models/score_annotation.dart';
import '../models/service_plan.dart';
import '../models/song.dart';
import '../services/chord_transposer.dart';
import '../services/chordpro_document_service.dart';
import '../services/chordpro_metadata.dart';
import '../services/music_xml_transposer.dart';
import '../services/service_plan_repository.dart';
import '../services/song_repository.dart';

enum LibrarySection { songs, servicePlans, musicXml }

enum LibrarySaveState { loading, saved, unsaved, saving, error }

enum SongSort { title, artist }

class LibraryController extends ChangeNotifier {
  LibraryController({
    SongRepository? repository,
    ServicePlanRepository? servicePlanRepository,
    this.autosaveDelay = const Duration(milliseconds: 600),
  }) : _repository = repository ?? SongRepository(),
       _servicePlanRepository =
           servicePlanRepository ?? ServicePlanRepository() {
    _songs = _repository.getAll().toList();
    _servicePlans = _servicePlanRepository.getAll().toList();
    _selectedSong = _songs.firstOrNull;
    _selectedServicePlan = _servicePlans.firstOrNull;
  }

  final SongRepository _repository;
  final ServicePlanRepository _servicePlanRepository;
  final Duration autosaveDelay;
  late final List<Song> _songs;
  late final List<ServicePlan> _servicePlans;
  Song? _selectedSong;
  ServicePlan? _selectedServicePlan;
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
  List<ServicePlan> get servicePlans => List.unmodifiable(_servicePlans);
  ServicePlan? get selectedServicePlan => _selectedServicePlan;
  Set<String> get serviceSongIds => Set.unmodifiable(
    (_selectedServicePlan?.songIds ?? const <String>[]).toSet(),
  );
  List<Song> get serviceSongs => servicePlanSongs(_selectedServicePlan);

  List<Song> servicePlanSongs(ServicePlan? plan) {
    if (plan == null) return const <Song>[];
    final songsById = {for (final song in _songs) song.id: song};
    return plan.songIds
        .map((id) => songsById[id])
        .whereType<Song>()
        .toList(growable: false);
  }

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
      final selectedPlanId = _selectedServicePlan?.id;
      final loaded = await _repository.load();
      final loadedPlans = await _servicePlanRepository.load();
      _songs
        ..clear()
        ..addAll(loaded);
      _servicePlans
        ..clear()
        ..addAll(loadedPlans);
      _selectedSong = _songs.where((song) => song.id == selectedId).firstOrNull;
      _selectedSong ??= _songs.firstOrNull;
      _selectedServicePlan = _servicePlans
          .where((plan) => plan.id == selectedPlanId)
          .firstOrNull;
      _selectedServicePlan ??= _servicePlans.firstOrNull;
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

  void setMusicXmlArrangement(
    MusicXmlArrangementType type,
    MusicXmlArrangement arrangement,
  ) {
    final song = _selectedSong;
    if (song == null) return;
    _replaceSong(switch (type) {
      MusicXmlArrangementType.leadSheet => song.copyWith(
        leadSheet: arrangement,
      ),
      MusicXmlArrangementType.fullPiano => song.copyWith(
        fullPiano: arrangement,
      ),
    });
  }

  void removeMusicXmlArrangement(MusicXmlArrangementType type) {
    final song = _selectedSong;
    if (song == null || song.arrangement(type) == null) return;
    _replaceSong(switch (type) {
      MusicXmlArrangementType.leadSheet => song.copyWith(clearLeadSheet: true),
      MusicXmlArrangementType.fullPiano => song.copyWith(clearFullPiano: true),
    });
  }

  void setMusicXmlTranspose(MusicXmlArrangementType type, int semitones) {
    final song = _selectedSong;
    final arrangement = song?.arrangement(type);
    if (song == null || arrangement == null) return;
    final boundedSemitones = semitones
        .clamp(
          MusicXmlTransposer.minimumSemitones,
          MusicXmlTransposer.maximumSemitones,
        )
        .toInt();
    if (arrangement.transposeSemitones == boundedSemitones) return;
    setMusicXmlArrangement(
      type,
      arrangement.copyWith(transposeSemitones: boundedSemitones),
    );
  }

  void setMusicXmlAnnotations(
    MusicXmlArrangementType type,
    List<ScoreAnnotationStroke> annotations,
  ) {
    final song = _selectedSong;
    final arrangement = song?.arrangement(type);
    if (song == null || arrangement == null) return;
    setMusicXmlArrangement(
      type,
      arrangement.copyWith(annotations: List.unmodifiable(annotations)),
    );
  }

  void toggleServiceSong(Song song) {
    final plan =
        _selectedServicePlan ?? createServicePlan(selectSection: false);
    if (plan.songIds.contains(song.id)) {
      removeSongFromServicePlan(song);
    } else {
      addSongToServicePlan(song);
    }
  }

  ServicePlan createServicePlan({String? title, bool selectSection = true}) {
    final plan = ServicePlan(
      id: 'plan-${DateTime.now().microsecondsSinceEpoch}',
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : 'New Service Plan',
      date: DateTime.now(),
      items: const <ServicePlanItem>[],
    );
    _servicePlans.add(plan);
    _servicePlanRepository.add(plan);
    _selectedServicePlan = plan;
    if (selectSection) _section = LibrarySection.servicePlans;
    _scheduleAutosave();
    return plan;
  }

  void selectServicePlan(ServicePlan plan) {
    if (_selectedServicePlan?.id == plan.id) return;
    _selectedServicePlan = plan;
    notifyListeners();
  }

  void renameSelectedServicePlan(String value) {
    final plan = _selectedServicePlan;
    final title = value.trim();
    if (plan == null || title.isEmpty || title == plan.title) return;
    _replaceServicePlan(plan.copyWith(title: title));
  }

  void updateSelectedServicePlanDate(DateTime value) {
    final plan = _selectedServicePlan;
    final date = DateTime(value.year, value.month, value.day);
    if (plan == null ||
        (plan.date.year == date.year &&
            plan.date.month == date.month &&
            plan.date.day == date.day)) {
      return;
    }
    _replaceServicePlan(plan.copyWith(date: date));
  }

  void deleteServicePlan(ServicePlan plan) {
    final index = _servicePlans.indexWhere(
      (candidate) => candidate.id == plan.id,
    );
    if (index == -1) return;
    _servicePlans.removeAt(index);
    _servicePlanRepository.delete(plan.id);
    if (_selectedServicePlan?.id == plan.id) {
      _selectedServicePlan = _servicePlans.isEmpty
          ? null
          : _servicePlans[index.clamp(0, _servicePlans.length - 1).toInt()];
    }
    _scheduleAutosave();
  }

  void addSongToServicePlan(Song song) {
    final plan =
        _selectedServicePlan ?? createServicePlan(selectSection: false);
    if (plan.songIds.contains(song.id)) return;
    _replaceServicePlan(
      plan.copyWith(
        items: [
          ...plan.items,
          ServicePlanItem.song(
            id: 'item-${DateTime.now().microsecondsSinceEpoch}',
            songId: song.id,
          ),
        ],
      ),
    );
  }

  void removeSongFromServicePlan(Song song) {
    final plan = _selectedServicePlan;
    if (plan == null || !plan.songIds.contains(song.id)) return;
    _replaceServicePlan(
      plan.copyWith(
        items: plan.items.where((item) => item.songId != song.id).toList(),
      ),
    );
  }

  void addServicePlanSection(String value) {
    final plan = _selectedServicePlan;
    final title = value.trim();
    if (plan == null || title.isEmpty) return;
    _replaceServicePlan(
      plan.copyWith(
        items: [
          ...plan.items,
          ServicePlanItem.section(
            id: 'item-${DateTime.now().microsecondsSinceEpoch}',
            title: title,
          ),
        ],
      ),
    );
  }

  void updateServicePlanItemNotes(ServicePlanItem item, String value) {
    final plan = _selectedServicePlan;
    if (plan == null || !item.isSong || item.notes == value) return;
    _replaceServicePlan(
      plan.copyWith(
        items: [
          for (final candidate in plan.items)
            if (candidate.id == item.id)
              candidate.copyWith(notes: value)
            else
              candidate,
        ],
      ),
    );
  }

  void removeServicePlanItem(ServicePlanItem item) {
    final plan = _selectedServicePlan;
    if (plan == null ||
        !plan.items.any((candidate) => candidate.id == item.id)) {
      return;
    }
    _replaceServicePlan(
      plan.copyWith(
        items: plan.items
            .where((candidate) => candidate.id != item.id)
            .toList(),
      ),
    );
  }

  void reorderServicePlanItems(int oldIndex, int newIndex) {
    final plan = _selectedServicePlan;
    if (plan == null || oldIndex < 0 || oldIndex >= plan.items.length) return;
    if (newIndex < 0 || newIndex >= plan.items.length) return;
    final items = List<ServicePlanItem>.of(plan.items);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    _replaceServicePlan(plan.copyWith(items: items));
  }

  void reorderServiceSongs(int oldIndex, int newIndex) {
    reorderServicePlanItems(oldIndex, newIndex);
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
    for (final plan in List<ServicePlan>.of(_servicePlans)) {
      if (plan.songIds.contains(song.id)) {
        _replaceServicePlan(
          plan.copyWith(
            items: plan.items.where((item) => item.songId != song.id).toList(),
          ),
          scheduleSave: false,
        );
      }
    }
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

  void _replaceServicePlan(ServicePlan updated, {bool scheduleSave = true}) {
    final index = _servicePlans.indexWhere((plan) => plan.id == updated.id);
    if (index == -1) return;
    _servicePlans[index] = updated;
    _servicePlanRepository.update(updated);
    if (_selectedServicePlan?.id == updated.id) {
      _selectedServicePlan = updated;
    }
    if (scheduleSave) {
      _scheduleAutosave();
    }
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
      await Future.wait([
        _repository.persist(),
        _servicePlanRepository.persist(),
      ]);
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
      unawaited(_servicePlanRepository.persist());
    }
    super.dispose();
  }
}
