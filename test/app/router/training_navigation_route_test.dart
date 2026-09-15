import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/app/router/route_names.dart';
import 'package:laoo/app/router/route_paths.dart';

void main() {
  test('Training master menus retain their approved Core route contracts', () {
    final trainingTypes = AppMenuRouteRegistry.byMenuCode('37001');
    final trainingInstructors = AppMenuRouteRegistry.byMenuCode('37002');

    expect(trainingTypes, isNotNull);
    expect(trainingTypes!.databaseRouteName, 'trainingTypes');
    expect(trainingTypes.goRouteName, RouteNames.trainingTypes);
    expect(trainingTypes.path, RoutePaths.trainingTypes);
    expect(trainingTypes.scope, AppMenuScope.company);

    expect(trainingInstructors, isNotNull);
    expect(trainingInstructors!.databaseRouteName, 'trainingInstructors');
    expect(trainingInstructors.goRouteName, RouteNames.trainingInstructors);
    expect(trainingInstructors.path, RoutePaths.trainingInstructors);
    expect(trainingInstructors.scope, AppMenuScope.company);
  });
}
