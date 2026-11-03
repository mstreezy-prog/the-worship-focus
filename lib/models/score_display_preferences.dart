enum ScoreChordColor {
  black(0xFF111111, 'Black'),
  blue(0xFF174EA6, 'Blue'),
  burgundy(0xFF8B1E3F, 'Burgundy'),
  green(0xFF176B3A, 'Green'),
  purple(0xFF663399, 'Purple');

  const ScoreChordColor(this.value, this.label);
  final int value;
  final String label;
}

class ScoreDisplayPreferences {
  const ScoreDisplayPreferences({
    this.lyricFontSize = defaultLyricFontSize,
    this.chordFontSize = defaultChordFontSize,
    this.chordColor = ScoreChordColor.black,
    this.noteSize = defaultNoteSize,
  });

  static const double defaultLyricFontSize = 17;
  static const double defaultChordFontSize = 22;
  static const double defaultNoteSize = 12;

  static const double minimumLyricFontSize = 10;
  static const double maximumLyricFontSize = 36;
  static const double minimumChordFontSize = 14;
  static const double maximumChordFontSize = 50;
  static const double minimumNoteSize = 5;
  static const double maximumNoteSize = 18;

  final double lyricFontSize;
  final double chordFontSize;
  final ScoreChordColor chordColor;

  /// The size of noteheads and staff lines in the rendered score.
  final double noteSize;

  /// Keep the generous score spacing proportional as noteheads grow or shrink.
  double get staffGap => noteSize * 13;
  double get interSystemGap => noteSize * 9;

  ScoreDisplayPreferences copyWith({
    double? lyricFontSize,
    double? chordFontSize,
    ScoreChordColor? chordColor,
    double? noteSize,
  }) {
    return ScoreDisplayPreferences(
      lyricFontSize: _clamp(
        lyricFontSize ?? this.lyricFontSize,
        minimumLyricFontSize,
        maximumLyricFontSize,
      ),
      chordFontSize: _clamp(
        chordFontSize ?? this.chordFontSize,
        minimumChordFontSize,
        maximumChordFontSize,
      ),
      chordColor: chordColor ?? this.chordColor,
      noteSize: _clamp(
        noteSize ?? this.noteSize,
        minimumNoteSize,
        maximumNoteSize,
      ),
    );
  }

  Map<String, Object> toJson() => {
    'lyricFontSize': lyricFontSize,
    'chordFontSize': chordFontSize,
    'chordColor': chordColor.name,
    'noteSize': noteSize,
  };

  factory ScoreDisplayPreferences.fromJson(Map<String, Object?> json) {
    return ScoreDisplayPreferences().copyWith(
      lyricFontSize: (json['lyricFontSize'] as num?)?.toDouble(),
      chordFontSize: (json['chordFontSize'] as num?)?.toDouble(),
      chordColor: ScoreChordColor.values
          .where((color) => color.name == json['chordColor'])
          .firstOrNull,
      noteSize: (json['noteSize'] as num?)?.toDouble(),
    );
  }

  static double _clamp(double value, double minimum, double maximum) {
    return value.clamp(minimum, maximum).toDouble();
  }
}
