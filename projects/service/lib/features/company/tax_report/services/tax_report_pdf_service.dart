import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TaxReportPdfService {
  const TaxReportPdfService._();

  static Future<Uint8List> buildReport(
    Map<String, dynamic> report,
    Color accent,
  ) async {
    final fontBytes = await rootBundle.load(
      'assets/fonts/NotoSansThai-Variable.ttf',
    );
    final font = pw.Font.ttf(fontBytes.buffer.asByteData());
    final title = report['type'] == 'SALE' ? 'รายงานภาษีขาย' : 'รายงานภาษีซื้อ';
    final rows = (report['rows'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final color = PdfColor(accent.r, accent.g, accent.b);
    String money(Object? value) =>
        (num.tryParse('$value') ?? 0).toStringAsFixed(2);
    String date(Object? value) {
      final parsed = DateTime.tryParse('$value');
      return parsed == null
          ? '-'
          : '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    }

    final summary = Map<String, dynamic>.from(report['summary'] as Map);
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(font: font, fontSize: 18, color: color),
            ),
            pw.Text(
              'เดือนภาษี ${report['month']}/${report['year']} · ${report['companyName'] ?? ''} · เลขภาษี ${report['companyTaxId'] ?? ''}',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            pw.Text(
              'สถานประกอบการ: ${report['branchId'] == null ? 'ภาพรวมทุกสาขา (ใช้กระทบยอดเท่านั้น)' : '${report['branchName']} ${report['branchTaxCode']}'}',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ข้อมูลเพื่อการตรวจสอบ ไม่ใช่แบบ ภ.พ.30',
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
            pw.Text(
              'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
          ],
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: const [
              'ลำดับ',
              'วันที่ใบ',
              'เลขใบกำกับฯ',
              'คู่ค้า',
              'เลขภาษี',
              'สาขาคู่ค้า',
              'มูลค่า',
              'VAT',
              'สิทธิ์',
            ],
            data: rows.indexed.map((entry) {
              final row = entry.$2;
              return [
                '${entry.$1 + 1}',
                date(row['invoiceDate']),
                '${row['invoiceCode']}',
                '${row['counterparty']}',
                '${row['taxId'] ?? '-'}',
                '${row['counterpartyTaxBranchCode'] ?? '-'}',
                money(row['taxBase']),
                money(row['taxAmount']),
                '${row['claimStatus'] ?? '-'}',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: color),
            cellStyle: pw.TextStyle(font: font, fontSize: 8),
            cellAlignments: {
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'รวมมูลค่า ${money(summary['taxBase'])} · VAT ทั้งหมด ${money(summary['taxAmount'])} · VAT หักได้ ${money(summary['eligibleTaxAmount'])}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
          if (report['type'] == 'SALE')
            pw.Text(
              'มูลค่ามีอัตราภาษี ${money(summary['ratedTaxBase'])} · มูลค่าอัตรา 0% ${money(summary['zeroRatedTaxBase'])}',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          pw.Text(
            'ขอบเขต: เฉพาะใบกำกับภาษีส่วนกลาง ยังไม่รวม POS, School Food, Rental และใบเพิ่ม–ลดหนี้',
            style: pw.TextStyle(font: font, fontSize: 8),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> printReport(
    Map<String, dynamic> report,
    Color accent,
  ) async {
    final bytes = await buildReport(report, accent);
    await Printing.layoutPdf(
      name: 'vat_${report['type']}_${report['year']}_${report['month']}.pdf',
      format: PdfPageFormat.a4.landscape,
      onLayout: (_) async => bytes,
    );
  }
}
