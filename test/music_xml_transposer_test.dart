import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/services/music_xml_transposer.dart';
import 'package:xml/xml.dart';

const _dMajorScore = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Music</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key><fifths>2</fifths><mode>major</mode></key>
      </attributes>
      <harmony>
        <root><root-step>D</root-step></root>
        <kind>major</kind>
        <bass><bass-step>F</bass-step><bass-alter>1</bass-alter></bass>
      </harmony>
      <note>
        <pitch><step>F</step><alter>1</alter><octave>4</octave></pitch>
        <duration>1</duration><type>quarter</type>
        <accidental cautionary="yes">sharp</accidental>
      </note>
      <note>
        <pitch><step>B</step><octave>4</octave></pitch>
        <duration>1</duration><type>quarter</type>
      </note>
      <note>
        <unpitched><display-step>C</display-step><display-octave>5</display-octave></unpitched>
        <duration>1</duration><type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>''';

void main() {
  test('zero semitones preserves the original MusicXML exactly', () {
    expect(MusicXmlTransposer.transpose(_dMajorScore, 0), _dMajorScore);
  });

  test('transposes key, notes, octaves, harmony, and accidentals', () {
    final document = XmlDocument.parse(
      MusicXmlTransposer.transpose(_dMajorScore, 1),
    );

    expect(_texts(document, 'fifths'), ['-3']);
    expect(_texts(document, 'root-step'), ['E']);
    expect(_texts(document, 'root-alter'), ['-1']);
    expect(_texts(document, 'bass-step'), ['G']);
    expect(_texts(document, 'bass-alter'), isEmpty);
    expect(_texts(document, 'step'), ['G', 'C']);
    expect(_texts(document, 'alter'), isEmpty);
    expect(_texts(document, 'octave'), ['4', '5']);
    expect(_texts(document, 'accidental'), ['natural']);
    expect(_texts(document, 'display-step'), ['C']);
    expect(_texts(document, 'display-octave'), ['5']);
  });

  test('transposes downward with key-aware note spelling', () {
    final document = XmlDocument.parse(
      MusicXmlTransposer.transpose(_dMajorScore, -2),
    );

    expect(_texts(document, 'fifths'), ['0']);
    expect(_texts(document, 'step'), ['E', 'A']);
    expect(_texts(document, 'alter'), isEmpty);
    expect(_texts(document, 'octave'), ['4', '4']);
    expect(MusicXmlTransposer.keySignature(_dMajorScore)?.label, 'D major');
    expect(
      MusicXmlTransposer.keySignature(_dMajorScore, semitones: -2)?.label,
      'C major',
    );
  });

  test('preserves minor mode when choosing a destination key', () {
    const score = '''<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Music</part-name></score-part></part-list>
  <part id="P1"><measure number="1"><attributes>
    <key><fifths>0</fifths><mode>minor</mode></key>
  </attributes><note><pitch><step>A</step><octave>4</octave></pitch></note>
  </measure></part>
</score-partwise>''';
    final transposed = MusicXmlTransposer.transpose(score, 2);

    expect(_texts(XmlDocument.parse(transposed), 'fifths'), ['2']);
    expect(
      MusicXmlTransposer.keySignature(score, semitones: 2)?.label,
      'B minor',
    );
  });

  test('formats saved offsets for the interface', () {
    expect(MusicXmlTransposer.offsetLabel(0), 'Original');
    expect(MusicXmlTransposer.offsetLabel(1), '+1 semitone');
    expect(MusicXmlTransposer.offsetLabel(-3), '-3 semitones');
  });
}

List<String> _texts(XmlDocument document, String localName) {
  return document.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == localName)
      .map((element) => element.innerText.trim())
      .toList();
}
