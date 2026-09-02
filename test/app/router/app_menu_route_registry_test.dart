import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';

void main() {
  test('all active Center, Service, and Meeting menus are routable', () {
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
      '07001',
      '08001',
      '08002',
      '08003',
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
      '14001',
      '14002',
      '14003',
      '15001',
      '15002',
      '16001',
      '16002',
      '16003',
      '17001',
      '17002',
      '17003',
      '19001',
      '19002',
      '19003',
      '20001',
      '20002',
      '20003',
      '20004',
      '20005',
      '20006',
      '21001',
      '21002',
      '21003',
      '21004',
      '21005',
      '22001',
      '22002',
      '22003',
      '23001',
      '23002',
      '23003',
      '23004',
      '23005',
      '24001',
      '24002',
      '24003',
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
