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
    expect(find.text('Amazing Grace'), findsWidgets);
    expect(find.text('ChordPro editor'), findsOneWidget);
    expect(find.text('Live preview'), findsOneWidget);
    expect(find.byTooltip('Performance mode'), findsOneWidget);
    expect(find.byTooltip('Import ChordPro'), findsOneWidget);
    expect(find.byTooltip('Save ChordPro as'), findsOneWidget);
    expect(find.byTooltip('New song'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(find.byTooltip('Redo'), findsOneWidget);
    expect(find.byKey(const ValueKey('title-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('artist-1')), findsOneWidget);
  });

  testWidgets('opens performance mode', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipFocusStudioApp());

    await tester.tap(find.byTooltip('Performance mode'));
    await tester.pumpAndSettle();

    expect(find.text('Performance mode'), findsOneWidget);
    expect(find.byTooltip('Decrease font size'), findsOneWidget);
    expect(find.byTooltip('Increase font size'), findsOneWidget);
    expect(find.byTooltip('Start auto-scroll'), findsOneWidget);
    expect(find.byTooltip('Keep screen awake'), findsOneWidget);
    expect(find.byTooltip('Next song'), findsOneWidget);
  });

  testWidgets('uses a compact song-tools menu in portrait', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipFocusStudioApp());

    expect(find.byTooltip('Song tools'), findsOneWidget);
    expect(find.byTooltip('Save ChordPro as'), findsNothing);
  });
}
