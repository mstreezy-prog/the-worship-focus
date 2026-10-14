import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/services/chordpro_performance_info.dart';

void main() {
  test('reads leading tempo, time, order, and notes from ChordPro', () {
    final info = ChordProPerformanceInfo.fromSong(
      Song(
        id: 'song',
        title: 'Test Song',
        chordPro: '''{title: Test Song}
{key: G}
{tempo: 84}
{time: 6/8}
{order: Intro V1 C V2 C}
{comment: Build through the chorus.}
[G]Test lyrics''',
      ),
    );

    expect(info.key, 'G');
    expect(info.tempo, '84 BPM');
    expect(info.timeSignature, '6/8');
    expect(info.songOrder, 'Intro V1 C V2 C');
    expect(info.notes, ['Build through the chorus.']);
  });

  test('uses the saved song tempo when the ChordPro header has none', () {
    final info = ChordProPerformanceInfo.fromSong(
      Song(
        id: 'song',
        title: 'Test Song',
        tempo: 72,
        chordPro: '{title: Test Song}\n[C]Lyrics',
      ),
    );

    expect(info.tempo, '72 BPM');
  });
}
