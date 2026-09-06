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
