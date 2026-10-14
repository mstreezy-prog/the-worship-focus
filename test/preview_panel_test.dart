import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/widgets/preview_panel.dart';

void main() {
  testWidgets('shows a defined ChordPro diagram in the preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: PreviewPanel(
              song: Song(
                id: 'diagram-song',
                title: 'Diagram Song',
                chordPro: '''{define: G base-fret 1 frets 3 2 0 0 0 3}
{chord: G}
[G]Amazing grace''',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('G chord diagram'), findsOneWidget);
  });
}
