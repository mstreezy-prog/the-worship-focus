enum PerformanceTheme { dark, light }

enum ChordProColumnLayout { single, two }

class PerformancePreferences {
  const PerformancePreferences({
    this.fontSize = 20,
    this.theme = PerformanceTheme.dark,
    this.chordProColumns = ChordProColumnLayout.single,
    this.keepAwake = false,
  });

  final double fontSize;
  final PerformanceTheme theme;
  final ChordProColumnLayout chordProColumns;
  final bool keepAwake;

  PerformancePreferences copyWith({
    double? fontSize,
    PerformanceTheme? theme,
    ChordProColumnLayout? chordProColumns,
    bool? keepAwake,
  }) {
    return PerformancePreferences(
      fontSize: fontSize ?? this.fontSize,
      theme: theme ?? this.theme,
      chordProColumns: chordProColumns ?? this.chordProColumns,
      keepAwake: keepAwake ?? this.keepAwake,
    );
  }

  Map<String, Object> toJson() {
    return {
      'fontSize': fontSize,
      'theme': theme.name,
      'chordProColumns': chordProColumns.name,
      'keepAwake': keepAwake,
    };
  }

  factory PerformancePreferences.fromJson(Map<String, Object?> json) {
    final fontSize = (json['fontSize'] as num?)?.toDouble() ?? 20;
    final themeName = json['theme'] as String?;
    final columnName = json['chordProColumns'] as String?;
    return PerformancePreferences(
      fontSize: fontSize.clamp(14, 36).toDouble(),
      theme:
          PerformanceTheme.values
              .where((theme) => theme.name == themeName)
              .firstOrNull ??
          PerformanceTheme.dark,
      chordProColumns:
          ChordProColumnLayout.values
              .where((layout) => layout.name == columnName)
              .firstOrNull ??
          ChordProColumnLayout.single,
      keepAwake: json['keepAwake'] as bool? ?? false,
    );
  }
}
