import '../models/song.dart';

/// The musician-facing details declared at the beginning of a ChordPro chart.
class ChordProPerformanceInfo {
  const ChordProPerformanceInfo({
    this.key,
    this.tempo,
    this.timeSignature,
    this.songOrder,
    this.notes = const [],
  });

  final String? key;
  final String? tempo;
  final String? timeSignature;
  final String? songOrder;
  final List<String> notes;

  bool get hasDetails =>
      key != null ||
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
      ..._allValues(directives, const ['comment', 'c', 'notes', 'note']),
      ..._allValues(directives, const ['subtitle', 'st']),
    ];

    return ChordProPerformanceInfo(
      key: _firstValue(directives, const ['key', 'k']) ?? song.key,
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
    final directive = RegExp(r'^\s*\{\s*([^:}]+)\s*:\s*([^}]*)\}\s*$');

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final match = directive.firstMatch(line);
      if (match == null) break;
      final name = match.group(1)!.trim().toLowerCase();
      final value = match.group(2)!.trim();
      if (value.isNotEmpty) {
        result.putIfAbsent(name, () => []).add(value);
      }
    }
    return result;
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
