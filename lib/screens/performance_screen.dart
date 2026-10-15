import '../widgets/annotation_palette.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

import '../controllers/reader_annotation_controller.dart';
import '../services/reader_document_service.dart';
import '../services/chordpro_document.dart';
import '../services/reader_pagination.dart';
import '../services/music_stand_page_sequence.dart';

import '../controllers/performance_controller.dart';
import '../controllers/score_display_controller.dart';
import '../models/music_xml_arrangement.dart';
import '../models/performance_content.dart';
import '../models/performance_preferences.dart';
import '../models/score_annotation.dart';
import '../models/score_display_preferences.dart';
import '../models/song.dart';
import '../services/music_xml_transposer.dart';
import '../widgets/chordpro_performance_view.dart';
import '../widgets/scrollable_score_view.dart';
import '../widgets/score_annotation_canvas.dart';

/// Full-screen presentation for ChordPro and attached MusicXML scores.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({
    required this.songs,
    required this.initialIndex,
    this.initialContent = PerformanceContent.chordPro,
    this.songNotes = const <String, String>{},
    this.initialScoreDisplayPreferences,
    this.onAnnotationsChanged,
    this.onScoreAnnotationsChanged,
    super.key,
  }) : assert(songs.length > 0);

  final List<Song> songs;
  final void Function(
    String songId,
    Map<String, List<ScoreAnnotationStroke>> annotations,
  )?
  onAnnotationsChanged;
  final void Function(
    String songId,
    MusicXmlArrangementType type,
    List<ScoreAnnotationStroke> annotations,
  )?
  onScoreAnnotationsChanged;
  final int initialIndex;
  final PerformanceContent initialContent;
  final Map<String, String> songNotes;
  final ScoreDisplayPreferences? initialScoreDisplayPreferences;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final PerformanceController _controller = PerformanceController();
  late final ScoreDisplayController _scoreDisplayController;
  final Map<String, ScrollController> _scoreScrollControllers = {};
  late final PageController _songPageController;
  MusicStandPageSequence? _pageSequence;
  bool _restorePage = true;
  bool _restoringPage = false;
  String get _scoreKey => '${_currentSong.id}:${_currentContent.name}';
  late final Map<String, PerformanceContent> _contentBySongId;
  late final Map<String, int> _chordProPageCounts;
  late final Map<String, int> _chordProPages;
  late int _currentIndex;
  bool _showControls = true;
  ScoreAnnotationTool _annotationTool = ScoreAnnotationTool.none;
  ScoreAnnotationColor _annotationColor = ScoreAnnotationColor.black;
  double _annotationWidthScale = 1;
  late final Map<String, ReaderAnnotationController> _annotations;
  final Map<String, ReaderAnnotationController> _scoreAnnotations = {};
  ReaderAnnotationController get _currentAnnotations => _showingScore
      ? _scoreAnnotations['${_currentSong.id}:${_currentContent.name}']!
      : _annotations[_currentSong.id]!;
  late ScoreDisplayPreferences _scoreDisplayPreferences;

  Song get _currentSong => widget.songs[_currentIndex];

  List<PerformanceContent> _availableContent(Song song) => [
    PerformanceContent.chordPro,
    if (song.leadSheet != null) PerformanceContent.leadSheet,
    if (song.fullPiano != null) PerformanceContent.fullPiano,
  ];

  PerformanceContent _contentFor(Song song) {
    final selected = _contentBySongId[song.id] ?? PerformanceContent.chordPro;
    return _availableContent(song).contains(selected)
        ? selected
        : PerformanceContent.chordPro;
  }

  PerformanceContent get _currentContent => _contentFor(_currentSong);

  String? get _currentSongNote {
    final note = widget.songNotes[_currentSong.id]?.trim();
    return note?.isEmpty ?? true ? null : note;
  }

  bool get _showingScore => _currentContent != PerformanceContent.chordPro;

  @override
  void initState() {
    super.initState();
    _scoreDisplayPreferences =
        widget.initialScoreDisplayPreferences ??
        const ScoreDisplayPreferences();
    _scoreDisplayController = ScoreDisplayController();
    unawaited(_initializeScoreDisplayPreferences());
    _currentIndex = widget.initialIndex < 0
        ? 0
        : widget.initialIndex >= widget.songs.length
        ? widget.songs.length - 1
        : widget.initialIndex;
    _songPageController = PageController();
    _annotations = {
      for (final song in widget.songs)
        song.id: ReaderAnnotationController(song.chordProAnnotations),
    };
    for (final entry in _annotations.entries) {
      entry.value.addListener(() {
        widget.onAnnotationsChanged?.call(entry.key, entry.value.annotations);
        if (mounted) setState(() {});
      });
    }
    for (final song in widget.songs) {
      for (final content in _availableContent(
        song,
      ).where((content) => content != PerformanceContent.chordPro)) {
        final type = content.arrangementType!;
        final controller = ReaderAnnotationController({
          'score': song.arrangement(type)!.annotations,
        });
        _scoreAnnotations['${song.id}:${content.name}'] = controller;
        _scoreScrollControllers['${song.id}:${content.name}'] =
            ScrollController();
        controller.addListener(() {
          widget.onScoreAnnotationsChanged?.call(
            song.id,
            type,
            controller.annotations['score'] ?? const [],
          );
          if (mounted) setState(() {});
        });
      }
    }
    _contentBySongId = {
      for (final song in widget.songs)
        song.id: _availableContent(song).contains(widget.initialContent)
            ? widget.initialContent
            : PerformanceContent.chordPro,
    };
    _chordProPageCounts = {for (final song in widget.songs) song.id: 1};
    _chordProPages = {for (final song in widget.songs) song.id: 0};
    unawaited(_controller.initialize());
  }

  Future<void> _initializeScoreDisplayPreferences() async {
    await _scoreDisplayController.initialize();
    if (!mounted || widget.initialScoreDisplayPreferences != null) return;
    setState(
      () => _scoreDisplayPreferences = _scoreDisplayController.preferences,
    );
  }

  @override
  void dispose() {
    for (final controller in _scoreAnnotations.values) {
      controller.dispose();
    }
    for (final controller in _annotations.values) {
      controller.dispose();
    }
    _songPageController.dispose();
    for (final controller in _scoreScrollControllers.values) {
      controller.dispose();
    }
    unawaited(_controller.deactivate());
    _controller.dispose();
    _scoreDisplayController.dispose();
    super.dispose();
  }

  void _showSong(int index) {
    if (index < 0 || index >= widget.songs.length) return;
    final sequence = _pageSequence;
    if (sequence == null) return;
    _animateToReaderPage(sequence.indexFor(index, 0));
  }

  void _animateToReaderPage(int index) {
    if (!_songPageController.hasClients || _pageSequence == null) return;
    final target = index.clamp(0, _pageSequence!.pages.length - 1);
    _songPageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _changeReaderPage(int direction) {
    final sequence = _pageSequence;
    if (sequence == null) return;
    _animateToReaderPage(
      sequence.indexFor(_currentIndex, _currentChordProPage) + direction,
    );
  }

  double get _controlsBottomPadding => 72;

  void _toggleControls() => setState(() => _showControls = !_showControls);

  double _readerTopPadding(Song song) =>
      _showControls ? _controlsTopPadding(song) : 8;

  double _controlsTopPadding(Song song) =>
      (_availableContent(song).length > 1 ? 128 : 72) +
      ((widget.songNotes[song.id]?.trim().isNotEmpty ?? false) ? 40 : 0);

  void _syncPageSequence(MusicStandPageSequence next) {
    final changed =
        _pageSequence == null || !_pageSequence!.hasSameLayout(next);
    _pageSequence = next;
    for (var index = 0; index < widget.songs.length; index++) {
      _chordProPageCounts[widget.songs[index].id] = next.pageCounts[index];
    }
    if (!changed && !_restorePage) return;
    _restorePage = false;
    final chartPage = _currentChordProPage.clamp(
      0,
      next.pageCounts[_currentIndex] - 1,
    );
    _chordProPages[_currentSong.id] = chartPage;
    final target = next.indexFor(_currentIndex, chartPage);
    _restoringPage = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_songPageController.hasClients &&
          (_songPageController.page ?? 0).round() != target) {
        _songPageController.jumpToPage(target);
      }
      _restoringPage = false;
      setState(() {});
    });
  }

  void _selectContent(PerformanceContent content) {
    if (!_availableContent(_currentSong).contains(content)) return;
    if (_currentContent == content) return;
    setState(() {
      _annotationTool = ScoreAnnotationTool.none;
      _contentBySongId[_currentSong.id] = content;
      _chordProPages[_currentSong.id] = 0;
      _restorePage = true;
    });
  }

  int get _currentChordProPage => _chordProPages[_currentSong.id] ?? 0;

  int get _currentChordProPageCount =>
      _chordProPageCounts[_currentSong.id] ?? 1;

  void _changeChordProPage(int direction) => _changeReaderPage(direction);

  void _resetChordProPage() {
    setState(() {
      _chordProPages[_currentSong.id] = 0;
      _restorePage = true;
    });
  }

  void _changeChordProColumns() {
    _controller.toggleChordProColumns();
    _resetChordProPage();
  }

  void _changeChordProFontSize(bool increase) {
    if (increase) {
      _controller.increaseFontSize();
    } else {
      _controller.decreaseFontSize();
    }
    _resetChordProPage();
  }

  void _changeCurrentPage(int direction) {
    if (_showingScore) {
      _changeScorePage(direction);
    } else {
      _changeChordProPage(direction);
    }
  }

  void _changeScorePage(int direction) {
    final controller = _scoreScrollControllers[_scoreKey]!;
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = (position.pixels + position.viewportDimension * direction)
        .clamp(0.0, position.maxScrollExtent);
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final preferences = _controller.preferences;
        final dark = preferences.theme == PerformanceTheme.dark;
        final baseTheme = dark
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData.light(useMaterial3: true);
        final theme = baseTheme.copyWith(
          iconButtonTheme: const IconButtonThemeData(
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(48, 48)),
            ),
          ),
        );
        final currentContent = _currentContent;

        return Theme(
          data: theme,
          child: Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: SafeArea(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                      _changeReaderPage(-1),
                  const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                      _changeReaderPage(1),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _changeCurrentPage(-1),
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _changeCurrentPage(1),
                  const SingleActivator(LogicalKeyboardKey.pageUp): () =>
                      _changeCurrentPage(-1),
                  const SingleActivator(LogicalKeyboardKey.pageDown): () =>
                      _changeCurrentPage(1),
                  const SingleActivator(LogicalKeyboardKey.minus): () =>
                      _changeChordProFontSize(false),
                  const SingleActivator(LogicalKeyboardKey.equal): () =>
                      _changeChordProFontSize(true),
                  const SingleActivator(
                    LogicalKeyboardKey.equal,
                    shift: true,
                  ): () =>
                      _changeChordProFontSize(true),
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      Navigator.maybePop(context),
                },
                child: Focus(
                  autofocus: true,
                  child: Stack(
                    children: [
                      ScrollConfiguration(
                        behavior: const MaterialScrollBehavior().copyWith(
                          dragDevices:
                              _annotationTool == ScoreAnnotationTool.none
                              ? PointerDeviceKind.values.toSet()
                              : {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.trackpad,
                                },
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final sequence = MusicStandPageSequence([
                              for (final song in widget.songs)
                                if (_contentFor(song) !=
                                    PerformanceContent.chordPro)
                                  1
                                else
                                  ReaderPagination.paginate(
                                    fontSize: preferences.fontSize,
                                    twoColumns:
                                        preferences.chordProColumns ==
                                            ChordProColumnLayout.two &&
                                        constraints.maxWidth >= 700,
                                    blocks: ChordProDocument.parse(
                                      ReaderDocumentService.transpose(
                                        song,
                                        _controller.transposeFor(song.id),
                                      ).chordPro,
                                    ).blocks,
                                    hasInfo: true,
                                    maxHeight:
                                        constraints.maxHeight -
                                        _controlsTopPadding(song) -
                                        _controlsBottomPadding,
                                  ).length,
                            ]);
                            _syncPageSequence(sequence);
                            return Semantics(
                              label: _showControls
                                  ? 'Tap music to hide controls'
                                  : 'Tap music to show controls',
                              onTap: _toggleControls,
                              child: GestureDetector(
                                key: const ValueKey('music-stand-tap-surface'),
                                behavior: HitTestBehavior.opaque,
                                supportedDevices: const {
                                  PointerDeviceKind.touch,
                                },
                                excludeFromSemantics: true,
                                onTap: _toggleControls,
                                child: PageView.builder(
                                  key: const ValueKey(
                                    'music-stand-song-reader',
                                  ),
                                  controller: _songPageController,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: sequence.pages.length,
                                  onPageChanged: (flatIndex) {
                                    if (_restoringPage ||
                                        flatIndex >= sequence.pages.length) {
                                      return;
                                    }
                                    final page = sequence.pages[flatIndex];
                                    setState(() {
                                      if (_currentIndex != page.songIndex) {
                                        _annotationTool =
                                            ScoreAnnotationTool.none;
                                      }
                                      _currentIndex = page.songIndex;
                                      _chordProPages[_currentSong.id] =
                                          page.chartPage;
                                    });
                                  },
                                  itemBuilder: (context, flatIndex) {
                                    final page = sequence.pages[flatIndex];
                                    final song = widget.songs[page.songIndex];
                                    return Padding(
                                      key: ValueKey(
                                        'reader-${page.songIndex}-${page.chartPage}',
                                      ),
                                      padding: EdgeInsets.only(
                                        top: _readerTopPadding(song),
                                        bottom: _showControls
                                            ? _controlsBottomPadding
                                            : 8,
                                      ),
                                      child: _buildContent(
                                        songIndex: page.songIndex,
                                        chartPage: page.chartPage,
                                        chartLayoutHeight:
                                            constraints.maxHeight -
                                            _controlsTopPadding(song) -
                                            _controlsBottomPadding,
                                        song: song,
                                        content: _contentFor(song),
                                        preferences: preferences,
                                        scoreDisplayPreferences:
                                            _scoreDisplayPreferences,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_showControls) ...[
                        _buildTopBar(theme, currentContent),
                        _buildControlBar(preferences, theme, currentContent),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent({
    required int songIndex,
    required int chartPage,
    required double chartLayoutHeight,
    required Song song,
    required PerformanceContent content,
    required PerformancePreferences preferences,
    required ScoreDisplayPreferences scoreDisplayPreferences,
  }) {
    if (content == PerformanceContent.chordPro) {
      return ChordProPerformanceView(
        key: ValueKey(song.id),
        song: ReaderDocumentService.transpose(
          song,
          _controller.transposeFor(song.id),
        ),
        annotations: _annotations[song.id],
        annotationTool: songIndex == _currentIndex
            ? _annotationTool
            : ScoreAnnotationTool.none,
        annotationColor: _annotationColor,
        widthScale: _annotationWidthScale,
        fontSize: preferences.fontSize,
        twoColumns: preferences.chordProColumns == ChordProColumnLayout.two,
        pageIndex: chartPage,
        layoutHeight: chartLayoutHeight,
      );
    }
    final arrangement = song.arrangement(content.arrangementType!)!;
    return ScrollableScoreView(
      key: ValueKey('${song.id}:${content.name}'),
      musicXml: MusicXmlTransposer.transpose(
        arrangement.sourceXml,
        arrangement.transposeSemitones,
      ),
      annotations: _scoreAnnotations['${song.id}:${content.name}']!,
      tool: songIndex == _currentIndex
          ? _annotationTool
          : ScoreAnnotationTool.none,
      color: _annotationColor,
      widthScale: _annotationWidthScale,
      preferences: scoreDisplayPreferences,
      scrollController: _scoreScrollControllers['${song.id}:${content.name}']!,
    );
  }

  Widget _buildTopBar(ThemeData theme, PerformanceContent content) {
    final availableContent = _availableContent(_currentSong);
    final arrangement = content.arrangementType == null
        ? null
        : _currentSong.arrangement(content.arrangementType!);
    final keyLabel = arrangement == null
        ? null
        : MusicXmlTransposer.keySignature(
            arrangement.sourceXml,
            semitones: arrangement.transposeSemitones,
          )?.label;
    final sourceLabel = keyLabel == null
        ? content.label
        : '${content.label} • $keyLabel';
    final title = Text(
      '${_currentSong.title}  •  $sourceLabel  •  ${_currentIndex + 1} of ${widget.songs.length}',
      overflow: TextOverflow.ellipsis,
    );
    return Positioned(
      key: const ValueKey('music-stand-header'),
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.96),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Close live mode',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 8),
                  const Text('Music Stand'),
                  const SizedBox(width: 12),
                  Expanded(child: title),
                  IconButton(
                    tooltip: 'Service order',
                    onPressed: _showServiceOrder,
                    icon: const Icon(Icons.queue_music),
                  ),
                  IconButton(
                    tooltip: 'Hide controls',
                    onPressed: _toggleControls,
                    icon: const Icon(Icons.visibility_off_outlined),
                  ),
                ],
              ),
              if (availableContent.length > 1) ...[
                const SizedBox(height: 6),
                SegmentedButton<PerformanceContent>(
                  showSelectedIcon: false,
                  segments: [
                    for (final option in availableContent)
                      ButtonSegment(value: option, label: Text(option.label)),
                  ],
                  selected: {content},
                  onSelectionChanged: (selection) =>
                      _selectContent(selection.first),
                ),
              ],
              if (_currentSongNote case final note?) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showServiceOrder() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: widget.songs.length,
          itemBuilder: (context, index) => ListTile(
            minTileHeight: 56,
            leading: Text('${index + 1}'),
            title: Text(widget.songs[index].title),
            selected: index == _currentIndex,
            trailing: index == _currentIndex
                ? const Icon(Icons.play_arrow)
                : null,
            onTap: () {
              Navigator.pop(context);
              _showSong(index);
            },
          ),
        ),
      ),
    );
  }

  void _showReaderSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final preferences = _controller.preferences;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reader settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ...[
                    Row(
                      children: [
                        const Expanded(child: Text('Text size')),
                        IconButton(
                          tooltip: 'Decrease font size',
                          onPressed: () => _changeChordProFontSize(false),
                          icon: const Icon(Icons.text_decrease),
                        ),
                        Text('${preferences.fontSize.round()} pt'),
                        IconButton(
                          tooltip: 'Increase font size',
                          onPressed: () => _changeChordProFontSize(true),
                          icon: const Icon(Icons.text_increase),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('Two columns'),
                      value:
                          preferences.chordProColumns ==
                          ChordProColumnLayout.two,
                      onChanged: (_) => _changeChordProColumns(),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Transpose for this session'),
                        ),
                        IconButton(
                          tooltip: 'Transpose down',
                          onPressed: () =>
                              _controller.transpose(_currentSong.id, -1),
                          icon: const Icon(Icons.remove),
                        ),
                        Text('${_controller.transposeFor(_currentSong.id)}'),
                        IconButton(
                          tooltip: 'Transpose up',
                          onPressed: () =>
                              _controller.transpose(_currentSong.id, 1),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const Text(
                      'Chord shapes appear in the original key. Return transpose to 0 to view them.',
                    ),
                  ],
                  SwitchListTile(
                    title: const Text('Dark stage theme'),
                    value: preferences.theme == PerformanceTheme.dark,
                    onChanged: (_) => _controller.toggleTheme(),
                  ),
                  SwitchListTile(
                    title: const Text('Keep screen awake'),
                    value: preferences.keepAwake,
                    onChanged: (_) => unawaited(_controller.toggleKeepAwake()),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlBar(
    PerformancePreferences preferences,
    ThemeData theme,
    PerformanceContent content,
  ) {
    final navigation = <Widget>[
      IconButton(
        tooltip: 'Previous song',
        onPressed: _currentIndex == 0
            ? null
            : () => _showSong(_currentIndex - 1),
        icon: const Icon(Icons.skip_previous),
      ),
      IconButton(
        tooltip: _showingScore
            ? 'Previous score page'
            : 'Previous ChordPro page',
        onPressed: () => _changeCurrentPage(-1),
        icon: const Icon(Icons.chevron_left),
      ),
      Text(
        _showingScore
            ? content.label
            : 'Page ${_currentChordProPage + 1}/$_currentChordProPageCount',
        key: ValueKey('performance-content-${content.name}'),
      ),
      IconButton(
        tooltip: _showingScore ? 'Next score page' : 'Next ChordPro page',
        onPressed: () => _changeCurrentPage(1),
        icon: const Icon(Icons.chevron_right),
      ),
      IconButton(
        tooltip: 'Next song',
        onPressed: _currentIndex == widget.songs.length - 1
            ? null
            : () => _showSong(_currentIndex + 1),
        icon: const Icon(Icons.skip_next),
      ),
    ];
    final palette = AnnotationPalette(
      tool: _annotationTool,
      color: _annotationColor,
      widthScale: _annotationWidthScale,
      onToolChanged: (tool) => setState(() => _annotationTool = tool),
      onColorChanged: (color) => setState(() => _annotationColor = color),
      onWidthChanged: (width) => setState(() => _annotationWidthScale = width),
      onUndo: _currentAnnotations.canUndo ? _currentAnnotations.undo : null,
      onRedo: _currentAnnotations.canRedo ? _currentAnnotations.redo : null,
      onClear: _currentAnnotations.hasMarks ? _currentAnnotations.clear : null,
    );
    final pencilMenu = MenuAnchor(
      style: const MenuStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
      ),
      menuChildren: [
        SizedBox(
          width: (MediaQuery.sizeOf(context).width - 32).clamp(0, 720),
          child: palette,
        ),
      ],
      builder: (context, controller, child) => IconButton(
        tooltip: 'Pencil tools',
        isSelected: controller.isOpen,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.draw_outlined),
      ),
    );
    final settings = IconButton(
      tooltip: 'Reader settings',
      onPressed: _showReaderSettings,
      icon: const Icon(Icons.tune),
    );
    Widget row(List<Widget> children) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: Column(
        key: const ValueKey('music-stand-footer'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            child: row([...navigation, settings, pencilMenu]),
          ),
        ],
      ),
    );
  }
}
