import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';

void main() {
  test('Core person directory remains a ShowOnly route', () {
    final person = AppMenuRouteRegistry.byMenuCode('13002');

    expect(person, isNotNull);
    expect(person!.path, '/company/persons');
    expect(person.scope, AppMenuScope.company);
  });
}
