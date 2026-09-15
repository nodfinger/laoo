import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo/app/router/app_router.dart';
import 'package:laoo_time/time_feature.dart';

void main() {
  test('Root and composed Project routes have unique names and paths', () {
    final routes = appRouter.configuration.routes.whereType<GoRoute>().toList();
    final names = routes
        .map((route) => route.name)
        .whereType<String>()
        .toList();
    final paths = routes.map((route) => route.path).toList();

    expect(names.toSet(), hasLength(names.length));
    expect(paths.toSet(), hasLength(paths.length));
  });

  test('Time is route owner and each Time route is composed exactly once', () {
    final centerRoutes = appRouter.configuration.routes.whereType<GoRoute>();

    for (final route in TimeRoutes.implemented) {
      expect(
        centerRoutes.where((candidate) => candidate.name == route.routeName),
        hasLength(1),
      );
      expect(
        centerRoutes.where((candidate) => candidate.path == route.routePath),
        hasLength(1),
      );
    }
  });
}
