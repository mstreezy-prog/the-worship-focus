import 'chordpro_directive.dart';

class ChordTransposer {
  static const _sharpNotes = <String>[
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static const _flatNotes = <String>[
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];

  static final _chordPattern = RegExp(r'(?<=\[)([A-G](?:#|b)?)([^\]]*)');
  static final _rootPattern = RegExp(r'^([A-G](?:#|b)?)(.*)$');

  static String transposeChordPro(String source, int semitones) {
    if (semitones % 12 == 0) {
      return source;
    }

    return source
        .split('\n')
        .map((line) {
          if (ChordProDirective.parse(line) != null ||
              line.trimLeft().startsWith('#')) {
            return line;
          }
          return line.replaceAllMapped(
            _chordPattern,
            (match) => transposeChord('${match[1]}${match[2]}', semitones),
          );
        })
        .join('\n');
  }

  static String transposeChord(String chord, int semitones) {
    if (semitones % 12 == 0) return chord;
    final slashIndex = chord.lastIndexOf('/');
    // A slash is an inversion only when followed by a note, not a quality (6/9).
    final hasBass =
        slashIndex != -1 &&
        RegExp(r'^[A-G](?:#|b)?$').hasMatch(chord.substring(slashIndex + 1));
    final primary = hasBass ? chord.substring(0, slashIndex) : chord;
    final bass = hasBass ? chord.substring(slashIndex + 1) : null;
    final match = _rootPattern.firstMatch(primary);
    if (match == null) return chord;
    final transposed = '${_transposeNote(match[1]!, semitones)}${match[2]!}';
    return bass == null
        ? transposed
        : '$transposed/${_transposeNote(bass, semitones)}';
  }

  static String _transposeNote(String note, int semitones) {
    var index = _sharpNotes.indexOf(note);
    final preferFlats = note.contains('b');
    if (index == -1) {
      index = _flatNotes.indexOf(note);
    }
    if (index == -1) {
      return note;
    }

    final transposedIndex = (index + semitones) % 12;
    return (preferFlats ? _flatNotes : _sharpNotes)[transposedIndex];
  }
}
