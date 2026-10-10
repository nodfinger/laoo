import 'package:go_router/go_router.dart';
import 'booking_page.dart';

class BookingRoute {
  const BookingRoute(this.menuCode, this.slug);
  final String menuCode;
  final String slug;
  String get routeName => 'booking-$slug';
  String get routePath => '/company/$routeName';
}

abstract final class BookingRoutes {
  static const all = <BookingRoute>[
    BookingRoute('61001', 'settings'),
    BookingRoute('61002', 'services'),
    BookingRoute('61003', 'providers'),
    BookingRoute('61004', 'resources'),
    BookingRoute('61005', 'members'),
    BookingRoute('61006', 'promotions'),
    BookingRoute('61007', 'calendar'),
    BookingRoute('61008', 'usage'),
    BookingRoute('61009', 'member-history'),
    BookingRoute('61010', 'dashboard'),
  ];
}

List<GoRoute> buildBookingRoutes() => BookingRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (context, state) => BookingPage(menuCode: route.menuCode),
      ),
    )
    .toList();
