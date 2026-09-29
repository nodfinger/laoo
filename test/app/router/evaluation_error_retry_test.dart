import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/theme/laoo_design_tokens.dart';
import 'package:laoo_evaluation/features/evaluation/evaluation_feature_host.dart';
import 'package:laoo_evaluation/features/evaluation/evaluation_response_dialog.dart';
import 'package:laoo_evaluation/features/evaluation/evaluation_results_dialog.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

void main() {
  late _FailingEvaluationApi api;

  setUp(() {
    api = _FailingEvaluationApi();
    configureEvaluationFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => child,
      apiClientFactory: () => api,
      apiClientDisposer: (_) {},
      errorText: (_) => 'ไม่สามารถโหลดข้อมูลได้',
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
  });

  testWidgets('results popup explains load failure and retries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EvaluationResultsDialog(roundId: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('รายละเอียดเพิ่มเติม'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    expect(api.getCount, 1);
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.getCount, 2);
  });

  testWidgets('response popup explains load failure and retries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EvaluationResponseDialog(roundId: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('รายละเอียดเพิ่มเติม'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    expect(api.getCount, 1);
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.getCount, 2);
  });
}

class _FailingEvaluationApi implements JsonApiClient {
  int getCount = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    getCount++;
    throw StateError('offline');
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => throw UnimplementedError();

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => throw UnimplementedError();

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async => throw UnimplementedError();
}
