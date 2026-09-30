import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_time/time_feature.dart';

void main() {
  testWidgets(
    '25002 distinguishes API failure from empty results and retries on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _RetryResultsApi();
      configureTimeFeatureHost(
        ({required pageTitle, required activeMenu, required child}) =>
            MaterialApp(home: Scaffold(body: child)),
        apiClientFactory: () => api,
        apiClientDisposer: (_) {},
        errorText: (error) => 'ระบบขัดข้องชั่วคราว',
        uiTokens: TimeUiTokens(
          contentMargin: const EdgeInsets.all(16),
          cardPadding: const EdgeInsets.all(12),
          cardSpacing: 6,
          itemSpacing: 6,
          radius: 8,
          compactBreakpoint: 700,
          paginationHeight: 56,
          captionStyle: const TextStyle(fontSize: 20),
          sectionStyle: const TextStyle(fontSize: 16),
          inputStyle: const TextStyle(fontSize: 14),
          inputLabelStyle: const TextStyle(fontSize: 16),
          tableStyle: const TextStyle(fontSize: 14),
          buttonStyle: const TextStyle(fontSize: 14),
          buttonHeight: 40,
          primaryColor: Colors.green,
          borderColor: Colors.grey,
          backgroundColor: Colors.white,
          businessDate: DateTime(2026, 9, 29),
        ),
      );

      await tester.pumpWidget(const AttendanceResultsPage());
      await tester.pumpAndSettle();
      expect(find.text('โหลดผลการลงเวลาไม่สำเร็จ'), findsOneWidget);
      expect(find.textContaining('ระบบขัดข้องชั่วคราว'), findsOneWidget);
      expect(find.text('ไม่พบข้อมูล'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('ลองอีกครั้ง'));
      await tester.pumpAndSettle();
      expect(api.listCalls, 2);
      expect(find.text('โหลดผลการลงเวลาไม่สำเร็จ'), findsNothing);
      expect(find.textContaining('TEST-25002'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _RetryResultsApi implements JsonApiClient {
  int listCalls = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path == '/api/user-favorites') return <dynamic>[];
    if (path.endsWith('/actions')) {
      return {
        'menuCode': '25002',
        'caption': 'ผลการลงเวลารายวัน',
        'screenType': 3,
        'view': true,
      };
    }
    if (path == '/api/time/attendance/results') {
      listCalls++;
      if (listCalls == 1) throw StateError('temporary error');
      return {
        'total': 1,
        'page': 1,
        'pageSize': 30,
        'items': [
          {
            'workDate': '2026-09-29',
            'employeeCode': 'TEST-25002',
            'fullName': 'ผู้ทดสอบ',
            'statusCode': 'COMPLETE',
            'scheduledWorkMinutes': 480,
            'actualWorkMinutes': 480,
            'lateMinutes': 0,
            'earlyMinutes': 0,
          },
        ],
      };
    }
    throw StateError('Unexpected GET: $path');
  }

  @override
  Future<void> post(String path, {Object? body, bool authenticated = true}) =>
      throw UnimplementedError();
  @override
  Future<void> put(String path, {Object? body, bool authenticated = true}) =>
      throw UnimplementedError();
  @override
  Future<void> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) => throw UnimplementedError();
}
