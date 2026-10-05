import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CustomerShippingLabelPdfService {
  const CustomerShippingLabelPdfService._();

  static const pageFormat = PdfPageFormat(
    100 * PdfPageFormat.mm,
    150 * PdfPageFormat.mm,
    marginAll: 0,
  );

  static Future<void> export({
    required Map<String, dynamic> customer,
    required Color accent,
  }) async {
    final bytes = await build(customer: customer, accent: accent);
    final code = _text(customer['cusCode']);
    final safeCode = (code.isEmpty ? 'customer' : code).replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    await Printing.layoutPdf(
      name: 'shipping_label_$safeCode.pdf',
      format: pageFormat,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> build({
    required Map<String, dynamic> customer,
    required Color accent,
  }) async {
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Variable.ttf',
    );
    final font = pw.Font.ttf(fontData.buffer.asByteData());
    final primary = PdfColor.fromInt(accent.toARGB32());
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    document.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(18),
        build: (_) => pw.Container(
          width: double.infinity,
          height: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: primary, width: 1.2),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ใบปะหน้าจัดส่ง',
                style: pw.TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 12),
              pw.Text(
                'ถึง',
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 11,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                _display(customer['shippingLabelName']),
                style: pw.TextStyle(
                  fontSize: 19,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 14),
              _line(
                label: 'ที่อยู่',
                value: customer['shippingLabelAddress'],
                fontSize: 13,
              ),
              pw.SizedBox(height: 14),
              _line(
                label: 'โทรศัพท์',
                value: customer['shippingLabelPhone'],
                fontSize: 14,
              ),
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  static pw.Widget _line({
    required String label,
    required dynamic value,
    required double fontSize,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
      ),
      pw.SizedBox(height: 3),
      pw.Text(_display(value), style: pw.TextStyle(fontSize: fontSize)),
    ],
  );

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String _display(dynamic value) {
    final text = _text(value);
    return text.isEmpty ? '-' : text;
  }
}
