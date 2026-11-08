import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

void main() {
  testWidgets('filter buttons follow the rendered search height', (
    tester,
  ) async {
    Future<void> showField(double height) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterHeightSync(
              builder: (context, key, actionHeight) => Column(
                children: [
                  SizedBox(
                    key: key,
                    height: height,
                    child: const Text('search'),
                  ),
                  SizedBox(
                    height: actionHeight,
                    child: FilledButton(
                      style: filterActionHeightStyle(actionHeight),
                      onPressed: () {},
                      child: const Text('ค้นหา'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await showField(40);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'ค้นหา')).height,
      40,
    );
    await showField(56);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'ค้นหา')).height,
      56,
    );
  });
}
