import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import 'chordpro_parser.dart';

class PdfExporter {
  static Future<File> exportSong({
    required String title,
    required String content,
  }) async {
    final pdf = pw.Document();

    final lines = ChordProParser.parse(content);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),

              ...lines.map((line) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      line.chords,
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      line.lyrics,
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/$title.pdf');

    await file.writeAsBytes(await pdf.save());

    return file;
  }
}
