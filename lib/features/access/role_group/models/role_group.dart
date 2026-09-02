class RoleGroup {
  const RoleGroup({
    required this.id,
    required this.scope,
    required this.code,
    required this.name,
    this.description,
    required this.isActive,
  });
  final int id;
  final String scope;
  final String code;
  final String name;
  final String? description;
  final bool isActive;
  factory RoleGroup.fromJson(Map<String, dynamic> json) => RoleGroup(
    id: (json['roleGroupId'] as num).toInt(),
    scope: json['scope'] as String? ?? '',
    code: json['roleCode'] as String? ?? '',
    name: json['roleNameTh'] as String? ?? '',
    description: json['description'] as String?,
    isActive: _readActive(json['isActive']),
  );
  Map<String, dynamic> toJson() => {
    'roleCode': code,
    'roleNameTh': name,
    'description': description,
    'isActive': isActive,
  };
}

bool _readActive(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true' || value == '1';
  return true;
}
