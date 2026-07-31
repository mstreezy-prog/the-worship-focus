class Song {
  final String id;
  final String title;
  final String? artist;

  /// The editable ChordPro source for this song.
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

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? chordPro,
    String? musicXml,
    String? key,
    int? tempo,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      chordPro: chordPro ?? this.chordPro,
      musicXml: musicXml ?? this.musicXml,
      key: key ?? this.key,
      tempo: tempo ?? this.tempo,
    );
  }
}
