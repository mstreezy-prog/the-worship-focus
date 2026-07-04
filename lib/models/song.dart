class Song {
  final String id;
  final String title;
  final String? artist;

  /// Primary formats (we now support both)
  final String chordPro;

  /// Optional MusicXML (for sheet music / piano parts later)
  final String? musicXml;

  final String? key;
  final int? tempo;

  Song({
    required this.id,
    required this.title,
    required this.chordPro,
    this.artist,
    this.musicXml,
    this.key,
    this.tempo,
  });
}