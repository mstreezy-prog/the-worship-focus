import 'music_xml_arrangement.dart';

class Song {
  final String id;
  final String title;
  final String? artist;

  /// The editable ChordPro source for this song.
  final String chordPro;

  final MusicXmlArrangement? leadSheet;
  final MusicXmlArrangement? fullPiano;

  final String? key;
  final int? tempo;

  Song({
    required this.id,
    required this.title,
    required this.chordPro,
    this.artist,
    this.leadSheet,
    this.fullPiano,
    this.key,
    this.tempo,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    bool clearArtist = false,
    String? chordPro,
    MusicXmlArrangement? leadSheet,
    bool clearLeadSheet = false,
    MusicXmlArrangement? fullPiano,
    bool clearFullPiano = false,
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
      leadSheet: clearLeadSheet ? null : leadSheet ?? this.leadSheet,
      fullPiano: clearFullPiano ? null : fullPiano ?? this.fullPiano,
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
      'leadSheet': leadSheet?.toJson(),
      'fullPiano': fullPiano?.toJson(),
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

    final legacyMusicXml = json['musicXml'];
    return Song(
      id: id,
      title: title,
      chordPro: chordPro,
      artist: json['artist'] as String?,
      leadSheet:
          _arrangementFromJson(json['leadSheet']) ??
          (legacyMusicXml is String
              ? MusicXmlArrangement(
                  fileName: 'Legacy-Lead-Sheet.musicxml',
                  sourceXml: legacyMusicXml,
                )
              : null),
      fullPiano: _arrangementFromJson(json['fullPiano']),
      key: json['key'] as String?,
      tempo: json['tempo'] as int?,
    );
  }

  MusicXmlArrangement? arrangement(MusicXmlArrangementType type) {
    return switch (type) {
      MusicXmlArrangementType.leadSheet => leadSheet,
      MusicXmlArrangementType.fullPiano => fullPiano,
    };
  }

  static MusicXmlArrangement? _arrangementFromJson(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, Object?>) {
      throw const FormatException('Invalid saved MusicXML arrangement');
    }
    return MusicXmlArrangement.fromJson(value);
  }
}
