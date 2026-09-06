import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/navigation/navigation_menu.dart';

void main() {
  test('parses project, menu group, and main menu hierarchy', () {
    final project = NavigationProject.fromJson({
      'projectId': 4,
      'projectCode': 'LAOO_SERVICE',
      'projectName': 'ระบบแจ้งซ่อม',
      'projectType': 'BUSINESS',
      'iconName': 'home_repair_service_outlined',
      'isExpandedDefault': false,
      'menuGroups': [
        {
          'menuGroupCode': '08',
          'menuGroupName': 'รับแจ้งซ่อม',
          'isExpandedDefault': true,
          'items': [
            {
              'menuCode': '08001',
              'menuName': 'รายการแจ้งซ่อม',
              'routeName': 'company-service-requests',
              'routePath': '/company/service-requests',
              'isFavoriteAllowed': true,
            },
          ],
        },
      ],
    });

    expect(project.code, 'LAOO_SERVICE');
    expect(project.isCore, isFalse);
    expect(project.menuGroups, hasLength(1));
    expect(project.menuGroups.single.code, '08');
    expect(project.menuGroups.single.items.single.code, '08001');
  });

  test('identifies the center project as core', () {
    final project = NavigationProject.fromJson({
      'projectId': 1,
      'projectCode': 'LAOO',
      'projectName': 'ข้อมูลส่วนกลาง',
      'projectType': 'core',
      'menuGroups': <Map<String, Object?>>[],
    });

    expect(project.isCore, isTrue);
  });
}
