import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'package:laoo_training/features/masters/training_test_template_placeholder_page.dart';
import 'package:laoo_training/features/training/training_feature_host.dart';

void main() {
  testWidgets('retry reloads training template actions and list', (
    tester,
  ) async {
    final api = _RetryTrainingApi();
    configureTrainingFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => child,
      apiClientFactory: () => api,
      apiClientDisposer: (_) {},
      errorText: (_) => 'โหลดสิทธิ์ไม่สำเร็จ',
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

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TrainingTestTemplatePlaceholderPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    expect(find.text('เพิ่ม'), findsNothing);

    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.actionCalls, 2);
    expect(api.listCalls, 1);
    expect(find.text('ลองอีกครั้ง'), findsNothing);
    expect(find.text('เพิ่ม'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _RetryTrainingApi implements JsonApiClient {
  int actionCalls = 0;
  int listCalls = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions')) {
      actionCalls++;
      if (actionCalls == 1) throw StateError('temporary failure');
      return {'caption': 'ชุดแบบทดสอบอบรม', 'screenType': 1, 'create': true};
    }
    if (path == '/api/company/training/test-templates') {
      listCalls++;
      return {'page': 1, 'total': 0, 'items': <Object>[]};
    }
    throw StateError('unexpected GET path: $path');
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
