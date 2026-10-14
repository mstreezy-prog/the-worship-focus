import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/score_display_controller.dart';
import '../models/music_xml_arrangement.dart';
import '../models/performance_content.dart';
import '../models/score_annotation.dart';
import '../models/score_display_preferences.dart';
import '../models/song.dart';
import '../services/music_xml_transposer.dart';
import '../widgets/notation_score_view.dart';
import '../widgets/score_annotation_canvas.dart';
import 'performance_screen.dart';

class MusicXmlViewerScreen extends StatefulWidget {
  MusicXmlViewerScreen({
    required this.song,
    required this.initialType,
    required this.onTranspose,
    required this.onAnnotationsChanged,
    this.displayController,
    super.key,
  }) : assert(
         song.leadSheet != null || song.fullPiano != null,
         'The score viewer requires an attached MusicXML arrangement.',
       );

  final Song song;
  final MusicXmlArrangementType initialType;
  final MusicXmlTransposeCallback onTranspose;
  final MusicXmlAnnotationsChangedCallback onAnnotationsChanged;
  final ScoreDisplayController? displayController;

  @override
  State<MusicXmlViewerScreen> createState() => _MusicXmlViewerScreenState();
}

class _MusicXmlViewerScreenState extends State<MusicXmlViewerScreen> {
  final TransformationController _transformation = TransformationController();
  final GlobalKey<ScoreAnnotationCanvasState> _annotationCanvasKey =
      GlobalKey<ScoreAnnotationCanvasState>();
  late MusicXmlArrangementType _selectedType;
  late final Map<MusicXmlArrangementType, int> _transposeSemitones;
  late final Map<MusicXmlArrangementType, List<ScoreAnnotationStroke>>
  _annotations;
  late final ScoreDisplayController _displayController;
  late final bool _ownsDisplayController;
  ScoreAnnotationTool _annotationTool = ScoreAnnotationTool.none;
  ScoreAnnotationColor _annotationColor = ScoreAnnotationColor.purple;

  List<MusicXmlArrangementType> get _availableTypes => [
    for (final type in MusicXmlArrangementType.values)
      if (widget.song.arrangement(type) != null) type,
  ];

  MusicXmlArrangement get _arrangement {
    return _arrangementFor(_selectedType);
  }

  MusicXmlArrangement _arrangementFor(MusicXmlArrangementType type) {
    final arrangement = widget.song.arrangement(type)!;
    return arrangement.copyWith(
      transposeSemitones:
          _transposeSemitones[type] ?? arrangement.transposeSemitones,
      annotations: _annotations[type] ?? arrangement.annotations,
    );
  }

  Song get _performanceSong => widget.song.copyWith(
    leadSheet: widget.song.leadSheet == null
        ? null
        : _arrangementFor(MusicXmlArrangementType.leadSheet),
    fullPiano: widget.song.fullPiano == null
        ? null
        : _arrangementFor(MusicXmlArrangementType.fullPiano),
  );

  void _openPerformance() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PerformanceScreen(
          songs: [_performanceSong],
          initialIndex: 0,
          initialContent: PerformanceContentDetails.fromArrangement(
            _selectedType,
          ),
          initialScoreDisplayPreferences: _displayController.preferences,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ownsDisplayController = widget.displayController == null;
    _displayController = widget.displayController ?? ScoreDisplayController();
    unawaited(_displayController.initialize());
    _selectedType = widget.song.arrangement(widget.initialType) != null
        ? widget.initialType
        : _availableTypes.first;
    _transposeSemitones = {
      for (final type in _availableTypes)
        type: widget.song.arrangement(type)!.transposeSemitones,
    };
    _annotations = {
      for (final type in _availableTypes)
        type: widget.song.arrangement(type)!.annotations,
    };
  }

  @override
  void dispose() {
    _transformation.dispose();
    if (_ownsDisplayController) _displayController.dispose();
    super.dispose();
  }

  void _selectType(MusicXmlArrangementType type) {
    if (type == _selectedType) return;
    setState(() => _selectedType = type);
    _fitScore();
  }

  bool get _isAnnotating => _annotationTool != ScoreAnnotationTool.none;

  void _setAnnotationTool(ScoreAnnotationTool tool) {
    setState(() {
      _annotationTool = _annotationTool == tool
          ? ScoreAnnotationTool.none
          : tool;
    });
  }

  void _setAnnotationColor(ScoreAnnotationColor color) {
    setState(() => _annotationColor = color);
  }

  void _updateAnnotations(List<ScoreAnnotationStroke> annotations) {
    setState(() => _annotations[_selectedType] = annotations);
    widget.onAnnotationsChanged(_selectedType, annotations);
  }

