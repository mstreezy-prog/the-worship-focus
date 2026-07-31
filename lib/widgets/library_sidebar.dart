import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';

class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar({
    required this.selected,
    required this.onSelected,
    this.compact = false,
    super.key,
  });

  final LibrarySection selected;
  final ValueChanged<LibrarySection> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final destinations = <({IconData icon, String label})>[
      (icon: Icons.library_music_outlined, label: 'Songs'),
      (icon: Icons.event_note_outlined, label: 'Service plans'),
      (icon: Icons.music_note_outlined, label: 'MusicXML'),
    ];

    if (compact) {
      return NavigationBar(
        selectedIndex: selected.index,
        onDestinationSelected: (index) =>
            onSelected(LibrarySection.values[index]),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Text(
                'Library',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            for (var index = 0; index < destinations.length; index++)
              ListTile(
                minTileHeight: 56,
                leading: Icon(destinations[index].icon),
                title: Text(destinations[index].label),
                selected: selected.index == index,
                onTap: () => onSelected(LibrarySection.values[index]),
              ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('The Worship Focus'),
            ),
          ],
        ),
      ),
    );
  }
}
