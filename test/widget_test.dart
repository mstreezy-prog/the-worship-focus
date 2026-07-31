import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/main.dart';

void main() {
  testWidgets('shows the adaptive application shell', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipFocusStudioApp());

    expect(find.text('Worship Focus'), findsWidgets);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Amazing Grace'), findsOneWidget);
    expect(find.text('ChordPro editor'), findsOneWidget);
    expect(find.text('Live preview'), findsOneWidget);
    expect(find.byTooltip('Performance mode'), findsOneWidget);
  });

  testWidgets('opens performance mode', (tester) async {
    await tester.pumpWidget(const WorshipFocusStudioApp());

    await tester.tap(find.byTooltip('Performance mode'));
    await tester.pumpAndSettle();

    expect(find.text('Performance mode'), findsOneWidget);
  });
}
