enum PerformanceTheme { dark, light }

enum ChordProColumnLayout { single, two }

enum ChordProChordColor {
  automatic('Match lyrics', null, null),
  blue('Blue', 0xFF174EA6, 0xFF90CAF9),
  burgundy('Burgundy', 0xFF8B1E3F, 0xFFFFA6BE),
  green('Green', 0xFF176B3A, 0xFF8DDCA8),
  purple('Purple', 0xFF663399, 0xFFD5B3FF);

  const ChordProChordColor(this.label, this.lightValue, this.darkValue);

  final String label;
  final int? lightValue, darkValue;

  int? valueFor(PerformanceTheme theme) =>
      theme == PerformanceTheme.dark ? darkValue : lightValue;
}

class PerformancePreferences {
  const PerformancePreferences({
    this.fontSize = 20,
    this.chordFontSize = defaultChordFontSize,
    this.chordColor = ChordProChordColor.automatic,
    this.theme = PerformanceTheme.dark,
    this.chordProColumns = ChordProColumnLayout.single,
    this.keepAwake = false,
  });

  /// Lyric size; chord appearance has independent preferences.
  final double fontSize;
  static const double defaultChordFontSize = 22;
  static const double minimumChordFontSize = 14;
  static const double maximumChordFontSize = 50;

  final double chordFontSize;
  final ChordProChordColor chordColor;
  final PerformanceTheme theme;
  final ChordProColumnLayout chordProColumns;
  final bool keepAwake;

  PerformancePreferences copyWith({
    double? fontSize,
    double? chordFontSize,
    ChordProChordColor? chordColor,
    PerformanceTheme? theme,
    ChordProColumnLayout? chordProColumns,
    bool? keepAwake,
  }) {
    return PerformancePreferences(
      fontSize: fontSize ?? this.fontSize,
      chordFontSize: (chordFontSize ?? this.chordFontSize)
          .clamp(minimumChordFontSize, maximumChordFontSize)
          .toDouble(),
      chordColor: chordColor ?? this.chordColor,
      theme: theme ?? this.theme,
      chordProColumns: chordProColumns ?? this.chordProColumns,
      keepAwake: keepAwake ?? this.keepAwake,
    );
  }

  Map<String, Object> toJson() {
    return {
      'fontSize': fontSize,
      'chordFontSize': chordFontSize,
      'chordColor': chordColor.name,
      'theme': theme.name,
      'chordProColumns': chordProColumns.name,
      'keepAwake': keepAwake,
    };
  }

  factory PerformancePreferences.fromJson(Map<String, Object?> json) {
    final fontSize = (json['fontSize'] as num?)?.toDouble() ?? 20;
    final themeName = json['theme'] as String?;
    final columnName = json['chordProColumns'] as String?;
    final lyricSize = fontSize.clamp(14, 36).toDouble();
    return PerformancePreferences(
      fontSize: lyricSize,
      // Older readers sized chords at 110% of the lyric size.
      chordFontSize:
          ((json['chordFontSize'] as num?)?.toDouble() ?? lyricSize * 1.1)
              .clamp(minimumChordFontSize, maximumChordFontSize)
              .toDouble(),
      chordColor:
          ChordProChordColor.values
              .where((color) => color.name == json['chordColor'])
              .firstOrNull ??
          ChordProChordColor.automatic,
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
