import '../api/api_client.dart';
import 'navigation_menu.dart';

class NavigationMenuRepository {
  NavigationMenuRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;
  Future<List<NavigationMenuGroup>> getMenus() async {
    final data = await _api.get('/api/navigation/menus');
    return (data as List<dynamic>).map((item) => NavigationMenuGroup.fromJson(item as Map<String, dynamic>)).toList();
  }
}
