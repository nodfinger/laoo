import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/core/company_setup/company_setup_controller.dart';
import 'package:laoo_service/core/widgets/auto_dismiss_message.dart';
import 'package:laoo_service/core/widgets/timed_snack_bar.dart';

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
                    message: 'ทดสอบ',
                    onClose: () => setState(() => visible = false),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('ปิด'));
    await tester.pump();

    expect(find.byType(AutoDismissMessage), findsNothing);
  });

  testWidgets('timed SnackBar uses fallback duration and close action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTimedSnackBar(context, message: 'ทดสอบ SnackBar'),
              child: const Text('แสดง'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('แสดง'));
    await tester.pumpAndSettle();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 30));
    expect(find.text('ปิด'), findsOneWidget);

    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });
}
