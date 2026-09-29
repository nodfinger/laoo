import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'package:laoo_training/features/results/training_results_page.dart';
import 'package:laoo_training/features/training/training_feature_host.dart';

void main() {
  testWidgets('list error is not empty state and retry restores results', (
    tester,
  ) async {
    final api = _ResultsApi(failListOnce: true);
    _configure(api);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TrainingResultsPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('โหลดผลการอบรมไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ไม่พบผลการอบรม'), findsNothing);
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.listCalls, 2);
    expect(find.text('ดูผลการอบรม'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail retries section and evaluation separately on mobile', (
    tester,
  ) async {
    final api = _ResultsApi(failSectionOnce: true, failEvaluationOnce: true);
    _configure(api);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TrainingResultsPage())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ดูผลการอบรม'));
    await tester.pumpAndSettle();
    expect(find.text('โหลดผลสอบไม่สำเร็จ'), findsOneWidget);
    expect(find.text('โหลดรอบประเมินไม่สำเร็จ'), findsOneWidget);
    await tester.tap(find.text('ลองอีกครั้ง').first);
    await tester.pumpAndSettle();
    expect(api.evaluationCalls, 2);
    await tester.ensureVisible(find.text('ลองอีกครั้ง'));
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.sectionCalls, 2);
    expect(find.text('โหลดผลสอบไม่สำเร็จ'), findsNothing);
    expect(find.text('โหลดรอบประเมินไม่สำเร็จ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _configure(_ResultsApi api) {
  configureTrainingFeatureHost(
    ({required pageTitle, required activeMenu, required child}) => child,
    apiClientFactory: () => api,
    apiClientDisposer: (_) {},
    errorText: (error) => error.toString().replaceFirst('Bad state: ', ''),
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

class _ResultsApi implements JsonApiClient {
  _ResultsApi({
    this.failListOnce = false,
    this.failSectionOnce = false,
    this.failEvaluationOnce = false,
  });
  final bool failListOnce;
  final bool failSectionOnce;
  final bool failEvaluationOnce;
  int listCalls = 0;
  int sectionCalls = 0;
  int evaluationCalls = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path == '/api/company/training/results') {
      listCalls++;
      if (failListOnce && listCalls == 1) {
        throw StateError('โหลดผลการอบรมไม่สำเร็จ');
      }
      return {
        'total': 1,
        'items': [
          {
            'bookingId': 91,
            'bookingNo': 'BK91',
            'subject': 'อบรมทดสอบ',
            'roomCode': 'R1',
            'roomName': 'ห้อง 1',
            'invited': 1,
            'accepted': 1,
            'pending': 0,
          },
        ],
      };
    }
    if (path == '/api/company/training/results/91') {
      return {'bookingId': 91, 'bookingNo': 'BK91', 'subject': 'อบรมทดสอบ'};
    }
    if (path == '/api/company/training/results/91/PRE') {
      sectionCalls++;
      if (failSectionOnce && sectionCalls == 1) {
        throw StateError('โหลดผลสอบไม่สำเร็จ');
      }
      return {'eligible': 1, 'submitted': 0, 'items': <Object>[]};
    }
    if (path == '/api/company/training/results/91/evaluations') {
      evaluationCalls++;
      if (failEvaluationOnce && evaluationCalls == 1) {
        throw StateError('โหลดรอบประเมินไม่สำเร็จ');
      }
      return {'items': <Object>[]};
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
