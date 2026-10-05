import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_router.dart';
import 'package:laoo/app/router/route_paths.dart';

void main() {
  String? redirect(String path) => resolveAppRouteRedirect(
    path: path,
    isChecking: false,
    isAuthenticated: false,
    isLaooSupport: false,
    isCompanyUser: false,
    isPartnerUser: false,
  );
  test(
    'student portal entry is public but company operations are protected',
    () {
      expect(redirect('/school/student/food'), isNull);
      expect(redirect('/school/guardian/food'), isNull);
      expect(redirect('/school/student/food/admin'), RoutePaths.login);
      expect(redirect('/company/school-food-pos'), RoutePaths.login);
      expect(redirect('/company/school-food-wallet'), RoutePaths.login);
    },
  );
}
