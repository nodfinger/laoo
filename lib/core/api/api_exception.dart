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
    if (details is! Map) return null;
    final data = details as Map;
    final values = <String>[];
    for (final key in const ['description', 'detail', 'title']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        values.add(value.trim());
      }
    }
    final errors = data['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final items = entry.value is List ? entry.value as List : [entry.value];
        for (final item in items) {
          final text = item.toString().trim();
          if (text.isNotEmpty) values.add('${entry.key}: $text');
        }
      }
    }
    return values.isEmpty ? null : values.toSet().join('\n');
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  @override
  String toString() {
    if (isConflict) {
      return 'ไม่สามารถดำเนินการได้ เนื่องจากข้อมูลยังถูกใช้งานอยู่';
    }
    final status = statusCode == null ? '' : ' ($statusCode)';
    return 'ApiException$status: $message';
  }
}
