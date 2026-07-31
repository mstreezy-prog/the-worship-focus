import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/song.dart';

enum SongListAction { toggleService, duplicate, delete }

class SongList extends StatelessWidget {
  const SongList({
    required this.songs,
    required this.selectedSong,
    required this.serviceSongIds,
    required this.searchQuery,
    required this.songSort,
    required this.sortAscending,
    required this.onSelected,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onSortDirectionChanged,
    required this.onCreate,
    required this.onAction,
    super.key,
  });

  final List<Song> songs;
  final Song? selectedSong;
  final Set<String> serviceSongIds;
  final String searchQuery;
  final SongSort songSort;
  final bool sortAscending;
  final ValueChanged<Song> onSelected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SongSort> onSortChanged;
  final VoidCallback onSortDirectionChanged;
  final VoidCallback onCreate;
  final void Function(Song song, SongListAction action) onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Songs',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'New song',
                onPressed: onCreate,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextFormField(
            initialValue: searchQuery,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search songs',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              const Text('Sort by'),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<SongSort>(
                  value: songSort,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: SongSort.title,
                      child: Text('Title'),
                    ),
                    DropdownMenuItem(
                      value: SongSort.artist,
                      child: Text('Artist'),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: sortAscending ? 'Sort descending' : 'Sort ascending',
                onPressed: onSortDirectionChanged,
                icon: Icon(
                  sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: songs.isEmpty
              ? const Center(child: Text('No songs match your search'))
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final inService = serviceSongIds.contains(song.id);
                    return ListTile(
                      minTileHeight: 60,
                      title: Text(
                        song.title.trim().isEmpty
                            ? 'Untitled Song'
                            : song.title,
                      ),
                      subtitle: song.artist == null ? null : Text(song.artist!),
                      selected: selectedSong?.id == song.id,
                      onTap: () => onSelected(song),
                      trailing: PopupMenuButton<SongListAction>(
                        tooltip: 'Song actions',
                        onSelected: (action) => onAction(song, action),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: SongListAction.toggleService,
                            child: ListTile(
                              leading: Icon(
                                inService
                                    ? Icons.playlist_remove
                                    : Icons.playlist_add,
                              ),
                              title: Text(
                                inService
                                    ? 'Remove from service'
                                    : 'Add to service',
                              ),
                            ),
                          ),
                          const PopupMenuItem(
                            value: SongListAction.duplicate,
                            child: ListTile(
                              leading: Icon(Icons.copy_outlined),
                              title: Text('Duplicate'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: SongListAction.delete,
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
