import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/company_setup/company_setup_controller.dart';
import 'package:laoo/core/widgets/auto_dismiss_message.dart';
import 'package:laoo/core/widgets/timed_snack_bar.dart';

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
                    message: 'Test alert',
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

  testWidgets('AutoDismissMessage uses 50 percent background opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutoDismissMessage(message: 'Test alert', onClose: () {}),
        ),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color?.a, closeTo(.50, .001));
    expect(find.byTooltip('ปิด'), findsOneWidget);
  });

  testWidgets('timed alert uses top-right overlay and close action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTimedSnackBar(context, message: 'Test overlay alert'),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.byType(AutoDismissMessage), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(AutoDismissMessage), findsNothing);
  });
}
