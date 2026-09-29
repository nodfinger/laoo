import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'package:laoo_training/features/masters/training_master_page.dart';
import 'package:laoo_training/features/training/training_feature_host.dart';

void main() {
  for (final instructors in [false, true]) {
    final code = instructors ? '37002' : '37001';
    testWidgets('$code mobile create validates and stays open after save', (
      tester,
    ) async {
      final api = _MasterApi(instructors: instructors);
      _configure(api);
      await _open(tester, instructors);
      await tester.tap(find.text('เพิ่ม'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
        Colors.white,
      );

      await tester.tap(find.text('บันทึก'));
      await tester.pumpAndSettle();
      expect(find.text('กรุณาระบุข้อมูล'), findsOneWidget);
      expect(api.postCalls, 0);

      final label = instructors ? 'ชื่อวิทยากร *' : 'ชื่อประเภทการอบรม *';
      await tester.enterText(
        find.widgetWithText(TextFormField, label),
        'ทดสอบฟอร์ม',
      );
      await tester.tap(find.text('บันทึก'));
      await tester.pumpAndSettle();
      expect(api.postCalls, 1);
      expect(api.lastPost?['name'], 'ทดสอบฟอร์ม');
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, label))
            .controller
            ?.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('37002 failed create keeps input for retry', (tester) async {
    final api = _MasterApi(instructors: true)..failNextPost = true;
    _configure(api);
    await _open(tester, true);
    await tester.tap(find.text('เพิ่ม'));
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextFormField, 'ชื่อวิทยากร *');
    await tester.enterText(field, 'วิทยากรทดสอบ');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.postCalls, 1);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      tester.widget<TextFormField>(field).controller?.text,
      'วิทยากรทดสอบ',
    );
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.postCalls, 2);
    expect(tester.widget<TextFormField>(field).controller?.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('37001 mobile edit sends rowVersion and closes after save', (
    tester,
  ) async {
    final api = _MasterApi(instructors: false)..withItem = true;
    _configure(api);
    await _open(tester, false);
    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.text('ประเภทการอบรม > แก้ไข'), findsOneWidget);
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.putCalls, 1);
    expect(api.lastPut?['rowVersion'], 'AQIDBAUGBwg=');
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _open(WidgetTester tester, bool instructors) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: instructors
            ? const TrainingMasterPage.instructors()
            : const TrainingMasterPage.types(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _configure(_MasterApi api) {
  configureTrainingFeatureHost(
    ({required pageTitle, required activeMenu, required child}) => child,
    apiClientFactory: () => api,
    apiClientDisposer: (_) {},
    errorText: (_) => 'บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง',
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

class _MasterApi implements JsonApiClient {
  _MasterApi({required this.instructors});
  final bool instructors;
  bool withItem = false;
  bool failNextPost = false;
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
    final expected = instructors
        ? '/api/company/training/instructors'
        : '/api/company/training/types';
    if (path == '$expected/actions') {
      return {
        'caption': instructors ? 'วิทยากร' : 'ประเภทการอบรม',
        'screenType': 1,
        'create': true,
        'edit': true,
        'delete': true,
      };
    }
    if (path == expected) {
      return {
        'page': 1,
        'total': withItem ? 1 : 0,
        'items': withItem
            ? [
                {
                  'id': 7,
                  'code': 'TRN007',
                  'name': 'ประเภทเดิม',
                  'isActive': true,
                  'rowVersion': 'AQIDBAUGBwg=',
                },
              ]
            : <Object>[],
      };
    }
    throw StateError('Unexpected GET');
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    postCalls++;
    if (failNextPost) {
      failNextPost = false;
      throw StateError('temporary failure');
    }
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
    return {'id': 7};
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) => throw UnimplementedError();
}
