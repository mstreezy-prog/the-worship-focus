import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class NotationRenderer {
  NotationRenderer._();

  static Future<void>? _initialization;

  /// Text treatments chosen for legibility on an iPad music stand.
  ///
  /// MusicXML lyric elements use [lyricTextStyle]. Harmony labels are made
  /// renderer-readable as MusicXML direction words, so they use the
  /// expression style until the notation package natively supports harmony.
  static const scoreTheme = MusicScoreTheme(
    lyricTextStyle: TextStyle(
      fontFamily: 'CMG Sans',
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    expressionTextStyle: TextStyle(
      fontFamily: 'CMG Sans',
      fontSize: 16,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.normal,
    ),
    chordTextStyle: TextStyle(
      fontFamily: 'CMG Sans',
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );

  static Future<void> initialize() async {
    final initialization = _initialization ??= _loadAssets();
    try {
      await initialization;
    } on Object {
      if (identical(_initialization, initialization)) _initialization = null;
      rethrow;
    }
  }

  static Future<void> _loadAssets() async {
    final loader = FontLoader('Bravura')
      ..addFont(
        rootBundle.load('packages/flutter_notemus/assets/smufl/Bravura.otf'),
      );
    await loader.load();
    await SmuflMetadata().load();
  }

  static NotationDocument parse(String musicXml) {
    return NotationDocument._(MusicXMLParser.scoreFromMusicXML(musicXml));
  }
}

class NotationDocument {
  const NotationDocument._(this._score);

  final Score _score;

  int get staffGroupCount => _score.staffGroups.length;

  int get staffCount =>
      _score.staffGroups.fold(0, (total, group) => total + group.staves.length);

  Widget buildView({Key? key, double staffSpace = 10}) {
    return ScoreView(
      key: key,
      score: _score,
      staffSpace: staffSpace,
      theme: NotationRenderer.scoreTheme,
    );
  }
}
