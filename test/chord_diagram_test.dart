import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/services/chordpro_document.dart';
import 'package:worship_focus_studio/widgets/chord_diagram.dart';

void main() {
  testWidgets('renders a labeled, accessible ChordPro chord diagram', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChordDiagram(
            definition: ChordDiagramDefinition(
              name: 'G',
              baseFret: 1,
              frets: [3, 2, 0, 0, 0, 3],
              fingers: ['2', '1', '0', '0', '0', '3'],
            ),
          ),
        ),
      ),
    );

    expect(find.text('G'), findsOneWidget);
    expect(find.bySemanticsLabel('G chord diagram'), findsOneWidget);
  });
}
