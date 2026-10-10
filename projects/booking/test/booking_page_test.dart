import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_booking/src/booking_host.dart';
import 'package:laoo_booking/src/booking_page.dart';
import 'package:laoo_booking/src/booking_forms.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

const tokens = LaooWorkspaceUiTokens(
  contentMargin: EdgeInsets.all(10),
  cardPadding: EdgeInsets.all(10),
  sectionSpacing: 8,
  captionFilterSpacing: 8,
  itemSpacing: 8,
  radius: 4,
  compactBreakpoint: 900,
  paginationHeight: 54,
  captionStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  sectionStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  inputStyle: TextStyle(fontSize: 14),
  tableStyle: TextStyle(fontSize: 14),
  buttonStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  buttonHeight: 48,
  primaryColor: Color(0xFF12805F),
  borderColor: Color(0xFFE2E8E5),
  backgroundColor: Color(0xFFF7F9F8),
);

class FakeBookingApi implements JsonApiClient {
  FakeBookingApi(this.create);
  final bool create;
  Object? lastPostBody;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions/61002')) {
      return {
        'metadata': {
          'MenuName': 'ประเภทบริการ',
          'ScreenType': 1,
          'IconName': 'event_available',
        },
        'actions': {
          'view': true,
          'create': create,
          'edit': false,
          'delete': false,
        },
      };
    }
    if (path.endsWith('/services')) {
      return [
        {
          'id': 1,
          'code': 'ELEC',
          'name': 'ตรวจระบบไฟฟ้าและกล้องวงจรปิดภายในอาคาร',
          'durationMinutes': 60,
          'price': 450.0,
          'active': true,
        },
      ];
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    lastPostBody = body;
    return {'id': 42};
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => null;
  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async => null;
}

class FakeUsageApi extends FakeBookingApi {
  FakeUsageApi() : super(false);
  String? lastPostPath;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions/61008')) {
      return {
        'metadata': {'MenuName': 'บันทึกใช้บริการและขาย', 'ScreenType': 4},
        'actions': {'view': true, 'sale': true},
      };
    }
    if (path.endsWith('/options/61008')) return <String, dynamic>{};
    if (path.endsWith('/bookings')) {
      return [
        {
          'id': 12,
          'number': 'BK-TEST-12',
          'name': 'ลูกค้าทดสอบ',
          'startsAt': DateTime.now().toIso8601String(),
          'status': 'BOOKED',
          'amount': 300.0,
        },
      ];
    }
    if (path == '/api/company/pos/sales') {
      return [
        {
          'id': 77,
          'receipt': 'POS-TEST-77',
          'branch': 'สาขาทดสอบ',
          'net': 10.70,
          'status': 'COMPLETED',
        },
        {
          'id': 78,
          'receipt': 'POS-CANCELLED-78',
          'branch': 'สาขาทดสอบ',
          'net': 20.0,
          'status': 'CANCELLED',
        },
      ];
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    lastPostPath = path;
    lastPostBody = body;
    return null;
  }
}

void main() {
  testWidgets('sale picker links a completed receipt, not a cancelled sale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = FakeUsageApi();
    configureBookingFeatureHost(
      shell: ({required pageTitle, required activeMenu, required child}) =>
          child,
      api: () => api,
      dispose: (_) {},
      tokens: () => tokens,
      menuIcon: (_) => Icons.point_of_sale_outlined,
      errorText: (error, action) => '$action: $error',
      message: (_, {required message, required error}) {},
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BookingPage(menuCode: '61008')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('เชื่อมใบขาย POS'));
    await tester.pumpAndSettle();
    expect(find.text('ใบขาย POS *'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.textContaining('POS-CANCELLED-78'), findsNothing);
    await tester.tap(find.textContaining('POS-TEST-77').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('เชื่อมใบขาย'));
    await tester.pumpAndSettle();
    expect(api.lastPostPath, '/api/company/booking/bookings/12/sales');
    expect((api.lastPostBody as Map<String, dynamic>)['saleId'], 77);
    expect(tester.takeException(), isNull);
  });
  testWidgets('booking popup submits two distinct services for a guest', (
    tester,
  ) async {
    final api = FakeBookingApi(true);
    configureBookingFeatureHost(
      shell: ({required pageTitle, required activeMenu, required child}) =>
          child,
      api: () => api,
      dispose: (_) {},
      tokens: () => tokens,
      menuIcon: (_) => Icons.event_available_outlined,
      errorText: (error, action) => '$action: $error',
      message: (_, {required message, required error}) {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => BookingForm(
                  code: '61007',
                  title: 'รายการจอง',
                  row: null,
                  options: const {
                    'members': [],
                    'branches': [],
                    'providers': [],
                    'resources': [],
                    'services': [
                      {
                        'id': 1,
                        'name': 'อาบน้ำตัดขน',
                        'price': 300,
                        'requiresProvider': false,
                        'requiresResource': false,
                      },
                      {
                        'id': 2,
                        'name': 'รับส่งสัตว์เลี้ยง',
                        'price': 150,
                        'requiresProvider': false,
                        'requiresResource': false,
                      },
                    ],
                  },
                  settings: const {},
                  api: api,
                  tokens: tokens,
                  icon: Icons.event_available_outlined,
                ),
              ),
              child: const Text('เปิดฟอร์ม'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิดฟอร์ม'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'ลูกค้าทั่วไป');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('อาบน้ำตัดขน — 300'));
    await tester.tap(find.text('อาบน้ำตัดขน — 300'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('รับส่งสัตว์เลี้ยง — 150'));
    await tester.tap(find.text('รับส่งสัตว์เลี้ยง — 150'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('บันทึก'));
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    final body = api.lastPostBody as Map<String, dynamic>;
    expect(body['guestName'], 'ลูกค้าทั่วไป');
    expect((body['services'] as List).length, 2);
    expect(tester.takeException(), isNull);
  });
  for (final width in [360.0, 430.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('services list uses menu caption and fits $width px', (
      tester,
    ) async {
      final api = FakeBookingApi(false);
      configureBookingFeatureHost(
        shell: ({required pageTitle, required activeMenu, required child}) =>
            child,
        api: () => api,
        dispose: (_) {},
        tokens: () => tokens,
        menuIcon: (_) => Icons.event_available_outlined,
        errorText: (error, action) => '$action: $error',
        message: (_, {required message, required error}) {},
      );
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BookingPage(menuCode: '61002')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ประเภทบริการ'), findsOneWidget);
      expect(find.text('ELEC'), findsOneWidget);
      expect(find.text('เพิ่ม'), findsNothing);
      if (width < 900) {
        expect(find.byType(DataTable), findsNothing);
        expect(find.byType(LaooListCardToggle), findsNothing);
      } else {
        expect(find.byType(DataTable), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
