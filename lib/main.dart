import 'package:flutter/material.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const WorshipFocusStudioApp());
}

class WorshipFocusStudioApp extends StatelessWidget {
  const WorshipFocusStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worship Focus Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomeScreen(),
    );
  }
}
