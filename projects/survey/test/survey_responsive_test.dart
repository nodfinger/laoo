import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'package:laoo_survey/features/survey/survey_feature_host.dart';
import 'package:laoo_survey/features/survey/survey_pages.dart';

void main() {
  const tokens = LaooWorkspaceUiTokens(
    contentMargin: EdgeInsets.all(12),
    cardPadding: EdgeInsets.all(16),
    sectionSpacing: 6,
    captionFilterSpacing: 6,
    itemSpacing: 6,
    radius: 4,
    compactBreakpoint: 900,
    paginationHeight: 56,
    captionStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    sectionStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    inputStyle: TextStyle(fontSize: 14),
    tableStyle: TextStyle(fontSize: 14),
    buttonStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    buttonHeight: 40,
    primaryColor: Color(0xFF087F5B),
    borderColor: Color(0xFFD8DEE4),
    backgroundColor: Color(0xFFF4F6F8),
  );

  setUp(() {
    configureSurveyFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => child,
      apiClientFactory: _SurveyFakeApi.new,
      uiTokensProvider: () => tokens,
      menuTitleResolver: (_, fallback) async => fallback,
      messagePresenter: (_, {required message, required error}) {},
    );
  });

  testWidgets('desktop list and document popup render without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 820);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        const SurveyPage(menuCode: '40002', title: 'แบบสอบถาม', endpoint: ''),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('แบบสอบถามตัวอย่าง'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่ม'));
    await tester.pumpAndSettle();
    expect(find.text('แบบสอบถาม > เพิ่ม'), findsOneWidget);
    expect(find.text('Header'), findsOneWidget);
    expect(find.textContaining('Detail'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/survey_document_desktop.png'),
    );
  });

  testWidgets('mobile list switches to cards without overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        const SurveyPage(menuCode: '40002', title: 'แบบสอบถาม', endpoint: ''),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('แบบสอบถามตัวอย่าง'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/survey_list_mobile.png'),
    );
  });
}

Widget _app(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F5B)),
    scaffoldBackgroundColor: const Color(0xFFF4F6F8),
  ),
  home: Scaffold(body: child),
);

class _SurveyFakeApi implements JsonApiClient {
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions/40002')) {
      return {
        'create': true,
        'edit': true,
        'delete': true,
        'submit': true,
        'cancel': true,
      };
    }
    if (path.endsWith('/options')) {
      return {
        'employees': [
          {
            'id': 10,
            'code': 'E001',
            'name': 'ผู้อนุมัติตัวอย่าง',
            'isCurrent': true,
          },
        ],
        'departments': [
          {'id': 1, 'code': 'D001', 'name': 'ฝ่ายตัวอย่าง'},
        ],
      };
    }
    if (path == '/api/company/surveys') {
      return [
        {
          'id': 1,
          'code': 'SV-DEMO',
          'name': 'แบบสอบถามตัวอย่าง',
          'openAt': '2026-09-30T08:00:00',
          'closeAt': '2026-10-14T17:00:00',
          'status': 'DRAFT',
          'audienceCount': 0,
        },
      ];
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => <String, dynamic>{};
  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => <String, dynamic>{};
  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async => null;
}
