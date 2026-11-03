import 'duration.dart';

/// Infer a written value only when MusicXML omits its note type.
/// Explicit note types remain authoritative for engraving.
Duration musicXmlDurationFromValue(double wholeNotes) {
  if (!wholeNotes.isFinite || wholeNotes <= 0) {
    throw const FormatException('MusicXML duration must be positive.');
  }
  for (var dots = 0; dots <= 3; dots++) {
    for (final type in DurationType.values) {
      final duration = Duration(type, dots: dots);
      if ((duration.realValue - wholeNotes).abs() < 0.000001) return duration;
    }
  }
  throw FormatException(
    'MusicXML duration $wholeNotes needs an explicit note type or tuplet ratio.',
  );
}
