import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> printGatePass(
  Map<String, dynamic> document,
  Map<String, dynamic> row,
  List<Map<String, dynamic>> purposes,
  String yearFormat,
) async {
  final bytes = await buildGatePassPdf(document, row, purposes, yearFormat);
  await Printing.layoutPdf(
    name: 'gate-pass.pdf',
    format: PdfPageFormat.a4,
    dynamicLayout: false,
    onLayout: (_) async => bytes,
  );
}

Future<Uint8List> buildGatePassPdf(
  Map<String, dynamic> document,
  Map<String, dynamic> row,
  List<Map<String, dynamic>> purposes,
  String yearFormat,
) async {
  final fontData = await rootBundle.load(
    'assets/fonts/NotoSansThai-Variable.ttf',
  );
  final font = pw.Font.ttf(fontData.buffer.asByteData());
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  final items = (document['items'] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  final files = (document['files'] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  String value(Object? v) =>
      v == null || v.toString().trim().isEmpty ? '—' : v.toString();
  String date(Object? v, {bool time = false}) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    if (d == null) return '—';
    if (time)
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final year =
        {'B', 'BE', 'T', 'TH', 'THAI'}.contains(yearFormat.toUpperCase())
        ? d.year + 543
        : d.year;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/$year';
  }

  String purpose(Object? id) {
    for (final p in purposes) {
      if ('${p['id']}' == '$id') return value(p['name']);
    }
    return value(document['purpose']);
  }

  pw.Widget field(String label, Object? val) => pw.Expanded(
    child: pw.Padding(
      padding: const pw.EdgeInsets.only(right: 8, bottom: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(value(val), style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    ),
  );
  pw.Widget heading(String text) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 10, bottom: 7),
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    color: PdfColors.green50,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.green900,
      ),
    ),
  );
  String documentName(Object? fileName) {
    final name = value(fileName);
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  List<pw.Widget> fileWidgets(List<Map<String, dynamic>> list) {
    if (list.isEmpty)
      return [
        pw.Text(
          'ไม่มีไฟล์แนบ',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ];
    return [
      for (final f in list)
        if (f['image'] != null)
          pw.Container(
            width: 90,
            margin: const pw.EdgeInsets.only(right: 6, bottom: 6),
            padding: const pw.EdgeInsets.all(3),
            child: pw.SizedBox(
              width: 82,
              height: 65,
              child: pw.Image(
                pw.MemoryImage(base64Decode(f['image'].toString())),
                fit: pw.BoxFit.contain,
              ),
            ),
          )
        else
          pw.Container(
            margin: const pw.EdgeInsets.only(right: 8, bottom: 4),
            child: pw.Text(
              documentName(f['fileName']),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
    ];
  }

  final widgets = <pw.Widget>[
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (document['companyLogo'] is String)
          pw.Padding(
            padding: const pw.EdgeInsets.only(right: 8),
            child: pw.SizedBox(
              width: 46,
              height: 46,
              child: pw.Image(
                pw.MemoryImage(base64Decode(document['companyLogo'] as String)),
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        pw.Expanded(
          child: pw.Text(
            value(document['companyName']),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'ใบขอนำทรัพย์สินออก',
              style: pw.TextStyle(
                fontSize: 18,
                color: PdfColors.green900,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(value(document['number'])),
          ],
        ),
      ],
    ),
    heading('ข้อมูลเอกสาร'),
    pw.Row(
      children: [
        field('วันที่เอกสาร', date(document['documentDateTime'])),
        field('เวลา', date(document['documentDateTime'], time: true)),
        field('วันที่นำของออก', date(document['plannedExitDate'])),
        field(
          'สถานะ',
          document['status'] == 'DRAFT' ? 'แบบร่าง' : document['status'],
        ),
      ],
    ),
    pw.Row(
      children: [
        field('วัตถุประสงค์', document['purpose']),
        field('ผู้รับมอบ', document['carrier']),
        field('เบอร์โทรผู้รับมอบ', document['carrierPhone']),
      ],
    ),
    pw.Row(
      children: [
        field('ปลายทาง', document['destination']),
        field('ผู้ขอ', row['requesterName']),
        field('แผนกผู้ขอ', row['departmentName']),
      ],
    ),
    pw.Row(children: [field('หมายเหตุ', document['remark'])]),
    heading('รูปภาพและเอกสารแนบใบขอ'),
  ];
  final headerFiles = files.where((f) => f['itemId'] == null).toList();
  if (headerFiles.isEmpty) {
    widgets.addAll(fileWidgets(headerFiles));
  } else {
    for (var offset = 0; offset < headerFiles.length; offset += 6) {
      widgets.add(
        pw.Wrap(
          children: fileWidgets(headerFiles.skip(offset).take(6).toList()),
        ),
      );
    }
  }
  widgets.add(heading('รายการทรัพย์สิน (${items.length} รายการ)'));
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final attached = files
        .where((f) => '${f['itemId']}' == '${item['id']}')
        .toList();
    widgets.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 7),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${i + 1}. ${value(item['name'])}   •   ${value(item['quantity'])} ${item['unit'] ?? ''}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              children: [
                field(
                  'วัตถุประสงค์',
                  item['purposeName'] ?? purpose(item['purposeId']),
                ),
                field(
                  'การนำกลับ',
                  item['isReturnRequired'] == true
                      ? 'ต้องนำกลับ'
                      : 'ไม่ต้องนำกลับ',
                ),
                field(
                  'นำกลับภายในวันที่',
                  item['isReturnRequired'] == true
                      ? date(item['expectedReturnDate'])
                      : '—',
                ),
              ],
            ),
            pw.Row(children: [field('หมายเหตุ', item['remark'])]),
            if (attached.isNotEmpty)
              pw.Wrap(children: fileWidgets(attached.take(6).toList())),
          ],
        ),
      ),
    );
    if (attached.isNotEmpty) {
      for (var offset = 6; offset < attached.length; offset += 6) {
        final chunk = attached.skip(offset).take(6).toList();
        widgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${i + 1}. ${value(item['name'])} (ต่อ)',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 4),
                pw.Wrap(children: fileWidgets(chunk)),
              ],
            ),
          ),
        );
      }
    }
  }
  widgets.add(pw.SizedBox(height: 26));
  widgets.add(
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        for (final label in ['ผู้ขอ', 'ผู้รับมอบ', 'ผู้ตรวจสอบ'])
          pw.Column(
            children: [
              pw.Text('........................................'),
              pw.Text(label),
              pw.Text(
                'วันที่ ......... / ......... / .........',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
      ],
    ),
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => widgets,
    ),
  );
  return pdf.save();
}
