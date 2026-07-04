import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import '../models/service_packet.dart';
import 'chord_layout_engine.dart';

class ServicePacketPdf {
  static Future<File> export(ServicePacket packet) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                packet.title,
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Service Order",
                style: pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 10),
              ...packet.songs.map((s) => pw.Text("- ${s.title}")),
            ],
          );
        },
      ),
    );

    for (final song in packet.songs) {
      final lines = ChordLayoutEngine.build(song.content);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  song.title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 15),

                ...lines.map((line) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        line.chords.map((c) => c.chord).join(' '),
                        style: pw.TextStyle(
                          font: pw.Font.courier(),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        line.lyrics,
                        style: pw.TextStyle(font: pw.Font.courier()),
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
    }

    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/${packet.title}.pdf');

    await file.writeAsBytes(await pdf.save());

    return file;
  }
}
