import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_gate_pass/features/gate_pass/gate_pass_print.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('สร้าง PDF A4 จากข้อมูลและรูปแนบหลายรายการ', () async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAALSURBVBhXY2BABwAAEgABp3qZbgAAAABJRU5ErkJggg==';
    final document = <String, dynamic>{
      'number': 'GP-001',
      'companyName': 'บริษัทตัวอย่าง',
      'status': 'DRAFT',
      'documentDateTime': '2026-11-15T09:00:00',
      'plannedExitDate': '2026-11-15',
      'purpose': 'ซ่อมแซม',
      'carrier': 'ผู้รับมอบ',
      'destination': 'โรงงาน',
      'items': [
        {
          'id': 1,
          'name': 'เครื่องพิมพ์',
          'quantity': 1,
          'unit': 'เครื่อง',
          'isReturnRequired': true,
          'expectedReturnDate': '2026-11-20',
        },
      ],
      'files': [
        for (var i = 0; i < 12; i++)
          {'itemId': i < 6 ? null : 1, 'fileName': 'image$i.png', 'image': png},
      ],
    };
    final bytes = await buildGatePassPdf(
      document,
      {'requesterName': 'ผู้ขอ', 'departmentName': 'ไอที'},
      [],
      'BE',
    );
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
