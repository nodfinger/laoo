import '../network/http_service.dart';

class UserFavorite {
  const UserFavorite({
    required this.menuCode,
    required this.menuName,
    this.routeName,
    this.routePath,
    this.iconName,
    this.sortOrder = 0,
  });

  final String menuCode;
  final String menuName;
  final String? routeName;
  final String? routePath;
  final String? iconName;
  final int sortOrder;

  factory UserFavorite.fromJson(Map<String, dynamic> json) => UserFavorite(
    menuCode: json['menuCode'] as String,
    menuName: json['menuName'] as String,
    routeName: json['routeName'] as String?,
    routePath: json['routePath'] as String?,
    iconName: json['iconName'] as String?,
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
  );
}

class UserFavoriteRepository {
  UserFavoriteRepository({HttpService? client})
    : _client = client ?? HttpService();
  final HttpService _client;

  Future<List<UserFavorite>> getAll() async {
    final data = await _client.get('/api/user-favorites') as List<dynamic>;
    return data
        .map((e) => UserFavorite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(String menuCode, {int sortOrder = 0}) async {
    await _client.post(
      '/api/user-favorites',
      body: {'menuCode': menuCode, 'sortOrder': sortOrder},
    );
  }

  Future<void> remove(String menuCode) async {
    await _client.delete('/api/user-favorites/$menuCode');
  }
}
