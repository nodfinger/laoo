import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';

void main() {
  test('all active Center menu codes have a routable registry entry', () {
    const activeMenuCodes = {
      '01001',
      '01004',
      '01005',
      '01006',
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
      '05003',
      '06001',
      '06002',
      '06003',
      '07001',
      '08001',
      '09001',
      '09002',
      '09003',
      '09004',
      '09005',
      '09006',
      '09007',
      '10001',
      '10003',
      '10004',
      '10005',
      '10006',
      '11001',
      '11003',
      '11004',
      '11005',
      '12001',
      '13001',
    };

    final specs = AppMenuRouteRegistry.all.toList();
    final registryCodes = specs.map((item) => item.menuCode).toSet();

    expect(registryCodes, containsAll(activeMenuCodes));
    for (final menuCode in activeMenuCodes) {
      expect(AppMenuRouteRegistry.byMenuCode(menuCode), isNotNull);
    }
    for (final spec in specs) {
      expect(AppMenuRouteRegistry.byMenuCode(spec.menuCode), same(spec));
      expect(AppMenuRouteRegistry.byPath(spec.path), contains(same(spec)));
      expect(spec.path, isNotEmpty);
      expect(spec.goRouteName, isNotEmpty);
    }
  });

  test('shared organization path retains every owner MenuCode identity', () {
    final specs = AppMenuRouteRegistry.byPath('/organization-structure');

    expect(specs.map((spec) => spec.menuCode).toSet(), {
      '10005',
      '11005',
      '12005',
    });
  });
}
