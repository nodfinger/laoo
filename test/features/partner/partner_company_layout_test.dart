import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/partner/pages/partner_company_page.dart';
import 'package:laoo/core/navigation/menu_style_preferences.dart';
import 'package:laoo/app/theme/workspace_theme_presets.dart';

void main() {
  testWidgets('partner company list renders standard filter actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    workspaceButtonMenu.value = false;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: PartnerCompanyPage()));
    await tester.pump(const Duration(milliseconds: 200));
    final failure = tester.takeException();
    if (failure != null) fail('Layout error: $failure');
    expect(find.text('ล้าง Filter'), findsOneWidget);
    expect(find.text('ค้นหา'), findsOneWidget);
    expect(find.byTooltip('แสดงแบบการ์ด'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('partner pagination follows the logged in user theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    workspaceButtonMenu.value = false;
    final original = workspaceThemeController.value;
    final preset = workspaceThemeByCode('STYLE21');
    workspaceThemeController.value = preset;
    addTearDown(() => workspaceThemeController.value = original);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: PartnerCompanyPage()));
    await tester.pump(const Duration(milliseconds: 200));
    final button = tester.widget<FilledButton>(
      find
          .ancestor(of: find.text('1'), matching: find.byType(FilledButton))
          .first,
    );
    expect(
      button.style!.backgroundColor!.resolve({WidgetState.disabled}),
      preset.primary,
    );
    final next = workspaceThemeByCode('STYLE31');
    workspaceThemeController.value = next;
    await tester.pump();
    final updated = tester.widget<FilledButton>(
      find
          .ancestor(of: find.text('1'), matching: find.byType(FilledButton))
          .first,
    );
    expect(
      updated.style!.backgroundColor!.resolve({WidgetState.disabled}),
      next.primary,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
