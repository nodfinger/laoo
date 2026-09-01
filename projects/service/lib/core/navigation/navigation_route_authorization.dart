import 'navigation_menu.dart';
import 'navigation_menu_repository.dart';

typedef NavigationMenuLoader =
    Future<List<NavigationMenuGroup>> Function({bool refresh});

/// Loads the menu codes already filtered to VIEW permission by Navigation API.
///
/// The cache is bound to one authenticated session. A different session always
/// forces a fresh API request, so permissions cannot leak between users.
class NavigationRouteAuthorization {
  NavigationRouteAuthorization({NavigationMenuLoader? loadMenus})
    : _loadMenus = loadMenus ?? NavigationMenuRepository().getMenus;

  final NavigationMenuLoader _loadMenus;

  String? _sessionKey;
  Future<Set<String>>? _allowedMenuCodes;

  Future<Set<String>> allowedMenuCodes({
    required String sessionKey,
    bool refresh = false,
  }) {
    final sessionChanged = _sessionKey != sessionKey;
    if (sessionChanged) {
      _sessionKey = sessionKey;
      _allowedMenuCodes = null;
    }

    if (refresh) {
      _allowedMenuCodes = null;
    }

    return _allowedMenuCodes ??= _loadAllowedMenuCodes(
      refresh: refresh || sessionChanged,
    );
  }

  void clear() {
    _sessionKey = null;
    _allowedMenuCodes = null;
  }

  Future<Set<String>> _loadAllowedMenuCodes({required bool refresh}) async {
    try {
      final groups = await _loadMenus(refresh: refresh);
      return {
        for (final group in groups)
          for (final item in group.items)
            if (item.code.trim().isNotEmpty) item.code.trim(),
      };
    } catch (_) {
      // Do not pin a failed request in the cache; the next router refresh may
      // retry, while the current navigation remains fail-closed.
      _allowedMenuCodes = null;
      rethrow;
    }
  }
}
