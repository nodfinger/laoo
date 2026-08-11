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
      '06001',
      '06002',
      '07001',
      '08001',
      '09001',
    };

    final specs = AppMenuRouteRegistry.all.toList();

    expect(specs.map((item) => item.menuCode).toSet(), expectedMenuCodes);
    expect(specs.map((item) => item.path).toSet(), hasLength(specs.length));
    for (final spec in specs) {
      expect(AppMenuRouteRegistry.byMenuCode(spec.menuCode), same(spec));
      expect(AppMenuRouteRegistry.byPath(spec.path), same(spec));
      expect(spec.goRouteName, isNotEmpty);
    }
  });
}
