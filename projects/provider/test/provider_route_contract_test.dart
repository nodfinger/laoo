import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_provider/provider_feature.dart';

void main() {
  test('provider menu contracts are complete and unique', () {
    expect(ProviderRoutes.all.length, 9);
    expect(ProviderRoutes.all.map((x) => x.menuCode).toSet(), hasLength(9));
    expect(ProviderRoutes.all.map((x) => x.routePath).toSet(), hasLength(9));
    expect(
      ProviderRoutes.all.map((x) => x.screenType),
      orderedEquals([2, 1, 1, 2, 3, 1, 3, 3, 1]),
    );
    expect(ProviderRoutes.all.every((x) => x.isImplemented), isTrue);
  });
}
