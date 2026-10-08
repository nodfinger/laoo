import 'package:go_router/go_router.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'digital_checklist_page.dart';

abstract final class DigitalChecklistProject {
  static const code = 'LAOO_DIGITAL_CHECKLIST';
}

abstract final class DigitalChecklistRoutes {
  static const _codes = [
    '58001',
    '58002',
    '58003',
    '58004',
    '58005',
    '58006',
    '58007',
    '58008',
    '58009',
    '58010',
  ];
  static const _names = [
    'digital-checklist-settings',
    'digital-checklist-groups',
    'digital-checklist-templates',
    'digital-checklist-workflows',
    'digital-checklist-schedules',
    'digital-checklist-inspections',
    'digital-checklist-approvals',
    'digital-checklist-corrective',
    'digital-checklist-audit',
    'digital-checklist-dashboard',
  ];
  static const _screens = [2, 1, 1, 1, 1, 4, 3, 3, 3, 3];
  static List<FeatureRouteContract> get all => List.generate(
    10,
    (i) => FeatureRouteContract(
      projectCode: DigitalChecklistProject.code,
      menuCode: _codes[i],
      screenType: _screens[i],
      routeName: _names[i],
      routePath: '/company/${_names[i]}',
      isImplemented: true,
    ),
    growable: false,
  );
}

List<GoRoute> buildDigitalChecklistFeatureRoutes() => DigitalChecklistRoutes.all
    .map(
      (r) => GoRoute(
        path: r.routePath,
        name: r.routeName,
        builder: (_, _) => DigitalChecklistPage(menuCode: r.menuCode),
      ),
    )
    .toList(growable: false);
