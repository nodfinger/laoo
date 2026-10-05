import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_visitor/core/config/app_config.dart';
import 'package:laoo_visitor/features/visitor/visitor_inside_repository.dart';
import 'package:laoo_visitor/features/visitor/visitor_settings_repository.dart';
import 'package:laoo_visitor/visitor_feature.dart';

void main() {
  test('Visitor uses the Center API and reserved project catalog', () {
    expect(AppConfig.projectCode, 'LAOO_VISITOR');
    expect(AppConfig.apiBaseUrl, 'http://localhost:5080');
    expect(LaooOwnerScope.values, hasLength(3));
    expect(VisitorRoutes.all, hasLength(23));
    expect(VisitorRoutes.implemented, hasLength(8));
    expect(buildVisitorFeatureRoutes(), hasLength(11));
    expect(
      VisitorRoutes.all
          .singleWhere((route) => route.menuCode == '34003')
          .isImplemented,
      isTrue,
    );
  });

  test('maps the Core employee host contract into a Visitor host option', () {
    final host = VisitorHostOption.fromJson(const {
      'hostType': 'EMPLOYEE',
      'employeeId': 42,
      'displayName': 'สมชาย ใจดี',
      'phone': '0812345678',
      'branchId': 3,
      'branchName': 'สำนักงานใหญ่',
    });

    expect(host.id, 42);
    expect(host.name, 'สมชาย ใจดี');
    expect(host.phone, '0812345678');
    expect(host.building, 'สำนักงานใหญ่');
  });

  test('maps company identity used by the 50 mm visitor slip', () {
    final detail = VisitorVisitDetail.fromJson(const {
      'visit': {'visitorVisitId': 101, 'visitorName': 'ผู้มาติดต่อทดสอบ'},
      'company': {
        'companyName': 'บริษัทตัวอย่าง จำกัด',
        'logoPath': 'uploads/provider/companies/1/cover/logo.png',
      },
      'images': [],
      'notes': [],
      'notifications': [],
    });

    expect(detail.visit['visitorVisitId'], 101);
    expect(detail.company['companyName'], 'บริษัทตัวอย่าง จำกัด');
    expect(
      detail.company['logoPath'],
      'uploads/provider/companies/1/cover/logo.png',
    );
  });
}
