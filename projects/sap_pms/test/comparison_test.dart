import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_sap_pms/src/comparison.dart';
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

void main() {
  final pmsFile = Platform.environment['LAOO_PMS_TEST_FILE'];
  final sapFile = Platform.environment['LAOO_SAP_TEST_FILE'];
  if (pmsFile != null && sapFile != null) {
    test('reads and compares supplied workbooks', () {
      final pms = PmsSapComparison.read(File(pmsFile).readAsBytesSync());
      final sap = PmsSapComparison.read(File(sapFile).readAsBytesSync());
      expect(pms.rows, isNotEmpty);
      expect(sap.rows, isNotEmpty);
      final result = PmsSapComparison.compare(pms, sap);
      expect(result, isNotEmpty);
      print(
        'Input counts: PMS ${pms.rows.length}, SAP ${sap.rows.length}; results ${result.length}; issues ${result.where((r) => r.status == 'problem').length}',
      );
      expect(PmsSapComparison.export(result), isNotEmpty);
    });
  }
  final headers = [
    'ประเภท',
    'เลขที่เอกสาร',
    'วันที่สร้างเอกสาร',
    'วันที่ Posting',
    'สถานะเอกสาร',
    'สถานะส่ง SAP',
    'รวมเงินก่อน VAT',
    'ผู้ทำรายการ',
    'รหัสฝ่าย',
    'ฝ่าย',
    'SAPStatusSendNotOK',
    'PmsStatus',
    'SapStatus',
  ];
  List<String> row(String number, String status, String amount) => [
    'x',
    number,
    '46296',
    '46296',
    'x',
    'x',
    amount,
    'x',
    '1',
    'x',
    '1',
    status,
    '1',
  ];
  test('rejects an invalid ISO date instead of normalizing it', () {
    final pmsRow = row('invalid-date', '2', '10');
    pmsRow[2] = '2026-02-30';
    final result = PmsSapComparison.compare(
      SheetData(headers, [pmsRow], false),
      SheetData(headers, [row('invalid-date', '2', '10')], false),
    );
    expect(result.single.status, 'problem');
    expect(result.single.details, 'วันที่เอกสารไม่ถูกต้อง');
  });
  test('rejects a different SAP header at the document number position', () {
    final sapHeaders = List<String>.from(headers)..[1] = 'รหัสอื่น';
    expect(
      () => PmsSapComparison.compare(
        SheetData(headers, [row('a', '2', '10')], false),
        SheetData(sapHeaders, [row('a', '2', '10')], false),
      ),
      throwsFormatException,
    );
  });
  test(
    'compares by key, skips absent columns and reports unmatched, waiting and duplicates',
    () {
      final pms = SheetData(headers, [
        row('ok', '2', '10'),
        row('diff', '2', '10'),
        row('missing', '2', '10'),
        row('wait', '1', '10'),
        row('dup', '2', '10'),
        row('dup', '2', '10'),
      ], false);
      final sap = SheetData(headers, [
        row('ok', '2', '10'),
        row('diff', '2', '11'),
        row('dup', '2', '10'),
        row('extra', '2', '10'),
      ], false);
      final result = PmsSapComparison.compare(pms, sap);
      expect(result.where((r) => r.status == 'normal').length, 1);
      expect(result.where((r) => r.status == 'waiting').single.number, 'wait');
      expect(
        result.where((r) => r.result == 'ข้อมูลไม่ตรงกัน').single.number,
        'diff',
      );
      expect(result.where((r) => r.result == 'เลขที่เอกสารซ้ำ').length, 2);
      expect(
        result.where((r) => r.result == 'ไม่พบใน PMS').single.number,
        'extra',
      );
      expect(PmsSapComparison.export(result), isNotEmpty);
    },
  );
  test(
    'date filter uses PMS and does not treat an out-of-range match as SAP only',
    () {
      final pms = SheetData(headers, [row('outside', '2', '1')], false);
      final sap = SheetData(headers, [
        row('outside', '2', '1'),
        row('only', '2', '1'),
      ], false);
      final result = PmsSapComparison.compare(pms, sap, from: DateTime(2030));
      expect(result.map((r) => r.number), ['only']);
    },
  );
  test(
    'compares equivalent date and number values and skips missing SAP columns',
    () {
      final a = row('same', '2', '1,000.00');
      final b = row('same', '2', '1000');
      final date = DateTime.utc(1899, 12, 30).add(const Duration(days: 46296));
      b[2] =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      final sapHeaders = List<String>.from(headers)..[9] = '';
      b[9] = 'different';
      expect(
        PmsSapComparison.compare(
          SheetData(headers, [a], false),
          SheetData(sapHeaders, [b], false),
        ).single.status,
        'normal',
      );
    },
  );
  test('export creates a readable worksheet and escapes user data', () {
    final bytes = PmsSapComparison.export([
      const ComparisonRow(
        status: 'problem',
        number: '<x>&',
        date: '-',
        pmsStatus: '2',
        result: 'แตกต่าง',
        details: 'detail',
      ),
    ]);
    final zip = ZipDecoder().decodeBytes(bytes);
    final file = zip.findFile('xl/worksheets/sheet1.xml');
    expect(file, isNotNull);
    final xml = XmlDocument.parse(utf8.decode(file!.content as List<int>));
    expect(xml.innerText, contains('<x>&'));
  });
  test(
    'finds key, date and status by PMS header when columns move together',
    () {
      final reordered = [
        'วันที่เอกสาร',
        'เลขที่เอกสาร',
        'PmsStatus',
        'จำนวนเงิน',
      ];
      final pms = SheetData(reordered, [
        ['46296', 'X-1', '2', '100'],
      ], false);
      final sap = SheetData(reordered, [
        ['46296', 'X-1', '2', '100'],
      ], false);
      expect(PmsSapComparison.compare(pms, sap).single.status, 'normal');
    },
  );
  test('retains meaningful leading zeros in text values', () {
    final a = row('same', '2', '001');
    final b = row('same', '2', '1');
    expect(
      PmsSapComparison.compare(
        SheetData(headers, [a], false),
        SheetData(headers, [b], false),
      ).single.status,
      'problem',
    );
  });
}
