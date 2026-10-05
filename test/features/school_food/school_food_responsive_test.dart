import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_school_food/school_food_feature.dart';
import 'package:laoo_school_food/src/school_food_page.dart';
import 'package:laoo_school_food/src/pos.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

class FoodFixtureApi implements JsonApiClient {
  final int type;
  FoodFixtureApi(this.type);
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.contains('/actions/'))
      return {
        'actions': {
          'view': true,
          'create': type == 1,
          'edit': type != 3,
          'delete': type == 1 || type == 4,
          'sale': true,
          'topup': true,
          'refund': true,
          'export': true,
        },
        'metadata': {
          'MenuName': 'ระบบขายอาหารในโรงเรียน ทดสอบชื่อภาษาไทยยาว',
          'ScreenType': type,
        },
      };
    if (path.contains('/options/'))
      return {
        'warehouses': [
          {'id': 1, 'name': 'คลังโรงอาหาร'},
        ],
      };
    if (path.endsWith('/shops'))
      return [
        {
          'id': 1,
          'code': 'FOOD',
          'name': 'ร้านอาหารทดสอบชื่อยาวสำหรับโทรศัพท์มือถือ',
          'TrackStock': true,
          'IsActive': true,
        },
      ];
    if (path.endsWith('/settings'))
      return {
        'IsEnabled': true,
        'CommissionEnabled': true,
        'DefaultCommissionRate': 5,
      };
    if (path.endsWith('/commission'))
      return [
        {'id': 1, 'ItemName': 'ข้าวไก่กระเทียม', 'Rate': 10},
      ];
    return {
      'rows': [
        {
          'id': 1,
          'code': 'SFDEMO001',
          'name': 'ข้าวไก่กระเทียมและเครื่องดื่มสำหรับทดสอบข้อความยาว',
          'price': 35,
          'selected': true,
          'trackStock': true,
          'stock': 20,
          'balance': 445,
          'IsActive': true,
          'Kind': 'CARD',
          'DisplaySuffix': '0001',
          'status': 'DRAFT',
          'student': 'นักเรียนตัวอย่าง',
          'total': 80,
          'refunded': 35,
          'gross': 80,
          'refunds': 35,
          'net': 45,
          'commission': 4.5,
          'payable': 40.5,
        },
      ],
      'total': 1,
    };
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => {};
  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => {};
  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async => {};
}

class CardEntryApi extends FoodFixtureApi {
  CardEntryApi() : super(4);
  int scans = 0;
  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/identify')) {
      scans++;
      final data = Map<String, dynamic>.from(body! as Map);
      if (data['kind'] == 'CARD' && data['value'] == 'SFDEMO-CARD001') {
        return {
          'id': 5,
          'name': 'นักเรียนตัวอย่าง',
          'classroom': '3/2',
          'balance': 445,
        };
      }
      throw StateError('ไม่พบบัตรหรือบัตรถูกระงับ');
    }
    return super.post(path, body: body, authenticated: authenticated);
  }
}

