class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Object? details;

  String? get description {
    if (details is Map) {
      final data = details as Map;
      final values = <String>[];
      for (final key in const ['description', 'detail', 'title']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty && !values.contains(value.trim())) {
          values.add(value.trim());
        }
      }
      final errors = data['errors'];
      if (errors is Map) {
        for (final entry in errors.entries) {
          final value = entry.value;
          if (value is List) {
            for (final item in value) {
              if (item.toString().trim().isNotEmpty) values.add('${entry.key}: ${item.toString().trim()}');
            }
          } else if (value.toString().trim().isNotEmpty) {
            values.add('${entry.key}: ${value.toString().trim()}');
          }
        }
      }
      if (values.isNotEmpty) return values.join('\n');
    }
    return null;
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    final detail = description;
    return 'ApiException$status: $message${detail == null ? '' : '\n$detail'}';
  }
}
