import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/features/job_dispatch/pages/job_dispatch_page.dart';
import 'package:laoo_service/features/service_request/data/service_request_api.dart';
import 'package:laoo_service/features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  setUpAll(
    () => configureServiceWorkspaceShell(
      ({
        required String pageTitle,
        required String activeMenu,
        required Widget child,
      }) => Scaffold(body: child),
    ),
  );

  for (final size in [const Size(1200, 800), const Size(390, 800)]) {
    testWidgets('queue filter and display work at ${size.width}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _QueueApi();
      await tester.pumpWidget(MaterialApp(home: JobDispatchPage(api: api)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'initial render');
      expect(find.text('งานแทรกคิว'), findsWidgets);
      expect(find.text('แทรกคิว'), findsOneWidget);
      expect(find.text('ไม่แทรกคิว'), findsOneWidget);
      await tester.tap(find.text('ทั้งหมด').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'open filter');
      await tester.tap(find.text('แทรกคิว').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'apply filter');
      expect(api.lastFilter, isTrue);
      expect(find.text('SR-1'), findsOneWidget);
      expect(find.text('SR-2'), findsNothing);
      await tester.tap(find.text('ล้าง Filter'));
      await tester.pumpAndSettle();
      expect(api.lastFilter, isNull);
      expect(find.text('SR-2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _QueueApi extends ServiceRequestApi {
  bool? lastFilter;
  @override
  Future<Map<String, dynamic>> actions() async => {'dispatchEdit': false};

  @override
  Future<Map<String, dynamic>> dispatchList({
    String search = '',
    int page = 1,
    bool? queueJump,
  }) async {
    lastFilter = queueJump;
    final all = [
      {'requestId': 1, 'requestNo': 'SR-1', 'isQueueJump': true},
      {'requestId': 2, 'requestNo': 'SR-2', 'isQueueJump': false},
    ];
    final items = all
        .where((row) => queueJump == null || row['isQueueJump'] == queueJump)
        .toList();
    return {'items': items, 'total': items.length};
  }
}
