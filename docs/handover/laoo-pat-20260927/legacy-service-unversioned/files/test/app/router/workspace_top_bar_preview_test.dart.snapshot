import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/core/navigation/menu_style_preferences.dart';
import 'package:laoo_service/app/theme/workspace_theme_presets.dart';
import 'package:laoo_service/features/support/presentation/widgets/support_workspace_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> renderTopBar(
    WidgetTester tester, {
    required Size size,
    required String golden,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    workspaceButtonMenu.value = true;
    SharedPreferences.setMockInitialValues(const {});
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null),
    );

    final desktop = size.width >= 900;
    workspaceButtonMenu.value = desktop;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: desktop
            ? Scaffold(
                body: Column(
                  children: [
                    WorkspaceTopBar(
                      preset: workspaceThemeController.value,
                      buttonMenu: true,
                      activeMenu: 'home',
                    ),
                    const Expanded(child: ColoredBox(color: Color(0xFFF5F7F8))),
                  ],
                ),
              )
            : const SupportWorkspaceShell(
                pageTitle: 'หน้าหลัก',
                activeMenu: 'home',
                menuScope: WorkspaceMenuScope.company,
                child: ColoredBox(color: Color(0xFFF5F7F8)),
              ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(golden));
  }

  testWidgets('desktop top bar preview', (tester) async {
    await renderTopBar(
      tester,
      size: const Size(1366, 768),
      golden: 'goldens/workspace_top_bar_desktop.png',
    );
  });

  testWidgets('mobile top bar preview', (tester) async {
    await renderTopBar(
      tester,
      size: const Size(390, 844),
      golden: 'goldens/workspace_top_bar_mobile.png',
    );

    await tester.tap(find.byTooltip('ผู้ใช้งาน'));
    await tester.pumpAndSettle();
    expect(find.text('ข้อมูลส่วนตัว'), findsOneWidget);
    expect(find.text('ออกจากระบบ'), findsOneWidget);
  });
}
