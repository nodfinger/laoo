import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_meeting/core/company_setup/company_setup_controller.dart';
import 'package:laoo_meeting/core/widgets/auto_dismiss_message.dart';
import 'package:laoo_meeting/core/widgets/timed_snack_bar.dart';

void main() {
  setUp(companySetupController.clear);

  testWidgets('AutoDismissMessage supports manual close', (tester) async {
    var visible = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: visible
                ? AutoDismissMessage(
                    message: 'test message',
                    onClose: () => setState(() => visible = false),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.byType(AutoDismissMessage), findsNothing);
  });

  testWidgets('timed notification uses overlay and close action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTimedSnackBar(context, message: 'test overlay'),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();

    expect(find.text('test overlay'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('test overlay'), findsNothing);
  });
}