const tokens = LaooWorkspaceUiTokens(
  contentMargin: EdgeInsets.all(10),
  cardPadding: EdgeInsets.all(10),
  sectionSpacing: 6,
  captionFilterSpacing: 6,
  itemSpacing: 6,
  radius: 4,
  compactBreakpoint: 900,
  paginationHeight: 56,
  captionStyle: TextStyle(
    fontFamily: 'NotoSansThai',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Colors.black,
  ),
  sectionStyle: TextStyle(
    fontFamily: 'NotoSansThai',
    fontSize: 16,
    fontWeight: FontWeight.w600,
  ),
  inputStyle: TextStyle(fontFamily: 'NotoSansThai', fontSize: 14),
  tableStyle: TextStyle(fontFamily: 'NotoSansThai', fontSize: 14),
  buttonStyle: TextStyle(fontFamily: 'NotoSansThai', fontSize: 13),
  buttonHeight: 48,
  primaryColor: Color(0xff128365),
  borderColor: Color(0xffdddddd),
  backgroundColor: Color(0xfff8f9fb),
);
void main() {
  for (final width in [360.0, 430.0, 768.0, 1024.0, 1440.0]) {
    for (var index = 0; index < 12; index++) {
      testWidgets('menu ${53001 + index} fits width $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = FoodFixtureApi([2, 1, 2, 2, 1, 4, 4, 4, 4, 3, 3, 3][index]);
        configureSchoolFoodFeatureHost(
          shell: ({required pageTitle, required activeMenu, required child}) =>
              Scaffold(body: child),
          api: () => api,
          dispose: (_) {},
          tokens: () => tokens,
          message: (context, {required message, required error}) {},
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: tokens.primaryColor),
            ),
            home: SchoolFoodPage(menuCode: '${53001 + index}'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('ระบบขายอาหารในโรงเรียน ทดสอบชื่อภาษาไทยยาว'),
          findsOneWidget,
        );
        if (index != 0 && index != 7)
          expect(find.byType(LaooPaginationCard), findsOneWidget);
      });
    }
  }
  for (final width in [360.0, 1440.0]) {
    for (final menu in ['53002', '53007']) {
      testWidgets('menu $menu opens paged detail at $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = FoodFixtureApi(menu == '53002' ? 1 : 4);
        configureSchoolFoodFeatureHost(
          shell: ({required pageTitle, required activeMenu, required child}) =>
              Scaffold(body: child),
          api: () => api,
          dispose: (_) {},
          tokens: () => tokens,
          message: (context, {required message, required error}) {},
        );
        await tester.pumpWidget(
          MaterialApp(home: SchoolFoodPage(menuCode: menu)),
        );
        await tester.pumpAndSettle();
        final tooltip = menu == '53002' ? 'ผู้ใช้ร้านค้า' : 'ประวัติ Wallet';
        await tester.tap(find.byTooltip(tooltip).first);
        await tester.pumpAndSettle();
        expect(find.byType(LaooActionDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('dashboard exports current filters', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? exportedPath;
    Map<String, String>? exportedQuery;
    configureSchoolFoodFeatureHost(
      shell: ({required pageTitle, required activeMenu, required child}) =>
          Scaffold(body: child),
      api: () => FoodFixtureApi(3),
      dispose: (_) {},
      tokens: () => tokens,
      reportExport: (path, query, fileName) async {
        exportedPath = path;
        exportedQuery = query;
        expect(fileName.endsWith('.csv'), isTrue);
      },
      message: (context, {required message, required error}) {},
    );
    await tester.pumpWidget(
      const MaterialApp(home: SchoolFoodPage(menuCode: '53012')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ส่งออก CSV'));
    await tester.pumpAndSettle();
    expect(exportedPath, endsWith('/reports/53012/export'));
    expect(exportedQuery?['dimension'], 'shop');
    expect(exportedQuery?['from'], isNotEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('commission category editor opens on mobile', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    configureSchoolFoodFeatureHost(
      shell: ({required pageTitle, required activeMenu, required child}) =>
          Scaffold(body: child),
      api: () => FoodFixtureApi(2),
      dispose: (_) {},
      tokens: () => tokens,
      message: (context, {required message, required error}) {},
    );
    await tester.pumpWidget(
      const MaterialApp(home: SchoolFoodPage(menuCode: '53004')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('อัตราตามประเภท'));
    await tester.pumpAndSettle();
    expect(find.byType(LaooActionDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [360.0, 1440.0]) {
    testWidgets(
      'card number Enter identifies before item selection at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = CardEntryApi();
        configureSchoolFoodFeatureHost(
          shell: ({required pageTitle, required activeMenu, required child}) =>
              Scaffold(body: child),
          api: () => api,
          dispose: (_) {},
          tokens: () => tokens,
          message: (context, {required message, required error}) {},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FoodPos(
                shops: const [
                  {'id': 1, 'name': 'ร้านอาหารทดสอบ'},
                ],
                canSell: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final product = find.text(
          'ข้าวไก่กระเทียมและเครื่องดื่มสำหรับทดสอบข้อความยาว',
        );
        await tester.tap(product);
        await tester.pump();
        expect(api.scans, 0);
        final input = find.byType(TextField).first;
        await tester.enterText(input, 'SFDEMO-CARD001');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(api.scans, 1);
        expect(find.textContaining('นักเรียนตัวอย่าง'), findsWidgets);
        await tester.tap(product);
        await tester.pump();
        if (width < 900)
          expect(find.textContaining('ตะกร้า 1 รายการ'), findsOneWidget);
        await tester.enterText(input, 'SFDEMO-UNKNOWN');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(api.scans, 2);
        expect(find.textContaining('ไม่พบบัตรหรือบัตรถูกระงับ'), findsWidgets);
        if (width < 900)
          expect(find.textContaining('ตะกร้า 0 รายการ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
