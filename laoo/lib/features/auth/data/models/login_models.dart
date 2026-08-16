class LoginRequest {
  const LoginRequest({
    required this.username,
    required this.password,
    required this.projectCode,
  });

  final String username;
  final String password;
  final String projectCode;

  Map<String, dynamic> toJson() {
    return {
      'Username': username,
      'Password': password,
      'ProjectCode': projectCode,
    };
  }
}

class LoginUser {
  const LoginUser({
    required this.loginMode,
    required this.projectId,
    required this.projectCode,
    required this.username,
    required this.displayName,
    required this.canLoginAsUser,
    required this.showSupportBanner,
    this.laooUserId,
    this.userId,
    this.companyId,
    this.branchId,
  });

  final String loginMode;
  final int? laooUserId;
  final int? userId;
  final int? companyId;
  final int? branchId;
  final int projectId;
  final String projectCode;
  final String username;
  final String displayName;
  final bool canLoginAsUser;
  final bool showSupportBanner;

  factory LoginUser.fromJson(Map<String, dynamic> json) {
    return LoginUser(
      loginMode: json['loginMode'] as String? ?? '',
      laooUserId: _toNullableInt(json['laooUserId']),
      userId: _toNullableInt(json['userId']),
      companyId: _toNullableInt(json['companyId']),
      branchId: _toNullableInt(json['branchId']),
      projectId: _toInt(json['projectId']),
      projectCode: json['projectCode'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      canLoginAsUser: json['canLoginAsUser'] as bool? ?? false,
      showSupportBanner: json['showSupportBanner'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'loginMode': loginMode,
      'laooUserId': laooUserId,
      'userId': userId,
      'companyId': companyId,
      'branchId': branchId,
      'projectId': projectId,
      'projectCode': projectCode,
      'username': username,
      'displayName': displayName,
      'canLoginAsUser': canLoginAsUser,
      'showSupportBanner': showSupportBanner,
    };
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }
}

class LoginResult {
  const LoginResult({
    required this.success,
    required this.message,
    this.accessToken,
    this.expiresAt,
    this.user,
  });

  final bool success;
  final String message;
  final String? accessToken;
  final DateTime? expiresAt;
  final LoginUser? user;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];

    return LoginResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? 'เกิดข้อผิดพลาด',
      accessToken: json['accessToken'] as String?,
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      user: userJson is Map<String, dynamic>
          ? LoginUser.fromJson(userJson)
          : userJson is Map
          ? LoginUser.fromJson(
              userJson.map((key, value) => MapEntry(key.toString(), value)),
            )
          : null,
    );
  }
}
