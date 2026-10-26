import 'package:flutter/material.dart';

import '../services/chordpro_document.dart';

/// Shared section-label presentation for the editor preview and Music Stand.
class ChordProComment extends StatelessWidget {
  const ChordProComment({
    required this.comment,
    required this.fontSize,
    super.key,
  });

  final ChordProCommentBlock comment;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: fontSize * .3),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: fontSize * .4,
          vertical: fontSize * .15,
        ),
        decoration: BoxDecoration(
          color: comment.style == ChordProCommentStyle.standard
              ? colors.surfaceContainerHighest
              : null,
          border: comment.style == ChordProCommentStyle.boxed
              ? Border.all(color: colors.outline)
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          comment.text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            fontStyle: comment.style == ChordProCommentStyle.italic
                ? FontStyle.italic
                : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
