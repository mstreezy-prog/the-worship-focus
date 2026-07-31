import 'package:flutter/material.dart';

import '../models/song.dart';
import '../widgets/preview_panel.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({required this.song, super.key});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Performance mode'),
      ),
      body: SafeArea(
        child: Theme(
          data: ThemeData.dark(useMaterial3: true),
          child: PreviewPanel(song: song, performance: true),
        ),
      ),
    );
  }
}
