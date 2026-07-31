import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/service_packet.dart';
import '../models/song.dart';
import '../services/chordpro_document_service.dart';
import '../services/service_packet_pdf.dart';
import '../widgets/chordpro_editor.dart';
import '../widgets/library_sidebar.dart';
import '../widgets/preview_panel.dart';
import '../widgets/song_list.dart';
import '../widgets/song_metadata_editor.dart';
import 'performance_screen.dart';

enum _ToolbarAction {
  saveAs,
  transposeDown,
  transposeUp,
  performance,
  exportService,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final LibraryController _controller = LibraryController();
  final ChordProDocumentService _documents = ChordProDocumentService();
  int _compactDetailIndex = 0;
  UndoHistoryController _undoController = UndoHistoryController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_controller.flushPendingSave());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _undoController.dispose();
    super.dispose();
  }

  void _resetUndoHistory() {
    final previous = _undoController;
    setState(() => _undoController = UndoHistoryController());
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  void _selectSong(Song song) {
    if (_controller.selectedSong?.id == song.id) return;
    _resetUndoHistory();
    _controller.selectSong(song);
  }

  void _openPerformance(Song song) {
    final songs = _controller.songs;
    final initialIndex = songs.indexWhere(
      (candidate) => candidate.id == song.id,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PerformanceScreen(
          songs: songs,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _exportServicePacket() async {
    final songs = _controller.serviceSongs;
    if (songs.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final file = await ServicePacketPdf.export(
      ServicePacket(title: 'Sunday Service Packet', songs: songs),
    );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Saved: ${file.path}')));
  }

  Future<void> _importChordPro() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final document = await _documents.import();
      if (document == null || !mounted) return;
      _resetUndoHistory();
      final song = _controller.addImportedSong(document);
      messenger.showSnackBar(SnackBar(content: Text('Imported ${song.title}')));
    } on Object catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import file: $error')),
      );
    }
  }

  void _createSong() {
    _resetUndoHistory();
    _controller.createSong();
  }

  void _duplicateSong(Song song) {
    _resetUndoHistory();
    _controller.duplicateSong(song);
  }

  Future<void> _confirmDeleteSong(Song song) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete song?'),
        content: Text(
          '“${song.title.trim().isEmpty ? 'Untitled Song' : song.title}” will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    if (_controller.selectedSong?.id == song.id) _resetUndoHistory();
    _controller.deleteSong(song);
  }

  void _handleSongAction(Song song, SongListAction action) {
    switch (action) {
      case SongListAction.toggleService:
        _controller.toggleServiceSong(song);
        break;
      case SongListAction.duplicate:
        _duplicateSong(song);
        break;
      case SongListAction.delete:
        unawaited(_confirmDeleteSong(song));
        break;
    }
  }

  Future<void> _saveChordPro() async {
    final song = _controller.selectedSong;
    if (song == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await _documents.save(
        title: song.title,
        chordPro: song.chordPro,
      );
      if (path == null || !mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Saved: $path')));
    } on Object catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save file: $error')),
      );
    }
  }

  void _handleToolbarAction(_ToolbarAction action) {
    final song = _controller.selectedSong;
    if (song == null) return;
    switch (action) {
      case _ToolbarAction.saveAs:
        unawaited(_saveChordPro());
        break;
      case _ToolbarAction.transposeDown:
        _controller.transpose(-1);
        break;
      case _ToolbarAction.transposeUp:
        _controller.transpose(1);
        break;
      case _ToolbarAction.performance:
        _openPerformance(song);
        break;
      case _ToolbarAction.exportService:
        unawaited(_exportServicePacket());
        break;
    }
  }

  List<Widget> _buildAppActions(bool wide) {
    final song = _controller.selectedSong;
    return [
      IconButton(
        tooltip: 'Import ChordPro',
        onPressed: _importChordPro,
        icon: const Icon(Icons.file_open_outlined),
      ),
      if (song != null && wide) ...[
        IconButton(
          tooltip: 'Save ChordPro as',
          onPressed: _saveChordPro,
          icon: const Icon(Icons.save_as_outlined),
        ),
        IconButton(
          tooltip: 'Transpose down',
          onPressed: () => _controller.transpose(-1),
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          tooltip: 'Transpose up',
          onPressed: () => _controller.transpose(1),
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: 'Performance mode',
          onPressed: () => _openPerformance(song),
          icon: const Icon(Icons.fullscreen),
        ),
        IconButton(
          tooltip: 'Export service packet',
          onPressed: _controller.serviceSongs.isEmpty
              ? null
              : _exportServicePacket,
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
      ] else if (song != null)
        PopupMenuButton<_ToolbarAction>(
          tooltip: 'Song tools',
          onSelected: _handleToolbarAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _ToolbarAction.saveAs,
              child: ListTile(
                leading: Icon(Icons.save_as_outlined),
                title: Text('Save ChordPro as'),
              ),
            ),
            const PopupMenuItem(
              value: _ToolbarAction.transposeDown,
              child: ListTile(
                leading: Icon(Icons.remove),
                title: Text('Transpose down'),
              ),
            ),
            const PopupMenuItem(
              value: _ToolbarAction.transposeUp,
              child: ListTile(
                leading: Icon(Icons.add),
                title: Text('Transpose up'),
              ),
            ),
            const PopupMenuItem(
              value: _ToolbarAction.performance,
              child: ListTile(
                leading: Icon(Icons.fullscreen),
                title: Text('Performance mode'),
              ),
            ),
            PopupMenuItem(
              value: _ToolbarAction.exportService,
              enabled: _controller.serviceSongs.isNotEmpty,
              child: const ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined),
                title: Text('Export service packet'),
              ),
            ),
          ],
        ),
      const SizedBox(width: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Scaffold(
              appBar: AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Worship Focus'),
                    const SizedBox(width: 12),
                    _SaveStatus(
                      state: _controller.saveState,
                      error: _controller.saveError,
                    ),
                  ],
                ),
                actions: _buildAppActions(wide),
              ),
              body: wide ? _buildWideLayout() : _buildCompactLayout(),
              bottomNavigationBar: wide
                  ? null
                  : LibrarySidebar(
                      compact: true,
                      selected: _controller.section,
                      onSelected: _controller.selectSection,
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: LibrarySidebar(
            selected: _controller.section,
            onSelected: _controller.selectSection,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(flex: 3, child: _buildSection()),
        if (_controller.section == LibrarySection.songs) ...[
          const VerticalDivider(width: 1),
          Expanded(flex: 7, child: _buildSongWorkspace()),
        ],
      ],
    );
  }

  Widget _buildCompactLayout() {
    if (_controller.section != LibrarySection.songs) {
      return _buildSection();
    }
    final song = _controller.selectedSong;
    return Column(
      children: [
        Flexible(flex: 3, child: _buildSongList()),
        const Divider(height: 1),
        if (song != null)
          Expanded(
            flex: 7,
            child: Column(
              children: [
                SongMetadataEditor(
                  song: song,
                  onTitleChanged: _controller.updateTitle,
                  onArtistChanged: _controller.updateArtist,
                  onKeyChanged: _controller.updateKey,
                  onTempoChanged: _controller.updateTempo,
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Editor')),
                    ButtonSegment(value: 1, label: Text('Preview')),
                  ],
                  selected: {_compactDetailIndex},
                  onSelectionChanged: (selection) {
                    setState(() => _compactDetailIndex = selection.first);
                  },
                ),
                Expanded(
                  child: _compactDetailIndex == 0
                      ? ChordProEditor(
                          song: song,
                          onChanged: _controller.updateChordPro,
                          undoController: _undoController,
                        )
                      : PreviewPanel(song: song),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSection() {
    return switch (_controller.section) {
      LibrarySection.songs => _buildSongList(),
      LibrarySection.servicePlans => const _Placeholder(
        icon: Icons.event_note_outlined,
        title: 'Service plans',
        message: 'Build and rehearse service orders here.',
      ),
      LibrarySection.musicXml => const _Placeholder(
        icon: Icons.music_note_outlined,
        title: 'MusicXML',
        message: 'MusicXML viewing and editing will arrive in a later phase.',
      ),
    };
  }

  Widget _buildSongList() {
    return SongList(
      songs: _controller.visibleSongs,
      selectedSong: _controller.selectedSong,
      serviceSongIds: _controller.serviceSongIds,
      searchQuery: _controller.searchQuery,
      songSort: _controller.songSort,
      sortAscending: _controller.sortAscending,
      onSelected: _selectSong,
      onSearchChanged: _controller.setSearchQuery,
      onSortChanged: _controller.setSongSort,
      onSortDirectionChanged: _controller.toggleSortDirection,
      onCreate: _createSong,
      onAction: _handleSongAction,
    );
  }

  Widget _buildSongWorkspace() {
    final song = _controller.selectedSong;
    if (song == null) {
      return const Center(child: Text('Select a song to begin'));
    }
    return Column(
      children: [
        SongMetadataEditor(
          song: song,
          onTitleChanged: _controller.updateTitle,
          onArtistChanged: _controller.updateArtist,
          onKeyChanged: _controller.updateKey,
          onTempoChanged: _controller.updateTempo,
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650) {
                return _buildTabbedWorkspace(song);
              }
              return Row(
                children: [
                  Expanded(
                    child: ChordProEditor(
                      song: song,
                      onChanged: _controller.updateChordPro,
                      undoController: _undoController,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: PreviewPanel(song: song)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabbedWorkspace(Song song) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Editor'),
              Tab(text: 'Preview'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ChordProEditor(
                  song: song,
                  onChanged: _controller.updateChordPro,
                  undoController: _undoController,
                ),
                PreviewPanel(song: song),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SaveStatus extends StatelessWidget {
  const _SaveStatus({required this.state, this.error});

  final LibrarySaveState state;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (state) {
      LibrarySaveState.loading => (Icons.sync, 'Loading'),
      LibrarySaveState.saved => (Icons.cloud_done_outlined, 'Saved'),
      LibrarySaveState.unsaved => (Icons.edit_outlined, 'Unsaved'),
      LibrarySaveState.saving => (Icons.sync, 'Saving'),
      LibrarySaveState.error => (Icons.error_outline, 'Save error'),
    };
    return Tooltip(
      message: error ?? label,
      child: Semantics(
        label: error ?? label,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
