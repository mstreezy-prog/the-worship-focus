import 'package:flutter/foundation.dart';

import '../models/score_annotation.dart';
import '../services/chordpro_document.dart';

/// Keeps document markings and history separate from the reader widgets.
class ReaderAnnotationController extends ChangeNotifier {
  ReaderAnnotationController(Map<String, List<ScoreAnnotationStroke>> initial)
    : _annotations = Map.unmodifiable(initial);

  Map<String, List<ScoreAnnotationStroke>> _annotations;
  final _undo = <Map<String, List<ScoreAnnotationStroke>>>[];
  final _redo = <Map<String, List<ScoreAnnotationStroke>>>[];

  Map<String, List<ScoreAnnotationStroke>> get annotations => _annotations;
  bool get hasMarks => _annotations.values.any((strokes) => strokes.isNotEmpty);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void update(String anchor, List<ScoreAnnotationStroke> strokes) {
    _recordChange({
      ..._annotations,
      anchor: List<ScoreAnnotationStroke>.unmodifiable(strokes),
    });
  }

  /// Clear the active document in one undoable operation, including offscreen pages.
  void clear() {
    if (!hasMarks) return;
    _recordChange(const {});
  }

  void _recordChange(Map<String, List<ScoreAnnotationStroke>> next) {
    _undo.add(_annotations);
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
    _annotations = Map<String, List<ScoreAnnotationStroke>>.unmodifiable(next);
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_annotations);
    _annotations = _undo.removeLast();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_annotations);
    _annotations = _redo.removeLast();
    notifyListeners();
  }

  /// Content plus occurrence avoids attaching ink to a different line after edits.
  /// Lyrics survive transposition; identical repeated lines remain distinct.
  static Map<ChordProContentBlock, String> anchors(
    List<ChordProContentBlock> blocks,
  ) {
    final occurrences = <String, int>{};
    return {
      for (final block in blocks)
        block: (() {
          final text = switch (block) {
            ChordProTextBlock(:final line) => 'line:${line.lyrics}',
            ChordProDiagramBlock(:final definition) =>
              'shape:${definition.name}:${definition.frets}',
          };
          final occurrence = occurrences.update(
            text,
            (value) => value + 1,
            ifAbsent: () => 0,
          );
          return '$occurrence:$text';
        })(),
    };
  }
}
