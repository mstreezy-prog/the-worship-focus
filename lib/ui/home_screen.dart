import 'package:flutter/material.dart';

import '../models/song.dart';
import '../models/service_packet.dart';
import '../services/song_repository.dart';
import '../services/chordpro_parser.dart';
import '../services/service_packet_pdf.dart';
import '../widgets/chord_line.dart';
import '../services/chord_layout_engine.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final repo = SongRepository();

  late List<Song> songs;
  Song? selected;

  final List<Song> selectedSongs = [];

  @override
  void initState() {
    super.initState();
    songs = repo.getAll();
    selected = songs.isNotEmpty ? songs.first : null;
  }

  void selectSong(Song song) {
    setState(() {
      selected = song;
    });
  }

  void toggleSong(Song song) {
    setState(() {
      if (selectedSongs.contains(song)) {
        selectedSongs.remove(song);
      } else {
        selectedSongs.add(song);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Worship Focus Studio"),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check),
            onPressed: () async {
              if (selectedSongs.isEmpty) return;

              final packet = ServicePacket(
                title: "Sunday Service Packet",
                songs: selectedSongs,
              );

              final file = await ServicePacketPdf.export(packet);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Saved: ${file.path}")),
              );
            },
          ),
        ],
      ),

      body: Row(
        children: [
          // LEFT: SONG LIST
          Container(
            width: 260,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: ListView(
              children: songs.map((s) {
                return ListTile(
                  leading: Checkbox(
                    value: selectedSongs.contains(s),
                    onChanged: (_) => toggleSong(s),
                  ),
                  title: Text(s.title),
                  selected: selected?.id == s.id,
                  onTap: () => selectSong(s),
                );
              }).toList(),
            ),
          ),

          // RIGHT: PREVIEW (PROPER CHORD ENGINE)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Builder(
                builder: (context) {
                  if (song == null) {
                    return const Center(
                      child: Text("No song selected"),
                    );
                  }

                  final lines = ChordLayoutEngine.build(song.content);

                  return ListView(
                    children: lines
                        .map((line) => ChordLine(line: line))
                        .toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
