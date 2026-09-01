import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/app/theme/laoo_typography.dart';
import 'package:laoo_service/features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  const title = 'รหัสพื้นฐาน > จังหวัด > เพิ่ม';

  Widget buildHeader(double width) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: WorkspaceActionHeader(
            title: title,
            actions: [
              OutlinedButton(
                key: const Key('cancel'),
                onPressed: () {},
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                key: const Key('save'),
                onPressed: () {},
                child: const Text('บันทึก'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('moves actions below caption on compact width', (tester) async {
    await tester.pumpWidget(buildHeader(320));

    final titleRect = tester.getRect(find.text(title));
    final cancelRect = tester.getRect(find.byKey(const Key('cancel')));
    final saveRect = tester.getRect(find.byKey(const Key('save')));

    expect(cancelRect.top, greaterThan(titleRect.bottom));
    expect(saveRect.top, greaterThan(titleRect.bottom));
    expect(cancelRect.left, 0);
    expect(saveRect.left, greaterThan(cancelRect.right));
  });

  testWidgets('keeps actions beside caption on desktop width', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildHeader(1200));

    final titleRect = tester.getRect(find.text(title));
    final cancelRect = tester.getRect(find.byKey(const Key('cancel')));

    expect((cancelRect.center.dy - titleRect.center.dy).abs(), lessThan(2));
  });

  testWidgets('moves actions below caption at tablet width', (tester) async {
    await tester.pumpWidget(buildHeader(760));

    final titleRect = tester.getRect(find.text(title));
    final cancelRect = tester.getRect(find.byKey(const Key('cancel')));
    final saveRect = tester.getRect(find.byKey(const Key('save')));

    expect(cancelRect.top, greaterThan(titleRect.bottom));
    expect(saveRect.top, greaterThan(titleRect.bottom));
    expect(cancelRect.left, 0);
  });

  testWidgets('keeps favorite star left of a black caption', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorkspacePageTitle(title: title, favoriteKey: '05002'),
        ),
      ),
    );

    final starRect = tester.getRect(find.byIcon(Icons.star_border_rounded));
    final titleRect = tester.getRect(find.text(title));
    final titleText = tester.widget<Text>(find.text(title));

    expect(starRect.right, lessThan(titleRect.left));
    expect(titleText.style?.color, Colors.black);
  });

  test('uses 14px for shared controls and list data', () {
    expect(LaooTypography.body, 14);
    expect(LaooTypography.inputText, 14);
    expect(LaooTypography.inputHint, 14);
    expect(LaooTypography.comboBox, 14);
    expect(LaooTypography.button, 14);
    expect(LaooTypography.tableHeader, 14);
    expect(LaooTypography.tableBody, 14);
  });
}
