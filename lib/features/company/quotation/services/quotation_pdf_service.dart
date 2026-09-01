
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class QuotationPdfService {
  const QuotationPdfService._();

  static const defaultCompanyName = 'บริษัท ละออซอฟต์เทค จำกัด';
  static const defaultCompanyAddress =
      '45 เพชรเกษม 50/2 ถนนเพชรเกษม แขวงบางหว้า เขตภาษีเจริญ กรุงเทพฯ 10160';
  static const defaultCompanyTaxId = '0105554083578';

  static Future<void> export({
    required String documentCode,
    required DateTime documentDate,
    required String companyPhone,
    required String companyEmail,
    required String customerCode,
    required String customerName,
    required String customerAddress,
    required String customerTaxId,
    required String contactName,
    required String contactPhone,
    required String contactEmail,
    required String salespersonName,
    required int validDays,
    required String paymentType,
    required int creditDays,
    required String remark,
    required List<Map<String, dynamic>> items,
    required double discountPercent,
    required double vatPercent,
    required Color accent,
    Uint8List? signatureBytes,
  }) async {
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Variable.ttf',
    );
    final font = pw.Font.ttf(fontData.buffer.asByteData());
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    final primary = PdfColor.fromInt(accent.toARGB32());
    final subtotal = items.fold<double>(0, (sum, item) => sum + _amount(item));
    final discount = subtotal * discountPercent / 100;
    final afterDiscount = subtotal - discount;
    final tax = afterDiscount * vatPercent / 100;
    final net = afterDiscount + tax;

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
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _companyHeader(primary, companyPhone, companyEmail),
              ),
              pw.SizedBox(width: 18),
              pw.SizedBox(
                width: 190,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ใบเสนอราคา',
                      style: pw.TextStyle(
                        color: primary,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    _rightValue('เลขที่เอกสาร', _display(documentCode)),
                    _rightValue('วันที่เอกสาร', _date(documentDate)),
                    _rightValue('ยืนราคา', '$validDays วัน'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
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
                  taxId: customerTaxId,
                  contactName: contactName,
                  contactPhone: contactPhone,
                  contactEmail: contactEmail,
                ),
              ),
              pw.SizedBox(width: 16),
              pw.SizedBox(
                width: 210,
                child: _salesBlock(
                  salespersonName: salespersonName,
                  paymentType: paymentType,
                  creditDays: creditDays,
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
                  constraints: const pw.BoxConstraints(minHeight: 84),
                  padding: const pw.EdgeInsets.all(9),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'หมายเหตุ: ${_display(remark)}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.black,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.SizedBox(
                width: 245,
                child: pw.Column(
                  children: [
                    _amountRow('รวมเงิน', subtotal),
                    _amountRow('ส่วนลด ${_number(discountPercent)}%', discount),
                    _amountRow('รวมหลังหักส่วนลด', afterDiscount),
                    if (vatPercent > 0)
                      _amountRow('ภาษี ${_number(vatPercent)}%', tax),
                    pw.Divider(color: primary),
                    _amountRow(
                      'รวมเงินสุทธิ',
                      net,
                      emphasized: true,
                      primary: primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 48),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _signature(
                'ผู้เสนอราคา',
                salespersonName,
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
      name: 'quotation_$safeCode.pdf',
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  static pw.Widget _companyHeader(
    PdfColor primary,
    String phone,
    String email,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        defaultCompanyName,
        style: pw.TextStyle(
          color: primary,
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(defaultCompanyAddress, style: const pw.TextStyle(fontSize: 9)),
      if (phone.trim().isNotEmpty || email.trim().isNotEmpty)
        pw.Text(
          [
            if (phone.trim().isNotEmpty) 'โทรศัพท์: $phone',
            if (email.trim().isNotEmpty) 'Email: $email',
          ].join('  |  '),
          style: const pw.TextStyle(fontSize: 9),
        ),
      pw.Text(
        'ทะเบียนนิติบุคคล $defaultCompanyTaxId',
        style: const pw.TextStyle(fontSize: 9),
      ),
    ],
  );

  static pw.Widget _customerBlock({
    required String customerCode,
    required String customerName,
    required String address,
    required String taxId,
    required String contactName,
    required String contactPhone,
    required String contactEmail,
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
        if (taxId.trim().isNotEmpty) pw.Text('เลขประจำตัวผู้เสียภาษี: $taxId'),
        if (contactName.trim().isNotEmpty) pw.Text('ผู้ติดต่อ: $contactName'),
        if (contactPhone.trim().isNotEmpty) pw.Text('โทรศัพท์: $contactPhone'),
        if (contactEmail.trim().isNotEmpty) pw.Text('Email: $contactEmail'),
      ],
    ),
  );

  static pw.Widget _salesBlock({
    required String salespersonName,
    required String paymentType,
    required int creditDays,
  }) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('ผู้เสนอราคา: ${_display(salespersonName)}'),
        pw.Text('ประเภทชำระเงิน: ${_display(paymentType)}'),
        pw.Text('จำนวนวันเครดิต: $creditDays วัน'),
      ],
    ),
  );

  static pw.Widget _itemTable(
    List<Map<String, dynamic>> items,
    PdfColor primary,
  ) => pw.TableHelper.fromTextArray(
    headers: const [
      'ลำดับ',
      'รายการ',
      'จำนวน',
      'หน่วย',
      'ราคา',
      'ส่วนลด',
      'รวมเงิน',
    ],
    data: items.indexed.map((entry) {
      final item = entry.$2;
      return [
        '${entry.$1 + 1}',
        '${item['itemName'] ?? ''}',
        _number(_value(item['quantity'])),
        '${item['unitName'] ?? item['unitCode'] ?? ''}',
        _money(_value(item['unitPrice'])),
        _money(_discountAmount(item)),
        _money(_amount(item)),
      ];
    }).toList(),
    headerDecoration: pw.BoxDecoration(color: primary.shade(.12)),
    headerStyle: pw.TextStyle(
      color: PdfColors.black,
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    ),
    cellStyle: const pw.TextStyle(color: PdfColors.black, fontSize: 8),
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignment: pw.Alignment.centerLeft,
    border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
    columnWidths: {
      0: const pw.FixedColumnWidth(30),
      1: const pw.FlexColumnWidth(2.4),
      2: const pw.FixedColumnWidth(45),
      3: const pw.FixedColumnWidth(45),
      4: const pw.FixedColumnWidth(56),
      5: const pw.FixedColumnWidth(50),
      6: const pw.FixedColumnWidth(62),
    },
  );

  static pw.Widget _rightValue(String label, String value) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    ],
  );

  static pw.Widget _amountRow(
    String label,
    double value, {
    bool emphasized = false,
    PdfColor? primary,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColors.black,
            fontWeight: emphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          _money(value),
          style: pw.TextStyle(
            color: emphasized ? primary : PdfColors.black,
            fontWeight: emphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
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
        pw.Container(height: .5, color: PdfColors.grey500),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        if (name.trim().isNotEmpty)
          pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );

  static double _value(dynamic value) =>
      double.tryParse('$value'.replaceAll(',', '')) ?? 0;

  static double _discountAmount(Map<String, dynamic> item) {
    final before = _value(item['quantity']) * _value(item['unitPrice']);
    final type = '${item['discountType'] ?? 'N'}'.toUpperCase();
    if (type == 'P') {
      return before *
          _value(item['discountPercent'] ?? item['discountValue']) /
          100;
    }
    if (type == 'A') {
      return _value(item['discountAmount'] ?? item['discountValue']);
    }
    return 0;
  }

  static double _amount(Map<String, dynamic> item) =>
      _value(item['quantity']) * _value(item['unitPrice']) -
      _discountAmount(item);

  static String _display(String value, {String fallback = '-'}) =>
      value.trim().isEmpty ? fallback : value.trim();

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  static String _money(double value) => value
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  static String _number(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}
