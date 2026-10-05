import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/features/company/customer/services/customer_shipping_label_pdf_service.dart';
import 'package:laoo_service/features/company/customer/widgets/customer_shipping_label_dialog.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const customer = <String, dynamic>{
    'customerID': 1,
    'cusCode': 'CUST-001',
    'cusName': 'บริษัทลูกค้าตัวอย่าง จำกัด',
    'shippingLabelName': 'คุณมนต์ ฝ่ายจัดซื้อ',
    'shippingLabelAddress':
        '99/9 ถนนตัวอย่าง แขวงตัวอย่าง เขตตัวอย่าง กรุงเทพมหานคร 10110',
    'shippingLabelPhone': '02-123-4567',
  };

  test('shipping label uses a 10 cm wide page', () {
    expect(
      CustomerShippingLabelPdfService.pageFormat.width,
      closeTo(100 * PdfPageFormat.mm, 0.001),
    );
    expect(
      CustomerShippingLabelPdfService.pageFormat.height,
      closeTo(150 * PdfPageFormat.mm, 0.001),
    );
  });

  test('builds a Thai shipping-label PDF', () async {
    final bytes = await CustomerShippingLabelPdfService.build(
      customer: customer,
      accent: Colors.teal,
    );

    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  testWidgets('shipping-label popup fits a compact viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomerShippingLabelDialog(
            customer: customer,
            accent: Colors.teal,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ข้อมูลลูกค้า > พิมพ์ใบปะหน้า'), findsOneWidget);
    expect(find.text('คุณมนต์ ฝ่ายจัดซื้อ'), findsOneWidget);
    expect(find.text('02-123-4567'), findsOneWidget);
    expect(find.text('พิมพ์'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
