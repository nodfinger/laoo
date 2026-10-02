import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_vote/features/vote/vote_feature_host.dart';
import 'package:laoo_vote/features/vote/vote_pages.dart';

void main() {
  testWidgets('44005 mobile dashboard recovers and paginates read-only data', (
    tester,
  ) async {
    final api = _VoteResultsApi();
    configureVoteFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => child,
      apiClientFactory: () => api,
      apiClientDisposer: (_) {},
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VotePage('results'))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('รายละเอียดเพิ่มเติม'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);

    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(find.text('ผู้มีสิทธิ์'), findsOneWidget);
    expect(find.text('อัตราโหวต'), findsOneWidget);
    expect(find.text('VOTE-18'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('1-20 จาก 21'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1-20 จาก 21'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final nextPage = find.byIcon(Icons.chevron_right);
    await tester.ensureVisible(nextPage);
    await tester.pumpAndSettle();
    await tester.tap(nextPage);
    await tester.pumpAndSettle();
    expect(api.lastPage, 2);
    expect(find.text('VOTE-19'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('21-21 จาก 21'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('21-21 จาก 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _VoteResultsApi implements JsonApiClient {
  bool failDashboardOnce = true;
  int lastPage = 1;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path == '/api/company/votes/results/dashboard') {
      if (failDashboardOnce) {
        failDashboardOnce = false;
        throw StateError('temporary failure');
      }
      return {
        'open': 1,
        'closed': 2,
        'pendingApproval': 3,
        'eligible': 13,
        'voted': 8,
        'turnout': 61.5,
      };
    }
    if (path.startsWith('/api/company/votes/results?')) {
      final uri = Uri.parse(path);
      lastPage = int.parse(uri.queryParameters['page'] ?? '1');
      return {
        'page': lastPage,
        'pageSize': 20,
        'total': 21,
        'items': [
          {
            'id': lastPage == 2 ? 19 : 18,
            'voteNo': lastPage == 2 ? 'VOTE-19' : 'VOTE-18',
            'name': 'หัวข้อทดสอบ',
            'status': 'CLOSED',
            'eligible': 13,
            'voted': 8,
          },
        ],
      };
    }
    throw StateError('Unexpected GET path');
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
