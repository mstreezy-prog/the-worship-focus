import '../models/song.dart';
import 'chord_transposer.dart';
import 'chordpro_directive.dart';

/// The musician-facing details declared at the beginning of a ChordPro chart.
class ChordProPerformanceInfo {
  const ChordProPerformanceInfo({
    this.key,
    this.capo,
    this.tempo,
    this.timeSignature,
    this.songOrder,
    this.notes = const [],
  });

  final String? key;
  final int? capo;

  String? get soundingKey => key == null || capo == null
      ? null
      : ChordTransposer.transposeChord(key!, capo!);

  String? get capoSummary => capo == null
      ? null
      : [
          if (key != null) 'Key (shapes): $key',
          'Capo: $capo',
          if (soundingKey != null) 'Sounding key: $soundingKey',
        ].join(' | ');

  final String? tempo;
  final String? timeSignature;
  final String? songOrder;
  final List<String> notes;

  bool get hasDetails =>
      key != null ||
      capo != null ||
      tempo != null ||
      timeSignature != null ||
      songOrder != null ||
      notes.isNotEmpty;

  factory ChordProPerformanceInfo.fromSong(Song song) {
    final directives = _leadingDirectives(song.chordPro);
    final directiveTempo = _firstValue(directives, const [
      'tempo',
      'bpm',
      'metronome',
    ]);
    final savedTempo = song.tempo == null ? null : '${song.tempo} BPM';
    final notes = <String>[
      ..._allValues(directives, const ['notes', 'note']),
      ..._allValues(directives, const ['subtitle', 'st']),
    ];

    return ChordProPerformanceInfo(
      key: _firstValue(directives, const ['key', 'k']) ?? song.key,
      capo: _capo(directives),
      tempo: _tempoLabel(directiveTempo) ?? savedTempo,
      timeSignature: _firstValue(directives, const [
        'time',
        'time_signature',
        'time-signature',
        'timesig',
        'meter',
      ]),
      songOrder: _firstValue(directives, const [
        'order',
        'song_order',
        'song-order',
        'songorder',
        'sequence',
      ]),
      notes: notes,
    );
  }

  static Map<String, List<String>> _leadingDirectives(String source) {
    final result = <String, List<String>>{};

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) continue;
      final directive = ChordProDirective.parse(line);
      if (directive == null ||
          directive.name.startsWith('start_of_') ||
          const {'sov', 'soc', 'sob', 'chorus'}.contains(directive.name)) {
        break;
      }
      final name = directive.name;
      final value = directive.arguments;
      if (value.isNotEmpty) {
        result.putIfAbsent(name, () => []).add(value);
      }
    }
    return result;
  }

  static int? _capo(Map<String, List<String>> directives) {
    var value = _firstValue(directives, const ['capo']);
    if (value == null) {
      for (final meta in directives['meta'] ?? <String>[]) {
        final match = RegExp(
          r'^capo\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(meta);
        if (match != null) {
          value = match[1];
          break;
        }
      }
    }
    final fret = int.tryParse(value ?? '');
    return fret != null && fret >= 0 ? fret : null;
  }

  static String? _firstValue(
    Map<String, List<String>> directives,
    List<String> names,
  ) {
    for (final name in names) {
      final values = directives[name];
      if (values != null && values.isNotEmpty) return values.first;
    }
    return null;
  }

  static List<String> _allValues(
    Map<String, List<String>> directives,
    List<String> names,
  ) => [for (final name in names) ...?directives[name]];

  static String? _tempoLabel(String? value) {
    if (value == null || value.isEmpty) return null;
    return RegExp(r'\bbpm\b', caseSensitive: false).hasMatch(value)
        ? value
        : '$value BPM';
  }
}
