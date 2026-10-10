import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_rental/src/rental_routes.dart';

void main() {
  test('Rental menu routes cover 60001–60010 exactly once', () {
    final codes = RentalRoutes.all.map((route) => route.menuCode).toList();
    expect(codes, [
      '60001',
      '60002',
      '60003',
      '60004',
      '60005',
      '60006',
      '60007',
      '60008',
      '60009',
      '60010',
    ]);
    expect(codes.toSet(), hasLength(codes.length));
  });

  test('every Rental route has a unique named Center path', () {
    final routes = buildRentalRoutes();
    expect(routes, hasLength(RentalRoutes.all.length));
    expect(routes.map((route) => route.path).toSet(),
        hasLength(RentalRoutes.all.length));
    expect(routes.map((route) => route.name).toSet(),
        hasLength(RentalRoutes.all.length));
  });
}
