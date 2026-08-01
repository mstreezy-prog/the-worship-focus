import 'package:flutter/material.dart';

import '../models/music_xml_arrangement.dart';
import '../models/song.dart';

class MusicXmlWorkspace extends StatelessWidget {
  const MusicXmlWorkspace({
    required this.songs,
    required this.selectedSong,
    required this.onSongSelected,
    required this.onImport,
    required this.onExport,
    required this.onRemove,
    super.key,
  });

  final List<Song> songs;
  final Song? selectedSong;
  final ValueChanged<Song> onSongSelected;
  final ValueChanged<MusicXmlArrangementType> onImport;
  final ValueChanged<MusicXmlArrangementType> onExport;
  final ValueChanged<MusicXmlArrangementType> onRemove;

  @override
  Widget build(BuildContext context) {
    final song = selectedSong;
    if (song == null) {
      return const Center(child: Text('Create or select a song to add scores'));
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MusicXML arrangements',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Attach one lead sheet and one full-piano score. Original files remain unchanged.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  key: const ValueKey('musicxml-song-selector'),
                  initialValue: song.id,
                  decoration: const InputDecoration(
                    labelText: 'Song',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in songs)
                      DropdownMenuItem(value: item.id, child: Text(item.title)),
                  ],
                  onChanged: (id) {
                    final selected = songs
                        .where((candidate) => candidate.id == id)
                        .firstOrNull;
                    if (selected != null) onSongSelected(selected);
                  },
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                for (final type in MusicXmlArrangementType.values)
                  _ArrangementCard(
                    type: type,
                    arrangement: song.arrangement(type),
                    onImport: () => onImport(type),
                    onExport: () => onExport(type),
                    onRemove: () => onRemove(type),
                  ),
              ];
              if (constraints.crossAxisExtent < 720) {
                return SliverList.separated(
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (_, index) => cards[index],
                );
              }
              return SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.25,
                children: cards,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArrangementCard extends StatelessWidget {
  const _ArrangementCard({
    required this.type,
    required this.arrangement,
    required this.onImport,
    required this.onExport,
    required this.onRemove,
  });

  final MusicXmlArrangementType type;
  final MusicXmlArrangement? arrangement;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final document = arrangement;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  type == MusicXmlArrangementType.leadSheet
                      ? Icons.music_note_outlined
                      : Icons.piano_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (document != null)
                  const Chip(
                    avatar: Icon(Icons.check_circle_outline, size: 18),
                    label: Text('Attached'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (document == null)
              const SizedBox(
                height: 112,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text('No MusicXML score attached.'),
                ),
              )
            else
              SizedBox(
                height: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.scoreTitle ?? document.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      document.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${document.partCount ?? 0} score part${document.partCount == 1 ? '' : 's'} • ${document.isCompressed ? 'Compressed MXL' : 'MusicXML'}',
                    ),
                    const SizedBox(height: 8),
                    const Text('Key: Original'),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(document == null ? 'Import' : 'Replace'),
                ),
                if (document != null) ...[
                  OutlinedButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('Export'),
                  ),
                  IconButton(
                    tooltip: 'Remove ${type.label}',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
