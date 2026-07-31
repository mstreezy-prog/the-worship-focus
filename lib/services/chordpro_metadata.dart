class ChordProMetadata {
  static String setDirective(String source, String name, String? value) {
    final aliases = name == 'title' ? '(?:title|t)' : RegExp.escape(name);
    final pattern = RegExp(
      '^\\s*\\{$aliases\\s*:[^}]*\\}\\s*(?:\\n|\$)',
      caseSensitive: false,
      multiLine: true,
    );
    final trimmed = value?.trim() ?? '';

    if (pattern.hasMatch(source)) {
      return source.replaceFirst(
        pattern,
        trimmed.isEmpty ? '' : '{$name: $trimmed}\n',
      );
    }
    if (trimmed.isEmpty) return source;
    return '{$name: $trimmed}\n$source';
  }
}
