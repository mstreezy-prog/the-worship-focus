import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'controllers/cloud_sync_controller.dart';
import 'theme/worship_focus_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CloudConnection.initialize();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'CMG Sans',
    ], await rootBundle.loadString('assets/licenses/CMG-Sans-OFL-1.1.txt'));
  });
  runApp(const WorshipFocusStudioApp());
}

class WorshipFocusStudioApp extends StatelessWidget {
  const WorshipFocusStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Worship Focus',
      debugShowCheckedModeBanner: false,
      theme: WorshipFocusTheme.light,
      home: const HomeScreen(),
    );
  }
}
