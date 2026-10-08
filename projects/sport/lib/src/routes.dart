import 'package:go_router/go_router.dart';
import 'sport_page.dart';

class SportRoute {
  const SportRoute(this.menuCode, this.slug);
  final String menuCode;
  final String slug;
  String get routeName => 'sport-$slug';
  String get routePath => '/company/$routeName';
}

abstract final class SportRoutes {
  static const all = <SportRoute>[
    SportRoute('54001', 'settings'),
    SportRoute('54002', 'types'),
    SportRoute('54003', 'facilities'),
    SportRoute('54004', 'levels'),
    SportRoute('54005', 'packages'),
    SportRoute('54006', 'members'),
    SportRoute('54007', 'enrollments'),
    SportRoute('54008', 'bookings'),
    SportRoute('54009', 'checkins'),
    SportRoute('54010', 'pos-pricing'),
    SportRoute('54011', 'dashboard'),
  ];
}

List<GoRoute> buildSportRoutes() => SportRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (context, state) => SportPage(menuCode: route.menuCode),
      ),
    )
    .toList();
