import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/theme/workspace_theme_presets.dart';
import 'package:laoo_evaluation/features/evaluation/evaluation_feature_host.dart';
import 'package:laoo_evaluation/features/evaluation/evaluation_list_page.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

void main() {
  testWidgets(
    '47002 cards inherit 4px borderless shapes from the shared theme',
    (tester) async {
      final api = _TemplateApi();
      configureEvaluationFeatureHost(
        ({required pageTitle, required activeMenu, required child}) => Theme(
          data: workspaceThemeController.value.toThemeData(),
          child: child,
        ),
        apiClientFactory: () => api,
        apiClientDisposer: (_) {},
        uiTokensProvider: () => const EvaluationUiTokens(
          contentMargin: EdgeInsets.all(10),
          cardPadding: EdgeInsets.all(10),
          sectionSpacing: 6,
          itemSpacing: 6,
          radius: 4,
          popupHeaderMinHeight: 48,
          popupFieldSpacing: 16,
          buttonHeight: 48,
          paginationCardHeight: 56,
          compactBreakpoint: 900,
          captionStyle: TextStyle(fontSize: 18),
          sectionStyle: TextStyle(fontSize: 16),
          inputStyle: TextStyle(fontSize: 14),
          buttonStyle: TextStyle(fontSize: 13),
          primaryColor: Color(0xFF168364),
          borderColor: Color(0xFFE4EAE6),
          backgroundColor: Color(0xFFF8F9FB),
          popupSurfaceColor: Colors.white,
          dangerColor: Color(0xFFD94A4A),
          dangerSurfaceColor: Color(0x14D94A4A),
        ),
        errorText: (_) => 'โหลดไม่สำเร็จ',
        dateTimeText: (value) => value.toIso8601String(),
        menuTitleResolver: (_, fallback) async => fallback,
      );

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1;

      Future<void> verifyAt(Size size) async {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EvaluationListPage(
                menu: '47002',
                title: 'แบบประเมิน',
                path: '/api/company/evaluations/templates',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('แบบประเมิน'), findsOneWidget);
        expect(find.text('แบบประเมินตัวอย่าง'), findsOneWidget);
        final cards = find.byType(Card);
        expect(cards, findsWidgets);
        for (final element in cards.evaluate()) {
          final shape =
              Theme.of(element).cardTheme.shape as RoundedRectangleBorder;
          expect(shape.borderRadius, BorderRadius.circular(4));
          expect(shape.side, BorderSide.none);
        }
        expect(tester.takeException(), isNull);
      }

      await verifyAt(const Size(1366, 768));
      await verifyAt(const Size(700, 768));
    },
  );
}

class _TemplateApi implements JsonApiClient {
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async => {
    'items': [
      {
        'id': 1,
        'code': 'DEMO-EVAL',
        'name': 'แบบประเมินตัวอย่าง',
        'sourceType': 'GENERAL',
      },
    ],
    'permissions': {'create': true, 'edit': true, 'delete': true},
  };

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {}

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {}

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {}
}
