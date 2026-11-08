import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/core/company_setup/company_setup_controller.dart';
import 'package:laoo_service/core/widgets/auto_dismiss_message.dart';
import 'package:laoo_service/core/widgets/timed_snack_bar.dart';

void main() {
  setUp(companySetupController.clear);
  tearDown(() {
    configureServiceAlertPrimary(null);
    configureServiceAlertDuration(null);
  });

  testWidgets('embedded alerts dismiss at the host company timeout', (
    tester,
  ) async {
    configureServiceAlertDuration(() => const Duration(seconds: 2));
    var visible = true;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: visible
                ? AutoDismissMessage(
                    message: 'Alert',
                    onClose: () => setState(() => visible = false),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byType(AutoDismissMessage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AutoDismissMessage), findsNothing);
  });

  testWidgets(
    'embedded alerts use the current user color, errors use error color',
    (tester) async {
      const purple = Color(0xFF673AB7);
      const blue = Color(0xFF1565C0);
      const error = Color(0xFFB00020);
      var primary = purple;
      configureServiceAlertPrimary(() => primary);
      Future<void> show(bool isError) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
            ).copyWith(error: error),
          ),
          home: Scaffold(
            body: AutoDismissMessage(
              message: 'Alert',
              error: isError,
              onClose: () {},
            ),
          ),
        ),
      );
      Color? cardColor() => tester.widget<Card>(find.byType(Card)).color;
      await show(false);
      expect(cardColor(), purple.withValues(alpha: .5));
      primary = blue;
      await show(false);
      expect(cardColor(), blue.withValues(alpha: .5));
      await show(true);
      expect(cardColor(), error.withValues(alpha: .5));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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

  testWidgets(
    'AutoDismissMessage keeps the original deadline across parent rebuilds',
    (tester) async {
      var visible = true;
      late StateSetter rebuild;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: visible
                    ? AutoDismissMessage(
                        message: 'Three second alert',
                        duration: const Duration(seconds: 3),
                        onClose: () => setState(() => visible = false),
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      rebuild(() {});
      await tester.pump();
      expect(find.byType(AutoDismissMessage), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(AutoDismissMessage), findsNothing);
    },
  );
}
