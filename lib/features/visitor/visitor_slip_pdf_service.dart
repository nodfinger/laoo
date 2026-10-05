import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class VisitorSlipPdfService {
  const VisitorSlipPdfService._();

  static const pageFormat = PdfPageFormat(
    50 * PdfPageFormat.mm,
    140 * PdfPageFormat.mm,
    marginAll: 3 * PdfPageFormat.mm,
  );

  static Future<void> print({
    required Map<String, dynamic> visit,
    required Map<String, dynamic> company,
    Uint8List? companyLogo,
  }) async {
    final bytes = await build(
      visit: visit,
      company: company,
      companyLogo: companyLogo,
    );
    final visitId = _text(visit['visitorVisitId']);
    await Printing.layoutPdf(
      name: 'visitor_slip_${visitId.isEmpty ? 'draft' : visitId}.pdf',
      format: pageFormat,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> build({
    required Map<String, dynamic> visit,
    required Map<String, dynamic> company,
    Uint8List? companyLogo,
  }) async {
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Variable.ttf',
    );
    final font = pw.Font.ttf(fontData.buffer.asByteData());
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    final visitId = _text(visit['visitorVisitId']);
    pw.MemoryImage? logo;
    if (companyLogo != null && companyLogo.isNotEmpty) {
      try {
        logo = pw.MemoryImage(companyLogo);
      } catch (_) {
        logo = null;
      }
    }

    document.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (logo != null)
              pw.Center(
                child: pw.Container(
                  width: 14 * PdfPageFormat.mm,
                  height: 14 * PdfPageFormat.mm,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              ),
            if (logo != null) pw.SizedBox(height: 2),
            pw.Text(
              _display(company['companyName'], fallback: 'บริษัท'),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'สลิปเข้าพบ',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'VIS-${visitId.padLeft(8, '0')}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.SizedBox(height: 3),
            pw.Divider(thickness: .6, color: PdfColors.grey600),
            _line('ผู้มาติดต่อ', visit['visitorName']),
            _line('โทรศัพท์', visit['phone'], hideWhenEmpty: true),
            _line('ผู้รับรอง', visit['hostName']),
            _line('ห้อง/พื้นที่', visit['hostRoom'], hideWhenEmpty: true),
            _line('จุดติดต่อ', visit['contactPointName']),
            _line('วัตถุประสงค์', visit['visitPurpose']),
            _line('เวลาเข้า', _dateTime(visit['checkedInDate'])),
            _line(
              'เวลาออก',
              _dateTime(visit['checkedOutDate']),
              hideWhenEmpty: true,
            ),
            _line('สถานะ', _status(visit['statusCode'])),
            pw.Divider(thickness: .6, color: PdfColors.grey600),
            pw.Text(
              'กรุณาเก็บสลิปและปฏิบัติตามข้อกำหนดของสถานที่',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'พิมพ์ ${_dateTime(DateTime.now())}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );

    return document.save();
  }

  static pw.Widget _line(
    String label,
    Object? value, {
    bool hideWhenEmpty = false,
  }) {
    final text = _display(value);
    if (hideWhenEmpty && text == '-') return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.2),
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  static String _status(Object? value) => switch (_text(value)) {
    'CHECKED_IN' => 'อยู่ภายในพื้นที่',
    'CHECKED_OUT' => 'ออกจากพื้นที่แล้ว',
    'CANCELLED' => 'ยกเลิก',
    final value when value.isNotEmpty => value,
    _ => '-',
  };

  static String _dateTime(Object? value) {
    final parsed = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _display(Object? value, {String fallback = '-'}) {
    final text = _text(value);
    return text.isEmpty ? fallback : text;
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';
}
