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
    bool clearArtist = false,
    String? chordPro,
    String? musicXml,
    String? key,
    bool clearKey = false,
    int? tempo,
    bool clearTempo = false,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: clearArtist ? null : artist ?? this.artist,
      chordPro: chordPro ?? this.chordPro,
      musicXml: musicXml ?? this.musicXml,
      key: clearKey ? null : key ?? this.key,
      tempo: clearTempo ? null : tempo ?? this.tempo,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'chordPro': chordPro,
      'musicXml': musicXml,
      'key': key,
      'tempo': tempo,
    };
  }

  factory Song.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final chordPro = json['chordPro'];
    if (id is! String || title is! String || chordPro is! String) {
      throw const FormatException('Invalid saved song');
    }

    return Song(
      id: id,
      title: title,
      chordPro: chordPro,
      artist: json['artist'] as String?,
      musicXml: json['musicXml'] as String?,
      key: json['key'] as String?,
      tempo: json['tempo'] as int?,
    );
  }
}
