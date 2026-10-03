import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_school/school_feature.dart';

void main() {
  test('school exposes 14 unique menu routes', () {
    expect(SchoolRoutes.all, hasLength(14));
    expect(SchoolRoutes.all.map((x) => x.menuCode).toSet().length, 14);
    expect(SchoolRoutes.all.map((x) => x.routeName).toSet().length, 14);
    expect(SchoolRoutes.all.map((x) => x.routePath).toSet().length, 14);
    expect(SchoolRoutes.all.every((x) => x.menuCode.startsWith('520')), isTrue);
  });
}
