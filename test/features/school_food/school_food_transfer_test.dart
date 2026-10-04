import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_school_food/school_food_feature.dart';
import 'package:laoo_school_food/src/transfer_editor.dart';
import 'school_food_responsive_test.dart' show FoodFixtureApi, tokens;

class TransferApi extends FoodFixtureApi {
  TransferApi() : super(4);
  String status = 'DRAFT';
  num quantity = 2;
  final calls = <String>[];
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async => {
    'header': {
      'ShopID': 1,
      'SourceWarehouseID': 2,
      'ReferenceNo': 'SFDEMO-T01',
      'StatusCode': status,
    },
    'items': [
      {
        'ItemID': 3,
        'code': 'RICE',
        'name': 'ข้าวทดสอบชื่อภาษาไทยยาวสำหรับหน้าจอโทรศัพท์',
        'Quantity': quantity,
      },
    ],
  };
  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    calls.add('save');
    quantity = ((body as Map)['items'] as List).first['quantity'] as num;
    return {'id': 1};
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    calls.add(path.split('/').last);
    status = path.endsWith('/send') ? 'SENT' : 'RECEIVED';
    return {'id': 1};
  }
}

void main() {
  for (final width in [360.0, 1440.0]) {
    testWidgets('transfer edit send receive $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = TransferApi();
      configureSchoolFoodFeatureHost(
        shell: ({required pageTitle, required activeMenu, required child}) =>
            child,
        api: () => api,
        dispose: (_) {},
        tokens: () => tokens,
        message: (_, {required message, required error}) {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodTransferEditor(
              title: 'โอนและรับสต๊อกร้านค้า',
              id: 1,
              shops: const [
                {'id': 1, 'name': 'ร้านอาหาร', 'TrackStock': true},
              ],
              warehouses: const [
                {'id': 2, 'name': 'คลังกลาง'},
              ],
              actions: const {
                'view': true,
                'edit': true,
                'transfer': true,
                'receive': true,
              },
              close: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextFormField).last, '5');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'ส่งใบโอน'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
      await tester.pumpAndSettle();
      expect(api.quantity, 5);
      await tester.tap(find.widgetWithText(FilledButton, 'ส่งใบโอน'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'รับเข้าร้าน'));
      await tester.pumpAndSettle();
      expect(api.calls, ['save', 'send', 'receive']);
      expect(find.text('ข้อมูลหลัก · RECEIVED'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'บันทึก'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
