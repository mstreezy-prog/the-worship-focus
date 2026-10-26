/// A whole-line ChordPro directive, with colon or whitespace arguments.
class ChordProDirective {
  const ChordProDirective({required this.name, required this.arguments});

  final String name;
  final String arguments;

  static final _pattern = RegExp(
    r'^\s*\{\s*([A-Za-z_][A-Za-z0-9_-]*)(?:\s*:\s*|\s+)?(.*?)\s*\}\s*$',
  );

  static ChordProDirective? parse(String line) {
    final match = _pattern.firstMatch(line);
    if (match == null) return null;
    return ChordProDirective(
      name: match[1]!.toLowerCase(),
      arguments: match[2]!.trim(),
    );
  }

  /// Section labels accept both plain text and the standard label attribute.
  String sectionLabel(String fallback) {
    final label = RegExp(
      r'''(?:^|\s)label\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s]+))''',
      caseSensitive: false,
    ).firstMatch(arguments);
    if (label != null) {
      final value = label[1] ?? label[2] ?? label[3]!;
      return value.isEmpty ? fallback : value;
    }
    return arguments.isEmpty || arguments.contains('=') ? fallback : arguments;
  }
}
