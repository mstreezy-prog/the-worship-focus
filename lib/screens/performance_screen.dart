import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/performance_controller.dart';
import '../models/music_xml_arrangement.dart';
import '../models/performance_content.dart';
import '../models/performance_preferences.dart';
import '../models/song.dart';
import '../services/music_xml_transposer.dart';
import '../widgets/notation_score_view.dart';
import '../widgets/preview_panel.dart';

/// Full-screen presentation for ChordPro and attached MusicXML scores.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({
    required this.songs,
    required this.initialIndex,
    this.initialContent = PerformanceContent.chordPro,
    super.key,
  }) : assert(songs.length > 0);

  final List<Song> songs;
  final int initialIndex;
  final PerformanceContent initialContent;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final PerformanceController _controller = PerformanceController();
  late final PageController _pageController;
  late final List<ScrollController> _scrollControllers;
  late final Map<String, PerformanceContent> _contentBySongId;
  late int _currentIndex;
  Timer? _scrollTimer;
  bool _showControls = true;
  bool _canGoBackScorePage = false;
  bool _canGoForwardScorePage = false;

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

  bool get _showingScore => _currentContent != PerformanceContent.chordPro;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex < 0
        ? 0
        : widget.initialIndex >= widget.songs.length
        ? widget.songs.length - 1
        : widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _scrollControllers = List.generate(
      widget.songs.length,
      (_) => ScrollController(),
    );
    for (final scrollController in _scrollControllers) {
      scrollController.addListener(_refreshScrollControls);
    }
    _contentBySongId = {
      for (final song in widget.songs)
        song.id: _availableContent(song).contains(widget.initialContent)
            ? widget.initialContent
            : PerformanceContent.chordPro,
    };
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _pageController.dispose();
    for (final controller in _scrollControllers) {
      controller
        ..removeListener(_refreshScrollControls)
        ..dispose();
    }
    unawaited(_controller.deactivate());
    _controller.dispose();
    super.dispose();
  }

  void _refreshScrollControls() {
    if (!mounted || !_showingScore) return;
    final controller = _scrollControllers[_currentIndex];
    if (!controller.hasClients) return;
    final canGoBack = controller.position.pixels > 0;
    final canGoForward =
        controller.position.pixels < controller.position.maxScrollExtent;
    if (canGoBack == _canGoBackScorePage &&
        canGoForward == _canGoForwardScorePage) {
      return;
    }
    setState(() {
      _canGoBackScorePage = canGoBack;
      _canGoForwardScorePage = canGoForward;
    });
  }

  void _showSong(int index) {
    if (index < 0 || index >= widget.songs.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _selectContent(PerformanceContent content) {
    if (!_availableContent(_currentSong).contains(content)) return;
    if (_currentContent == content) return;
    if (content != PerformanceContent.chordPro && _controller.autoScrolling) {
      _stopAutoScroll();
    }
    setState(() {
      _contentBySongId[_currentSong.id] = content;
      _canGoBackScorePage = false;
      _canGoForwardScorePage = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _scrollControllers[_currentIndex];
      if (controller.hasClients) controller.jumpTo(0);
      _refreshScrollControls();
    });
  }

  void _toggleAutoScroll() {
    if (_showingScore) return;
    _controller.toggleAutoScroll();
    if (_controller.autoScrolling) {
      _scrollTimer?.cancel();
      _scrollTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _advanceScroll(),
      );
    } else {
      _stopAutoScroll();
    }
  }

  void _stopAutoScroll() {
    if (_controller.autoScrolling) _controller.toggleAutoScroll();
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  void _advanceScroll() {
    final scrollController = _scrollControllers[_currentIndex];
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final next = position.pixels + _controller.preferences.scrollSpeed / 20;
    if (next >= position.maxScrollExtent) {
      _stopAutoScroll();
      return;
    }
    scrollController.jumpTo(next);
  }

  void _changeScorePage(int direction) {
    if (!_showingScore) return;
    final scrollController = _scrollControllers[_currentIndex];
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final target = (position.pixels + position.viewportDimension * direction)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
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
        final theme = dark
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData.light(useMaterial3: true);
        final currentContent = _currentContent;
        final hasSourcePicker = _availableContent(_currentSong).length > 1;
        return Theme(
          data: theme,
          child: Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: SafeArea(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                      _showSong(_currentIndex - 1),
                  const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                      _showSong(_currentIndex + 1),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _changeScorePage(-1),
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _changeScorePage(1),
                  const SingleActivator(LogicalKeyboardKey.pageUp): () =>
                      _changeScorePage(-1),
                  const SingleActivator(LogicalKeyboardKey.pageDown): () =>
                      _changeScorePage(1),
                  const SingleActivator(LogicalKeyboardKey.space):
                      _toggleAutoScroll,
                  const SingleActivator(LogicalKeyboardKey.minus):
                      _controller.decreaseFontSize,
                  const SingleActivator(LogicalKeyboardKey.equal):
                      _controller.increaseFontSize,
                  const SingleActivator(LogicalKeyboardKey.equal, shift: true):
                      _controller.increaseFontSize,
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      Navigator.maybePop(context),
                },
                child: Focus(
                  autofocus: true,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: widget.songs.length,
                        onPageChanged: (index) {
                          setState(() => _currentIndex = index);
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _refreshScrollControls(),
                          );
                        },
                        itemBuilder: (context, index) {
                          final song = widget.songs[index];
                          final content = _contentFor(song);
                          return Padding(
                            padding: EdgeInsets.only(
                              top: _showControls
                                  ? (index == _currentIndex && hasSourcePicker
                                        ? 128
                                        : 72)
                                  : 8,
                              bottom: _showControls ? 84 : 8,
                            ),
                            child: _buildContent(
                              song: song,
                              content: content,
                              preferences: preferences,
                              scrollController: _scrollControllers[index],
                            ),
                          );
                        },
                      ),
                      if (_showControls) ...[
                        _buildTopBar(theme, currentContent),
                        _buildControlBar(preferences, theme, currentContent),
                      ] else
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filledTonal(
                            tooltip: 'Show controls',
                            onPressed: () =>
                                setState(() => _showControls = true),
                            icon: const Icon(Icons.visibility_outlined),
                          ),
                        ),
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
    required Song song,
    required PerformanceContent content,
    required PerformancePreferences preferences,
    required ScrollController scrollController,
  }) {
    if (content == PerformanceContent.chordPro) {
      return PreviewPanel(
        song: song,
        performance: true,
        fontSize: preferences.fontSize,
        scrollController: scrollController,
      );
    }
    final arrangement = song.arrangement(content.arrangementType!)!;
    return _ScorePerformanceView(
      arrangement: arrangement,
      scrollController: scrollController,
      onMetricsChanged: _refreshScrollControls,
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
                  const Text('Live mode'),
                  const SizedBox(width: 12),
                  Expanded(child: title),
                  IconButton(
                    tooltip: 'Hide controls',
                    onPressed: () => setState(() => _showControls = false),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar(
    PerformancePreferences preferences,
    ThemeData theme,
    PerformanceContent content,
  ) {
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceContainerHigh,
        child: SizedBox(
          height: 68,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous song',
                  onPressed: _currentIndex == 0
                      ? null
                      : () => _showSong(_currentIndex - 1),
                  icon: const Icon(Icons.skip_previous),
                ),
                if (content == PerformanceContent.chordPro) ...[
                  IconButton(
                    tooltip: 'Decrease font size',
                    onPressed: preferences.fontSize <= 14
                        ? null
                        : _controller.decreaseFontSize,
                    icon: const Icon(Icons.text_decrease),
                  ),
                  Text('${preferences.fontSize.round()} pt'),
                  IconButton(
                    tooltip: 'Increase font size',
                    onPressed: preferences.fontSize >= 36
                        ? null
                        : _controller.increaseFontSize,
                    icon: const Icon(Icons.text_increase),
                  ),
                ] else ...[
                  IconButton.filledTonal(
                    tooltip: 'Previous score page',
                    onPressed: _canGoBackScorePage
                        ? () => _changeScorePage(-1)
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    content.label,
                    key: ValueKey('performance-content-${content.name}'),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Next score page',
                    onPressed: _canGoForwardScorePage
                        ? () => _changeScorePage(1)
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
                IconButton(
                  tooltip: 'Toggle stage theme',
                  onPressed: _controller.toggleTheme,
                  icon: Icon(
                    preferences.theme == PerformanceTheme.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
                if (content == PerformanceContent.chordPro) ...[
                  const SizedBox(width: 8),
                  const Text('Scroll'),
                  const SizedBox(width: 8),
                  DropdownButton<double>(
                    value:
                        const [
                          12.0,
                          24.0,
                          40.0,
                        ].contains(preferences.scrollSpeed)
                        ? preferences.scrollSpeed
                        : 24.0,
                    underline: const SizedBox.shrink(),
                    onChanged: (value) {
                      if (value != null) _controller.setScrollSpeed(value);
                    },
                    items: const [
                      DropdownMenuItem(value: 12.0, child: Text('Slow')),
                      DropdownMenuItem(value: 24.0, child: Text('Medium')),
                      DropdownMenuItem(value: 40.0, child: Text('Fast')),
                    ],
                  ),
                  IconButton.filledTonal(
                    tooltip: _controller.autoScrolling
                        ? 'Pause auto-scroll'
                        : 'Start auto-scroll',
                    onPressed: _toggleAutoScroll,
                    icon: Icon(
                      _controller.autoScrolling
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                ],
                IconButton(
                  tooltip: preferences.keepAwake
                      ? 'Allow screen sleep'
                      : 'Keep screen awake',
                  onPressed: () => unawaited(_controller.toggleKeepAwake()),
                  icon: Icon(
                    preferences.keepAwake
                        ? Icons.visibility
                        : Icons.visibility_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Next song',
                  onPressed: _currentIndex == widget.songs.length - 1
                      ? null
                      : () => _showSong(_currentIndex + 1),
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScorePerformanceView extends StatelessWidget {
  const _ScorePerformanceView({
    required this.arrangement,
    required this.scrollController,
    required this.onMetricsChanged,
  });

  final MusicXmlArrangement arrangement;
  final ScrollController scrollController;
  final VoidCallback onMetricsChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final paperWidth = (constraints.maxWidth - 32)
            .clamp(360.0, 1080.0)
            .toDouble();
        return NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) onMetricsChanged();
            });
            return false;
          },
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Center(
                child: Container(
                  width: paperWidth,
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 56),
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
                    key: ValueKey(
                      '${arrangement.fileName}-${arrangement.transposeSemitones}',
                    ),
                    musicXml: MusicXmlTransposer.transpose(
                      arrangement.sourceXml,
                      arrangement.transposeSemitones,
                    ),
                    staffSpace: 10,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
