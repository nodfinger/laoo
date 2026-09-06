class ScreenContract {
  const ScreenContract({
    required this.menuCode,
    required this.routeName,
    required this.apiPath,
    required this.screenType,
    this.legacyPermissionCodes = const [],
  });

  final String menuCode;
  final String routeName;
  final String apiPath;
  final int screenType;
  final List<String> legacyPermissionCodes;
}

class FeatureRouteContract {
  const FeatureRouteContract({
    required this.projectCode,
    required this.menuCode,
    required this.screenType,
    required this.routeName,
    required this.routePath,
    this.goRouteName,
    this.isImplemented = true,
  });

  final String projectCode;
  final String menuCode;
  final int screenType;
  final String routeName;
  final String routePath;
  final String? goRouteName;
  final bool isImplemented;

  String get effectiveGoRouteName => goRouteName ?? routeName;
}
