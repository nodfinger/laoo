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
