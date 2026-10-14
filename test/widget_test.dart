import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/main.dart';
import 'package:worship_focus_studio/models/service_plan.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/screens/performance_screen.dart';
import 'package:worship_focus_studio/widgets/service_plan_workspace.dart';

void main() {
  testWidgets('shows the adaptive application shell', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipFocusStudioApp());

    expect(find.text('The Worship Focus'), findsWidgets);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Amazing Grace'), findsWidgets);
    expect(find.text('ChordPro editor'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Editor'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Preview'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'MusicXML'), findsOneWidget);
    expect(find.byTooltip('Live mode'), findsOneWidget);
    expect(find.byTooltip('Import ChordPro'), findsOneWidget);
    expect(find.byTooltip('Library backup'), findsOneWidget);
    expect(find.byTooltip('Save ChordPro as'), findsOneWidget);
    expect(find.byTooltip('New song'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(find.byTooltip('Redo'), findsOneWidget);
    expect(find.byKey(const ValueKey('title-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('artist-1')), findsOneWidget);
  });

  testWidgets('opens live mode', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipFocusStudioApp());

    await tester.tap(find.byTooltip('Live mode'));
    await tester.pumpAndSettle();

    expect(find.text('Live mode'), findsOneWidget);
    expect(find.byTooltip('Decrease font size'), findsOneWidget);
    expect(find.byTooltip('Increase font size'), findsOneWidget);
    expect(find.byTooltip('Previous ChordPro page'), findsOneWidget);
    expect(find.byTooltip('Next ChordPro page'), findsOneWidget);
    expect(find.text('One column'), findsOneWidget);
    expect(find.byTooltip('Keep screen awake'), findsOneWidget);
    expect(find.byTooltip('Next song'), findsOneWidget);

    await tester.tap(find.text('One column'));
    await tester.pump();
    expect(find.text('Two columns'), findsOneWidget);
  });

  testWidgets('shows ChordPro header notes on the first live page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceScreen(
          songs: [
            Song(
              id: 'header-song',
              title: 'Header Song',
              chordPro: '''{title: Header Song}
{tempo: 84}
{time: 6/8}
{order: Intro V1 C V2 C}
{comment: Start quietly.}
[G]Test lyrics''',
            ),
          ],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('chordpro-song-information')),
      findsOneWidget,
    );
    expect(find.text('Tempo: 84 BPM'), findsOneWidget);
    expect(find.text('Time: 6/8'), findsOneWidget);
    expect(find.text('Order: Intro V1 C V2 C'), findsOneWidget);
    expect(find.text('Start quietly.'), findsOneWidget);
  });

  testWidgets('shows service section text in live mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceScreen(
          songs: [
            Song(
              id: 'welcome',
              title: 'Welcome',
              chordPro: 'Invite everyone to stand and pray together.',
            ),
          ],
          initialIndex: 0,
        ),
      ),
    );

    expect(find.text('Welcome'), findsWidgets);
    expect(
      find.text('Invite everyone to stand and pray together.'),
      findsOneWidget,
    );
  });

  testWidgets('shows MusicXML as a tab for the selected song', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipFocusStudioApp());
    await tester.tap(find.widgetWithText(Tab, 'MusicXML'));
    await tester.pumpAndSettle();

    expect(find.text('MusicXML scores'), findsOneWidget);
    expect(find.text('Lead Sheet'), findsOneWidget);
    expect(find.text('Full Piano'), findsOneWidget);
    expect(find.text('Import'), findsNWidgets(2));
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

  testWidgets('shows MusicXML arrangement cards in portrait song workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipFocusStudioApp());
    await tester.tap(find.widgetWithText(Tab, 'MusicXML'));
    await tester.pumpAndSettle();

    expect(find.text('Lead Sheet'), findsOneWidget);
    expect(find.text('Full Piano'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the service plan workspace', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipFocusStudioApp());
    await tester.tap(find.text('Service plans'));
    await tester.pumpAndSettle();

    expect(find.text('Service plans'), findsWidgets);
    expect(find.byKey(const ValueKey('new-service-plan')), findsOneWidget);
    expect(find.text('Create service plan'), findsOneWidget);
  });

  testWidgets('changes service plans after the picker closes', (tester) async {
    final morning = ServicePlan(
      id: 'morning',
      title: 'Morning Service',
      date: DateTime.utc(2026, 8, 9),
      songIds: const [],
    );
    final evening = ServicePlan(
      id: 'evening',
      title: 'Evening Service',
      date: DateTime.utc(2026, 8, 9),
      songIds: const [],
    );
    var selectedPlan = morning;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: ServicePlanWorkspace(
              plans: [morning, evening],
              selectedPlan: selectedPlan,
              items: selectedPlan.items,
              librarySongs: const [],
              onPlanSelected: (plan) => setState(() => selectedPlan = plan),
              onCreatePlan: () {},
              onRenamePlan: (_) {},
              onChangePlanDate: (_) {},
              onDeletePlan: (_) {},
              onAddSong: (_) {},
              onAddSection: (_) {},
              onUpdateItemNotes: (_, _) {},
              onRemoveItem: (_) {},
              onReorderItems: (_, _) {},
              onPerform: () {},
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('service-plan-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evening Service'));
    await tester.pumpAndSettle();

    expect(selectedPlan, evening);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renames a service plan after its dialog closes', (tester) async {
    final plan = ServicePlan(
      id: 'morning',
      title: 'Morning Service',
      date: DateTime.utc(2026, 8, 9),
      songIds: const [],
    );
    var plans = [plan];
    var selectedPlan = plan;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: ServicePlanWorkspace(
              plans: plans,
              selectedPlan: selectedPlan,
              items: selectedPlan.items,
              librarySongs: const [],
              onPlanSelected: (_) {},
              onCreatePlan: () {},
              onRenamePlan: (title) => setState(() {
                selectedPlan = selectedPlan.copyWith(title: title);
                plans = [selectedPlan];
              }),
              onChangePlanDate: (_) {},
              onDeletePlan: (_) {},
              onAddSong: (_) {},
              onAddSection: (_) {},
              onUpdateItemNotes: (_, _) {},
              onRemoveItem: (_) {},
              onReorderItems: (_, _) {},
              onPerform: () {},
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Evening Service');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(selectedPlan.title, 'Evening Service');
    expect(find.text('Evening Service'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds a service section after its dialog closes', (tester) async {
    final plan = ServicePlan(
      id: 'morning',
      title: 'Morning Service',
      date: DateTime.utc(2026, 8, 9),
      items: const [],
    );
    var selectedPlan = plan;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: ServicePlanWorkspace(
              plans: [selectedPlan],
              selectedPlan: selectedPlan,
              items: selectedPlan.items,
              librarySongs: const [],
              onPlanSelected: (_) {},
              onCreatePlan: () {},
              onRenamePlan: (_) {},
              onChangePlanDate: (_) {},
              onDeletePlan: (_) {},
              onAddSong: (_) {},
              onAddSection: (title) => setState(() {
                selectedPlan = selectedPlan.copyWith(
                  items: [ServicePlanItem.section(id: 'section', title: title)],
                );
              }),
              onUpdateItemNotes: (item, notes) => setState(() {
                selectedPlan = selectedPlan.copyWith(
                  items: [
                    for (final candidate in selectedPlan.items)
                      if (candidate.id == item.id)
                        candidate.copyWith(notes: notes)
                      else
                        candidate,
                  ],
                );
              }),
              onRemoveItem: (_) {},
              onReorderItems: (_, _) {},
              onPerform: () {},
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add section'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Welcome');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit section text'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Invite everyone to stand and pray together.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Invite everyone to stand and pray together.'),
      findsOneWidget,
    );
    final sectionText = tester.widget<Text>(
      find.text('Invite everyone to stand and pray together.'),
    );
    expect(sectionText.style?.fontFamily, 'CMG Sans');
    expect(tester.takeException(), isNull);
  });
}
