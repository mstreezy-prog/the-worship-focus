import 'package:pdf/widgets.dart' as pw;

import 'chordpro_document.dart';
import 'chordpro_performance_info.dart';
import '../models/song.dart';

List<pw.Widget> chordProPdfContent(String source) => [
  if (ChordProPerformanceInfo.fromSong(
        Song(id: 'pdf', title: '', chordPro: source),
      ).capoSummary
      case final summary?)
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(summary),
    ),
  for (final block in ChordProDocument.parse(source).blocks)
    if (block is ChordProCommentBlock)
      pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 6),
        padding: const pw.EdgeInsets.all(4),
        decoration: block.style == ChordProCommentStyle.boxed
            ? pw.BoxDecoration(border: pw.Border.all())
            : null,
        child: pw.Text(
          block.text,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontStyle: block.style == ChordProCommentStyle.italic
                ? pw.FontStyle.italic
                : pw.FontStyle.normal,
          ),
        ),
      )
    else if (block is ChordProTextBlock)
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            block.line.chords.map((chord) => chord.chord).join(' '),
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            block.line.lyrics,
            style: pw.TextStyle(font: pw.Font.courier()),
          ),
          pw.SizedBox(height: 10),
        ],
      ),
];
