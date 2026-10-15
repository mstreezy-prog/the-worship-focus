import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
// Keep the dependency's engraving adapter confined to this service.
// Pinned vendored dependency: its public widget does not expose system metrics.
// ignore: implementation_imports
import 'package:flutter_notemus/src/rendering/grand_staff_painter.dart';

import '../models/score_display_preferences.dart';

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
      fontSize: 17,
      fontWeight: FontWeight.w500,
    ),
    expressionTextStyle: TextStyle(
      fontFamily: 'CMG Sans',
      fontSize: 19,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.normal,
    ),
    chordTextStyle: TextStyle(
      fontFamily: 'CMG Sans',
      fontSize: 19,
      fontWeight: FontWeight.w700,
    ),
    rehearsalTextStyle: TextStyle(
      color: Color(0xFF50637E),
      fontFamily: 'CMG Sans',
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  );

  static MusicScoreTheme scoreThemeFor(ScoreDisplayPreferences preferences) {
    return MusicScoreTheme(
      lyricTextStyle: scoreTheme.lyricTextStyle?.copyWith(
        fontSize: preferences.lyricFontSize,
      ),
      expressionTextStyle: scoreTheme.expressionTextStyle?.copyWith(
        fontSize: preferences.chordFontSize,
      ),
      chordTextStyle: scoreTheme.chordTextStyle?.copyWith(
        fontSize: preferences.chordFontSize,
      ),
      rehearsalTextStyle: scoreTheme.rehearsalTextStyle,
    );
  }

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

  NotationCanvas layout({
    required double width,
    required ScoreDisplayPreferences preferences,
  }) {
    if (staffCount == 0) {
      return const NotationCanvas(painter: null, height: 1);
    }
    final painter = GrandStaffPainter(
      groups: _score.staffGroups,
      staffSpace: preferences.noteSize,
      metadata: SmuflMetadata(),
      theme: NotationRenderer.scoreThemeFor(preferences),
      availableWidth: width,
      staffGap: preferences.staffGap,
      interSystemGap: preferences.interSystemGap,
    );
    return NotationCanvas(painter: painter, height: painter.totalHeight);
  }

  Widget buildView({
    Key? key,
    double staffSpace = 10,
    double? staffGap,
    double? interSystemGap,
    MusicScoreTheme? theme,
  }) {
    return ScoreView(
      key: key,
      score: _score,
      staffSpace: staffSpace,
      staffGap: staffGap,
      interSystemGap: interSystemGap,
      theme: theme ?? NotationRenderer.scoreTheme,
    );
  }
}

class NotationCanvas {
  const NotationCanvas({required this.painter, required this.height});
  final CustomPainter? painter;
  final double height;
}
