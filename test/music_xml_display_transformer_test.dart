import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/services/music_xml_display_transformer.dart';
import 'package:xml/xml.dart';

const _harmonyScore = '''<score-partwise version="4.0">
  <part id="P1">
    <measure number="1">
      <harmony><root><root-step>G</root-step></root><kind>major</kind></harmony>
      <harmony><root><root-step>C</root-step><root-alter>1</root-alter></root><kind>minor-seventh</kind><bass><bass-step>G</bass-step><bass-alter>-1</bass-alter></bass></harmony>
      <harmony><root><root-step>D</root-step></root><kind text="sus4">suspended-fourth</kind></harmony>
    </measure>
  </part>
</score-partwise>''';

const _sectionWordScore = '''<score-partwise version="4.0">
  <part id="P1">
    <measure number="1">
      <direction><direction-type><words>VERSE 1</words></direction-type></direction>
      <direction><direction-type><words>CHORUS</words></direction-type></direction>
      <direction><direction-type><words>rit.</words></direction-type></direction>
    </measure>
  </part>
</score-partwise>''';

void main() {
  test('preserves MusicXML without harmony elements exactly', () {
    const source = '<score-partwise version="4.0" />';

    expect(MusicXmlDisplayTransformer.prepare(source), source);
  });

  test('adds renderer-readable chord labels for MusicXML harmony elements', () {
    final document = XmlDocument.parse(
      MusicXmlDisplayTransformer.prepare(_harmonyScore),
    );
    final labels = document
        .findAllElements('direction')
        .map((direction) => direction.findAllElements('words').single.innerText)
        .toList();

    expect(labels, ['G', 'C#m7/Gb', 'Dsus4']);
    expect(document.findAllElements('harmony'), hasLength(3));
  });

  test('moves common section words into rehearsal-mark rendering', () {
    final document = XmlDocument.parse(
      MusicXmlDisplayTransformer.prepare(_sectionWordScore),
    );

    expect(
      document.findAllElements('rehearsal').map((element) => element.innerText),
      ['VERSE 1', 'CHORUS'],
    );
    expect(
      document.findAllElements('words').map((element) => element.innerText),
      ['rit.'],
    );
  });
}
