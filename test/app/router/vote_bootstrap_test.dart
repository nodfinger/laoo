import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_vote/vote_feature.dart';

void main() {
  test('Vote exposes approved routes and ScreenTypes through Center', () {
    expect(VoteProject.code, 'LAOO_VOTE');
    expect(VoteRoutes.all, hasLength(5));
    expect(
      VoteRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
        '44001',
        '44002',
        '44003',
        '44004',
        '44005',
      ]),
    );
    expect(VoteRoutes.implemented, hasLength(5));
    final routes = buildVoteFeatureRoutes();
    expect(routes, hasLength(5));
    expect(
      VoteRoutes.all.map((route) => route.screenType),
      orderedEquals(const <int>[2, 4, 3, 3, 3]),
    );
    for (final route in VoteRoutes.all) {
      final actual = routes.singleWhere((item) => item.name == route.routeName);
      expect(actual.path, route.routePath);
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
