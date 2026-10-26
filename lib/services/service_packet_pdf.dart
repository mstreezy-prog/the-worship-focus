import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import '../models/service_packet.dart';
import 'chordpro_pdf_content.dart';

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
              pw.Text("Service Order", style: pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 10),
              ...(packet.serviceOrder.isEmpty
                      ? packet.songs.map(
                          (song) => ServicePacketEntry.song(song.title),
                        )
                      : packet.serviceOrder)
                  .map(
                    (entry) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            entry.isSection ? entry.title : '- ${entry.title}',
                            style: pw.TextStyle(
                              fontSize: entry.isSection ? 15 : 12,
                              fontWeight: entry.isSection
                                  ? pw.FontWeight.bold
                                  : pw.FontWeight.normal,
                            ),
                          ),
                          if (entry.notes.trim().isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(
                                left: 12,
                                top: 2,
                              ),
                              child: pw.Text(
                                entry.notes,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );

    for (final song in packet.songs) {
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

                ...chordProPdfContent(song.chordPro),
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
