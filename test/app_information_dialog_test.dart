import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/services/app_links.dart';
import 'package:worship_focus_studio/widgets/app_information_dialog.dart';

void main() {
  testWidgets('Privacy and support open the published pages', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppInformationDialog(
            openLink: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Privacy policy'));
    await tester.pump();
    await tester.tap(find.text('Support'));
    await tester.pump();
    expect(opened, [AppLinks.privacy, AppLinks.support]);
  });
  testWidgets('Failed launch keeps a usable fallback URL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppInformationDialog(openLink: (_) async => false),
        ),
      ),
    );
    await tester.tap(find.text('Privacy policy'));
    await tester.pump();
    expect(find.textContaining('Could not open this page.'), findsOneWidget);
    expect(find.textContaining(AppLinks.privacy.toString()), findsOneWidget);
  });
}
