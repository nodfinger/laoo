import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DeliveryNoteReceiptPdfService {
  const DeliveryNoteReceiptPdfService._();

  static const defaultCompanyName = 'บริษัท ละออซอฟต์เทค จำกัด';
  static const defaultCompanyAddress =
      '45 เพชรเกษม 50/2 ถนนเพชรเกษม แขวงบางหว้า เขตภาษีเจริญ กรุงเทพฯ 10160';
  static const defaultCompanyTaxId = '0105554083578';

  static Future<void> export({
    required String documentCode,
    required DateTime documentDate,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
    required String companyTaxId,
    required String customerCode,
    required String customerName,
    required String customerAddress,
    required String contactName,
    required String contactPhone,
    required String issuerName,
    required String remark,
    required List<Map<String, dynamic>> items,
    required Color accent,
    Uint8List? signatureBytes,
    String documentTitle = 'ใบเสร็จรับเงิน',
  }) async {
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Variable.ttf',
    );
    final font = pw.Font.ttf(fontData.buffer.asByteData());
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    final primary = PdfColor.fromInt(accent.toARGB32());
    final total = items.fold<double>(
      0,
      (sum, item) =>
          sum + _number(item['deliveryQty']) * _number(item['unitPrice']),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 28),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'หน้า ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          _companyHeader(
            primary: primary,
            companyName: companyName,
            address: companyAddress,
            phone: companyPhone,
            email: companyEmail,
            taxId: companyTaxId,
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: primary, thickness: 1.2),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _customerBlock(
                  customerCode: customerCode,
                  customerName: customerName,
                  address: customerAddress,
                  contactName: contactName,
                  contactPhone: contactPhone,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.SizedBox(
                width: 190,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      documentTitle,
                      style: pw.TextStyle(
                        color: primary,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    _rightValue('เลขที่เอกสาร', _display(documentCode)),
                    _rightValue('วันที่เอกสาร', _date(documentDate)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          _itemTable(items, primary),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  constraints: const pw.BoxConstraints(minHeight: 62),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'หมายเหตุ: ${_display(remark)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: pw.BoxDecoration(
                  color: primary.shade(0.1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'รวมเงิน',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      _money(total),
                      style: pw.TextStyle(
                        color: primary,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 50),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _signature('ผู้รับสินค้า', ''),
              _signature(
                'ผู้รับชำระเงิน',
                'โชคชัย วันดี',
                signatureBytes: signatureBytes,
              ),
            ],
          ),
        ],
      ),
    );

    final safeCode = documentCode.trim().isEmpty
        ? 'draft'
        : documentCode.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final bytes = await document.save();
    await Printing.layoutPdf(
      name: 'receipt_$safeCode.pdf',
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  static pw.Widget _companyHeader({
    required PdfColor primary,
    required String companyName,
    required String address,
    required String phone,
    required String email,
    required String taxId,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        _display(companyName, fallback: 'บริษัท'),
        style: pw.TextStyle(
          color: primary,
          fontSize: 24,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 5),
      if (address.trim().isNotEmpty) pw.Text(address),
      if (phone.trim().isNotEmpty || email.trim().isNotEmpty)
        pw.Text(
          [
            if (phone.trim().isNotEmpty) 'โทรศัพท์: $phone',
            if (email.trim().isNotEmpty) 'Email: $email',
          ].join('  |  '),
        ),
      if (taxId.trim().isNotEmpty) pw.Text('เลขประจำตัวผู้เสียภาษี: $taxId'),
    ],
  );

  static pw.Widget _customerBlock({
    required String customerCode,
    required String customerName,
    required String address,
    required String contactName,
    required String contactPhone,
  }) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ลูกค้า: ${_display(customerName)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        if (address.trim().isNotEmpty) pw.Text('ที่อยู่: $address'),
        if (contactName.trim().isNotEmpty) pw.Text('ผู้ติดต่อ: $contactName'),
        if (contactPhone.trim().isNotEmpty) pw.Text('โทรศัพท์: $contactPhone'),
      ],
    ),
  );

  static pw.Widget _itemTable(
    List<Map<String, dynamic>> items,
    PdfColor primary,
  ) {
    final rows = items.indexed.map((entry) {
      final item = entry.$2;
      final quantity = _number(item['deliveryQty']);
      final price = _number(item['unitPrice']);
      return [
        '${entry.$1 + 1}',
        '${item['itemName'] ?? ''}',
        _quantity(quantity),
        '${item['unitName'] ?? item['unitCode'] ?? ''}',
        _money(price),
        _money(quantity * price),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: const [
        'ลำดับ',
        'รายการ',
        'จำนวน',
        'หน่วย',
        'ราคา',
        'รวมเงิน',
      ],
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
      headerDecoration: pw.BoxDecoration(color: primary.shade(0.12)),
      headerStyle: pw.TextStyle(
        color: primary,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerAlignment: pw.Alignment.center,
      cellAlignments: {
        0: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.center,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
      columnWidths: const {
        0: pw.FixedColumnWidth(34),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FixedColumnWidth(55),
        3: pw.FixedColumnWidth(52),
        4: pw.FixedColumnWidth(66),
        5: pw.FixedColumnWidth(72),
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
    );
  }

  static pw.Widget _rightValue(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text('$label: ', style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  static pw.Widget _signature(
    String label,
    String name, {
    Uint8List? signatureBytes,
  }) => pw.SizedBox(
    width: 190,
    child: pw.Column(
      children: [
        if (signatureBytes != null)
          pw.Image(pw.MemoryImage(signatureBytes), height: 34)
        else
          pw.SizedBox(height: 34),
        pw.Container(height: 1, color: PdfColors.grey500),
        pw.SizedBox(height: 5),
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        if (name.trim().isNotEmpty)
          pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );

  static double _number(dynamic value) =>
      double.tryParse('$value'.replaceAll(',', '')) ?? 0;

  static String _money(double value) => value
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  static String _quantity(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  static String _display(String value, {String fallback = '-'}) =>
      value.trim().isEmpty ? fallback : value.trim();
}
