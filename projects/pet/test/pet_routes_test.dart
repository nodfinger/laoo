import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_pet/src/pet_routes.dart';

void main() {
  test('Pet menu routes cover 62001–62010 exactly once', () {
    final codes = PetRoutes.all.map((route) => route.menuCode).toList();
    expect(codes, [
      '62001',
      '62002',
      '62003',
      '62004',
      '62005',
      '62006',
      '62007',
      '62008',
      '62009',
      '62010',
    ]);
    expect(codes.toSet(), hasLength(codes.length));
  });

  test('every Pet route has a unique named Center path', () {
    final routes = buildPetRoutes();
    expect(routes, hasLength(PetRoutes.all.length));
    expect(routes.map((route) => route.path).toSet(),
        hasLength(PetRoutes.all.length));
    expect(routes.map((route) => route.name).toSet(),
        hasLength(PetRoutes.all.length));
    expect(routes.map((route) => route.path),
        contains('/company/pet-appointments'));
  });
}
