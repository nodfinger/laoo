import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/theme/laoo_design_tokens.dart';
import 'package:laoo_evaluation/features/evaluation/evaluation_feature_host.dart';
import 'package:laoo_evaluation/features/evaluation/evaluation_list_page.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

void main() {
  testWidgets('47007 mobile report recovers from API error and pages', (
    tester,
  ) async {
    final api = _ReportApi();
    configureEvaluationFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => child,
      apiClientFactory: () => api,
      apiClientDisposer: (_) {},
      errorText: (_) => 'กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
      dateTimeText: (value) => value.toIso8601String(),
      menuTitleResolver: (_, fallback) async => fallback,
      messagePresenter: (_, {required message, required error}) {},
      uiTokensProvider: () => const EvaluationUiTokens(
        contentMargin: EdgeInsets.all(10),
        cardPadding: EdgeInsets.all(10),
        sectionSpacing: 6,
        itemSpacing: 6,
        radius: 4,
        popupHeaderMinHeight: 48,
        popupFieldSpacing: 16,
        buttonHeight: 48,
        paginationCardHeight: LaooLayout.paginationCardHeight,
        compactBreakpoint: 900,
        captionStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        sectionStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        inputStyle: TextStyle(fontSize: 14),
        buttonStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        primaryColor: Color(0xFF168364),
        borderColor: Color(0xFFE4EAE6),
        backgroundColor: Color(0xFFF8F9FB),
        popupSurfaceColor: Color(0xFFFFFFFF),
        dangerColor: Color(0xFFD94A4A),
        dangerSurfaceColor: Color(0x14D94A4A),
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EvaluationListPage(
            menu: '47007',
            title: 'รายงานการประเมิน',
            path: '/api/company/evaluations/reports-filtered',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('รายละเอียดเพิ่มเติม'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    expect(api.calls, 1);

    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(find.text('ลองอีกครั้ง'), findsNothing);
    expect(find.text('RUN-18'), findsOneWidget);
    expect(find.text('1-10 จาก 11'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(api.lastQuery?['page'], '2');
    expect(find.text('RUN-19'), findsOneWidget);
    expect(find.text('11-11 จาก 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ReportApi implements JsonApiClient {
  int calls = 0;
  Map<String, String>? lastQuery;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path != '/api/company/evaluations/reports-filtered') {
      throw StateError('Unexpected path: $path');
    }
    calls++;
    lastQuery = query;
    if (calls == 1) throw StateError('temporary offline');
    final secondPage = query?['page'] == '2';
    return {
      'page': secondPage ? 2 : 1,
      'total': 11,
      'items': [
        {
          'id': secondPage ? 19 : 18,
          'roundNo': secondPage ? 'RUN-19' : 'RUN-18',
          'sourceType': 'GENERAL',
          'status': 'CLOSED',
        },
      ],
    };
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => throw UnimplementedError();

  @override
  Future<dynamic> put(String path, {Object? body, bool authenticated = true}) =>
      throw UnimplementedError();

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) => throw UnimplementedError();
}
