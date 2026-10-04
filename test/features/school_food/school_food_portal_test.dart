import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_school_food/school_food_feature.dart';
import 'package:laoo_school_food/src/food_portal_page.dart';
import 'school_food_responsive_test.dart' show FoodFixtureApi, tokens;

void configure(FoodPortalRequest request) {
  configureSchoolFoodFeatureHost(
    shell: ({required pageTitle, required activeMenu, required child}) => child,
    api: () => FoodFixtureApi(3),
    dispose: (_) {},
    tokens: () => tokens,
    message: (_, {required message, required error}) {},
    portalRequest: request,
  );
}

Future<dynamic> history(
  String path, {
  Map<String, dynamic>? body,
  String? token,
}) async {
  if (path.endsWith('/children'))
    return {
      'children': [
        {'id': 1, 'name': 'นักเรียนทดสอบชื่อภาษาไทยยาวสำหรับผู้ปกครอง'},
      ],
    };
  return {
    'balance': 445,
    'total': 1,
    'rows': [
      {
        'item': 'ข้าวไก่กระเทียมและเครื่องดื่มสำหรับทดสอบข้อความภาษาไทยยาว',
        'shop': 'ร้านอาหารโรงเรียน',
        'receipt': 'SF20261004-001',
        'quantity': 2,
        'returned': 1,
        'net': 35,
      },
    ],
    'summary': [
      {'category': 'อาหาร', 'quantity': 1, 'net': 35},
    ],
  };
}

void main() {
  setUpAll(() async {
    await (FontLoader('NotoSansThai')
          ..addFont(rootBundle.load('assets/fonts/NotoSansThai-Variable.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [360.0, 430.0, 768.0, 1024.0, 1440.0]) {
    for (final guardian in [false, true]) {
      testWidgets('portal ${guardian ? 'guardian' : 'student'} $width loaded', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        configure(history);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              fontFamily: 'NotoSansThai',
              scaffoldBackgroundColor: tokens.backgroundColor,
              colorScheme: ColorScheme.fromSeed(seedColor: tokens.primaryColor),
            ),
            home: FoodPortalPage(guardian: guardian, initialToken: 'fixture'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('445.00 บาท'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('FOOD_CAPTURE') &&
            ((guardian && width == 360) || (!guardian && width == 1440))) {
          await expectLater(
            find.byType(FoodPortalPage),
            matchesGoldenFile(
              '../../../artifacts/school-food/portal-${guardian ? 'guardian' : 'student'}-${width.toInt()}.png',
            ),
          );
        }
      });
    }
  }
  testWidgets('student login requires password change and clears session', (
    tester,
  ) async {
    final calls = <String>[];
    configure((path, {body, token}) async {
      calls.add(path);
      if (path.endsWith('/login'))
        return {'accessToken': 'fixture', 'mustChangePassword': true};
      if (path.endsWith('/change-password')) return {'reauthenticate': true};
      throw StateError('Should not load purchases before password change');
    });
    await tester.pumpWidget(const MaterialApp(home: FoodPortalPage()));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'TEST');
    await tester.enterText(fields.at(1), 'SFDEMO002');
    await tester.enterText(fields.at(2), 'InitialPassword!2');
    await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    await tester.pumpAndSettle();
    expect(find.text('เปลี่ยนรหัสผ่านเริ่มต้น'), findsOneWidget);
    await tester.enterText(fields.at(0), 'InitialPassword!2');
    await tester.enterText(fields.at(1), 'NewPassword!234');
    await tester.enterText(fields.at(2), 'NewPassword!234');
    await tester.tap(find.widgetWithText(FilledButton, 'เปลี่ยนรหัสผ่าน'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'), findsOneWidget);
    expect(calls, [
      '/api/school/student/login',
      '/api/school/student/change-password',
    ]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('portal network error exposes retry without stale purchases', (
    tester,
  ) async {
    configure((path, {body, token}) async => throw StateError('offline'));
    await tester.pumpWidget(
      const MaterialApp(home: FoodPortalPage(initialToken: 'fixture')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ลองใหม่'), findsOneWidget);
    expect(find.text('ประวัติการซื้อ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
