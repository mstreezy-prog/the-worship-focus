import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/controllers/reader_annotation_controller.dart';
import 'package:worship_focus_studio/models/music_xml_arrangement.dart';
import 'package:worship_focus_studio/models/performance_content.dart';
import 'package:worship_focus_studio/models/score_annotation.dart';
import 'package:worship_focus_studio/models/score_display_preferences.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/screens/performance_screen.dart';
import 'package:worship_focus_studio/services/chordpro_document.dart';
import 'package:worship_focus_studio/services/notation_renderer.dart';
import 'package:worship_focus_studio/widgets/chordpro_performance_view.dart';
import 'package:worship_focus_studio/widgets/score_annotation_canvas.dart';

import 'music_stand_swipe_test.dart' as sample;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(NotationRenderer.initialize);
  const stroke = ScoreAnnotationStroke(
    points: [
      ScoreAnnotationPoint(x: .2, y: .3),
      ScoreAnnotationPoint(x: .8, y: .3),
    ],
    color: ScoreAnnotationColor.red,
    style: ScoreAnnotationStyle.pen,
  );

  void iPad(WidgetTester tester, {double width = 1024}) {
    tester.view.physicalSize = Size(width, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final header = find.byKey(const ValueKey('music-stand-header'));
  final footer = find.byKey(const ValueKey('music-stand-footer'));
  final surface = find.byKey(const ValueKey('music-stand-tap-surface'));

  test('clear is a single undoable change across all document anchors', () {
    final controller = ReaderAnnotationController({
      'first': [stroke],
      'offscreen': [stroke],
    });
    var changes = 0;
    controller.addListener(() => changes++);
    controller.clear();
    expect(controller.hasMarks, isFalse);
    expect(changes, 1);
    controller.clear();
    expect(changes, 1);
    controller.undo();
    expect(controller.annotations.keys, ['first', 'offscreen']);
    expect(controller.hasMarks, isTrue);
    controller.redo();
    expect(controller.annotations, isEmpty);
    controller.dispose();
  });

  testWidgets(
    'tap hides and restores both bars without changing chart pagination',
    (tester) async {
      iPad(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceScreen(
            songs: [
              Song(
                id: 'chart',
                title: 'Chart',
                chordPro: List.generate(50, (i) => '[C]Line $i').join('\n'),
              ),
            ],
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pager = tester.widget<PageView>(
        find.byKey(const ValueKey('music-stand-song-reader')),
      );
      final count = pager.childrenDelegate.estimatedChildCount;
      pager.controller!.jumpToPage(1);
      await tester.pumpAndSettle();
      final oldTop = tester
          .getTopLeft(find.byType(ChordProPerformanceView).first)
          .dy;
      await tester.tap(surface);
      await tester.pumpAndSettle();
      expect(header, findsNothing);
      expect(footer, findsNothing);
      expect(pager.controller!.page, 1);
      expect(
        tester
            .widget<PageView>(
              find.byKey(const ValueKey('music-stand-song-reader')),
            )
            .childrenDelegate
            .estimatedChildCount,
        count,
      );
      expect(
        tester.getTopLeft(find.byType(ChordProPerformanceView).first).dy,
        lessThan(oldTop),
      );
      await tester.tap(surface);
      await tester.pumpAndSettle();
      expect(header, findsOneWidget);
      expect(footer, findsOneWidget);
      expect(pager.controller!.page, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Pencil taps do not hide controls; visible eraser removes a stroke',
    (tester) async {
      iPad(tester, width: 820);
      Map<String, List<ScoreAnnotationStroke>> saved = {};
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceScreen(
            songs: [Song(id: 'chart', title: 'Chart', chordPro: '[C]Grace')],
            initialIndex: 0,
            onAnnotationsChanged: (_, marks) => saved = marks,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Eraser').hitTestable(), findsOneWidget);
      expect(find.text('Remove pencil marks').hitTestable(), findsOneWidget);
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Pencil'));
      await tester.pump();
      final area = tester.getRect(find.byType(ScoreAnnotationCanvas).first);
      final point = Offset(
        area.left + area.width * .4,
        area.top + area.height * .4,
      );
      final pencil = await tester.createGesture(kind: PointerDeviceKind.stylus);
      await pencil.down(point);
      await pencil.up();
      await tester.pumpAndSettle();
      expect(saved.values.single, hasLength(1));
      expect(header, findsOneWidget);
      expect(footer, findsOneWidget);
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Eraser'));
      await tester.pump();
      final eraser = await tester.createGesture(kind: PointerDeviceKind.stylus);
      await eraser.down(point);
      await eraser.up();
      await tester.pumpAndSettle();
      expect(saved.values.single, isEmpty);
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Undo marking'));
      await tester.pumpAndSettle();
      expect(saved.values.single, hasLength(1));
      expect(header, findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Remove pencil marks clears chart anchors and Undo restores saved marks',
    (tester) async {
      iPad(tester);
      final anchors = ReaderAnnotationController.anchors(
        ChordProDocument.parse('[C]Grace\n[G]Peace').blocks,
      ).values.toList();
      Map<String, List<ScoreAnnotationStroke>> saved = {};
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceScreen(
            songs: [
              Song(
                id: 'chart',
                title: 'Chart',
                chordPro: '[C]Grace\n[G]Peace',
                chordProAnnotations: {
                  for (final anchor in anchors) anchor: [stroke],
                },
              ),
            ],
            initialIndex: 0,
            onAnnotationsChanged: (_, marks) => saved = marks,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Remove pencil marks'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(header, findsOneWidget);
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Undo marking'));
      await tester.pumpAndSettle();
      expect(saved.keys, anchors);
      expect(saved.values.every((strokes) => strokes.length == 1), isTrue);
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Redo marking'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
    },
  );

  testWidgets(
    'XML fullscreen reclaims space and clear affects only the selected score',
    (tester) async {
      iPad(tester);
      final changed = <MusicXmlArrangementType, List<ScoreAnnotationStroke>>{};
      final xml = sample.longXml();
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceScreen(
            songs: [
              Song(
                id: 'score',
                title: 'Score',
                chordPro: '',
                leadSheet: MusicXmlArrangement(
                  fileName: 'lead.musicxml',
                  sourceXml: xml,
                  annotations: [stroke],
                ),
                fullPiano: MusicXmlArrangement(
                  fileName: 'piano.musicxml',
                  sourceXml: xml,
                  annotations: [stroke],
                ),
              ),
            ],
            initialIndex: 0,
            initialContent: PerformanceContent.leadSheet,
            initialScoreDisplayPreferences: const ScoreDisplayPreferences(),
            onScoreAnnotationsChanged: (_, type, marks) =>
                changed[type] = marks,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      final reader = find.byKey(const ValueKey('xml-vertical-reader'));
      final scroll = tester.widget<SingleChildScrollView>(reader).controller!;
      await tester.drag(reader, const Offset(0, -300));
      await tester.pumpAndSettle();
      final offset = scroll.offset;
      final height = tester.getSize(reader).height;
      await tester.tap(surface);
      await tester.pumpAndSettle();
      expect(tester.getSize(reader).height, greaterThan(height));
      expect(scroll.offset, closeTo(offset, 1));
      expect(header, findsNothing);
      await tester.tap(surface);
      await tester.pumpAndSettle();
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Remove pencil marks'));
      await tester.pumpAndSettle();
      expect(changed[MusicXmlArrangementType.leadSheet], isEmpty);
      expect(changed.containsKey(MusicXmlArrangementType.fullPiano), isFalse);
      await tester.tap(find.text('Full Piano'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScoreAnnotationCanvas>(find.byType(ScoreAnnotationCanvas))
            .annotations,
        hasLength(1),
      );
      await tester.tap(find.text('Lead Sheet').first);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      if (find.byTooltip('Pencil').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Pencil tools'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Undo marking'));
      await tester.pumpAndSettle();
      expect(changed[MusicXmlArrangementType.leadSheet], hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
