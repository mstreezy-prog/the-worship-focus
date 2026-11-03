import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
// Pinned renderer diagnostics let these checks inspect actual beam coordinates.
// ignore: implementation_imports
import 'package:flutter_notemus/src/rendering/grand_staff_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/score_display_preferences.dart';
import 'package:worship_focus_studio/services/music_xml_display_transformer.dart';
import 'package:worship_focus_studio/services/notation_renderer.dart';

import 'fixtures/music_xml_engraving_cases.dart';

Staff staff(String xml) =>
    MusicXMLParser.scoreFromMusicXML(xml).staffGroups.single.staves.single;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('inherits divisions and meter without inventing quarter notes', () {
    final measures = staff(inheritedTimingXml).measures;
    for (final measure in measures) {
      expect(measure.currentMusicalValue, closeTo(0.75, 0.000001));
    }
    expect(measures[0].elements.take(3).map((e) => e.runtimeType), [
      Clef,
      KeySignature,
      TimeSignature,
    ]);
    expect(measures[2].elements.whereType<Note>().first.duration.dots, 1);
  });

  test('keeps a single voice numbered other than one', () {
    expect(
      staff(numberedVoiceXml).measures.single.elements.whereType<Note>(),
      hasLength(1),
    );
  });

  test('forward gaps occupy time without drawing an invented note', () {
    final measure = staff(forwardGapXml).measures.single;
    expect(measure.elements.whereType<Space>().single.realValue, 0.25);
    expect(measure.currentMusicalValue, 0.75);
    expect(measure.elements.whereType<Note>(), hasLength(1));
  });

  test('chord tones share one duration and hidden notes retain their time', () {
    final chordMeasure = staff(simultaneousChordXml).measures.single;
    expect(chordMeasure.elements.whereType<Chord>().single.notes, hasLength(2));
    expect(chordMeasure.currentMusicalValue, 0.75);
    final hiddenMeasure = staff(graceAndHiddenXml).measures.single;
    expect(hiddenMeasure.currentMusicalValue, 0.75);
    expect(hiddenMeasure.elements.whereType<Space>(), hasLength(1));
  });

  test('backup preserves simultaneous voice durations', () {
    final measure =
        staff(scoreXml(polyphonicMeasures(1))).measures.single
            as MultiVoiceMeasure;
    expect(measure.voiceCount, 2);
    for (final voice in measure.voices) {
      final duration = voice.elements.whereType<Note>().fold(
        0.0,
        (sum, note) => sum + note.duration.realValue,
      );
      expect(duration, 0.75);
    }
  });

  test('mixed tuplets count rests and each written duration', () {
    final tuplet = Tuplet(
      actualNotes: 3,
      normalNotes: 2,
      elements: [
        Note(
          pitch: const Pitch(step: 'C', octave: 4),
          duration: const Duration(DurationType.sixteenth),
        ),
        Rest(duration: const Duration(DurationType.sixteenth)),
        Note(
          pitch: const Pitch(step: 'D', octave: 4),
          duration: const Duration(DurationType.eighth),
        ),
      ],
    );
    expect(tuplet.totalDuration, closeTo(1 / 6, 0.000001));
  });

  test(
    'harmony has its own style and does not recolor music or expressions',
    () {
      final xml = scoreXml('''<measure number="1">$meter68
<harmony><root><root-step>G</root-step></root><kind>major</kind></harmony>
${noteXml(ticks: 24)}</measure>''');
      final chord = staff(
        MusicXmlDisplayTransformer.prepare(xml),
      ).measures.single.elements.whereType<MusicText>().single;
      expect(chord.type, TextType.chord);
      final theme = NotationRenderer.scoreThemeFor(
        const ScoreDisplayPreferences(
          chordFontSize: 34,
          chordColor: ScoreChordColor.blue,
        ),
      );
      expect(theme.chordTextStyle?.fontSize, 34);
      expect(theme.chordTextStyle?.color, Color(ScoreChordColor.blue.value));
      expect(theme.noteheadColor, Colors.black);
      expect(theme.expressionTextStyle?.fontSize, 19);
    },
  );

  test(
    'grand staff beams and noteheads use the same vertical origin',
    () async {
      await NotationRenderer.initialize();
      final score = MusicXMLParser.scoreFromMusicXML(beamsXml);
      final painter = GrandStaffPainter(
        groups: score.staffGroups,
        staffSpace: 12,
        metadata: SmuflMetadata(),
        theme: NotationRenderer.scoreTheme,
        availableWidth: 804,
      );
      final layout = painter.layoutDiagnostics.single;
      expect(layout.engine.advancedBeamGroups, isNotEmpty);
      for (final note
          in layout.elements.map((e) => e.element).whereType<Note>()) {
        final pitch = StaffPositionCalculator.calculate(
          note.pitch,
          Clef(clefType: ClefType.treble),
        );
        final expected = StaffPositionCalculator.toPixelY(
          pitch,
          12,
          painter.staffBaseline,
        );
        expect(layout.engine.noteYPositions[note], expected);
      }
    },
  );

  test('wrapped systems retain all voices and inherited meter', () async {
    await NotationRenderer.initialize();
    final score = MusicXMLParser.scoreFromMusicXML(
      scoreXml(polyphonicMeasures(4)),
    );
    final painter = GrandStaffPainter(
      groups: score.staffGroups,
      staffSpace: 12,
      metadata: SmuflMetadata(),
      theme: NotationRenderer.scoreTheme,
      availableWidth: 220,
    );
    expect(
      painter.layoutDiagnostics.map((l) => l.system).toSet().length,
      greaterThan(1),
    );
    final notes = painter.layoutDiagnostics
        .expand((l) => l.elements)
        .where((e) => e.element is Note);
    expect(notes, hasLength(12));
  });

  test('later wrapped measures keep compound-meter beams', () async {
    await NotationRenderer.initialize();
    final measure = [
      for (var i = 0; i < 6; i++) noteXml(type: 'eighth'),
    ].join();
    final score = MusicXMLParser.scoreFromMusicXML(
      scoreXml(
        '<measure number="1">$meter68$measure</measure>'
        '<measure number="2">$measure</measure>'
        '<measure number="3">$measure</measure>',
      ),
    );
    final painter = GrandStaffPainter(
      groups: score.staffGroups,
      staffSpace: 12,
      metadata: SmuflMetadata(),
      theme: NotationRenderer.scoreTheme,
      availableWidth: 320,
    );
    for (final layout in painter.layoutDiagnostics) {
      expect(
        layout.engine.advancedBeamGroups.map((group) => group.notes.length),
        everyElement(3),
      );
    }
  });

  test('beam grouping keeps intervening chord labels on their own notes', () async {
    await NotationRenderer.initialize();
    const harmony =
        '<harmony><root><root-step>C</root-step></root><kind>major</kind></harmony>';
    final xml = scoreXml(
      '<measure number="1">$meter68'
      '${noteXml(type: 'eighth', step: 'C')}${noteXml(type: 'eighth', step: 'D')}'
      '$harmony${noteXml(type: 'eighth', step: 'E')}'
      '${noteXml(type: 'eighth', step: 'F')}${noteXml(type: 'eighth', step: 'G')}${noteXml(type: 'eighth', step: 'A')}</measure>',
    );
    final score = MusicXMLParser.scoreFromMusicXML(
      MusicXmlDisplayTransformer.prepare(xml),
    );
    final painter = GrandStaffPainter(
      groups: score.staffGroups,
      staffSpace: 12,
      metadata: SmuflMetadata(),
      theme: NotationRenderer.scoreTheme,
      availableWidth: 804,
    );
    final elements = painter.layoutDiagnostics.single.elements;
    final label = elements.singleWhere(
      (e) =>
          e.element is MusicText &&
          (e.element as MusicText).type == TextType.chord,
    );
    final note = elements.singleWhere(
      (e) => e.element is Note && (e.element as Note).pitch.step == 'E',
    );
    expect(label.position.dx, note.position.dx);
  });

  test('beamed chord tones share the surrounding beam geometry', () async {
    await NotationRenderer.initialize();
    final xml = scoreXml(
      '<measure number="1">$meter68'
      '${noteXml(type: 'eighth')}${noteXml(type: 'eighth', step: 'D')}'
      '${noteXml(type: 'eighth', step: 'E')}${noteXml(type: 'eighth', step: 'G', chord: true)}'
      '${noteXml(type: 'eighth', step: 'F')}${noteXml(type: 'eighth', step: 'G')}${noteXml(type: 'eighth', step: 'A')}</measure>',
    );
    final score = MusicXMLParser.scoreFromMusicXML(xml);
    final painter = GrandStaffPainter(
      groups: score.staffGroups,
      staffSpace: 12,
      metadata: SmuflMetadata(),
      theme: NotationRenderer.scoreTheme,
      availableWidth: 804,
    );
    final layout = painter.layoutDiagnostics.single;
    final chord = layout.elements
        .map((e) => e.element)
        .whereType<Chord>()
        .single;
    expect(chord.beam, BeamType.end);
    expect(
      layout.engine.advancedBeamGroups.any(
        (group) => chord.notes.every(group.notes.contains),
      ),
      isTrue,
    );
  });
}
