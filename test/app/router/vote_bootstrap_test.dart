import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_vote/vote_feature.dart';

void main() {
  test('Vote has all approved contracts but no active routes', () {
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
    expect(VoteRoutes.implemented, isEmpty);
    expect(buildVoteFeatureRoutes(), isEmpty);
    for (final route in VoteRoutes.all) {
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
