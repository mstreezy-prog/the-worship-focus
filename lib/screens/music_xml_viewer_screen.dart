import 'package:flutter/material.dart';

import '../models/music_xml_arrangement.dart';
import '../models/song.dart';
import '../widgets/notation_score_view.dart';

class MusicXmlViewerScreen extends StatefulWidget {
  MusicXmlViewerScreen({
    required this.song,
    required this.initialType,
    super.key,
  }) : assert(
         song.leadSheet != null || song.fullPiano != null,
         'The score viewer requires an attached MusicXML arrangement.',
       );

  final Song song;
  final MusicXmlArrangementType initialType;

  @override
  State<MusicXmlViewerScreen> createState() => _MusicXmlViewerScreenState();
}

class _MusicXmlViewerScreenState extends State<MusicXmlViewerScreen> {
  final TransformationController _transformation = TransformationController();
  late MusicXmlArrangementType _selectedType;

  List<MusicXmlArrangementType> get _availableTypes => [
    for (final type in MusicXmlArrangementType.values)
      if (widget.song.arrangement(type) != null) type,
  ];

  MusicXmlArrangement get _arrangement =>
      widget.song.arrangement(_selectedType)!;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.song.arrangement(widget.initialType) != null
        ? widget.initialType
        : _availableTypes.first;
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _selectType(MusicXmlArrangementType type) {
    if (type == _selectedType) return;
    setState(() => _selectedType = type);
    _fitScore();
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

  @override
  Widget build(BuildContext context) {
    final arrangement = _arrangement;
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
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final paperWidth = (constraints.maxWidth - 32)
                    .clamp(360.0, 960.0)
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
                      child: NotationScoreView(
                        key: ValueKey(_selectedType),
                        musicXml: arrangement.sourceXml,
                        staffSpace: 9,
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
  }
}

class _ViewerHeader extends StatelessWidget {
  const _ViewerHeader({
    required this.arrangement,
    required this.availableTypes,
    required this.selectedType,
    required this.onSelected,
  });

  final MusicXmlArrangement arrangement;
  final List<MusicXmlArrangementType> availableTypes;
  final MusicXmlArrangementType selectedType;
  final ValueChanged<MusicXmlArrangementType> onSelected;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: constraints.maxWidth < 600
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), selector],
                )
              : Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 16),
                    selector,
                  ],
                ),
        );
      },
    );
  }
}
