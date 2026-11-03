import 'package:flutter/material.dart';

import '../models/score_display_preferences.dart';

/// Shared controls for the score viewer and Music Stand.
class ScoreDisplaySettings extends StatelessWidget {
  const ScoreDisplaySettings({
    required this.preferences,
    required this.onChanged,
    this.footer,
    super.key,
  });

  final ScoreDisplayPreferences preferences;
  final ValueChanged<ScoreDisplayPreferences> onChanged;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Score display',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Chord settings are separate from notes and lyrics.'),
            const SizedBox(height: 16),
            _SizeControl(
              label: 'Chords',
              controlKey: 'score-chord-size',
              value: preferences.chordFontSize,
              minimum: ScoreDisplayPreferences.minimumChordFontSize,
              maximum: ScoreDisplayPreferences.maximumChordFontSize,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(chordFontSize: value)),
            ),
            Text('Chord color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in ScoreChordColor.values)
                  ChoiceChip(
                    key: ValueKey('score-chord-color-${color.name}'),
                    label: Text(color.label),
                    avatar: CircleAvatar(
                      radius: 7,
                      backgroundColor: Color(color.value),
                    ),
                    selected: color == preferences.chordColor,
                    onSelected: (_) =>
                        onChanged(preferences.copyWith(chordColor: color)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _SizeControl(
              label: 'Notes and staff',
              controlKey: 'score-note-size',
              value: preferences.noteSize,
              minimum: ScoreDisplayPreferences.minimumNoteSize,
              maximum: ScoreDisplayPreferences.maximumNoteSize,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(noteSize: value)),
            ),
            _SizeControl(
              label: 'Lyrics',
              controlKey: 'score-lyric-size',
              value: preferences.lyricFontSize,
              minimum: ScoreDisplayPreferences.minimumLyricFontSize,
              maximum: ScoreDisplayPreferences.maximumLyricFontSize,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(lyricFontSize: value)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onChanged(const ScoreDisplayPreferences()),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restore defaults'),
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    ),
  );
}

class _SizeControl extends StatelessWidget {
  const _SizeControl({
    required this.label,
    required this.controlKey,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });
  final String label, controlKey;
  final double value, minimum, maximum;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text('${value.round()}'),
        ],
      ),
      Slider(
        key: ValueKey(controlKey),
        label: '$label ${value.round()}',
        value: value,
        min: minimum,
        max: maximum,
        divisions: (maximum - minimum).round(),
        onChanged: onChanged,
      ),
    ],
  );
}
