import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_purchasing/features/purchasing/purchasing_route_contract.dart';

void main() {
  test('purchasing request contract uses Core menu and Header-Detail flow', () {
    expect(PurchasingMenuCodes.requests, '69002');
    expect(PurchasingRoutes.all.single.screenType, 4);
    expect(PurchasingRoutes.all.single.routeName, 'mySystemPurchaseScRequest');
    expect(
      PurchasingRoutes.all.single.routePath,
      '/company/my-system/purchase-sc-request',
    );
    expect(PurchasingRoutes.all.single.isImplemented, isTrue);
  });
}
