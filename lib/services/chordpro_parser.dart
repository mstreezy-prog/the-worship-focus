class ChordToken {
  final String chord;
  final int position;

  ChordToken(this.chord, this.position);
}

class ParsedLine {
  final String lyrics;
  final List<ChordToken> chords;

  ParsedLine(this.lyrics, this.chords);
}

class ChordProParser {
  static List<ParsedLine> parse(String input) {
    final lines = input.split('\n');
    final result = <ParsedLine>[];

    for (final line in lines) {
      if (_isDirective(line)) {
        continue;
      }

      final chords = <ChordToken>[];
      final buffer = StringBuffer();

      int i = 0;
      int pos = 0;

      while (i < line.length) {
        if (line[i] == '[') {
          final end = line.indexOf(']', i);
          if (end != -1) {
            final chord = line.substring(i + 1, end);
            chords.add(ChordToken(chord, pos));
            i = end + 1;
            continue;
          }
        }

        buffer.write(line[i]);
        pos++;
        i++;
      }

      result.add(ParsedLine(buffer.toString(), chords));
    }

    return result;
  }

  static bool _isDirective(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('{') && trimmed.endsWith('}');
  }
}
