import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:laoo/app/theme/laoo_theme.dart';
import 'package:laoo/features/auth/presentation/pages/login_page.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('NotoSansThai')
      ..addFont(rootBundle.load('assets/fonts/NotoSansThai-Variable.ttf'));
    await loader.load();
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await materialIcons.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> renderLogin(
    WidgetTester tester, {
    required Size size,
    required String goldenName,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: LaooTheme.fromKey(LaooThemeKey.green),
        home: const LoginPage(),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/laoo_login_service_hero.png'),
        tester.element(find.byType(LoginPage)),
      );
      await precacheImage(
        const AssetImage('assets/images/laoo_app_icon.png'),
        tester.element(find.byType(LoginPage)),
      );
    });
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบ'), findsWidgets);
    expect(find.text('ชื่อผู้ใช้งาน'), findsOneWidget);
    expect(find.text('รหัสผ่าน'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(LoginPage),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  testWidgets('desktop login visual review', (tester) async {
    await renderLogin(
      tester,
      size: const Size(1440, 900),
      goldenName: 'login_desktop',
    );
  });

  testWidgets('mobile login visual review', (tester) async {
    await renderLogin(
      tester,
      size: const Size(390, 844),
      goldenName: 'login_mobile',
    );
  });

  testWidgets('login form keeps validation and password visibility', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: LaooTheme.fromKey(LaooThemeKey.green),
        home: const LoginPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('แสดงรหัสผ่าน'));
    await tester.pump();
    expect(find.byTooltip('ซ่อนรหัสผ่าน'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    await tester.pump();
    expect(find.text('กรุณากรอก Username'), findsOneWidget);
    expect(find.text('กรุณากรอก Password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
