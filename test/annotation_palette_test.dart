import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/score_annotation.dart';
import 'package:worship_focus_studio/widgets/annotation_palette.dart';
import 'package:worship_focus_studio/widgets/score_annotation_canvas.dart';

void main() {
  testWidgets('Markup palette selects tools, colors and stroke widths', (
    tester,
  ) async {
    var tool = ScoreAnnotationTool.none;
    var color = ScoreAnnotationColor.black;
    var width = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnotationPalette(
            tool: tool,
            color: color,
            widthScale: width,
            onToolChanged: (value) => tool = value,
            onColorChanged: (value) => color = value,
            onWidthChanged: (value) => width = value,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Highlighter'));
    expect(tool, ScoreAnnotationTool.highlighter);
    await tester.tap(find.byTooltip('Yellow ink'));
    expect(color, ScoreAnnotationColor.yellow);
    await tester.tap(find.byTooltip('Stroke width'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<double>, 'Bold'));
    expect(width, 2);
  });
  test('New ink colors and widths survive saving', () {
    const stroke = ScoreAnnotationStroke(
      points: [ScoreAnnotationPoint(x: .2, y: .4)],
      color: ScoreAnnotationColor.yellow,
      style: ScoreAnnotationStyle.highlighter,
      width: 32,
    );
    final restored = ScoreAnnotationStroke.fromJson(stroke.toJson());
    expect(restored.color, stroke.color);
    expect(restored.width, 32);
  });
}
