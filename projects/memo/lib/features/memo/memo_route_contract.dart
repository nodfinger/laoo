import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class MemoProject {
  static const code = 'LAOO_MEMO';
}

abstract final class MemoMenuCodes {
  static const settings = '50001',
      types = '50002',
      routes = '50003',
      templates = '50004',
      memos = '50005',
      approvals = '50006',
      inbox = '50007',
      history = '50008',
      reports = '50009';
}

abstract final class MemoRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: MemoProject.code,
      menuCode: '50001',
      screenType: 2,
      routeName: 'memoSettings',
      routePath: '/company/memo-settings',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: MemoProject.code,
      menuCode: '50002',
      screenType: 1,
      routeName: 'memoTypes',
      routePath: '/company/memo-types',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: MemoProject.code,
      menuCode: '50003',
      screenType: 1,
      routeName: 'memoApprovalRoutes',
      routePath: '/company/memo-approval-routes',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: MemoProject.code,
      menuCode: '50004',
      screenType: 1,
      routeName: 'memoTemplates',
      routePath: '/company/memo-templates',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: MemoProject.code,
      menuCode: '50005',
      screenType: 4,
      routeName: 'memos',
      routePath: '/company/memos',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: MemoProject.code,
      menuCode: '50006',
      screenType: 3,
      routeName: 'memoApprovals',
      routePath: '/company/memo-approvals',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: MemoProject.code,
      menuCode: '50007',
      screenType: 3,
      routeName: 'memoInbox',
      routePath: '/company/memo-inbox',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: MemoProject.code,
      menuCode: '50008',
      screenType: 3,
      routeName: 'memoHistory',
      routePath: '/company/memo-history',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: MemoProject.code,
      menuCode: '50009',
      screenType: 3,
      routeName: 'memoReports',
      routePath: '/company/memo-reports',
      isImplemented: true,
    ),
  ];
}
