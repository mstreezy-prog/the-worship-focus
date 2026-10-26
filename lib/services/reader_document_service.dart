import '../models/song.dart';
import 'chord_transposer.dart';
import 'chordpro_directive.dart';

/// Session-only transformations never change the saved chart.
class ReaderDocumentService {
  static Song transpose(Song song, int semitones) {
    if (semitones % 12 == 0) return song;
    final source = ChordTransposer.transposeChordPro(song.chordPro, semitones)
        .split('\n')
        .where(
          (line) => !const {
            'define',
            'chord',
          }.contains(ChordProDirective.parse(line)?.name),
        )
        .map(
          (line) => line.replaceFirstMapped(
            RegExp(
              r'^(\s*\{\s*(?:key|k)(?:\s*:\s*|\s+))([^}]+)(\}.*)$',
              caseSensitive: false,
            ),
            (match) =>
                '${match[1]}${ChordTransposer.transposeChord(match[2]!.trim(), semitones)}${match[3]}',
          ),
        )
        .join('\n');
    return song.copyWith(
      chordPro: source,
      key: song.key == null
          ? null
          : ChordTransposer.transposeChord(song.key!, semitones),
    );
  }
}
