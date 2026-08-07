import 'music_xml_arrangement.dart';

/// The presentation source selected inside the unified performance screen.
enum PerformanceContent { chordPro, leadSheet, fullPiano }

extension PerformanceContentDetails on PerformanceContent {
  String get label => switch (this) {
    PerformanceContent.chordPro => 'ChordPro',
    PerformanceContent.leadSheet => 'Lead Sheet',
    PerformanceContent.fullPiano => 'Full Piano',
  };

  MusicXmlArrangementType? get arrangementType => switch (this) {
    PerformanceContent.chordPro => null,
    PerformanceContent.leadSheet => MusicXmlArrangementType.leadSheet,
    PerformanceContent.fullPiano => MusicXmlArrangementType.fullPiano,
  };

  static PerformanceContent fromArrangement(MusicXmlArrangementType type) {
    return switch (type) {
      MusicXmlArrangementType.leadSheet => PerformanceContent.leadSheet,
      MusicXmlArrangementType.fullPiano => PerformanceContent.fullPiano,
    };
  }
}
