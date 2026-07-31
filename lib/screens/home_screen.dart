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
import 'performance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LibraryController _controller = LibraryController();
  final ChordProDocumentService _documents = ChordProDocumentService();
  int _compactDetailIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openPerformance(Song song) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PerformanceScreen(song: song),
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
      final song = _controller.addImportedSong(document);
      messenger.showSnackBar(SnackBar(content: Text('Imported ${song.title}')));
    } on Object catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import file: $error')),
      );
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
                title: const Text('Worship Focus'),
                actions: [
                  IconButton(
                    tooltip: 'Import ChordPro',
                    onPressed: _importChordPro,
                    icon: const Icon(Icons.file_open_outlined),
                  ),
                  if (_controller.selectedSong != null) ...[
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
                      onPressed: () =>
                          _openPerformance(_controller.selectedSong!),
                      icon: const Icon(Icons.fullscreen),
                    ),
                    IconButton(
                      tooltip: 'Export service packet',
                      onPressed: _controller.serviceSongs.isEmpty
                          ? null
                          : _exportServicePacket,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
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
        SizedBox(height: 180, child: _buildSongList()),
        const Divider(height: 1),
        if (song != null)
          Expanded(
            child: Column(
              children: [
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
      songs: _controller.songs,
      selectedSong: _controller.selectedSong,
      serviceSongIds: _controller.serviceSongIds,
      onSelected: _controller.selectSong,
      onServiceToggled: _controller.toggleServiceSong,
    );
  }

  Widget _buildSongWorkspace() {
    final song = _controller.selectedSong;
    if (song == null) {
      return const Center(child: Text('Select a song to begin'));
    }
    return LayoutBuilder(
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
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: PreviewPanel(song: song)),
          ],
        );
      },
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
