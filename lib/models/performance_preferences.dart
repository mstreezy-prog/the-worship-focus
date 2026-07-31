enum PerformanceTheme { dark, light }

class PerformancePreferences {
  const PerformancePreferences({
    this.fontSize = 20,
    this.theme = PerformanceTheme.dark,
    this.scrollSpeed = 24,
    this.keepAwake = false,
  });

  final double fontSize;
  final PerformanceTheme theme;
  final double scrollSpeed;
  final bool keepAwake;

  PerformancePreferences copyWith({
    double? fontSize,
    PerformanceTheme? theme,
    double? scrollSpeed,
    bool? keepAwake,
  }) {
    return PerformancePreferences(
      fontSize: fontSize ?? this.fontSize,
      theme: theme ?? this.theme,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      keepAwake: keepAwake ?? this.keepAwake,
    );
  }

  Map<String, Object> toJson() {
    return {
      'fontSize': fontSize,
      'theme': theme.name,
      'scrollSpeed': scrollSpeed,
      'keepAwake': keepAwake,
    };
  }

  factory PerformancePreferences.fromJson(Map<String, Object?> json) {
    final fontSize = (json['fontSize'] as num?)?.toDouble() ?? 20;
    final scrollSpeed = (json['scrollSpeed'] as num?)?.toDouble() ?? 24;
    final themeName = json['theme'] as String?;
    return PerformancePreferences(
      fontSize: fontSize.clamp(14, 36).toDouble(),
      theme:
          PerformanceTheme.values
              .where((theme) => theme.name == themeName)
              .firstOrNull ??
          PerformanceTheme.dark,
      scrollSpeed: scrollSpeed.clamp(8, 60).toDouble(),
      keepAwake: json['keepAwake'] as bool? ?? false,
    );
  }
}
