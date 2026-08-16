import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';

void main() {
  test('all TDADMainMenu codes have one routable registry entry', () {
    const expectedMenuCodes = {
      '01001',
      '01002',
      '01003',
      '01004',
      '02001',
      '02002',
      '02003',
      '03001',
      '03002',
      '03003',
      '04001',
      '04002',
      '05001',
      '05002',
      '06001',
      '06002',
      '07001',
      '08001',
      '09001',
      '10001',
      '10002',
      '10003',
      '10004',
      '10005',
      '11001',
      '11002',
      '11003',
      '11004',
      '11005',
      '12001',
      '12002',
      '12003',
      '12004',
      '12005',
    };

    final specs = AppMenuRouteRegistry.all.toList();

    expect(specs.map((item) => item.menuCode).toSet(), expectedMenuCodes);
    for (final spec in specs) {
      expect(AppMenuRouteRegistry.byMenuCode(spec.menuCode), same(spec));
      expect(AppMenuRouteRegistry.byPath(spec.path), contains(same(spec)));
      expect(spec.path, isNotEmpty);
      expect(spec.goRouteName, isNotEmpty);
    }
  });

  test('shared paths retain every MenuCode identity', () {
    final specs = AppMenuRouteRegistry.byPath('/organization-structure');

    expect(specs.map((spec) => spec.menuCode).toSet(), {
      '10005',
      '11005',
      '12005',
    });
  });
}
