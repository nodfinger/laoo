import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:laoo_service/features/company/tax_report/services/tax_report_pdf_service.dart';
import 'package:laoo_service/features/company/tax_report/services/tax_report_xlsx_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Thai monthly VAT PDF renders many rows', () async {
    final report = <String, dynamic>{
      'type': 'PURCHASE',
      'month': 10,
      'year': 2026,
      'companyName': 'บริษัททดสอบ จำกัด',
      'companyTaxId': '0100000000018',
      'branchId': 1,
      'branchName': 'สำนักงานใหญ่',
      'branchTaxCode': '00000',
      'summary': {'taxBase': 1000, 'taxAmount': 70, 'eligibleTaxAmount': 70},
      'rows': List.generate(
        80,
        (index) => {
          'invoiceDate': '2026-10-11',
          'invoiceCode': 'TEST-${index + 1}',
          'counterparty': 'ผู้ขายตัวอย่างภาษาไทย',
          'taxId': '0100000000018',
          'counterpartyTaxBranchCode': '00000',
          'taxBase': 100,
          'taxAmount': 7,
          'claimStatus': 'ELIGIBLE',
        },
      ),
    };
    final bytes = await TaxReportPdfService.buildReport(report, Colors.green);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('Excel workbook is valid ZIP with escaped Thai values', () {
    final report = <String, dynamic>{
      'type': 'SALE',
      'year': 2026,
      'month': 10,
      'companyName': 'บริษัท ก & ข',
      'companyTaxId': '0100000000018',
      'branchId': 1,
      'branchName': 'สำนักงานใหญ่',
      'branchTaxCode': '00000',
      'summary': {
        'taxBase': 100,
        'taxAmount': 7,
        'ratedTaxBase': 100,
        'zeroRatedTaxBase': 0,
      },
      'rows': [
        {
          'invoiceDate': '2026-10-11',
          'invoiceCode': 'T-1',
          'counterparty': '=DANGEROUS() & <ชื่อ>',
          'taxId': '0100000000018',
          'counterpartyTaxBranchCode': '00000',
          'taxBase': 100,
          'taxAmount': 7,
          'claimStatus': null,
          'receivedDate': null,
        },
      ],
    };
    final bytes = TaxReportXlsxService.build(report);
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = archive.files.map((f) => f.name).toSet();
    expect(
      files,
      containsAll([
        '[Content_Types].xml',
        'xl/workbook.xml',
        'xl/worksheets/sheet1.xml',
      ]),
    );
    final sheet = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
    );
    expect(sheet, contains('=DANGEROUS() &amp; &lt;ชื่อ&gt;'));
    expect(sheet, isNot(contains('<f>')));
    expect(sheet, contains('มูลค่ามีอัตราภาษี'));
    expect(sheet, contains('มูลค่าอัตรา 0%'));
    expect(sheet, contains('ยังไม่รวม POS, School Food, Rental'));
  });
}
