import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class DocumentControlProject {
  static const code = 'LAOO_DOCUMENT';
}

abstract final class DocumentControlMenuCodes {
  static const settings = '48001';
  static const types = '48002';
  static const controlled = '48003';
  static const approvals = '48004';
  static const general = '48005';
  static const library = '48006';
  static const acknowledgements = '48007';
  static const reports = '48008';
}

abstract final class DocumentControlRouteNames {
  static const settings = 'documentControlSettings';
  static const types = 'documentTypes';
  static const controlled = 'controlledDocuments';
  static const approvals = 'documentApprovals';
  static const general = 'generalDocuments';
  static const library = 'documentLibrary';
  static const acknowledgements = 'documentAcknowledgements';
  static const reports = 'documentControlReports';
}

abstract final class DocumentControlRoutePaths {
  static const settings = '/company/document-control-settings';
  static const types = '/company/document-types';
  static const controlled = '/company/controlled-documents';
  static const approvals = '/company/document-approvals';
  static const general = '/company/general-documents';
  static const library = '/company/document-library';
  static const acknowledgements = '/company/document-acknowledgements';
  static const reports = '/company/document-control-reports';
}

abstract final class DocumentControlRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: DocumentControlProject.code,
      menuCode: DocumentControlMenuCodes.settings,
      screenType: 2,
      routeName: DocumentControlRouteNames.settings,
      routePath: DocumentControlRoutePaths.settings,
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: DocumentControlProject.code,
      menuCode: DocumentControlMenuCodes.types,
      screenType: 1,
      routeName: DocumentControlRouteNames.types,
      routePath: DocumentControlRoutePaths.types,
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: DocumentControlProject.code,
      menuCode: DocumentControlMenuCodes.controlled,
      screenType: 4,
      routeName: DocumentControlRouteNames.controlled,
      routePath: DocumentControlRoutePaths.controlled,
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: DocumentControlProject.code,
      menuCode: DocumentControlMenuCodes.approvals,
      screenType: 3,
      routeName: DocumentControlRouteNames.approvals,
      routePath: DocumentControlRoutePaths.approvals,
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: DocumentControlProject.code,
      menuCode: DocumentControlMenuCodes.general,
      screenType: 1,
      routeName: DocumentControlRouteNames.general,
      routePath: DocumentControlRoutePaths.general,
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: DocumentControlProject.code,
      menuCode: DocumentControlMenuCodes.library,
      screenType: 3,
      routeName: DocumentControlRouteNames.library,
      routePath: DocumentControlRoutePaths.library,
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: DocumentControlProject.code,
      menuCode: DocumentControlMenuCodes.acknowledgements,
      screenType: 3,
      routeName: DocumentControlRouteNames.acknowledgements,
      routePath: DocumentControlRoutePaths.acknowledgements,
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: DocumentControlProject.code,
      menuCode: DocumentControlMenuCodes.reports,
      screenType: 3,
      routeName: DocumentControlRouteNames.reports,
      routePath: DocumentControlRoutePaths.reports,
      isImplemented: true,
    ),
  ];
}
