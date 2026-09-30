import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'package:laoo_training/features/masters/training_test_template_placeholder_page.dart';
import 'package:laoo_training/features/training/training_feature_host.dart';

void main() {
  void configure(_TemplateApi api) {
    configureTrainingFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => child,
      apiClientFactory: () => api,
      apiClientDisposer: (_) {},
      errorText: (error) => error.toString(),
      messageBuilder: ({required message, required error, required onClose}) =>
          const SizedBox.shrink(),
      pageSizeProvider: () => 10,
      uiTokensProvider: () => const TrainingUiTokens(
        workspace: LaooWorkspaceUiTokens(
          contentMargin: EdgeInsets.all(10),
          cardPadding: EdgeInsets.all(10),
          sectionSpacing: 6,
          captionFilterSpacing: 6,
          itemSpacing: 6,
          radius: 4,
          compactBreakpoint: 900,
          paginationHeight: 56,
          captionStyle: TextStyle(fontSize: 18),
          sectionStyle: TextStyle(fontSize: 16),
          inputStyle: TextStyle(fontSize: 14),
          tableStyle: TextStyle(fontSize: 14),
          buttonStyle: TextStyle(fontSize: 13),
          buttonHeight: 48,
          primaryColor: Color(0xFF168364),
          borderColor: Color(0xFFE4EAE6),
          backgroundColor: Color(0xFFF8F9FB),
        ),
        primaryColor: Color(0xFF168364),
        borderColor: Color(0xFFE4EAE6),
        popupFieldSpacing: 16,
        popupHeaderMinHeight: 48,
        paginationButtonSize: 34,
        dialogInsetPadding: 20,
      ),
    );
  }

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TrainingTestTemplatePlaceholderPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    '37003 create popup validates question and stays open after save',
    (tester) async {
      final api = _TemplateApi();
      configure(api);
      await openPage(tester);

      await tester.tap(find.text('เพิ่ม'));
      await tester.pumpAndSettle();
      expect(find.text('ชุดแบบทดสอบอบรม > เพิ่ม'), findsOneWidget);
      expect(
        tester.widget<Dialog>(find.byType(Dialog).first).backgroundColor,
        Colors.white,
      );
      await tester.tap(find.text('บันทึก').hitTestable().last);
      await tester.pumpAndSettle();
      expect(api.postCalls, 0);
      expect(find.text('ระบุจำนวน 1-0 ข้อ'), findsOneWidget);

      await tester.ensureVisible(find.text('ประเภทข้อสอบ *'));
      await tester.tap(find.text('4 ตัวเลือก').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ถูก / ผิด').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('เพิ่มข้อสอบ'));
      await tester.tap(find.text('เพิ่มข้อสอบ'));
      await tester.pumpAndSettle();
      expect(find.text('ชุดแบบทดสอบอบรม > ข้อสอบ > เพิ่ม'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'คำถาม'),
        'ข้อทดสอบ?',
      );
      await tester.tap(find.text('บันทึกข้อสอบ').hitTestable());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'ชื่อชุดแบบทดสอบ *'),
        'ชุดทดสอบ UX',
      );
      await tester.tap(find.text('บันทึก').hitTestable().last);
      await tester.pumpAndSettle();
      expect(api.postCalls, 1);
      expect(api.lastPost?['name'], 'ชุดทดสอบ UX');
      expect(find.text('ชุดแบบทดสอบอบรม > เพิ่ม'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'ชื่อชุดแบบทดสอบ *'),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('37003 mobile edit sends rowVersion and closes popup', (
    tester,
  ) async {
    final api = _TemplateApi()..withItem = true;
    configure(api);
    await openPage(tester);

    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.text('ชุดแบบทดสอบอบรม > แก้ไข'), findsOneWidget);
    await tester.tap(find.text('บันทึก').hitTestable().last);
    await tester.pumpAndSettle();
    expect(api.putCalls, 1);
    expect(api.lastPut?['rowVersion'], 'AQIDBAUGBwg=');
    expect(find.text('ชุดแบบทดสอบอบรม > แก้ไข'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('37003 VIEW-only login has no mutation actions', (tester) async {
    final api = _TemplateApi()
      ..withItem = true
      ..allowMutations = false;
    configure(api);
    await openPage(tester);
    expect(find.text('แบบทดสอบเดิม'), findsOneWidget);
    expect(find.text('เพิ่ม'), findsNothing);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
    expect(api.postCalls, 0);
    expect(api.putCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('37003 non-CRUD ScreenType hides actions even with permissions', (
    tester,
  ) async {
    final api = _TemplateApi()
      ..withItem = true
      ..screenType = 3;
    configure(api);
    await openPage(tester);
    expect(find.text('แบบทดสอบเดิม'), findsOneWidget);
    expect(find.text('เพิ่ม'), findsNothing);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _TemplateApi implements JsonApiClient {
  bool withItem = false;
  bool allowMutations = true;
  int screenType = 1;
  int postCalls = 0;
  int putCalls = 0;
  Map<String, dynamic>? lastPost;
  Map<String, dynamic>? lastPut;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions')) {
      return {
        'caption': 'ชุดแบบทดสอบอบรม',
        'screenType': screenType,
        'create': allowMutations,
        'edit': allowMutations,
        'delete': allowMutations,
      };
    }
    if (path == '/api/company/training/test-templates') {
      return {
        'page': 1,
        'total': withItem ? 1 : 0,
        'items': withItem
            ? [
                {
                  'id': 99,
                  'code': 'QA99',
                  'name': 'แบบทดสอบเดิม',
                  'section': 'PRE',
                  'questionCount': 1,
                  'passingPercent': 60,
                  'bankCount': 1,
                  'versionNo': 1,
                  'isActive': true,
                  'rowVersion': 'AQIDBAUGBwg=',
                },
              ]
            : <Object>[],
      };
    }
    if (path.endsWith('/99')) {
      return {
        'id': 99,
        'code': 'QA99',
        'name': 'แบบทดสอบเดิม',
        'section': 'PRE',
        'isActive': true,
        'rowVersion': 'AQIDBAUGBwg=',
        'definition': {
          'questionType': 'TRUE_FALSE',
          'questionCount': 1,
          'passingPercent': 60,
          'questions': [
            {
              'id': '00000000-0000-4000-8000-000000000001',
              'text': 'คำถามเดิม',
              'options': [
                {
                  'id': '00000000-0000-4000-8000-000000000011',
                  'text': 'ถูก',
                  'isCorrect': true,
                },
                {
                  'id': '00000000-0000-4000-8000-000000000012',
                  'text': 'ผิด',
                  'isCorrect': false,
                },
              ],
            },
          ],
        },
      };
    }
    throw StateError('unexpected GET: $path');
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    postCalls++;
    lastPost = Map<String, dynamic>.from(body! as Map);
    return {'id': 100};
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    putCalls++;
    lastPut = Map<String, dynamic>.from(body! as Map);
    return {'id': 99};
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) => throw UnimplementedError();
}
