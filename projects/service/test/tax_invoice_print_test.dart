import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/core/api/api_client.dart';
import 'package:laoo_service/features/company/tax_invoice/data/tax_invoice_api.dart';
import 'package:laoo_service/features/company/tax_invoice/services/tax_invoice_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('print API sends explicit PREVIEW and FINAL modes', () async {
    final client = _RecordingClient();
    final api = TaxInvoiceApi(client: client);

    await api.printData(42, finalDocument: false);
    expect(client.path, '/api/company/tax-invoices/42/print-data');
    expect(client.query, {'mode': 'PREVIEW'});

    await api.printData(42, finalDocument: true);
    expect(client.query, {'mode': 'FINAL'});
  });

  test('final PDF defines four ordered business copies', () {
    expect(TaxInvoicePdfService.finalCopies, hasLength(4));
    expect(TaxInvoicePdfService.finalCopies[0].label, 'ต้นฉบับใบกำกับภาษี');
    expect(TaxInvoicePdfService.finalCopies[0].purpose, 'สำหรับลูกค้า');
    expect(TaxInvoicePdfService.finalCopies[1].purpose, 'สำหรับลูกค้า');
    expect(TaxInvoicePdfService.finalCopies[2].purpose, 'สำหรับบัญชี');
    expect(TaxInvoicePdfService.finalCopies[3].purpose, 'สำหรับจัดเก็บ');
  });

  test('builds one draft page and at least four final pages', () async {
    final data = <String, dynamic>{
      'company': {
        'companyName': 'บริษัท ทดสอบ จำกัด',
        'address': 'กรุงเทพมหานคร',
        'telephone': '021234567',
        'email': 'account@example.com',
        'taxId': '0100000000000',
      },
      'header': {
        'taxInvoiceCode': 'TI000001',
        'taxInvoiceDate': '2026-10-05',
        'dueDate': '2026-11-05',
        'customerCode': 'C001',
        'customerName': 'ลูกค้าทดสอบ',
        'customerAddress': 'ประเทศไทย',
        'customerTaxId': '0200000000000',
        'subtotal': 1000,
        'discountPercent': 0,
        'discountAmount': 0,
        'amountAfterDiscount': 1000,
        'taxPercent': 7,
        'taxAmount': 70,
        'netAmount': 1070,
        'remark': 'ข้อมูลทดสอบภาษาไทย',
      },
      'items': [
        {
          'lineNo': 1,
          'itemCode': 'ITEM-01',
          'itemName': 'สินค้าทดสอบ',
          'unitCode': 'PCS',
          'quantity': 1,
          'unitPrice': 1000,
          'discountAmount': 0,
          'amount': 1000,
        },
      ],
    };

    final preview = await TaxInvoicePdfService.build(
      data: data,
      finalDocument: false,
      accent: Colors.teal,
    );
    final finalPdf = await TaxInvoicePdfService.build(
      data: data,
      finalDocument: true,
      accent: Colors.teal,
    );

    expect(utf8.decode(preview.take(4).toList()), '%PDF');
    expect(utf8.decode(finalPdf.take(4).toList()), '%PDF');
    expect(_pageCount(preview), greaterThanOrEqualTo(1));
    expect(_pageCount(finalPdf), greaterThanOrEqualTo(4));
    expect(finalPdf.length, greaterThan(preview.length));
  });
}

int _pageCount(List<int> bytes) {
  final source = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Type\s*/Page(?!s)').allMatches(source).length;
}

class _RecordingClient extends ApiClient {
  String? path;
  Map<String, String>? query;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    this.path = path;
    this.query = query;
    return <String, dynamic>{};
  }
}
