import 'package:go_router/go_router.dart';

import 'rental_page.dart';

class RentalRoute {
  const RentalRoute(this.menuCode, this.slug);

  final String menuCode;
  final String slug;

  String get routeName => 'rental-$slug';
  String get routePath => '/company/rental-$slug';
}

abstract final class RentalRoutes {
  static const all = <RentalRoute>[
    RentalRoute('60001', 'settings'),
    RentalRoute('60002', 'items'),
    RentalRoute('60003', 'availability'),
    RentalRoute('60004', 'bookings'),
    RentalRoute('60005', 'payments'),
    RentalRoute('60006', 'handover'),
    RentalRoute('60007', 'returns'),
    RentalRoute('60008', 'settlements'),
    RentalRoute('60009', 'history'),
    RentalRoute('60010', 'dashboard'),
  ];
}

List<GoRoute> buildRentalRoutes() => RentalRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (context, state) => RentalPage(menuCode: route.menuCode),
      ),
    )
    .toList();
