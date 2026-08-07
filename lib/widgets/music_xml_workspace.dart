import 'package:flutter/material.dart';

import '../models/music_xml_arrangement.dart';
import '../models/song.dart';
import '../services/music_xml_transposer.dart';

class MusicXmlWorkspace extends StatelessWidget {
  const MusicXmlWorkspace({
    required this.songs,
    required this.selectedSong,
    required this.onSongSelected,
    required this.onImport,
    required this.onView,
    required this.onPerform,
    required this.onTranspose,
    required this.onExport,
    required this.onRemove,
    super.key,
  });

  final List<Song> songs;
  final Song? selectedSong;
  final ValueChanged<Song> onSongSelected;
  final ValueChanged<MusicXmlArrangementType> onImport;
  final ValueChanged<MusicXmlArrangementType> onView;
  final ValueChanged<MusicXmlArrangementType> onPerform;
  final MusicXmlTransposeCallback onTranspose;
  final ValueChanged<MusicXmlArrangementType> onExport;
  final ValueChanged<MusicXmlArrangementType> onRemove;

  @override
  Widget build(BuildContext context) {
    final song = selectedSong;
    if (song == null) {
      return const Center(child: Text('Create or select a song to add scores'));
    }
    final attachedTypes = [
      for (final type in MusicXmlArrangementType.values)
        if (song.arrangement(type) != null) type,
    ];
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
                if (attachedTypes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Open attached score',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in attachedTypes)
                        FilledButton.tonalIcon(
                          onPressed: () => onView(type),
                          icon: Icon(
                            type == MusicXmlArrangementType.leadSheet
                                ? Icons.music_note_outlined
                                : Icons.piano_outlined,
                          ),
                          label: Text('Open ${type.label}'),
                        ),
                      for (final type in attachedTypes)
                        FilledButton.tonalIcon(
                          onPressed: () => onPerform(type),
                          icon: const Icon(Icons.fullscreen),
                          label: Text('Go live: ${type.label}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Transpose',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final type in attachedTypes)
                        _ArrangementKeyControl(
                          type: type,
                          arrangement: song.arrangement(type)!,
                          onChanged: (semitones) =>
                              onTranspose(type, semitones),
                        ),
                    ],
                  ),
                ],
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
                    onView: () => onView(type),
                    onPerform: () => onPerform(type),
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
                childAspectRatio: 0.78,
                children: cards,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArrangementKeyControl extends StatelessWidget {
  const _ArrangementKeyControl({
    required this.type,
    required this.arrangement,
    required this.onChanged,
  });

  final MusicXmlArrangementType type;
  final MusicXmlArrangement arrangement;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final semitones = arrangement.transposeSemitones;
    final keySignature = MusicXmlTransposer.keySignature(
      arrangement.sourceXml,
      semitones: semitones,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Card.outlined(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              IconButton.outlined(
                tooltip: 'Transpose ${type.label} down',
                onPressed: semitones > MusicXmlTransposer.minimumSemitones
                    ? () => onChanged(semitones - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      keySignature?.label ??
                          MusicXmlTransposer.offsetLabel(semitones),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (semitones != 0)
                      Text(
                        MusicXmlTransposer.offsetLabel(semitones),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Transpose ${type.label} up',
                onPressed: semitones < MusicXmlTransposer.maximumSemitones
                    ? () => onChanged(semitones + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
              if (semitones != 0)
                IconButton(
                  tooltip: 'Reset ${type.label} key',
                  onPressed: () => onChanged(0),
                  icon: const Icon(Icons.restart_alt),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrangementCard extends StatelessWidget {
  const _ArrangementCard({
    required this.type,
    required this.arrangement,
    required this.onImport,
    required this.onView,
    required this.onPerform,
    required this.onExport,
    required this.onRemove,
  });

  final MusicXmlArrangementType type;
  final MusicXmlArrangement? arrangement;
  final VoidCallback onImport;
  final VoidCallback onView;
  final VoidCallback onPerform;
  final VoidCallback onExport;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final document = arrangement;
    final keySignature = document == null
        ? null
        : MusicXmlTransposer.keySignature(
            document.sourceXml,
            semitones: document.transposeSemitones,
          );
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
                    Text(
                      'Key: ${keySignature?.label ?? MusicXmlTransposer.offsetLabel(document.transposeSemitones)}',
                    ),
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
                  FilledButton.tonalIcon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View Score'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onPerform,
                    icon: const Icon(Icons.fullscreen),
                    label: const Text('Go live'),
                  ),
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
