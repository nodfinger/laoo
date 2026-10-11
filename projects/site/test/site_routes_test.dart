import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_site/src/site_routes.dart';

void main() {
  test('SITE menu routes cover approved codes exactly once', () {
    final codes = SiteRoutes.all.map((route) => route.menuCode).toList();
    expect(codes, [
      '63001',
      '63002',
      '63003',
      '63004',
      '63005',
      '63006',
      '63007',
      '63008',
    ]);
    expect(codes.toSet().length, codes.length);
    expect(
      SiteRoutes.all.map((route) => route.routePath).toSet().length,
      codes.length,
    );
  });
}
