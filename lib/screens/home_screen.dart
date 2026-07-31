import 'package:flutter/material.dart';

import '../models/service_packet.dart';
import '../models/song.dart';
import '../services/chord_layout_engine.dart';
import '../services/service_packet_pdf.dart';
import '../services/song_repository.dart';
import '../widgets/chord_line.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SongRepository _repository = SongRepository();
  final List<Song> _serviceSongs = [];
  late final List<Song> _songs;
  Song? _selected;

  @override
  void initState() {
    super.initState();
    _songs = _repository.getAll();
    _selected = _songs.firstOrNull;
  }

  Future<void> _exportServicePacket() async {
    if (_serviceSongs.isEmpty) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final file = await ServicePacketPdf.export(
      ServicePacket(
        title: 'Sunday Service Packet',
        songs: List.unmodifiable(_serviceSongs),
      ),
    );
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text('Saved: ${file.path}')));
  }

  @override
  Widget build(BuildContext context) {
    final song = _selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worship Focus Studio'),
        actions: [
          IconButton(
            tooltip: 'Export service packet',
            icon: const Icon(Icons.playlist_add_check),
            onPressed: _serviceSongs.isEmpty ? null : _exportServicePacket,
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 260,
            child: ListView(
              children: _songs.map((item) {
                return ListTile(
                  leading: Checkbox(
                    value: _serviceSongs.contains(item),
                    onChanged: (_) {
                      setState(() {
                        _serviceSongs.contains(item)
                            ? _serviceSongs.remove(item)
                            : _serviceSongs.add(item);
                      });
                    },
                  ),
                  title: Text(item.title),
                  selected: song?.id == item.id,
                  onTap: () => setState(() => _selected = item),
                );
              }).toList(),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: song == null
                ? const Center(child: Text('No song selected'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: ChordLayoutEngine.build(
                      song.chordPro,
                    ).map((line) => ChordLine(line: line)).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
