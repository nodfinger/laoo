import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/assistant/assistant_launcher.dart';

void main() {
  testWidgets('assistant can open a dialog from its overlay context', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => AssistantLauncher(
          navigatorKey: navigatorKey,
          child: Stack(
            children: [
              child!,
              Builder(
                builder: (overlayContext) => ElevatedButton(
                  onPressed: () => showAssistantDialog<void>(
                    context: overlayContext,
                    builder: (_) => const AlertDialog(
                      title: Text('บันทึกเป็นคำสั่งใช้บ่อย'),
                    ),
                  ),
                  child: const Text('เปิดหน้าต่าง'),
                ),
              ),
            ],
          ),
        ),
        home: const SizedBox(),
      ),
    );
    await tester.tap(find.text('เปิดหน้าต่าง'));
    await tester.pumpAndSettle();
    expect(find.text('บันทึกเป็นคำสั่งใช้บ่อย'), findsOneWidget);
  });
  testWidgets('assistant layer has an Overlay for popups and tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AssistantLauncher(
          child: Builder(
            builder: (context) => Text(
              Overlay.maybeOf(context) == null
                  ? 'overlay-missing'
                  : 'overlay-ready',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
        home: const SizedBox(),
      ),
    );
    expect(find.text('overlay-ready'), findsOneWidget);
  });
}
