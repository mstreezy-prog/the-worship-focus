import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/controllers/library_controller.dart';
import 'package:worship_focus_studio/controllers/reader_annotation_controller.dart';
import 'package:worship_focus_studio/models/score_annotation.dart';
import 'package:worship_focus_studio/models/service_plan.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/screens/performance_screen.dart';
import 'package:worship_focus_studio/services/chordpro_document.dart';
import 'package:worship_focus_studio/services/reader_document_service.dart';
import 'package:worship_focus_studio/services/reader_pagination.dart';
import 'package:worship_focus_studio/services/recent_service_store.dart';
import 'package:worship_focus_studio/services/service_plan_repository.dart';
import 'package:worship_focus_studio/services/service_plan_store.dart';
import 'package:worship_focus_studio/services/song_repository.dart';
import 'package:worship_focus_studio/services/song_store.dart';
import 'package:worship_focus_studio/widgets/score_annotation_canvas.dart';

class _Recent implements RecentServiceStore {
  String? id;
  @override
  Future<String?> read() async => id;
  @override
  Future<void> write(String value) async {
    id = value;
  }
}

class _Songs implements SongStore {
  List<Song>? songs;
  @override
  Future<List<Song>?> readSongs() async => songs;
  @override
  Future<void> writeSongs(List<Song> values) async {
    songs = values.map((song) => Song.fromJson(song.toJson())).toList();
  }
}

class _Plans implements ServicePlanStore {
  List<ServicePlan>? plans;
  @override
  Future<List<ServicePlan>?> readPlans() async => plans;
  @override
  Future<void> writePlans(List<ServicePlan> values) async {
    plans = List.of(values);
  }
}

void main() {
  const stroke = ScoreAnnotationStroke(
    points: [
      ScoreAnnotationPoint(x: .2, y: .3),
      ScoreAnnotationPoint(x: .8, y: .3),
    ],
    color: ScoreAnnotationColor.red,
    style: ScoreAnnotationStyle.pen,
  );

  test(
    'anchors survive transposition, insertion and pagination; repeats stay distinct',
    () {
      final blocks = ChordProDocument.parse(
        '[C]Grace\n[C]Grace\n[D]Peace',
      ).blocks;
      final anchors = ReaderAnnotationController.anchors(
        blocks,
      ).values.toList();
      expect(anchors[0], isNot(anchors[1]));
      final changed = ChordProDocument.parse(
        'New introduction\n[D]Grace\n[D]Grace\n[E]Peace',
      ).blocks;
      expect(
        ReaderAnnotationController.anchors(changed).values.skip(1),
        anchors,
      );
      for (final columns in [false, true]) {
        final pages = ReaderPagination.paginate(
          fontSize: 36,
          twoColumns: columns,
          blocks: blocks,
          hasInfo: true,
          maxHeight: 300,
        );
        expect(
          pages.expand((page) => page.columns).expand((column) => column),
          blocks,
        );
      }
      final controller = ReaderAnnotationController({});
      controller.update(anchors.first, [stroke]);
      controller.undo();
      expect(controller.annotations, isEmpty);
      controller.redo();
      expect(controller.annotations[anchors.first], [stroke]);
      controller.dispose();
    },
  );

  test(
    'session transpose updates directive key without mutating saved chart',
    () {
      final song = Song(
        id: 'a',
        title: 'Grace',
        key: 'C',
        chordPro:
            '{key: C}\n[C]Grace [G/B]peace\n{define: C frets x 3 2 0 1 0}\n{chord: C}',
      );
      final displayed = ReaderDocumentService.transpose(song, 2);
      expect(displayed.chordPro, contains('{key: D}'));
      expect(displayed.chordPro, contains('[D]Grace [A/C#]peace'));
      expect(displayed.chordPro, isNot(contains('{chord:')));
      expect(song.chordPro, contains('[C]Grace'));
      expect(ReaderDocumentService.transpose(song, 12), same(song));
    },
  );

  test(
    'annotations autosave through song JSON and recent service survives relaunch',
    () async {
      final songs = _Songs();
      final plans = _Plans();
      final recent = _Recent();
      LibraryController makeController() => LibraryController(
        repository: SongRepository(store: songs),
        servicePlanRepository: ServicePlanRepository(store: plans),
        recentServiceStore: recent,
        autosaveDelay: const Duration(days: 1),
      );
      final first = makeController();
      await first.initialize();
      final morning = first.createServicePlan(title: 'Morning');
      first.createServicePlan(title: 'Evening');
      first.selectServicePlan(morning);
      final song = first.songs.first;
      first.updateChordProAnnotations(song.id, {
        'line': [stroke],
      });
      await first.flushPendingSave();
      first.dispose();
      final second = makeController();
      await second.initialize();
      expect(second.selectedServicePlan?.id, morning.id);
      expect(
        second.songs.first.chordProAnnotations['line']!.single.toJson(),
        stroke.toJson(),
      );
      second.dispose();
    },
  );

  testWidgets(
    'Pencil marking survives rotation, undo, redo and song navigation',
    (tester) async {
      tester.view.physicalSize = const Size(820, 1180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, List<ScoreAnnotationStroke>> saved = {};
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceScreen(
            songs: [
              Song(id: 'a', title: 'Grace', chordPro: '[C]Amazing grace'),
              Song(id: 'b', title: 'Peace', chordPro: '[G]Peace'),
            ],
            initialIndex: 0,
            onAnnotationsChanged: (id, value) {
              if (id == 'a') saved = value;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Pencil'));
      await tester.pump();
      final area = tester.getRect(find.byType(ScoreAnnotationCanvas).first);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.stylus,
      );
      await gesture.down(area.centerLeft + const Offset(20, 20));
      await gesture.moveBy(const Offset(70, 0));
      await gesture.up();
      await tester.pump();
      expect(saved.values.single, hasLength(1));
      await tester.tap(find.byTooltip('Reader settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Increase font size'));
      await tester.tap(find.text('Two columns'));
      await tester.pump();
      Navigator.of(tester.element(find.text('Reader settings'))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScoreAnnotationCanvas>(
              find.byType(ScoreAnnotationCanvas).first,
            )
            .annotations,
        hasLength(1),
      );
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Undo marking'));
      await tester.pump();
      expect(saved, isEmpty);
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Redo marking'));
      await tester.pump();
      tester.view.physicalSize = const Size(1180, 820);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScoreAnnotationCanvas>(
              find.byType(ScoreAnnotationCanvas).first,
            )
            .annotations,
        hasLength(1),
      );
      await tester.tap(find.byTooltip('Next song'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous song'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScoreAnnotationCanvas>(
              find.byType(ScoreAnnotationCanvas).first,
            )
            .annotations,
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('eraser removes sparse stroke segments and supports undo', (
    tester,
  ) async {
    final key = GlobalKey<ScoreAnnotationCanvasState>();
    List<ScoreAnnotationStroke> strokes = [stroke];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 200,
            child: ScoreAnnotationCanvas(
              key: key,
              annotations: strokes,
              tool: ScoreAnnotationTool.eraser,
              color: ScoreAnnotationColor.red,
              onChanged: (value) => strokes = value,
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(ScoreAnnotationCanvas));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.stylus);
    await gesture.down(rect.topLeft + const Offset(200, 60));
    await gesture.up();
    await tester.pump();
    expect(strokes, isEmpty);
    key.currentState!.undo();
    await tester.pump();
    expect(strokes, hasLength(1));
  });
}
