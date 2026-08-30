class NavigationMenuGroup {
  const NavigationMenuGroup({required this.code, required this.name, required this.items, this.iconName, this.isExpandedDefault = false});
  final String code;
  final String name;
  final String? iconName;
  final bool isExpandedDefault;
  final List<NavigationMenuItem> items;
  factory NavigationMenuGroup.fromJson(Map<String, dynamic> json) => NavigationMenuGroup(code: (json['menuGroupCode'] as String).trim(), name: json['menuGroupName'] as String, iconName: json['iconName'] as String?, isExpandedDefault: json['isExpandedDefault'] as bool? ?? false, items: ((json['items'] as List<dynamic>?) ?? const []).map((item) => NavigationMenuItem.fromJson(item as Map<String, dynamic>)).toList());
}

class NavigationMenuItem {
  const NavigationMenuItem({required this.code, required this.name, this.routeName, this.routePath, this.featureCode, this.iconName, this.isFavoriteAllowed = false});
  final String code;
  final String name;
  final String? routeName;
  final String? routePath;
  final String? featureCode;
  final String? iconName;
  final bool isFavoriteAllowed;
  factory NavigationMenuItem.fromJson(Map<String, dynamic> json) => NavigationMenuItem(code: json['menuCode'] as String, name: json['menuName'] as String, routeName: json['routeName'] as String?, routePath: json['routePath'] as String?, featureCode: json['featureCode'] as String?, iconName: json['iconName'] as String?, isFavoriteAllowed: json['isFavoriteAllowed'] as bool? ?? false);
}
