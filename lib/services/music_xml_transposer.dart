import 'package:xml/xml.dart';

class MusicXmlKeySignature {
  const MusicXmlKeySignature({
    required this.fifths,
    required this.mode,
    required this.tonic,
  });

  final int fifths;
  final String mode;
  final String tonic;

  bool get isMinor => mode.toLowerCase() == 'minor';

  String get label => '$tonic ${isMinor ? 'minor' : 'major'}';
}

class MusicXmlTransposer {
  MusicXmlTransposer._();

  static const int minimumSemitones = -11;
  static const int maximumSemitones = 11;

  static String transpose(String sourceXml, int semitones) {
    if (semitones == 0) return sourceXml;
    final document = XmlDocument.parse(sourceXml);
    final root = document.rootElement;
    switch (root.name.local) {
      case 'score-partwise':
        for (final part in _children(root, 'part')) {
          final context = _PartKeyContext();
          for (final measure in _children(part, 'measure')) {
            _transposeMeasure(measure, context, semitones);
          }
        }
        break;
      case 'score-timewise':
        final contexts = <String, _PartKeyContext>{};
        for (final measure in _children(root, 'measure')) {
          for (final part in _children(measure, 'part')) {
            final id = part.getAttribute('id') ?? '';
            final context = contexts.putIfAbsent(id, _PartKeyContext.new);
            _transposeMeasure(part, context, semitones);
          }
        }
        break;
      default:
        throw const FormatException(
          'MusicXML must contain a score-partwise or score-timewise document',
        );
    }
    return document.toXmlString();
  }

