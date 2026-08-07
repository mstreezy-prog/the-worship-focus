import 'package:xml/xml.dart';

/// Adds display-only chord text for MusicXML readers that do not parse
/// standard `<harmony>` elements.
///
/// The returned XML is used only by the notation renderer. Imports, saved
/// arrangements, and exports retain their original MusicXML unchanged.
class MusicXmlDisplayTransformer {
  MusicXmlDisplayTransformer._();

  static String prepare(String sourceXml) {
    if (!sourceXml.contains('<harmony')) return sourceXml;
    try {
      final document = XmlDocument.parse(sourceXml);
      var changed = false;
      final measures = document.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'measure')
          .toList();
      for (final measure in measures) {
        final harmonies = measure.children
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'harmony')
            .toList();
        for (final harmony in harmonies) {
          final text = _harmonyText(harmony);
          if (text == null) continue;
          final index = measure.children.indexOf(harmony);
          if (index == -1) continue;
          measure.children.insert(index, _chordDirection(text));
          changed = true;
        }
      }
      return changed ? document.toXmlString() : sourceXml;
    } on XmlParserException {
      // Let the notation renderer report the original parse error instead.
      return sourceXml;
    }
  }

  static String? _harmonyText(XmlElement harmony) {
    final root = harmony.getElement('root');
    final rootStep = root?.getElement('root-step')?.innerText.trim();
    final kind = harmony.getElement('kind');
    final kindText = kind?.getAttribute('text')?.trim();
    final kindValue = kind?.innerText.trim();

    if (rootStep == null || rootStep.isEmpty) {
      return kindText?.isNotEmpty == true ? kindText : null;
    }

    final rootAlter = _alteration(root?.getElement('root-alter')?.innerText);
    final suffix = kindText?.isNotEmpty == true
        ? kindText!
        : _kindSuffix(kindValue);
    final bass = harmony.getElement('bass');
    final bassStep = bass?.getElement('bass-step')?.innerText.trim();
    final bassText = bassStep == null || bassStep.isEmpty
        ? ''
        : '/$bassStep${_alteration(bass?.getElement('bass-alter')?.innerText)}';
    return '$rootStep$rootAlter$suffix$bassText';
  }

  static String _alteration(String? value) {
    return switch (int.tryParse(value?.trim() ?? '')) {
      -2 => 'bb',
      -1 => 'b',
      1 => '#',
      2 => 'x',
      _ => '',
    };
  }

  static String _kindSuffix(String? kind) {
    return switch (kind) {
      null || '' || 'major' => '',
      'minor' => 'm',
      'dominant' => '7',
      'major-seventh' => 'maj7',
      'minor-seventh' => 'm7',
      'diminished' => 'dim',
      'half-diminished' => 'm7b5',
      'augmented' => 'aug',
      'suspended-second' => 'sus2',
      'suspended-fourth' => 'sus4',
      'power' => '5',
      'none' => 'N.C.',
      _ => kind,
    };
  }

  static XmlElement _chordDirection(String text) {
    final builder = XmlBuilder();
    builder.element(
      'direction',
      attributes: {'placement': 'above'},
      nest: () {
        builder.element(
          'direction-type',
          nest: () {
            builder.element(
              'words',
              attributes: {'font-weight': 'bold'},
              nest: text,
            );
          },
        );
      },
    );
    return builder.buildFragment().children.single as XmlElement;
  }
}
