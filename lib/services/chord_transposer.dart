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

    return source.replaceAllMapped(_chordPattern, (match) {
      final root = match.group(1)!;
      final suffix = match.group(2)!;
      final transposedSuffix = suffix.startsWith('/')
          ? '/${transposeChord(suffix.substring(1), semitones)}'
          : suffix;
      return '${_transposeNote(root, semitones)}$transposedSuffix';
    });
  }

  static String transposeChord(String chord, int semitones) {
    final slashIndex = chord.indexOf('/');
    final primary = slashIndex == -1 ? chord : chord.substring(0, slashIndex);
    final bass = slashIndex == -1 ? null : chord.substring(slashIndex + 1);
    final match = _rootPattern.firstMatch(primary);
    if (match == null) {
      return chord;
    }

    final transposed =
        '${_transposeNote(match.group(1)!, semitones)}${match.group(2)!}';
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
