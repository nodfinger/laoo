import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

abstract final class RentalReceiptPdf {
  static Future<void> print(Map<String, dynamic> data) async {
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Variable.ttf',
    );
    final font = pw.Font.ttf(fontData.buffer.asByteData());
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    final company = _map(data['company']);
    final payment = _map(data['payment']);
    final kind = '${payment['Kind'] ?? ''}';
    final refund = kind.endsWith('_REFUND');
    final money = double.tryParse('${payment['Amount'] ?? 0}') ?? 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Text(
            '${company['companyName'] ?? '-'}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${company['address'] ?? ''}',
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            'โทร ${company['phone'] ?? '-'}   ${company['email'] ?? ''}',
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            refund ? 'ใบคืนเงิน' : 'ใบรับเงินค่าเช่า/มัดจำ',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
          _line('เลขที่เอกสาร', data['documentNo']),
          _line('เลขที่จอง', payment['BookingCode']),
          _line('วันที่', payment['CreatedAt']),
          _line('ลูกค้า', payment['CusName']),
          _line('ที่อยู่', payment['CusAddress']),
          _line('เลขประจำตัวผู้เสียภาษี', payment['customerTaxId']),
          _line('รายการ', _kind(payment['Kind'])),
          _line('วิธีชำระ', payment['Method']),
          if ('${payment['ReferenceNo'] ?? ''}'.isNotEmpty)
            _line('เลขอ้างอิง', payment['ReferenceNo']),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: const pw.BorderSide(color: PdfColors.grey300),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(5),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('รายการของเช่า', bold: true),
                  _cell('จำนวน', bold: true),
                  _cell('ยอดเงิน', bold: true, align: pw.TextAlign.right),
                ],
              ),
              ..._list(data['lines']).map(
                (line) => pw.TableRow(
                  children: [
                    _cell(
                      '${line['ItemCode'] ?? ''} ${line['ItemName'] ?? ''}',
                    ),
                    _cell('${line['Quantity'] ?? 0}'),
                    _cell(_lineAmount(line, kind), align: pw.TextAlign.right),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${refund ? 'คืนเงินสุทธิ' : 'รับเงิน'}  ${money.toStringAsFixed(2)} บาท',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Divider(),
          pw.Text(
            'เอกสารรับเงิน/คืนเงินของระบบเช่า ไม่ใช่ใบกำกับภาษี',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('ผู้รับเงิน __________________'),
              pw.Text('ผู้ชำระเงิน __________________'),
            ],
          ),
        ],
      ),
    );
    final bytes = await pdf.save();
    await Printing.layoutPdf(
      name: '${data['documentNo'] ?? 'rental-receipt'}.pdf',
      format: PdfPageFormat.a5,
      onLayout: (_) async => bytes,
    );
  }

  static pw.Widget _line(String label, Object? value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: '${value ?? '-'}'),
        ],
      ),
    ),
  );

  static pw.Widget _cell(
    String value, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      value,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  static String _kind(Object? value) => switch ('$value') {
    'RENT' => 'ค่าเช่า',
    'DEPOSIT' => 'เงินมัดจำ',
    'ADDITIONAL' => 'ค่าเสียหายเพิ่มเติม',
    'DEPOSIT_REFUND' => 'คืนเงินมัดจำ',
    'RENT_REFUND' => 'คืนค่าเช่า',
    'ADDITIONAL_REFUND' => 'คืนเงินส่วนต่าง',
    _ => '$value',
  };

  static String _lineAmount(Map<String, dynamic> line, String kind) {
    final field = switch (kind) {
      'RENT' || 'RENT_REFUND' => 'RentAmount',
      'DEPOSIT' || 'DEPOSIT_REFUND' => 'DepositAmount',
      _ => null,
    };
    if (field == null) return '—';
    final amount = double.tryParse('${line[field] ?? 0}') ?? 0;
    return amount.toStringAsFixed(2);
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];
}
