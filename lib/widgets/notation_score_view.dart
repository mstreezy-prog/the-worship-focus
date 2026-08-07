import 'package:flutter/material.dart';

import '../services/music_xml_display_transformer.dart';
import '../services/notation_renderer.dart';

class NotationScoreView extends StatefulWidget {
  const NotationScoreView({
    required this.musicXml,
    this.staffSpace = 10,
    super.key,
  });

  final String musicXml;
  final double staffSpace;

  @override
  State<NotationScoreView> createState() => _NotationScoreViewState();
}

class _NotationScoreViewState extends State<NotationScoreView> {
  late Future<NotationDocument> _document;

  @override
  void initState() {
    super.initState();
    _document = _load();
  }

  @override
  void didUpdateWidget(NotationScoreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.musicXml != widget.musicXml) _document = _load();
  }

  Future<NotationDocument> _load() async {
    await NotationRenderer.initialize();
    await Future<void>.delayed(Duration.zero);
    return NotationRenderer.parse(
      MusicXmlDisplayTransformer.prepare(widget.musicXml),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NotationDocument>(
      future: _document,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _NotationError(
            message: 'This score could not be rendered.\n${snapshot.error}',
            onRetry: () => setState(() => _document = _load()),
          );
        }
        final document = snapshot.requireData;
        return Semantics(
          label:
              'Rendered score with ${document.staffCount} staff${document.staffCount == 1 ? '' : 's'}',
          child: document.buildView(
            key: ValueKey(widget.musicXml.hashCode),
            staffSpace: widget.staffSpace,
          ),
        );
      },
    );
  }
}

class _NotationError extends StatelessWidget {
  const _NotationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
