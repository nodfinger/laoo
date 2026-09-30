import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'package:laoo_training/features/tests/training_test_page.dart';
import 'package:laoo_training/features/training/training_feature_host.dart';

void main() {
  testWidgets('participant answers PRE questions and submits on mobile', (
    tester,
  ) async {
    final api = _ExamApi();
    _configure(api);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrainingTestPage(
            bookingId: 91,
            initialSection: 'PRE',
            examId: 41,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ก่อนอบรม'), findsNothing); // Deep link is section-locked.
    expect(find.text('ข้อ 1 จาก 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('ตัวเลือก ก'));
    await tester.tap(find.text('ยืนยันคำตอบและไปข้อถัดไป'));
    await tester.pumpAndSettle();
    expect(api.saved.length, 1);
    expect(api.saved.first['submit'], false);
    expect(find.text('ข้อ 2 จาก 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('ตัวเลือก ง'));
    await tester.tap(find.text('ยืนยันคำตอบและส่งข้อสอบ'));
    await tester.pumpAndSettle();
    expect(api.saved.length, 2);
    expect(api.saved.last['submit'], true);
    expect(api.saved.last['answers'], [
      {'questionId': 'q1', 'optionId': 'a'},
      {'questionId': 'q2', 'optionId': 'd'},
    ]);
    expect(find.textContaining('ผลการทดสอบ:'), findsOneWidget);
    expect(find.text('ยืนยันคำตอบและส่งข้อสอบ'), findsNothing);
    expect(api.attemptCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unanswered and closed-window exams cannot submit', (
    tester,
  ) async {
    final api = _ExamApi();
    _configure(api);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrainingTestPage(
            bookingId: 91,
            initialSection: 'PRE',
            examId: 41,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยืนยันคำตอบและไปข้อถัดไป'));
    await tester.pumpAndSettle();
    expect(api.saved, isEmpty);
    expect(find.text('ข้อ 1 จาก 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    api.canAnswer = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrainingTestPage(
            bookingId: 91,
            initialSection: 'PRE',
            examId: 41,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('อยู่นอกช่วงเวลาทำแบบทดสอบ'), findsOneWidget);
    await tester.tap(find.text('ยืนยันคำตอบและไปข้อถัดไป'));
    await tester.pumpAndSettle();
    expect(api.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

void _configure(_ExamApi api) {
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

class _ExamApi implements JsonApiClient {
  bool canAnswer = true;
  int attemptCalls = 0;
  final saved = <Map<String, dynamic>>[];
  bool submitted = false;

  Map<String, dynamic> get attempt => {
    'submitted': submitted,
    'canAnswer': canAnswer && !submitted,
    'score': submitted ? 2 : null,
    'maxScore': 2,
    'passed': submitted,
    'rowVersion': 'v1',
    'questions': [
      {
        'id': 'q1',
        'text': 'ข้อหนึ่ง',
        'options': [
          {'id': 'a', 'text': 'ตัวเลือก ก'},
          {'id': 'b', 'text': 'ตัวเลือก ข'},
        ],
      },
      {
        'id': 'q2',
        'text': 'ข้อสอง',
        'options': [
          {'id': 'c', 'text': 'ตัวเลือก ค'},
          {'id': 'd', 'text': 'ตัวเลือก ง'},
        ],
      },
    ],
  };

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path == '/api/company/training/bookings/91/tests') {
      return {'subject': 'อบรมทดสอบ', 'participantId': 7, 'canManage': false};
    }
    throw StateError('unexpected GET: $path');
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    if (path ==
        '/api/company/training/bookings/91/tests/PRE/attempt?examId=41') {
      attemptCalls++;
      return attempt;
    }
    throw StateError('unexpected POST: $path');
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    if (path !=
        '/api/company/training/bookings/91/tests/PRE/attempt?examId=41') {
      throw StateError('unexpected PUT: $path');
    }
    final payload = Map<String, dynamic>.from(body! as Map);
    saved.add(payload);
    submitted = payload['submit'] == true;
    return attempt;
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) => throw UnimplementedError();
}
