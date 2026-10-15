import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/reader_annotation_controller.dart';
import '../models/score_annotation.dart';
import '../models/score_display_preferences.dart';
import '../services/music_xml_display_transformer.dart';
import '../services/notation_renderer.dart';
import 'score_annotation_canvas.dart';

/// A continuous vertical score. Rendering at a stable logical width keeps
/// existing full-score Pencil coordinates unchanged during scrolling/rotation.
class ScrollableScoreView extends StatefulWidget {
  const ScrollableScoreView({
    required this.musicXml,
    required this.preferences,
    required this.annotations,
    required this.tool,
    required this.color,
    this.widthScale = 1,
    this.scrollController,
    this.transformationController,
    super.key,
  });
  final String musicXml;
  final ScoreDisplayPreferences preferences;
  final ReaderAnnotationController annotations;
  final ScoreAnnotationTool tool;
  final ScoreAnnotationColor color;
  final double widthScale;
  final ScrollController? scrollController;
  final TransformationController? transformationController;

  @override
  State<ScrollableScoreView> createState() => _ScrollableScoreViewState();
}

class _ScrollableScoreViewState extends State<ScrollableScoreView> {
  late Future<NotationDocument> _document;
  NotationDocument? _laidOutDocument;
  ScoreDisplayPreferences? _laidOutPreferences;
  NotationCanvas? _canvas;

  @override
  void initState() {
    super.initState();
    _document = _load();
  }

  @override
  void didUpdateWidget(ScrollableScoreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.musicXml != widget.musicXml) _document = _load();
  }

  Future<NotationDocument> _load() async {
    await NotationRenderer.initialize();
    return NotationRenderer.parse(
      MusicXmlDisplayTransformer.prepare(widget.musicXml),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<NotationDocument>(
    future: _document,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This score could not be rendered.'),
              TextButton(
                onPressed: () => setState(() => _document = _load()),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final document = snapshot.requireData;
      if (!identical(document, _laidOutDocument) ||
          widget.preferences != _laidOutPreferences) {
        _canvas = document.layout(width: 804, preferences: widget.preferences);
        _laidOutDocument = document;
        _laidOutPreferences = widget.preferences;
      }
      final score = _canvas!;
      return LayoutBuilder(
        builder: (context, constraints) {
          final paper = SizedBox(
            width: math.min(860, math.max(1, constraints.maxWidth - 32)),
            child: FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              child: Container(
                width: 860,
                height: score.height + 96,
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 56),
                color: Colors.white,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        label: 'Rendered score',
                        child: CustomPaint(painter: score.painter),
                      ),
                    ),
                    Positioned.fill(
                      child: ScoreAnnotationCanvas(
                        annotations:
                            widget.annotations.annotations['score'] ?? const [],
                        tool: widget.tool,
                        color: widget.color,
                        widthScale: widget.widthScale,
                        onChanged: (strokes) =>
                            widget.annotations.update('score', strokes),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          final transformation = widget.transformationController;
          if (transformation != null) {
            return InteractiveViewer(
              key: const ValueKey('xml-vertical-viewer'),
              transformationController: transformation,
              constrained: false,
              alignment: Alignment.topCenter,
              boundaryMargin: const EdgeInsets.all(80),
              minScale: 0.6,
              maxScale: 2.5,
              panEnabled: widget.tool == ScoreAnnotationTool.none,
              scaleEnabled: widget.tool == ScoreAnnotationTool.none,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: paper,
              ),
            );
          }
          return SingleChildScrollView(
            key: const ValueKey('xml-vertical-reader'),
            controller: widget.scrollController,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: paper),
            ),
          );
        },
      );
    },
  );
}