  static MusicXmlKeySignature? keySignature(
    String sourceXml, {
    int semitones = 0,
  }) {
    try {
      final document = XmlDocument.parse(sourceXml);
      final key = document.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'key')
          .firstOrNull;
      if (key == null) return null;
      final fifths = int.tryParse(_childText(key, 'fifths') ?? '');
      if (fifths == null) return null;
      final mode = (_childText(key, 'mode') ?? 'major').toLowerCase();
      final signature = _signature(fifths, mode);
      return semitones == 0
          ? signature.publicValue
          : _transposedSignature(signature, semitones).publicValue;
    } on Object {
      return null;
    }
  }

  static String offsetLabel(int semitones) {
    if (semitones == 0) return 'Original';
    final direction = semitones > 0 ? '+' : '';
    final unit = semitones.abs() == 1 ? 'semitone' : 'semitones';
    return '$direction$semitones $unit';
  }

  static void _transposeMeasure(
    XmlElement measure,
    _PartKeyContext context,
    int semitones,
  ) {
    for (final child in _elementChildren(measure)) {
      switch (child.name.local) {
        case 'attributes':
          for (final key in _children(child, 'key')) {
            final fifthsElement = _child(key, 'fifths');
            final fifths = int.tryParse(fifthsElement?.innerText.trim() ?? '');
            if (fifths == null || fifthsElement == null) continue;
            final mode = (_childText(key, 'mode') ?? 'major').toLowerCase();
            final original = _signature(fifths, mode);
            final transposed = _transposedSignature(original, semitones);
            fifthsElement.innerText = transposed.fifths.toString();
            final staffNumber = int.tryParse(key.getAttribute('number') ?? '');
            context.set(
              staffNumber,
              _KeyContext(
                diatonicShift: _diatonicShift(
                  original.stepIndex,
                  transposed.stepIndex,
                  semitones,
                ),
              ),
            );
          }
          break;
        case 'note':
          final staffNumber = int.tryParse(_childText(child, 'staff') ?? '');
          final keyContext = context.forStaff(staffNumber);
          final pitch = _child(child, 'pitch');
          if (pitch != null) {
            final alter = _transposeNotePitch(pitch, keyContext, semitones);
            final accidental = _child(child, 'accidental');
            final accidentalName = _accidentalName(alter);
            if (accidental != null && accidentalName != null) {
              accidental.innerText = accidentalName;
            }
          }
          break;
        case 'harmony':
          final staffNumber = int.tryParse(_childText(child, 'staff') ?? '');
          final keyContext = context.forStaff(staffNumber);
          final root = _child(child, 'root');
          if (root != null) {
            _transposePitchClass(
              root,
              'root-step',
              'root-alter',
              keyContext,
              semitones,
            );
          }
          final bass = _child(child, 'bass');
          if (bass != null) {
            _transposePitchClass(
              bass,
              'bass-step',
              'bass-alter',
              keyContext,
              semitones,
            );
          }
          break;
      }
    }
  }

  static double _transposeNotePitch(
    XmlElement pitch,
    _KeyContext? keyContext,
    int semitones,
  ) {
    final stepElement = _child(pitch, 'step');
    final octaveElement = _child(pitch, 'octave');
    final sourceStep = stepElement?.innerText.trim().toUpperCase();
    final sourceStepIndex = sourceStep == null
        ? -1
        : _stepNames.indexOf(sourceStep);
    final sourceOctave = int.tryParse(octaveElement?.innerText.trim() ?? '');
    final sourceAlter = double.tryParse(_childText(pitch, 'alter') ?? '') ?? 0;
    if (stepElement == null ||
        octaveElement == null ||
        sourceStepIndex < 0 ||
        sourceOctave == null) {
      return sourceAlter;
    }

    final sourceMidi =
        (sourceOctave + 1) * 12 +
        _naturalPitchClasses[sourceStepIndex] +
        sourceAlter;
    final targetMidi = sourceMidi + semitones;
    final spelling = keyContext == null
        ? _chromaticSpelling(targetMidi, preferFlats: semitones < 0)
        : _diatonicSpelling(
            sourceStepIndex,
            sourceOctave,
            targetMidi,
            keyContext.diatonicShift,
          );
    stepElement.innerText = _stepNames[spelling.stepIndex];
    octaveElement.innerText = spelling.octave.toString();
    _setOptionalNumberChild(pitch, 'alter', spelling.alter, after: stepElement);
    return spelling.alter;
  }

  static void _transposePitchClass(
    XmlElement container,
    String stepName,
    String alterName,
    _KeyContext? keyContext,
    int semitones,
  ) {
    final stepElement = _child(container, stepName);
    final sourceStep = stepElement?.innerText.trim().toUpperCase();
    final sourceStepIndex = sourceStep == null
        ? -1
        : _stepNames.indexOf(sourceStep);
    if (stepElement == null || sourceStepIndex < 0) return;
    final sourceAlter =
        double.tryParse(_childText(container, alterName) ?? '') ?? 0;
    final targetPitchClass = _modDouble(
      _naturalPitchClasses[sourceStepIndex] + sourceAlter + semitones,
      12,
    );
    final targetStepIndex = keyContext == null
        ? _chromaticStepIndex(
            targetPitchClass.round() % 12,
            preferFlats: semitones < 0,
          )
        : _mod(sourceStepIndex + keyContext.diatonicShift, 7);
    final targetAlter = _signedPitchClassDifference(
      targetPitchClass,
      _naturalPitchClasses[targetStepIndex].toDouble(),
    );
    stepElement.innerText = _stepNames[targetStepIndex];
    _setOptionalNumberChild(
      container,
      alterName,
      targetAlter,
      after: stepElement,
    );
  }

  static _PitchSpelling _diatonicSpelling(
    int sourceStepIndex,
    int sourceOctave,
    double targetMidi,
    int diatonicShift,
  ) {
    final targetDiatonic = sourceOctave * 7 + sourceStepIndex + diatonicShift;
    final targetStepIndex = _mod(targetDiatonic, 7);
    final targetOctave = _floorDivide(targetDiatonic, 7);
    final targetNaturalMidi =
        (targetOctave + 1) * 12 + _naturalPitchClasses[targetStepIndex];
    return _PitchSpelling(
      stepIndex: targetStepIndex,
      octave: targetOctave,
      alter: targetMidi - targetNaturalMidi,
    );
  }

  static _PitchSpelling _chromaticSpelling(
    double targetMidi, {
    required bool preferFlats,
  }) {
    final chromaticMidi = targetMidi.round();
    final pitchClass = _mod(chromaticMidi, 12);
    final stepIndex = _chromaticStepIndex(pitchClass, preferFlats: preferFlats);
    final octave = _floorDivide(chromaticMidi, 12) - 1;
    final naturalMidi = (octave + 1) * 12 + _naturalPitchClasses[stepIndex];
    return _PitchSpelling(
      stepIndex: stepIndex,
      octave: octave,
      alter: targetMidi - naturalMidi,
    );
  }

  static int _chromaticStepIndex(int pitchClass, {required bool preferFlats}) {
    const sharpSteps = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6];
    const flatSteps = [0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6];
    return (preferFlats ? flatSteps : sharpSteps)[pitchClass];
  }

  static _KeySignature _transposedSignature(
    _KeySignature original,
    int semitones,
  ) {
    final targetPitchClass = _mod(original.pitchClass + semitones, 12);
    final candidates = [
      for (var fifths = -7; fifths <= 7; fifths++)
        _signature(fifths, original.mode),
    ].where((signature) => signature.pitchClass == targetPitchClass).toList();
    candidates.sort((first, second) {
      final firstDistance = (first.fifths - original.fifths).abs();
      final secondDistance = (second.fifths - original.fifths).abs();
      final byDistance = firstDistance.compareTo(secondDistance);
      if (byDistance != 0) return byDistance;
      return first.fifths.abs().compareTo(second.fifths.abs());
    });
    return candidates.first;
  }

  static _KeySignature _signature(int fifths, String mode) {
    final isMinor = mode.toLowerCase() == 'minor';
    final stepIndex = _mod(fifths * 4 + (isMinor ? 5 : 0), 7);
    final pitchClass = _mod(fifths * 7 + (isMinor ? 9 : 0), 12);
    final alter = _signedPitchClassDifference(
      pitchClass.toDouble(),
      _naturalPitchClasses[stepIndex].toDouble(),
    ).round();
    return _KeySignature(
      fifths: fifths,
      mode: isMinor ? 'minor' : 'major',
      stepIndex: stepIndex,
      alter: alter,
      pitchClass: pitchClass,
    );
  }

  static int _diatonicShift(
    int sourceStepIndex,
    int targetStepIndex,
    int semitones,
  ) {
    final base = _mod(targetStepIndex - sourceStepIndex, 7);
    final expected = semitones * 7 / 12;
    var best = base;
    var bestDistance = double.infinity;
    for (var octave = -3; octave <= 3; octave++) {
      final candidate = base + octave * 7;
      final distance = (candidate - expected).abs();
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best;
  }

  static void _setOptionalNumberChild(
    XmlElement parent,
    String name,
    double value, {
    required XmlElement after,
  }) {
    final existing = _child(parent, name);
    if (value.abs() < 0.000001) {
      existing?.parent?.children.remove(existing);
      return;
    }
    final formatted = _formatNumber(value);
    if (existing != null) {
      existing.innerText = formatted;
      return;
    }
    final element = XmlElement(
      XmlName.parts(
        name,
        prefix: parent.name.prefix,
        namespaceUri: parent.name.namespaceUri,
      ),
      const [],
      [XmlText(formatted)],
    );
    parent.children.insert(parent.children.indexOf(after) + 1, element);
  }

  static String _formatNumber(double value) {
    final rounded = value.round();
    if ((value - rounded).abs() < 0.000001) return rounded.toString();
    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String? _accidentalName(double alter) {
    if ((alter - 2).abs() < 0.000001) return 'double-sharp';
    if ((alter - 1.5).abs() < 0.000001) return 'three-quarters-sharp';
    if ((alter - 1).abs() < 0.000001) return 'sharp';
    if ((alter - 0.5).abs() < 0.000001) return 'quarter-sharp';
    if (alter.abs() < 0.000001) return 'natural';
    if ((alter + 0.5).abs() < 0.000001) return 'quarter-flat';
    if ((alter + 1).abs() < 0.000001) return 'flat';
    if ((alter + 1.5).abs() < 0.000001) return 'three-quarters-flat';
    if ((alter + 2).abs() < 0.000001) return 'flat-flat';
    return null;
  }

  static Iterable<XmlElement> _elementChildren(XmlElement parent) =>
      parent.children.whereType<XmlElement>();

  static Iterable<XmlElement> _children(XmlElement parent, String name) =>
      _elementChildren(parent).where((element) => element.name.local == name);

  static XmlElement? _child(XmlElement parent, String name) =>
      _children(parent, name).firstOrNull;

  static String? _childText(XmlElement parent, String name) =>
      _child(parent, name)?.innerText.trim();

  static int _mod(int value, int modulus) =>
      (value % modulus + modulus) % modulus;

  static double _modDouble(double value, double modulus) =>
      (value % modulus + modulus) % modulus;

  static int _floorDivide(int dividend, int divisor) =>
      (dividend / divisor).floor();

  static double _signedPitchClassDifference(double target, double natural) {
    var difference = _modDouble(target - natural, 12);
    if (difference > 6) difference -= 12;
    return difference;
  }

  static const _stepNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const _naturalPitchClasses = [0, 2, 4, 5, 7, 9, 11];
}

class _PartKeyContext {
  _KeyContext? _defaultKey;
  final Map<int, _KeyContext> _staffKeys = {};

  void set(int? staffNumber, _KeyContext context) {
    if (staffNumber == null) {
      _defaultKey = context;
    } else {
      _staffKeys[staffNumber] = context;
      if (staffNumber == 1 && _defaultKey == null) _defaultKey = context;
    }
  }

  _KeyContext? forStaff(int? staffNumber) =>
      _staffKeys[staffNumber] ?? _defaultKey;
}

class _KeyContext {
  const _KeyContext({required this.diatonicShift});

  final int diatonicShift;
}

class _KeySignature {
  const _KeySignature({
    required this.fifths,
    required this.mode,
    required this.stepIndex,
    required this.alter,
    required this.pitchClass,
  });

  final int fifths;
  final String mode;
  final int stepIndex;
  final int alter;
  final int pitchClass;

  MusicXmlKeySignature get publicValue => MusicXmlKeySignature(
    fifths: fifths,
    mode: mode,
    tonic:
        '${MusicXmlTransposer._stepNames[stepIndex]}${switch (alter) {
          -2 => 'bb',
          -1 => 'b',
          0 => '',
          1 => '#',
          2 => '##',
          _ => '',
        }}',
  );
}

class _PitchSpelling {
  const _PitchSpelling({
    required this.stepIndex,
    required this.octave,
    required this.alter,
  });

  final int stepIndex;
  final int octave;
  final double alter;
}
