import 'score_annotation.dart';

enum MusicXmlArrangementType { leadSheet, fullPiano }

typedef MusicXmlTransposeCallback =
    void Function(MusicXmlArrangementType type, int semitones);
typedef MusicXmlAnnotationsChangedCallback =
    void Function(
      MusicXmlArrangementType type,
      List<ScoreAnnotationStroke> annotations,
    );

extension MusicXmlArrangementTypeLabel on MusicXmlArrangementType {
  String get label => switch (this) {
    MusicXmlArrangementType.leadSheet => 'Lead Sheet',
    MusicXmlArrangementType.fullPiano => 'Full Piano',
  };

  String get fileNameSegment => switch (this) {
    MusicXmlArrangementType.leadSheet => 'Lead-Sheet',
    MusicXmlArrangementType.fullPiano => 'Full-Piano',
  };
}

class MusicXmlArrangement {
  const MusicXmlArrangement({
    required this.fileName,
    required this.sourceXml,
    this.isCompressed = false,
    this.scoreTitle,
    this.partCount,
    this.transposeSemitones = 0,
    this.annotations = const <ScoreAnnotationStroke>[],
  });

  final String fileName;
  final String sourceXml;
  final bool isCompressed;
  final String? scoreTitle;
  final int? partCount;

  /// Always applied to [sourceXml], which remains unchanged.
  final int transposeSemitones;

  /// App-owned markings drawn over this particular arrangement.
  final List<ScoreAnnotationStroke> annotations;

  MusicXmlArrangement copyWith({
    String? fileName,
    String? sourceXml,
    bool? isCompressed,
    String? scoreTitle,
    bool clearScoreTitle = false,
    int? partCount,
    bool clearPartCount = false,
    int? transposeSemitones,
    List<ScoreAnnotationStroke>? annotations,
  }) {
    return MusicXmlArrangement(
      fileName: fileName ?? this.fileName,
      sourceXml: sourceXml ?? this.sourceXml,
      isCompressed: isCompressed ?? this.isCompressed,
      scoreTitle: clearScoreTitle ? null : scoreTitle ?? this.scoreTitle,
      partCount: clearPartCount ? null : partCount ?? this.partCount,
      transposeSemitones: transposeSemitones ?? this.transposeSemitones,
      annotations: annotations ?? this.annotations,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'fileName': fileName,
      'sourceXml': sourceXml,
      'isCompressed': isCompressed,
      'scoreTitle': scoreTitle,
      'partCount': partCount,
      'transposeSemitones': transposeSemitones,
      'annotations': [
        for (final annotation in annotations) annotation.toJson(),
      ],
    };
  }

  factory MusicXmlArrangement.fromJson(Map<String, Object?> json) {
    final fileName = json['fileName'];
    final sourceXml = json['sourceXml'];
    if (fileName is! String || sourceXml is! String) {
      throw const FormatException('Invalid saved MusicXML arrangement');
    }
    return MusicXmlArrangement(
      fileName: fileName,
      sourceXml: sourceXml,
      isCompressed: json['isCompressed'] as bool? ?? false,
      scoreTitle: json['scoreTitle'] as String?,
      partCount: json['partCount'] as int?,
      transposeSemitones: json['transposeSemitones'] as int? ?? 0,
      annotations: _annotationsFromJson(json['annotations']),
    );
  }

  static List<ScoreAnnotationStroke> _annotationsFromJson(Object? value) {
    if (value == null) return const <ScoreAnnotationStroke>[];
    if (value is! List) {
      throw const FormatException('Invalid saved score annotations');
    }
    return List.unmodifiable([
      for (final item in value)
        if (item is Map<String, Object?>)
          ScoreAnnotationStroke.fromJson(item)
        else
          throw const FormatException('Invalid saved score annotation'),
    ]);
  }
}
