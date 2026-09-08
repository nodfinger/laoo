import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_meeting/app/theme/laoo_design_tokens.dart';
import 'package:laoo_meeting/features/meeting/widgets/meeting_popup.dart';

void main() {
  for (final confirm in [false, true]) {
    testWidgets('nested delete returns $confirm and preserves parent popup', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (parentContext) {
                      return MeetingPopup(
                        title: const MeetingPopupTitle(
                          icon: Icons.rule,
                          text: 'Room rules',
                        ),
                        content: const Text('Parent popup'),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              result = await showDialog<bool>(
                                context: parentContext,
                                builder: (_) => const MeetingDeletePopup(
                                  record: 'R1 | Meeting room',
                                ),
                              );
                            },
                            child: const Text('Open delete'),
                          ),
                        ],
                      );
                    },
                  ),
                  child: const Text('Open parent'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open delete'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog).last);
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect(dialog.backgroundColor, LaooColors.white);
      expect(shape.side.color, LaooColors.error);
      expect(shape.borderRadius, BorderRadius.circular(LaooRadius.xs));
      await tester.tap(find.text(confirm ? 'ลบ' : 'ยกเลิก'));
      await tester.pumpAndSettle();
      expect(result, confirm);
      expect(find.text('Parent popup'), findsOneWidget);
      expect(find.byType(MeetingDeletePopup), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('delete popup fits a narrow screen with long record text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => MeetingDeletePopup(
                    record: List.filled(
                      12,
                      'ห้องประชุมสำหรับพนักงาน',
                    ).join(' '),
                  ),
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final cancel = tester.getRect(find.text('ยกเลิก'));
    final remove = tester.getRect(find.text('ลบ'));
    expect(cancel.center.dy, moreOrLessEquals(remove.center.dy));
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(find.byType(MeetingDeletePopup), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
