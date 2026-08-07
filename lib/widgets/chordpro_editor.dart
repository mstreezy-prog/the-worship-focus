import 'package:flutter/material.dart';

import '../models/song.dart';

class ChordProEditor extends StatefulWidget {
  const ChordProEditor({
    required this.song,
    required this.onChanged,
    required this.undoController,
    super.key,
  });

  final Song song;
  final ValueChanged<String> onChanged;
  final UndoHistoryController undoController;

  @override
  State<ChordProEditor> createState() => _ChordProEditorState();
}

class _ChordProEditorState extends State<ChordProEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.song.chordPro);
  }

  @override
  void didUpdateWidget(covariant ChordProEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.song.chordPro) {
      _controller.value = TextEditingValue(
        text: widget.song.chordPro,
        selection: TextSelection.collapsed(offset: widget.song.chordPro.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: widget.undoController,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'ChordPro editor',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Undo',
                    onPressed: widget.undoController.value.canUndo
                        ? widget.undoController.undo
                        : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Redo',
                    onPressed: widget.undoController.value.canRedo
                        ? widget.undoController.redo
                        : null,
                    icon: const Icon(Icons.redo),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: TextField(
            key: const ValueKey('chordpro-editor'),
            controller: _controller,
            undoController: widget.undoController,
            onChanged: widget.onChanged,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              fontFamily: 'CMG Sans',
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter ChordPro text',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}
