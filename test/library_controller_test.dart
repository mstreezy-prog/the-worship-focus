import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/controllers/library_controller.dart';
import 'package:worship_focus_studio/models/music_xml_arrangement.dart';
import 'package:worship_focus_studio/models/score_annotation.dart';
import 'package:worship_focus_studio/models/service_plan.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/services/chordpro_document_service.dart';
import 'package:worship_focus_studio/services/service_plan_repository.dart';
import 'package:worship_focus_studio/services/service_plan_store.dart';
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

class _MemoryServicePlanStore implements ServicePlanStore {
  List<ServicePlan>? savedPlans;

  @override
  Future<List<ServicePlan>?> readPlans() async => savedPlans;

  @override
  Future<void> writePlans(List<ServicePlan> plans) async {
    savedPlans = List.of(plans);
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
    final planStore = _MemoryServicePlanStore();
    final repository = SongRepository(store: store);
    final controller = LibraryController(
      repository: repository,
      servicePlanRepository: ServicePlanRepository(store: planStore),
      autosaveDelay: Duration.zero,
    );
    await controller.initialize();

    controller.updateChordPro('[F]Persisted edit');
    await controller.flushPendingSave();

    expect(controller.saveState, LibrarySaveState.saved);
    expect(store.savedSongs!.first.chordPro, '[F]Persisted edit');

    final restored = LibraryController(
      repository: SongRepository(store: store),
      servicePlanRepository: ServicePlanRepository(store: planStore),
    );
    await restored.initialize();
    expect(restored.selectedSong!.chordPro, '[F]Persisted edit');
    controller.dispose();
    restored.dispose();
  });

  test('attaches and removes the two fixed MusicXML arrangements', () async {
    final controller = LibraryController(
      repository: SongRepository(store: _MemorySongStore()),
      autosaveDelay: const Duration(days: 1),
    );
    const leadSheet = MusicXmlArrangement(
      fileName: 'lead.musicxml',
      sourceXml: '<score-partwise/>',
    );
    const fullPiano = MusicXmlArrangement(
      fileName: 'piano.mxl',
      sourceXml: '<score-partwise/>',
      isCompressed: true,
    );

    controller.setMusicXmlArrangement(
      MusicXmlArrangementType.leadSheet,
      leadSheet,
    );
    controller.setMusicXmlArrangement(
      MusicXmlArrangementType.fullPiano,
      fullPiano,
    );

    expect(controller.selectedSong!.leadSheet, same(leadSheet));
    expect(controller.selectedSong!.fullPiano, same(fullPiano));

    controller.removeMusicXmlArrangement(MusicXmlArrangementType.leadSheet);
    expect(controller.selectedSong!.leadSheet, isNull);
    expect(controller.selectedSong!.fullPiano, same(fullPiano));
    await controller.flushPendingSave();
    controller.dispose();
  });

  test('stores independent MusicXML transposition offsets', () async {
    final controller = LibraryController(
      repository: SongRepository(store: _MemorySongStore()),
      autosaveDelay: const Duration(days: 1),
    );
    const sourceXml = '<score-partwise/>';
    controller.setMusicXmlArrangement(
      MusicXmlArrangementType.leadSheet,
      const MusicXmlArrangement(
        fileName: 'lead.musicxml',
        sourceXml: sourceXml,
      ),
    );
    controller.setMusicXmlArrangement(
      MusicXmlArrangementType.fullPiano,
      const MusicXmlArrangement(
        fileName: 'piano.musicxml',
        sourceXml: sourceXml,
      ),
    );

    controller.setMusicXmlTranspose(MusicXmlArrangementType.leadSheet, 2);
    controller.setMusicXmlTranspose(MusicXmlArrangementType.fullPiano, -3);

    expect(controller.selectedSong!.leadSheet!.transposeSemitones, 2);
    expect(controller.selectedSong!.fullPiano!.transposeSemitones, -3);
    expect(controller.selectedSong!.leadSheet!.sourceXml, sourceXml);
    expect(controller.selectedSong!.fullPiano!.sourceXml, sourceXml);
    await controller.flushPendingSave();
    controller.dispose();
  });

  test('stores score annotations separately for each arrangement', () async {
    final controller = LibraryController(
      repository: SongRepository(store: _MemorySongStore()),
      autosaveDelay: const Duration(days: 1),
    );
    const sourceXml = '<score-partwise/>';
    for (final type in MusicXmlArrangementType.values) {
      controller.setMusicXmlArrangement(
        type,
        MusicXmlArrangement(
          fileName: '${type.name}.musicxml',
          sourceXml: sourceXml,
        ),
      );
    }
    const stroke = ScoreAnnotationStroke(
      points: [ScoreAnnotationPoint(x: 0.1, y: 0.2)],
      color: ScoreAnnotationColor.red,
      style: ScoreAnnotationStyle.pen,
    );

    controller.setMusicXmlAnnotations(MusicXmlArrangementType.leadSheet, const [
      stroke,
    ]);

    expect(controller.selectedSong!.leadSheet!.annotations, [stroke]);
    expect(controller.selectedSong!.fullPiano!.annotations, isEmpty);
    await controller.flushPendingSave();
    controller.dispose();
  });

  test('saves a service plan in its chosen song order', () async {
    final songStore = _MemorySongStore();
    final planStore = _MemoryServicePlanStore();
    final controller = LibraryController(
      repository: SongRepository(store: songStore),
      servicePlanRepository: ServicePlanRepository(store: planStore),
      autosaveDelay: const Duration(days: 1),
    );
    final firstSong = controller.songs[0];
    final secondSong = controller.songs[1];

    final plan = controller.createServicePlan(title: 'Sunday Morning');
    controller.addSongToServicePlan(firstSong);
    controller.addSongToServicePlan(secondSong);
    controller.reorderServiceSongs(1, 0);
    controller.renameSelectedServicePlan('August 9 Service');
    await controller.flushPendingSave();

    expect(controller.selectedServicePlan!.title, 'August 9 Service');
    expect(controller.serviceSongs.map((song) => song.id), [
      secondSong.id,
      firstSong.id,
    ]);
    expect(planStore.savedPlans!.single.id, plan.id);

    final restored = LibraryController(
      repository: SongRepository(store: songStore),
      servicePlanRepository: ServicePlanRepository(store: planStore),
    );
    await restored.initialize();
    expect(restored.servicePlans.single.title, 'August 9 Service');
    expect(restored.serviceSongs.map((song) => song.id), [
      secondSong.id,
      firstSong.id,
    ]);

    controller.deleteSong(secondSong);
    expect(controller.serviceSongs.map((song) => song.id), [firstSong.id]);
    controller.dispose();
    restored.dispose();
  });

  test(
    'adds section headers and keeps notes with their song entries',
    () async {
      final controller = LibraryController(
        repository: SongRepository(store: _MemorySongStore()),
        servicePlanRepository: ServicePlanRepository(
          store: _MemoryServicePlanStore(),
        ),
        autosaveDelay: const Duration(days: 1),
      );
      final song = controller.songs.first;
      controller.createServicePlan(title: 'Sunday Morning');
      controller.addServicePlanSection('Welcome');
      controller.addSongToServicePlan(song);
      final songItem = controller.selectedServicePlan!.items.last;

      controller.updateServicePlanItemNotes(
        songItem,
        'Start in G; repeat the chorus.',
      );
      controller.updateSelectedServicePlanDate(DateTime.utc(2026, 8, 9));
      controller.reorderServicePlanItems(1, 0);

      final items = controller.selectedServicePlan!.items;
      expect(items.first.songId, song.id);
      expect(items.first.notes, 'Start in G; repeat the chorus.');
      expect(items.last.title, 'Welcome');
      expect(controller.selectedServicePlan!.date.year, 2026);
      expect(controller.selectedServicePlan!.date.month, 8);
      expect(controller.selectedServicePlan!.date.day, 9);
      await controller.flushPendingSave();
      controller.dispose();
    },
  );

  test(
    'creates, edits, duplicates, filters, sorts, and deletes songs',
    () async {
      final controller = LibraryController(
        repository: SongRepository(store: _MemorySongStore()),
        autosaveDelay: const Duration(days: 1),
      );

      final created = controller.createSong();
      controller.updateTitle('New Arrangement');
      controller.updateArtist('A Writer');
      controller.updateKey('Bb');
      controller.updateTempo('84');

      expect(controller.selectedSong!.title, 'New Arrangement');
      expect(controller.selectedSong!.artist, 'A Writer');
      expect(controller.selectedSong!.key, 'Bb');
      expect(controller.selectedSong!.tempo, 84);
      expect(
        controller.selectedSong!.chordPro,
        contains('{title: New Arrangement}'),
      );
      expect(controller.selectedSong!.chordPro, contains('{artist: A Writer}'));

      final duplicate = controller.duplicateSong(controller.selectedSong!);
      expect(duplicate!.title, 'New Arrangement Copy');
      expect(duplicate.chordPro, contains('{title: New Arrangement Copy}'));

      controller.setSearchQuery('writer');
      expect(
        controller.visibleSongs.map((song) => song.id),
        contains(created.id),
      );
      controller.setSongSort(SongSort.artist);
      expect(controller.visibleSongs.first.artist, 'A Writer');

      controller.deleteSong(duplicate);
      expect(controller.songs, isNot(contains(duplicate)));

      await controller.flushPendingSave();
      controller.dispose();
    },
  );
}
