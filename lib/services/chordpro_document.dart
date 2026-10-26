import 'chord_layout_engine.dart';
import 'chordpro_parser.dart';
import 'chordpro_directive.dart';

/// A rendered piece of a ChordPro chart, in source order.
sealed class ChordProContentBlock {
  const ChordProContentBlock();
}

/// A normal lyric line, with its chord symbols positioned over the words.
class ChordProTextBlock extends ChordProContentBlock {
  const ChordProTextBlock(this.line);

  final ChordLayoutLine line;
}

enum ChordProCommentStyle { standard, italic, boxed }

/// A section label or playing instruction, kept at its position in the chart.
class ChordProCommentBlock extends ChordProContentBlock {
  const ChordProCommentBlock(
    this.text, {
    this.style = ChordProCommentStyle.standard,
  });

  final String text;
  final ChordProCommentStyle style;
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
/// Comments remain in source order alongside lyrics and chord diagrams.
/// Definitions are retained for later `{chord: Name}` directives; metadata and
/// unsupported directives do not produce content blocks.
class ChordProDocument {
  const ChordProDocument({required this.blocks});

  final List<ChordProContentBlock> blocks;

  factory ChordProDocument.parse(String source) {
    final definitions = <String, ChordDiagramDefinition>{};
    final blocks = <ChordProContentBlock>[];

    List<ChordProContentBlock>? lastChorus;
    var lastChorusLabel = 'Chorus';
    int? chorusStart;
    var chorusLabel = 'Chorus';

    for (final sourceLine in source.split('\n')) {
      final directive = ChordProDirective.parse(sourceLine);
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
        case 'start_of_verse':
        case 'sov':
        case 'start_of_bridge':
        case 'sob':
          blocks.add(
            ChordProCommentBlock(
              directive.sectionLabel(
                directive.name == 'sov' || directive.name == 'start_of_verse'
                    ? 'Verse'
                    : 'Bridge',
              ),
            ),
          );
          break;
        case 'start_of_chorus':
        case 'soc':
          chorusLabel = directive.sectionLabel('Chorus');
          blocks.add(ChordProCommentBlock(chorusLabel));
          chorusStart = blocks.length;
          break;
        case 'end_of_chorus':
        case 'eoc':
          if (chorusStart != null) {
            lastChorus = List.of(blocks.sublist(chorusStart));
            lastChorusLabel = chorusLabel;
            chorusStart = null;
          }
          break;
        case 'chorus':
          blocks.add(
            ChordProCommentBlock(directive.sectionLabel(lastChorusLabel)),
          );
          if (lastChorus != null) {
            // Every occurrence needs distinct block identities for annotations.
            blocks.addAll(lastChorus.map(_copyBlock));
          }
          break;
        case 'comment':
        case 'c':
        case 'highlight':
        case 'comment_italic':
        case 'ci':
        case 'comment_box':
        case 'cb':
          if (directive.arguments.isNotEmpty) {
            blocks.add(
              ChordProCommentBlock(
                directive.arguments,
                style: switch (directive.name) {
                  'comment_italic' || 'ci' => ChordProCommentStyle.italic,
                  'comment_box' || 'cb' => ChordProCommentStyle.boxed,
                  _ => ChordProCommentStyle.standard,
                },
              ),
            );
          }
          break;
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

  static ChordProContentBlock _copyBlock(ChordProContentBlock block) =>
      switch (block) {
        ChordProTextBlock(:final line) => ChordProTextBlock(line),
        ChordProCommentBlock(:final text, :final style) => ChordProCommentBlock(
          text,
          style: style,
        ),
        ChordProDiagramBlock(:final definition) => ChordProDiagramBlock(
          definition,
        ),
      };

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
