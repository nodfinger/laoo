import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/company/contact/contact_api.dart';
import 'package:laoo/features/company/contact/contact_ocr_customer_selection.dart';

class FakeContactApi implements ContactApi {
  FakeContactApi(this.canCreate);
  final bool canCreate;
  @override
  Future<Map<String, dynamic>> lookups({
    String search = '',
    int? personId,
    int? customerId,
  }) async => {
    'customers': [
      {'id': 42, 'name': 'บริษัทตัวอย่าง'},
    ],
    'canCreateCustomer': canCreate,
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('supplier selection uses supplier labels and requires a name', (
    tester,
  ) async {
    final key = GlobalKey<ContactOcrCustomerSelectionState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactOcrCustomerSelection(
            key: key,
            api: FakeContactApi(true),
            supplier: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('เชื่อมผู้ขายเดิม'), findsOneWidget);
    await tester.tap(find.text('สร้างผู้ขายใหม่'));
    await tester.pumpAndSettle();
    expect(key.currentState!.validate({'name': 'ทดสอบ'}), contains('ผู้ขาย'));
    expect(
      key.currentState!.validate({
        'name': 'ทดสอบ',
        'company': 'บริษัทตัวอย่าง',
      }),
      isNull,
    );
  });
  testWidgets('customer creation needs a selected contact name and company', (
    tester,
  ) async {
    final key = GlobalKey<ContactOcrCustomerSelectionState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactOcrCustomerSelection(
            key: key,
            api: FakeContactApi(true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('สร้างลูกค้าใหม่'));
    await tester.pumpAndSettle();
    expect(key.currentState!.validate({}), contains('ชื่อผู้ติดต่อ'));
    expect(
      key.currentState!.validate({'name': 'ทดสอบ'}),
      contains('ชื่อบริษัท'),
    );
    expect(
      key.currentState!.validate({
        'name': 'ทดสอบ',
        'company': 'บริษัทตัวอย่าง',
      }),
      isNull,
    );
  });

  testWidgets('customer creation is unavailable without permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactOcrCustomerSelection(api: FakeContactApi(false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'สร้างลูกค้าใหม่'),
          )
          .onSelected,
      isNull,
    );
    expect(
      find.textContaining('ต้องมีสิทธิ์เพิ่มข้อมูลลูกค้า'),
      findsOneWidget,
    );
  });
}
