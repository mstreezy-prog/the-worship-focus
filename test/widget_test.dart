import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/main.dart';

void main() {
  testWidgets('shows the application and its song library', (tester) async {
    await tester.pumpWidget(const WorshipFocusStudioApp());

    expect(find.text('Worship Focus Studio'), findsOneWidget);
    expect(find.text('Amazing Grace'), findsOneWidget);
    expect(find.text('Sample Song'), findsOneWidget);
    expect(find.textContaining('Amazing grace'), findsOneWidget);
  });
}