  void _zoom(double factor) {
    final currentScale = _transformation.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.6, 2.5).toDouble();
    final relativeScale = targetScale / currentScale;
    _transformation.value = _transformation.value.clone()
      ..scaleByDouble(relativeScale, relativeScale, 1, 1);
  }

  void _fitScore() {
    _transformation.value = Matrix4.identity();
  }

  Future<void> _showScoreDisplaySettings() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          _ScoreDisplaySettingsSheet(controller: _displayController),
    );
  }

  void _setTranspose(int semitones) {
    final boundedSemitones = semitones
        .clamp(
          MusicXmlTransposer.minimumSemitones,
          MusicXmlTransposer.maximumSemitones,
        )
        .toInt();
    if (_arrangement.transposeSemitones == boundedSemitones) return;
    setState(() => _transposeSemitones[_selectedType] = boundedSemitones);
    widget.onTranspose(_selectedType, boundedSemitones);
    _fitScore();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _displayController,
      builder: (context, _) {
        final arrangement = _arrangement;
        final displayPreferences = _displayController.preferences;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.song.title),
            actions: [
              IconButton(
                tooltip: 'Zoom out',
                onPressed: () => _zoom(0.8),
                icon: const Icon(Icons.zoom_out),
              ),
              IconButton(
                tooltip: 'Fit score',
                onPressed: _fitScore,
                icon: const Icon(Icons.fit_screen_outlined),
              ),
              IconButton(
                tooltip: 'Zoom in',
                onPressed: () => _zoom(1.25),
                icon: const Icon(Icons.zoom_in),
              ),
              IconButton(
                tooltip: 'Score display settings',
                onPressed: _showScoreDisplaySettings,
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                tooltip: 'Go live with score',
                onPressed: _openPerformance,
                icon: const Icon(Icons.fullscreen),
              ),
              IconButton(
                tooltip: _annotationTool == ScoreAnnotationTool.pen
                    ? 'Stop annotating'
                    : 'Annotate with Apple Pencil',
                onPressed: () => _setAnnotationTool(ScoreAnnotationTool.pen),
                color: _annotationTool == ScoreAnnotationTool.pen
                    ? Theme.of(context).colorScheme.primary
                    : null,
                icon: const Icon(Icons.draw_outlined),
              ),
              IconButton(
                tooltip: _annotationTool == ScoreAnnotationTool.highlighter
                    ? 'Stop highlighting'
                    : 'Highlight with Apple Pencil',
                onPressed: () =>
                    _setAnnotationTool(ScoreAnnotationTool.highlighter),
                color: _annotationTool == ScoreAnnotationTool.highlighter
                    ? Theme.of(context).colorScheme.primary
                    : null,
                icon: const Icon(Icons.highlight_outlined),
              ),
              IconButton(
                tooltip: _annotationTool == ScoreAnnotationTool.eraser
                    ? 'Stop erasing'
                    : 'Erase annotations with Apple Pencil',
                onPressed: () => _setAnnotationTool(ScoreAnnotationTool.eraser),
                color: _annotationTool == ScoreAnnotationTool.eraser
                    ? Theme.of(context).colorScheme.primary
                    : null,
                icon: const Icon(Icons.auto_fix_off_outlined),
              ),
              PopupMenuButton<ScoreAnnotationColor>(
                tooltip: 'Annotation color',
                icon: Icon(
                  Icons.palette_outlined,
                  color: _annotationColor.color,
                ),
                onSelected: _setAnnotationColor,
                itemBuilder: (context) => [
                  for (final color in ScoreAnnotationColor.values)
                    PopupMenuItem(
                      value: color,
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: color.color, radius: 9),
                          const SizedBox(width: 12),
                          Text(color.label),
                        ],
                      ),
                    ),
                ],
              ),
              IconButton(
                tooltip: 'Undo annotation',
                onPressed: _annotationCanvasKey.currentState?.canUndo ?? false
                    ? () => _annotationCanvasKey.currentState?.undo()
                    : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Redo annotation',
                onPressed: _annotationCanvasKey.currentState?.canRedo ?? false
                    ? () => _annotationCanvasKey.currentState?.redo()
                    : null,
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                tooltip: 'Clear score annotations',
                onPressed: _arrangement.annotations.isEmpty
                    ? null
                    : () => _annotationCanvasKey.currentState?.clear(),
                icon: const Icon(Icons.layers_clear_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              _ViewerHeader(
                arrangement: arrangement,
                availableTypes: _availableTypes,
                selectedType: _selectedType,
                onSelected: _selectType,
                onTranspose: _setTranspose,
              ),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final paperWidth = (constraints.maxWidth - 32)
                        .clamp(360.0, 780.0)
                        .toDouble();
                    return ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: InteractiveViewer(
                        transformationController: _transformation,
                        alignment: Alignment.topCenter,
                        boundaryMargin: const EdgeInsets.all(80),
                        constrained: false,
                        minScale: 0.6,
                        maxScale: 2.5,
                        panEnabled: !_isAnnotating,
                        scaleEnabled: !_isAnnotating,
                        child: Container(
                          width: paperWidth,
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          padding: const EdgeInsets.fromLTRB(28, 36, 28, 48),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            fit: StackFit.passthrough,
                            children: [
                              NotationScoreView(
                                key: ValueKey(
                                  '${_selectedType.name}-${arrangement.transposeSemitones}',
                                ),
                                musicXml: MusicXmlTransposer.transpose(
                                  arrangement.sourceXml,
                                  arrangement.transposeSemitones,
                                ),
                                displayPreferences: displayPreferences,
                              ),
                              Positioned.fill(
                                child: ScoreAnnotationCanvas(
                                  key: _annotationCanvasKey,
                                  annotations: arrangement.annotations,
                                  tool: _annotationTool,
                                  color: _annotationColor,
                                  onChanged: _updateAnnotations,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreDisplaySettingsSheet extends StatelessWidget {
  const _ScoreDisplaySettingsSheet({required this.controller});

  final ScoreDisplayController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final preferences = controller.preferences;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score display',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'These settings apply to every MusicXML score, including Live mode.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _ScoreSizeSlider(
                  label: 'Lyrics',
                  value: preferences.lyricFontSize,
                  minimum: ScoreDisplayPreferences.minimumLyricFontSize,
                  maximum: ScoreDisplayPreferences.maximumLyricFontSize,
                  onChanged: controller.setLyricFontSize,
                ),
                _ScoreSizeSlider(
                  label: 'Chords',
                  value: preferences.chordFontSize,
                  minimum: ScoreDisplayPreferences.minimumChordFontSize,
                  maximum: ScoreDisplayPreferences.maximumChordFontSize,
                  onChanged: controller.setChordFontSize,
                ),
                _ScoreSizeSlider(
                  label: 'Notes and staff',
                  value: preferences.noteSize,
                  minimum: ScoreDisplayPreferences.minimumNoteSize,
                  maximum: ScoreDisplayPreferences.maximumNoteSize,
                  onChanged: controller.setNoteSize,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: controller.reset,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Restore defaults'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScoreSizeSlider extends StatelessWidget {
  const _ScoreSizeSlider({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double minimum;
  final double maximum;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label size',
      value: value.round().toString(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text('${value.round()} pt'),
            ],
          ),
          Slider(
            value: value,
            min: minimum,
            max: maximum,
            divisions: (maximum - minimum).round(),
            label: '${value.round()} pt',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ViewerHeader extends StatelessWidget {
  const _ViewerHeader({
    required this.arrangement,
    required this.availableTypes,
    required this.selectedType,
    required this.onSelected,
    required this.onTranspose,
  });

  final MusicXmlArrangement arrangement;
  final List<MusicXmlArrangementType> availableTypes;
  final MusicXmlArrangementType selectedType;
  final ValueChanged<MusicXmlArrangementType> onSelected;
  final ValueChanged<int> onTranspose;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          arrangement.scoreTitle ?? arrangement.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          arrangement.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    final selector = availableTypes.length > 1
        ? SegmentedButton<MusicXmlArrangementType>(
            showSelectedIcon: false,
            segments: [
              for (final type in availableTypes)
                ButtonSegment(value: type, label: Text(type.label)),
            ],
            selected: {selectedType},
            onSelectionChanged: (selection) => onSelected(selection.first),
          )
        : Chip(label: Text(selectedType.label));
    final keySignature = MusicXmlTransposer.keySignature(
      arrangement.sourceXml,
      semitones: arrangement.transposeSemitones,
    );
    final transposeControls = _TransposeControls(
      keyLabel: keySignature?.label,
      semitones: arrangement.transposeSemitones,
      onChanged: onTranspose,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (constraints.maxWidth < 600) ...[
                title,
                const SizedBox(height: 12),
                selector,
              ] else
                Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 16),
                    selector,
                  ],
                ),
              const SizedBox(height: 8),
              transposeControls,
            ],
          ),
        );
      },
    );
  }
}

class _TransposeControls extends StatelessWidget {
  const _TransposeControls({
    required this.keyLabel,
    required this.semitones,
    required this.onChanged,
  });

  final String? keyLabel;
  final int semitones;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Key', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Transpose score down',
          onPressed: semitones > MusicXmlTransposer.minimumSemitones
              ? () => onChanged(semitones - 1)
              : null,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (keyLabel != null)
                Text(
                  keyLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              Text(MusicXmlTransposer.offsetLabel(semitones)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Transpose score up',
          onPressed: semitones < MusicXmlTransposer.maximumSemitones
              ? () => onChanged(semitones + 1)
              : null,
          icon: const Icon(Icons.add),
        ),
        if (semitones != 0) ...[
          const SizedBox(width: 8),
          TextButton(onPressed: () => onChanged(0), child: const Text('Reset')),
        ],
      ],
    );
  }
}
