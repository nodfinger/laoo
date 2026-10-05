import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TaxInvoiceCopyDefinition {
  const TaxInvoiceCopyDefinition(this.label, this.purpose);

  final String label;
  final String purpose;
}

class TaxInvoicePdfService {
  const TaxInvoicePdfService._();

  static const finalCopies = <TaxInvoiceCopyDefinition>[
    TaxInvoiceCopyDefinition('ต้นฉบับใบกำกับภาษี', 'สำหรับลูกค้า'),
    TaxInvoiceCopyDefinition('สำเนาใบกำกับภาษี', 'สำหรับลูกค้า'),
    TaxInvoiceCopyDefinition('สำเนาใบกำกับภาษี', 'สำหรับบัญชี'),
    TaxInvoiceCopyDefinition('สำเนาใบกำกับภาษี', 'สำหรับจัดเก็บ'),
  ];

  static const previewCopy = TaxInvoiceCopyDefinition(
    'ตัวอย่างใบกำกับภาษี',
    'ฉบับร่าง',
  );

  static Future<void> export({
    required Map<String, dynamic> data,
    required bool finalDocument,
    required Color accent,
  }) async {
    final bytes = await build(
      data: data,
      finalDocument: finalDocument,
      accent: accent,
    );
    final header = _map(data['header']);
    final code = _text(header['taxInvoiceCode']);
    final safeCode = code.isEmpty
        ? 'draft'
        : code.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await Printing.layoutPdf(
      name:
          'tax_invoice_${safeCode}_${finalDocument ? '4_copies' : 'preview'}.pdf',
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> build({
    required Map<String, dynamic> data,
    required bool finalDocument,
    required Color accent,
  }) async {
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Variable.ttf',
    );
    final font = pw.Font.ttf(fontData.buffer.asByteData());
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    final primary = PdfColor.fromInt(accent.toARGB32());
    final company = _map(data['company']);
    final header = _map(data['header']);
    final items = _maps(data['items']);
    final copies = finalDocument ? finalCopies : const [previewCopy];

    for (var index = 0; index < copies.length; index++) {
      final copy = copies[index];
      document.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
            buildBackground: finalDocument
                ? null
                : (_) => pw.Center(
                    child: pw.Transform.rotate(
                      angle: -0.45,
                      child: pw.Opacity(
                        opacity: 0.10,
                        child: pw.Text(
                          'ฉบับร่าง',
                          style: pw.TextStyle(
                            fontSize: 68,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          header: (_) => _header(
            company: company,
            header: header,
            copy: copy,
            primary: primary,
            copyNumber: index + 1,
            copyCount: copies.length,
          ),
          footer: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  finalDocument
                      ? 'ชุดที่ ${index + 1} / ${copies.length} • ${copy.purpose}'
                      : 'ตัวอย่างก่อนออกเอกสาร',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'หน้า ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          build: (_) => [
            _customerBlock(header),
            pw.SizedBox(height: 12),
            _itemTable(items, primary),
            pw.SizedBox(height: 12),
            _summary(header, primary),
            pw.SizedBox(height: 12),
            _remark(header),
            pw.SizedBox(height: 42),
            _signatures(),
          ],
        ),
      );
    }
    return document.save();
  }

  static pw.Widget _header({
    required Map<String, dynamic> company,
    required Map<String, dynamic> header,
    required TaxInvoiceCopyDefinition copy,
    required PdfColor primary,
    required int copyNumber,
    required int copyCount,
  }) => pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _display(company['companyName'], fallback: 'บริษัท'),
                  style: pw.TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (_text(company['address']).isNotEmpty)
                  pw.Text(
                    _text(company['address']),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                pw.Text(
                  [
                    if (_text(company['telephone']).isNotEmpty)
                      'โทรศัพท์: ${_text(company['telephone'])}',
                    if (_text(company['email']).isNotEmpty)
                      'อีเมล: ${_text(company['email'])}',
                  ].join('  |  '),
                  style: const pw.TextStyle(fontSize: 9),
                ),
                if (_text(company['taxId']).isNotEmpty)
                  pw.Text(
                    'เลขประจำตัวผู้เสียภาษี: ${_text(company['taxId'])}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.SizedBox(
            width: 210,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  copy.label,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    color: primary,
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  copy.purpose,
                  style: pw.TextStyle(
                    color: primary,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (copyCount > 1)
                  pw.Text(
                    'ชุดที่ $copyNumber / $copyCount',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                pw.SizedBox(height: 4),
                _rightValue('เลขที่เอกสาร', _display(header['taxInvoiceCode'])),
                _rightValue('วันที่เอกสาร', _date(header['taxInvoiceDate'])),
                _rightValue('ครบกำหนด', _date(header['dueDate'])),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 7),
      pw.Divider(color: primary, thickness: 1.1),
      pw.SizedBox(height: 8),
    ],
  );

  static pw.Widget _customerBlock(Map<String, dynamic> header) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(9),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ลูกค้า: ${_display(header['customerName'])} (${_display(header['customerCode'])})',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        if (_text(header['customerAddress']).isNotEmpty)
          pw.Text('ที่อยู่: ${_text(header['customerAddress'])}'),
        if (_text(header['customerTaxId']).isNotEmpty)
          pw.Text('เลขประจำตัวผู้เสียภาษี: ${_text(header['customerTaxId'])}'),
        if (_text(header['contactName']).isNotEmpty)
          pw.Text('ผู้ติดต่อ: ${_text(header['contactName'])}'),
        if (_text(header['contactPhone']).isNotEmpty ||
            _text(header['contactEmail']).isNotEmpty)
          pw.Text(
            [
              if (_text(header['contactPhone']).isNotEmpty)
                'โทรศัพท์: ${_text(header['contactPhone'])}',
              if (_text(header['contactEmail']).isNotEmpty)
                'อีเมล: ${_text(header['contactEmail'])}',
            ].join('  |  '),
          ),
      ],
    ),
  );

  static pw.Widget _itemTable(
    List<Map<String, dynamic>> items,
    PdfColor primary,
  ) => pw.TableHelper.fromTextArray(
    headers: const [
      'ลำดับ',
      'รหัส',
      'รายการ',
      'จำนวน',
      'หน่วย',
      'ราคา/หน่วย',
      'ส่วนลด',
      'จำนวนเงิน',
    ],
    data: items
        .map(
          (item) => [
            _text(item['lineNo']),
            _text(item['itemCode']),
            _text(item['itemName']),
            _quantity(item['quantity']),
            _text(item['unitCode']),
            _money(item['unitPrice']),
            _money(item['discountAmount']),
            _money(item['amount']),
          ],
        )
        .toList(),
    headerDecoration: pw.BoxDecoration(color: primary),
    headerStyle: pw.TextStyle(
      color: PdfColors.white,
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    ),
    cellStyle: const pw.TextStyle(fontSize: 8),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
    columnWidths: const {
      0: pw.FixedColumnWidth(30),
      1: pw.FixedColumnWidth(54),
      2: pw.FlexColumnWidth(2.6),
      3: pw.FixedColumnWidth(42),
      4: pw.FixedColumnWidth(38),
      5: pw.FixedColumnWidth(58),
      6: pw.FixedColumnWidth(52),
      7: pw.FixedColumnWidth(62),
    },
    cellAlignments: const {
      0: pw.Alignment.center,
      3: pw.Alignment.centerRight,
      5: pw.Alignment.centerRight,
      6: pw.Alignment.centerRight,
      7: pw.Alignment.centerRight,
    },
  );

  static pw.Widget _summary(Map<String, dynamic> header, PdfColor primary) =>
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 250,
          child: pw.Column(
            children: [
              _amountRow('รวมก่อนส่วนลด', header['subtotal']),
              _amountRow(
                'ส่วนลด ${_quantity(header['discountPercent'])}%',
                header['discountAmount'],
              ),
              _amountRow('รวมหลังส่วนลด', header['amountAfterDiscount']),
              _amountRow(
                'ภาษีมูลค่าเพิ่ม ${_quantity(header['taxPercent'])}%',
                header['taxAmount'],
              ),
              pw.Divider(color: primary),
              _amountRow(
                'ยอดสุทธิ',
                header['netAmount'],
                emphasized: true,
                color: primary,
              ),
            ],
          ),
        ),
      );

  static pw.Widget _remark(Map<String, dynamic> header) => pw.Container(
    width: double.infinity,
    constraints: const pw.BoxConstraints(minHeight: 48),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(
      'หมายเหตุ: ${_display(header['remark'])}',
      style: const pw.TextStyle(fontSize: 9),
    ),
  );

  static pw.Widget _signatures() => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
    children: [
      _signature('ผู้รับสินค้า/บริการ'),
      _signature('ผู้รับเงิน'),
      _signature('ผู้มีอำนาจลงนาม'),
    ],
  );

  static pw.Widget _signature(String label) => pw.SizedBox(
    width: 140,
    child: pw.Column(
      children: [
        pw.Container(
          height: 34,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey500)),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          'วันที่ ____ / ____ / ______',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );

  static pw.Widget _rightValue(String label, String value) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('$label: ', style: const pw.TextStyle(fontSize: 9)),
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );

  static pw.Widget _amountRow(
    String label,
    dynamic value, {
    bool emphasized = false,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: emphasized ? 11 : 9,
            fontWeight: emphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          _money(value),
          style: pw.TextStyle(
            color: color,
            fontSize: emphasized ? 12 : 9,
            fontWeight: emphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
  static List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.map((item) => Map<String, dynamic>.from(item as Map)).toList()
      : const [];
  static String _text(dynamic value) => value?.toString().trim() ?? '';
  static String _display(dynamic value, {String fallback = '-'}) {
    final text = _text(value);
    return text.isEmpty ? fallback : text;
  }

  static num _number(dynamic value) => num.tryParse(_text(value)) ?? 0;
  static String _money(dynamic value) => _number(value)
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  static String _quantity(dynamic value) {
    final number = _number(value);
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(2);
  }

  static String _date(dynamic value) {
    final date = DateTime.tryParse(_text(value));
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
