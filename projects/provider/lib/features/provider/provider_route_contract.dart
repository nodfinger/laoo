import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class ProviderProject {
  static const code = 'LAOO_PROVIDER';
}

abstract final class ProviderMenuCodes {
  static const settings = '51001',
      locations = '51002',
      serviceTypes = '51003',
      profile = '51004',
      approvals = '51005',
      reviewLinks = '51006',
      reviews = '51007',
      reports = '51008',
      portfolio = '51009';
}

abstract final class ProviderRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: ProviderProject.code,
      menuCode: '51001',
      screenType: 2,
      routeName: 'providerSettings',
      routePath: '/company/provider-settings',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: ProviderProject.code,
      menuCode: '51002',
      screenType: 1,
      routeName: 'providerLocations',
      routePath: '/company/provider-locations',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: ProviderProject.code,
      menuCode: '51003',
      screenType: 1,
      routeName: 'providerServiceTypes',
      routePath: '/company/provider-service-types',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: ProviderProject.code,
      menuCode: '51004',
      screenType: 2,
      routeName: 'providerProfile',
      routePath: '/company/provider-profile',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: ProviderProject.code,
      menuCode: '51005',
      screenType: 3,
      routeName: 'providerApprovals',
      routePath: '/company/provider-approvals',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: ProviderProject.code,
      menuCode: '51006',
      screenType: 1,
      routeName: 'providerReviewLinks',
      routePath: '/company/provider-review-links',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: ProviderProject.code,
      menuCode: '51007',
      screenType: 3,
      routeName: 'providerReviews',
      routePath: '/company/provider-reviews',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: ProviderProject.code,
      menuCode: '51008',
      screenType: 3,
      routeName: 'providerReports',
      routePath: '/company/provider-reports',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: ProviderProject.code,
      menuCode: '51009',
      screenType: 1,
      routeName: 'providerPortfolio',
      routePath: '/company/provider-portfolio',
      isImplemented: true,
    ),
  ];
}
