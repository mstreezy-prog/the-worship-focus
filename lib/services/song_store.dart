import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/song.dart';

abstract interface class SongStore {
  Future<List<Song>?> readSongs();
  Future<void> writeSongs(List<Song> songs);
}

class JsonSongStore implements SongStore {
  JsonSongStore({this.fileName = 'worship_focus_library.json'});

  final String fileName;

  Future<File> _libraryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  @override
  Future<List<Song>?> readSongs() async {
    final file = await _libraryFile();
    if (!await file.exists()) return null;

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List<Object?>) {
      throw const FormatException('Saved song library is not a list');
    }
    return decoded
        .map((value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('Saved song entry is invalid');
          }
          return Song.fromJson(value);
        })
        .toList(growable: false);
  }

  @override
  Future<void> writeSongs(List<Song> songs) async {
    final file = await _libraryFile();
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert(songs.map((song) => song.toJson()).toList());
    await file.writeAsString(encoded, flush: true);
  }
}
