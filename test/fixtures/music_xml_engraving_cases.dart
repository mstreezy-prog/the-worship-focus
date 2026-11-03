String scoreXml(String measures) => '''<score-partwise version="4.0">
<part-list><score-part id="P1"><part-name>Test melody</part-name></score-part></part-list>
<part id="P1">$measures</part></score-partwise>''';

const meter68 =
    '''<attributes><divisions>8</divisions><key><fifths>1</fifths></key>
<time><beats>6</beats><beat-type>8</beat-type></time>
<clef><sign>G</sign><line>2</line></clef></attributes>''';

String noteXml({
  int ticks = 4,
  String? type,
  String step = 'C',
  int octave = 4,
  int voice = 1,
  bool chord = false,
  bool grace = false,
  bool hidden = false,
  String extra = '',
}) =>
    '''<note${hidden ? ' print-object="no"' : ''}>
${chord ? '<chord/>' : ''}${grace ? '<grace/>' : ''}
<pitch><step>$step</step><octave>$octave</octave></pitch>
${grace ? '' : '<duration>$ticks</duration>'}<voice>$voice</voice>
${type == null ? '' : '<type>$type</type>'}$extra</note>''';

final inheritedTimingXml = scoreXml(
  '''
<measure number="1">$meter68${noteXml(ticks: 24)}</measure>
<measure number="2"><note><rest measure="yes"/><duration>24</duration></note></measure>
<measure number="3">${noteXml(ticks: 12)}${noteXml(ticks: 12, step: 'G')}</measure>''',
);

final numberedVoiceXml = scoreXml(
  '<measure number="1">$meter68${noteXml(ticks: 24, voice: 5)}</measure>',
);

final forwardGapXml = scoreXml('''<measure number="1">$meter68
<forward><duration>8</duration></forward>${noteXml(ticks: 16)}</measure>''');

final simultaneousChordXml = scoreXml('''<measure number="1">$meter68
${noteXml(ticks: 8)}${noteXml(ticks: 8, step: 'E', chord: true)}
${noteXml(ticks: 16, step: 'G')}</measure>''');

final graceAndHiddenXml = scoreXml('''<measure number="1">$meter68
${noteXml(grace: true, type: 'eighth', step: 'D')}
${noteXml(ticks: 8, hidden: true)}${noteXml(ticks: 16)}</measure>''');

String polyphonicMeasures(int count) => [
  for (var n = 1; n <= count; n++)
    '''
<measure number="$n">${n == 1 ? meter68 : ''}
${noteXml(ticks: 24, voice: 1, step: 'G')}
<backup><duration>24</duration></backup>
${noteXml(ticks: 8, voice: 2)}${noteXml(ticks: 16, voice: 2, step: 'E')}
</measure>''',
].join();

final beamsXml = scoreXml('''<measure number="1">$meter68
${[
  for (var i = 0; i < 6; i++) noteXml(step: ['C', 'D', 'E', 'F', 'G', 'A'][i], type: 'eighth'),
].join()}
</measure>''');
