import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/visitor/visitor_slip_pdf_service.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a Thai visitor slip at exactly 50 mm wide', () async {
    final logoData = await rootBundle.load('assets/images/laoo_logo.png');
    final bytes = await VisitorSlipPdfService.build(
      companyLogo: Uint8List.sublistView(logoData),
      company: const {'companyName': 'บริษัท ทรีดีคอมเฮาส์ จำกัด'},
      visit: const {
        'visitorVisitId': 22,
        'visitorName': 'ผู้มาติดต่อ - ประวัติทดสอบ',
        'phone': '0812345678',
        'hostName': 'คนพัก-1',
        'hostRoom': 'อาคาร A ชั้น 2 ห้อง 304',
        'contactPointName': 'Door1',
        'visitPurpose': 'เข้าพบเพื่อติดต่อประสานงานและทดสอบข้อความยาว',
        'checkedInDate': '2026-09-26T05:46:35Z',
        'checkedOutDate': '2026-09-26T06:46:35Z',
        'statusCode': 'CHECKED_OUT',
      },
    );

    expect(
      VisitorSlipPdfService.pageFormat.width,
      closeTo(50 * PdfPageFormat.mm, .001),
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
