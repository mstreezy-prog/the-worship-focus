import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/performance_controller.dart';
import '../models/performance_preferences.dart';
import '../models/song.dart';
import '../widgets/preview_panel.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({
    required this.songs,
    required this.initialIndex,
    super.key,
  }) : assert(songs.length > 0);

  final List<Song> songs;
  final int initialIndex;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final PerformanceController _controller = PerformanceController();
  late final PageController _pageController;
  late final List<ScrollController> _scrollControllers;
  late int _currentIndex;
  Timer? _scrollTimer;
  bool _showControls = true;

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
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _pageController.dispose();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    unawaited(_controller.deactivate());
    _controller.dispose();
    super.dispose();
  }

  void _showSong(int index) {
    if (index < 0 || index >= widget.songs.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _toggleAutoScroll() {
    _controller.toggleAutoScroll();
    if (_controller.autoScrolling) {
      _scrollTimer?.cancel();
      _scrollTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _advanceScroll(),
      );
    } else {
      _scrollTimer?.cancel();
      _scrollTimer = null;
    }
  }

  void _advanceScroll() {
    final scrollController = _scrollControllers[_currentIndex];
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final next = position.pixels + _controller.preferences.scrollSpeed / 20;
    if (next >= position.maxScrollExtent) {
      if (_controller.autoScrolling) _controller.toggleAutoScroll();
      _scrollTimer?.cancel();
      _scrollTimer = null;
      return;
    }
    scrollController.jumpTo(next);
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
                        },
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              top: _showControls ? 72 : 8,
                              bottom: _showControls ? 84 : 8,
                            ),
                            child: PreviewPanel(
                              song: widget.songs[index],
                              performance: true,
                              fontSize: preferences.fontSize,
                              scrollController: _scrollControllers[index],
                            ),
                          );
                        },
                      ),
                      if (_showControls) ...[
                        _buildTopBar(theme),
                        _buildControlBar(preferences, theme),
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

  Widget _buildTopBar(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.96),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close performance mode',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 8),
              const Text('Performance mode'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.songs[_currentIndex].title}  •  ${_currentIndex + 1} of ${widget.songs.length}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Hide controls',
                onPressed: () => setState(() => _showControls = false),
                icon: const Icon(Icons.visibility_off_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar(PerformancePreferences preferences, ThemeData theme) {
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
                IconButton(
                  tooltip: 'Toggle stage theme',
                  onPressed: _controller.toggleTheme,
                  icon: Icon(
                    preferences.theme == PerformanceTheme.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Scroll'),
                const SizedBox(width: 8),
                DropdownButton<double>(
                  value:
                      const [12.0, 24.0, 40.0].contains(preferences.scrollSpeed)
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
                    _controller.autoScrolling ? Icons.pause : Icons.play_arrow,
                  ),
                ),
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
