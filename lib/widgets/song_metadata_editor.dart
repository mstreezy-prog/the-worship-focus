import 'package:flutter/material.dart';

import '../models/song.dart';

class SongMetadataEditor extends StatelessWidget {
  const SongMetadataEditor({
    required this.song,
    required this.onTitleChanged,
    required this.onArtistChanged,
    required this.onKeyChanged,
    required this.onTempoChanged,
    super.key,
  });

  final Song song;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onArtistChanged;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<String> onTempoChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final title = _field(
              flex: 3,
              key: ValueKey('title-${song.id}'),
              initialValue: song.title,
              label: 'Title',
              onChanged: onTitleChanged,
            );
            final artist = _field(
              flex: 2,
              key: ValueKey('artist-${song.id}'),
              initialValue: song.artist,
              label: 'Artist',
              onChanged: onArtistChanged,
            );
            final key = _field(
              key: ValueKey('key-${song.id}'),
              initialValue: song.key,
              label: 'Key',
              onChanged: onKeyChanged,
              capitalization: TextCapitalization.characters,
            );
            final tempo = _field(
              key: ValueKey('tempo-${song.id}'),
              initialValue: song.tempo?.toString(),
              label: 'Tempo',
              suffix: 'BPM',
              onChanged: onTempoChanged,
              keyboardType: TextInputType.number,
            );

            if (constraints.maxWidth >= 620) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(width: 8),
                  artist,
                  const SizedBox(width: 8),
                  key,
                  const SizedBox(width: 8),
                  tempo,
                ],
              );
            }
            return Column(
              children: [
                Row(children: [title, const SizedBox(width: 8), artist]),
                const SizedBox(height: 8),
                Row(children: [key, const SizedBox(width: 8), tempo]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required String? initialValue,
    required String label,
    required ValueChanged<String> onChanged,
    int flex = 1,
    String? suffix,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboardType,
  }) {
    return Expanded(
      flex: flex,
      child: TextFormField(
        key: key,
        initialValue: initialValue,
        onChanged: onChanged,
        textCapitalization: capitalization,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
