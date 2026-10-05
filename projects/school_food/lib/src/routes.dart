import 'package:go_router/go_router.dart';
import 'school_food_page.dart';
import 'food_portal_page.dart';

class FoodRoute {
  const FoodRoute(this.menuCode, this.slug);
  final String menuCode, slug;
  String get routeName => 'school-food-$slug';
  String get routePath => '/company/$routeName';
}

abstract final class SchoolFoodRoutes {
  static const all = [
    FoodRoute('53001', 'settings'),
    FoodRoute('53002', 'shops'),
    FoodRoute('53003', 'items'),
    FoodRoute('53004', 'commission'),
    FoodRoute('53005', 'identifiers'),
    FoodRoute('53006', 'transfers'),
    FoodRoute('53007', 'wallet'),
    FoodRoute('53008', 'pos'),
    FoodRoute('53009', 'sales'),
    FoodRoute('53010', 'students'),
    FoodRoute('53011', 'settlements'),
    FoodRoute('53012', 'dashboard'),
  ];
}

List<GoRoute> buildSchoolFoodRoutes() => [
  GoRoute(
    path: '/school/student/food',
    builder: (context, state) => const FoodPortalPage(),
  ),
  GoRoute(
    path: '/school/guardian/food',
    builder: (context, state) => FoodPortalPage(
      guardian: true,
      initialToken: state.extra is String ? state.extra as String : null,
    ),
  ),
  ...SchoolFoodRoutes.all.map(
    (r) => GoRoute(
      path: r.routePath,
      name: r.routeName,
      builder: (context, state) => SchoolFoodPage(menuCode: r.menuCode),
    ),
  ),
];
