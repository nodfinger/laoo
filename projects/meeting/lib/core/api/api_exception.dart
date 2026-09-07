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
        if (value is String &&
            value.trim().isNotEmpty &&
            !values.contains(value.trim())) {
          values.add(value.trim());
        }
      }
      final errors = data['errors'];
      if (errors is Map) {
        for (final entry in errors.entries) {
          final value = entry.value;
          if (value is List) {
            for (final item in value) {
              if (item.toString().trim().isNotEmpty) {
                values.add('${entry.key}: ${item.toString().trim()}');
              }
            }
          } else if (value.toString().trim().isNotEmpty) {
            values.add('${entry.key}: ${value.toString().trim()}');
          }
        }
      }
      values.removeWhere(message.contains);
      if (values.isNotEmpty) {
        return values.join('\n');
      }
    }
    if (message.contains('รายละเอียดเพิ่มเติม:')) return null;
    return _fallbackDescription;
  }

  String get _fallbackDescription => switch (statusCode) {
    401 => 'Session หมดอายุหรือยังไม่ได้เข้าสู่ระบบ กรุณาเข้าสู่ระบบใหม่',
    403 =>
      'บัญชีนี้ไม่มีสิทธิ์ดำเนินการ กรุณาติดต่อผู้ดูแลระบบเพื่อตรวจสอบสิทธิ์',
    404 => 'ไม่พบข้อมูลหรือบริการที่ร้องขอ กรุณาตรวจสอบรายการแล้วลองใหม่',
    408 || 504 => 'ระบบใช้เวลาตอบสนองนานเกินไป กรุณาลองใหม่อีกครั้ง',
    409 =>
      'ข้อมูลมีการเปลี่ยนแปลงหรือกำลังถูกใช้งาน กรุณาโหลดข้อมูลใหม่แล้วลองอีกครั้ง',
    422 => 'ข้อมูลบางรายการไม่ถูกต้อง กรุณาตรวจสอบข้อมูลที่กรอกแล้วลองใหม่',
    int value when value >= 500 =>
      'ระบบฝั่งเซิร์ฟเวอร์ขัดข้อง กรุณาลองใหม่อีกครั้งหรือติดต่อผู้ดูแลระบบ',
    _ =>
      'ไม่สามารถดำเนินการได้ กรุณาลองใหม่อีกครั้ง หากยังพบปัญหาให้ติดต่อผู้ดูแลระบบ',
  };

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}
