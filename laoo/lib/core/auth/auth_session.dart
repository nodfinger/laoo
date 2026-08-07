class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    this.userType,
    this.projectCode,
    this.projectId,
    this.companyId,
    this.branchId,
    this.userId,
    this.laooUserId,
  });

  final String accessToken;
  final DateTime expiresAt;

  final String? userType;
  final String? projectCode;

  final int? projectId;
  final int? companyId;
  final int? branchId;
  final int? userId;
  final int? laooUserId;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  AuthSession copyWith({
    String? userType,
    String? projectCode,
    int? projectId,
    int? companyId,
    int? branchId,
    int? userId,
    int? laooUserId,
  }) {
    return AuthSession(
      accessToken: accessToken,
      expiresAt: expiresAt,
      userType: userType ?? this.userType,
      projectCode: projectCode ?? this.projectCode,
      projectId: projectId ?? this.projectId,
      companyId: companyId ?? this.companyId,
      branchId: branchId ?? this.branchId,
      userId: userId ?? this.userId,
      laooUserId: laooUserId ?? this.laooUserId,
    );
  }
}
