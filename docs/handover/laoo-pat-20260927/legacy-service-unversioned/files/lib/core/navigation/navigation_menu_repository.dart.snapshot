import '../api/api_client.dart';
import 'navigation_menu.dart';

class NavigationMenuRepository {
  NavigationMenuRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();
  final ApiClient _api;

  Future<List<NavigationMenuGroup>>? _menuCache;
  static const Map<String, String> _routeFallbackNames = {
    'company': 'ผู้ใช้บริการ/ลูกค้า',
  };

  static String fallbackMenuName({
    String? menuCode,
    String? routeName,
    String fallback = '',
  }) {
    final normalizedRoute = routeName?.trim().toLowerCase();
    if (normalizedRoute != null) {
      final routeFallback = _routeFallbackNames[normalizedRoute];
      if (routeFallback != null) return routeFallback;
    }
    return fallback.isNotEmpty ? fallback : (routeName ?? menuCode ?? '');
  }

  Future<List<NavigationMenuGroup>> getMenus({bool refresh = false}) {
    if (refresh || _menuCache == null) {
      _menuCache = _loadMenus();
    }
    return _menuCache!;
  }

  Future<List<NavigationMenuGroup>> _loadMenus() async {
    final data = await _api.get('/api/navigation/menus');
    return (data as List<dynamic>)
        .map(
          (item) => NavigationMenuGroup.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<NavigationMenuItem?> findMenu({
    String? menuCode,
    String? routeName,
  }) async {
    final normalizedCode = menuCode?.trim().toLowerCase();
    final normalizedRoute = routeName?.trim().toLowerCase();
    final groups = await getMenus();
    for (final group in groups) {
      for (final item in group.items) {
        final codeMatches =
            normalizedCode != null &&
            item.code.trim().toLowerCase() == normalizedCode;
        final routeMatches =
            normalizedRoute != null &&
            item.routeName?.trim().toLowerCase() == normalizedRoute;
        if (codeMatches || routeMatches) return item;
      }
    }
    return null;
  }

  Future<String> resolveMenuName({
    String? menuCode,
    String? routeName,
    String fallback = '',
  }) async {
    final item = await findMenu(menuCode: menuCode, routeName: routeName);
    final name = item?.name.trim();
    return name == null || name.isEmpty
        ? fallbackMenuName(
            menuCode: menuCode,
            routeName: routeName,
            fallback: fallback,
          )
        : name;
  }
}
