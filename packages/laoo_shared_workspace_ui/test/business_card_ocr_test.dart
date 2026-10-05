import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

const tokens = LaooWorkspaceUiTokens(
  contentMargin: EdgeInsets.all(10),
  cardPadding: EdgeInsets.all(10),
  sectionSpacing: 10,
  captionFilterSpacing: 6,
  itemSpacing: 6,
  radius: 4,
  compactBreakpoint: 900,
  paginationHeight: 56,
  captionStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  sectionStyle: TextStyle(fontSize: 16),
  inputStyle: TextStyle(fontSize: 14),
  tableStyle: TextStyle(fontSize: 14),
  buttonStyle: TextStyle(fontSize: 13),
  buttonHeight: 48,
  primaryColor: Colors.teal,
  borderColor: Colors.grey,
  backgroundColor: Color(0xfff8f9fb),
);

void main() {
  test('customer contact slot 2 never overwrites slot 1 or company phone', () {
    const result = BusinessCardImport(
      values: {
        'company': 'บริษัท ทดสอบ จำกัด',
        'name': 'สมชาย ใจดี',
        'phone': '0812345678',
        'email': 'demo@example.test',
        'line': '@unsupported',
        'address': 'กรุงเทพมหานคร',
      },
      images: [],
      contactSlot: 2,
    );
    expect(result.forCustomer(), {
      'cusName': 'บริษัท ทดสอบ จำกัด',
      'cusAddress': 'กรุงเทพมหานคร',
      'contName2': 'สมชาย ใจดี',
      'phone2': '0812345678',
      'email2': 'demo@example.test',
    });
  });
  test('empty and unsupported fields never erase destination values', () {
    const result = BusinessCardImport(
      values: {'name': ' ', 'line': 'demo'},
      images: [],
    );
    expect(result.forCustomer(), isEmpty);
    expect(result.forVisitor(), isEmpty);
  });
  test('Visitor imports only name and telephone, not identity card', () {
    const result = BusinessCardImport(
      values: {
        'name': 'สมชาย',
        'phone': '0812345678',
        'company': 'ทดสอบ',
        'nationalId': '123',
      },
      images: [],
    );
    expect(result.forVisitor(), {'name': 'สมชาย', 'phone': '0812345678'});
  });
  for (final width in [1440.0, 1024.0, 768.0, 430.0, 360.0]) {
    testWidgets('initial screen no overflow at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessCardOcrPage(
            tokens: tokens,
            target: 'customers',
            maxImageSizeMB: 10,
            engineAvailable: false,
            get: (_, query) async => [],
            upload: (_, Uint8List bytes, name, fields) async => {},
            notify: (_, message, error) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('นำเข้าแบบฟอร์ม'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'นำเข้าแบบฟอร์ม'),
            )
            .onPressed,
        isNull,
      );
    });
  }
  testWidgets('denied capability hides OCR action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessCardOcrButton(
            tokens: tokens,
            target: 'customers',
            get: (_, query) async => throw StateError('403'),
            upload: (_, bytes, name, fields) async => {},
            notify: (_, message, error) {},
            onImported: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('อ่านนามบัตร'), findsNothing);
  });
  testWidgets('cancel overwrite keeps old form unchanged', (tester) async {
    bool? accepted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                accepted = await confirmBusinessCardChanges(
                  context,
                  tokens,
                  {'name': 'ชื่อเดิม'},
                  {'name': 'ชื่อใหม่'},
                  {'name': 'ชื่อผู้ติดต่อ'},
                );
              },
              child: const Text('เปิด'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(accepted, isFalse);
  });
}
