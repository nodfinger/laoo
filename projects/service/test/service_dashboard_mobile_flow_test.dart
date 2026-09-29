import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_service/features/service_dashboard/data/service_dashboard_api.dart';
import 'package:laoo_service/features/service_dashboard/pages/service_dashboard_page.dart';
import 'package:laoo_service/features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  setUpAll(() {
    configureServiceWorkspaceShell(
      ({
        required String pageTitle,
        required String activeMenu,
        required Widget child,
      }) => Scaffold(body: child),
    );
  });

  testWidgets('19001 mobile error retry and status links to 17002', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _DashboardApi();
    final router = GoRouter(
      initialLocation: '/reports/dashboard',
      routes: [
        GoRoute(
          path: '/reports/dashboard',
          builder: (_, _) => ServiceDashboardPage(api: api),
        ),
        GoRoute(
          path: '/jobs/work-orders',
          builder: (_, state) => Scaffold(
            body: Text('สถานะ ${state.uri.queryParameters['status']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('ไม่สามารถโหลดแดชบอร์ดงานบริการได้'),
      findsOneWidget,
    );
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    expect(find.text('ไม่มีงานบริการในช่วงวันที่ที่เลือก'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(find.text('กำลังดำเนินการ'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('กำลังดำเนินการ'));
    await tester.pumpAndSettle();
    expect(find.text('สถานะ IN_PROGRESS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DashboardApi extends ServiceDashboardApi {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> load(DateTime from, DateTime to) async {
    calls++;
    if (calls == 1) throw StateError('simulated dashboard outage');
    return {
      'statuses': [
        {'code': 'IN_PROGRESS', 'total': 2},
      ],
      'locations': [
        {'name': 'อาคารทดสอบ', 'total': 2},
      ],
      'technicians': [
        {'name': 'ช่างทดสอบ', 'total': 2},
      ],
    };
  }
}
