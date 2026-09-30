import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/theme/laoo_design_tokens.dart';
import 'package:laoo_evaluation/features/evaluation/evaluation_feature_host.dart';
import 'package:laoo_evaluation/features/evaluation/evaluation_settings_page.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

void main() {
  testWidgets(
    '47001 is an update-only card screen without refresh CRUD actions',
    (tester) async {
      final api = _FakeEvaluationApi();
      configureEvaluationFeatureHost(
        ({required pageTitle, required activeMenu, required child}) => child,
        apiClientFactory: () => api,
        apiClientDisposer: (_) {},
        errorText: (_) => 'ทดสอบไม่สำเร็จ',
        dateTimeText: (value) => value.toIso8601String(),
        menuTitleResolver: (_, _) async => 'ตั้งค่าจาก Navigation',
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

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: EvaluationSettingsPage(title: 'ตั้งค่าระบบประเมิน'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ตั้งค่าจาก Navigation'), findsOneWidget);
      expect(find.text('หลักสูตรอบรม'), findsOneWidget);
      expect(find.text('วิทยากร'), findsOneWidget);
      expect(find.text('ห้องประชุม'), findsOneWidget);
      expect(find.text('บันทึก'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byType(Card), findsWidgets);
    },
  );
}

class _FakeEvaluationApi implements JsonApiClient {
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/settings')) {
      return {
        'items': [
          {
            'sourceType': 'TRAINING_COURSE',
            'templateId': 1,
            'templateName': 'ประเมินหลักสูตร',
            'isActive': true,
          },
        ],
        'permissions': {'edit': true},
      };
    }
    return {
      'items': [
        {'id': 1, 'code': 'DEFAULT', 'name': 'แบบประเมินเริ่มต้น'},
      ],
    };
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {}

  @override
  Future<dynamic> post(
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
