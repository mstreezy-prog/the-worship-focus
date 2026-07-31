import 'package:flutter/material.dart';

import '../models/song.dart';

class SongList extends StatelessWidget {
  const SongList({
    required this.songs,
    required this.selectedSong,
    required this.serviceSongIds,
    required this.onSelected,
    required this.onServiceToggled,
    super.key,
  });

  final List<Song> songs;
  final Song? selectedSong;
  final Set<String> serviceSongIds;
  final ValueChanged<Song> onSelected;
  final ValueChanged<Song> onServiceToggled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Songs', style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                minTileHeight: 60,
                title: Text(song.title),
                subtitle: song.artist == null ? null : Text(song.artist!),
                selected: selectedSong?.id == song.id,
                onTap: () => onSelected(song),
                trailing: IconButton(
                  tooltip: serviceSongIds.contains(song.id)
                      ? 'Remove from service plan'
                      : 'Add to service plan',
                  onPressed: () => onServiceToggled(song),
                  icon: Icon(
                    serviceSongIds.contains(song.id)
                        ? Icons.playlist_add_check
                        : Icons.playlist_add,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
