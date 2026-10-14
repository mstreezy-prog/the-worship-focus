import 'chord_layout_engine.dart';
import 'chordpro_parser.dart';

/// A rendered piece of a ChordPro chart, in source order.
sealed class ChordProContentBlock {
  const ChordProContentBlock();
}

/// A normal lyric line, with its chord symbols positioned over the words.
class ChordProTextBlock extends ChordProContentBlock {
  const ChordProTextBlock(this.line);

  final ChordLayoutLine line;
}

/// A chord-grid directive that should be shown at this point in a chart.
class ChordProDiagramBlock extends ChordProContentBlock {
  const ChordProDiagramBlock(this.definition);

  final ChordDiagramDefinition definition;
}

/// A string-instrument chord shape declared by a ChordPro directive.
class ChordDiagramDefinition {
  const ChordDiagramDefinition({
    required this.name,
    required this.baseFret,
    required this.frets,
    this.fingers = const [],
  });

  final String name;
  final int baseFret;

  /// One position for every string, from the lowest-pitched to highest-pitched.
  ///
  /// A negative value is muted; zero is open; positive values are fret positions.
  final List<int> frets;
  final List<String> fingers;
}

/// Parses the subset of ChordPro that affects the reader's document layout.
///
/// Definitions are retained for later `{chord: Name}` directives, while all
/// other directives remain non-rendering so existing ChordPro charts keep their
/// current appearance.
class ChordProDocument {
  const ChordProDocument({required this.blocks});

  final List<ChordProContentBlock> blocks;

  factory ChordProDocument.parse(String source) {
    final definitions = <String, ChordDiagramDefinition>{};
    final blocks = <ChordProContentBlock>[];

    for (final sourceLine in source.split('\n')) {
      final directive = _directiveFor(sourceLine);
      if (directive == null) {
        final parsed = ChordProParser.parse(sourceLine);
        blocks.addAll(
          parsed.map(
            (line) => ChordProTextBlock(
              ChordLayoutLine(lyrics: line.lyrics, chords: line.chords),
            ),
          ),
        );
        continue;
      }

      switch (directive.name) {
        case 'define':
          final name = _firstArgument(directive.arguments);
          if (_diagramDisabled(directive.arguments)) {
            if (name != null) definitions.remove(_definitionKey(name));
            break;
          }
          final definition = _definitionFromArguments(directive.arguments);
          if (definition != null) {
            definitions[_definitionKey(definition.name)] = definition;
          }
          break;
        case 'chord':
          if (_diagramDisabled(directive.arguments)) break;
          final inlineDefinition = _definitionFromArguments(
            directive.arguments,
          );
          final name = _firstArgument(directive.arguments);
          final definition =
              inlineDefinition ??
              (name == null ? null : definitions[_definitionKey(name)]);
          if (definition != null) blocks.add(ChordProDiagramBlock(definition));
          break;
        default:
          // ChordPro metadata and other directives are intentionally not lines.
          break;
      }
    }

    return ChordProDocument(blocks: blocks);
  }

  static _Directive? _directiveFor(String sourceLine) {
    final match = RegExp(
      r'^\s*\{\s*([A-Za-z_-]+)\s*:\s*(.*?)\s*\}\s*$',
    ).firstMatch(sourceLine);
    if (match == null) return null;
    return _Directive(
      name: match.group(1)!.toLowerCase(),
      arguments: match.group(2)!.trim(),
    );
  }

  static ChordDiagramDefinition? _definitionFromArguments(String arguments) {
    final tokens = _tokens(arguments);
    if (tokens.isEmpty) return null;
    final name = _unbracket(tokens.first);
    final fretsStart = _indexOfKeyword(tokens, 'frets');
    if (fretsStart == -1) return null;
    final frets = <int>[];
    for (var index = fretsStart + 1; index < tokens.length; index++) {
      if (_isKeyword(tokens[index])) break;
      final fret = _fret(tokens[index]);
      if (fret == null) return null;
      frets.add(fret);
    }
    if (frets.length < 4) return null;

    final baseFretStart = _indexOfAnyKeyword(tokens, const [
      'base-fret',
      'base_fret',
    ]);
    final baseFret = baseFretStart == -1
        ? 1
        : int.tryParse(tokens.elementAtOrNull(baseFretStart + 1) ?? '') ?? 1;
    final fingersStart = _indexOfKeyword(tokens, 'fingers');
    final fingers = <String>[];
    if (fingersStart != -1) {
      for (var index = fingersStart + 1; index < tokens.length; index++) {
        if (_isKeyword(tokens[index])) break;
        fingers.add(tokens[index]);
      }
    }

    return ChordDiagramDefinition(
      name: name,
      baseFret: baseFret < 1 ? 1 : baseFret,
      frets: frets,
      fingers: fingers,
    );
  }

  static List<String> _tokens(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();

  static String? _firstArgument(String arguments) {
    final tokens = _tokens(arguments);
    return tokens.isEmpty ? null : _unbracket(tokens.first);
  }

  static String _unbracket(String value) =>
      value.replaceFirst(RegExp(r'^\['), '').replaceFirst(RegExp(r'\]$'), '');

  static String _definitionKey(String name) => name.toLowerCase();

  static int _indexOfKeyword(List<String> tokens, String keyword) =>
      _indexOfAnyKeyword(tokens, [keyword]);

  static int _indexOfAnyKeyword(List<String> tokens, List<String> keywords) {
    for (var index = 0; index < tokens.length; index++) {
      if (keywords.contains(tokens[index].toLowerCase())) return index;
    }
    return -1;
  }

  static bool _isKeyword(String token) => const {
    'base-fret',
    'base_fret',
    'frets',
    'fingers',
    'keys',
    'copy',
    'copyall',
    'diagram',
    'display',
    'format',
  }.contains(token.toLowerCase());

  static bool _diagramDisabled(String arguments) =>
      RegExp(r'\bdiagram\s+off\b', caseSensitive: false).hasMatch(arguments);

  static int? _fret(String value) {
    if (value.toLowerCase() == 'x' || value.toLowerCase() == 'n') return -1;
    return int.tryParse(value);
  }
}

class _Directive {
  const _Directive({required this.name, required this.arguments});

  final String name;
  final String arguments;
}
