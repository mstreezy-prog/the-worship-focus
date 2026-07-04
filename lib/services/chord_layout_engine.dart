import 'chordpro_parser.dart';

class ChordLayoutLine {
  final String lyrics;
  final List<ChordToken> chords;

  ChordLayoutLine({
    required this.lyrics,
    required this.chords,
  });
}

class ChordLayoutEngine {
  static List<ChordLayoutLine> build(String input) {
    final parsed = ChordProParser.parse(input);

    return parsed
        .map(
          (line) => ChordLayoutLine(
            lyrics: line.lyrics,
            chords: line.chords,
          ),
        )
        .toList();
  }
}
