import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/assistant/assistant_launcher.dart';

void main() {
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
