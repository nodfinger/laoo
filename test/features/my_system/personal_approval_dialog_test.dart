import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/api/api_client.dart';
import 'package:laoo/features/my_system/personal_approval_dialog.dart';

class _FakeApi extends ApiClient {
  final data = <String, dynamic>{
    'employees': [
      {'id': 1, 'name': 'Requester A', 'department': 'A', 'active': true},
      {'id': 2, 'name': 'Requester B', 'department': 'B', 'active': true},
      {'id': 3, 'name': 'Approver A', 'department': 'A', 'active': true},
      {'id': 4, 'name': 'Approver B', 'department': 'B', 'active': true},
    ],
    'steps': [
      {'requesterId': 1, 'approverId': 3, 'order': 1},
      {'requesterId': 2, 'approverId': 4, 'order': 1},
    ],
  };
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async => data;
}

void main() {
  testWidgets(
    'reopening shows all saved requesters and their approval orders',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonalApprovalDialog(
              api: _FakeApi(),
              menuCode: '66001',
              menuName: 'Travel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Requester A'), findsOneWidget);
      expect(find.text('Requester B'), findsOneWidget);
      await tester.tap(find.text('Requester A'));
      await tester.pumpAndSettle();
      expect(find.text('Approver A'), findsOneWidget);
    },
  );

  testWidgets('each requester retains their own approver', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalApprovalDialog(
            api: _FakeApi(),
            menuCode: '66001',
            menuName: 'Travel',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requester B'));
    await tester.pumpAndSettle();
    expect(find.text('Approver B'), findsOneWidget);
    expect(find.text('Approver A'), findsNothing);
  });
}
