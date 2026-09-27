class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    this.userType,
    this.username,
    this.displayName,
    this.projectCode,
    this.projectId,
    this.partnerUserId,
    this.partnerId,
    this.companyId,
    this.branchId,
    this.userId,
    this.laooUserId,
  });

  final String accessToken;
  final DateTime expiresAt;

  final String? userType;
  final String? username;
  final String? displayName;
  final String? projectCode;

  final int? projectId;
  final int? partnerUserId;
  final int? partnerId;
  final int? companyId;
  final int? branchId;
  final int? userId;
  final int? laooUserId;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  AuthSession copyWith({
    String? userType,
    String? username,
    String? displayName,
    String? projectCode,
    int? projectId,
    int? partnerUserId,
    int? partnerId,
    int? companyId,
    int? branchId,
    int? userId,
    int? laooUserId,
  }) {
    return AuthSession(
      accessToken: accessToken,
      expiresAt: expiresAt,
      userType: userType ?? this.userType,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      projectCode: projectCode ?? this.projectCode,
      projectId: projectId ?? this.projectId,
      partnerUserId: partnerUserId ?? this.partnerUserId,
      partnerId: partnerId ?? this.partnerId,
      companyId: companyId ?? this.companyId,
      branchId: branchId ?? this.branchId,
      userId: userId ?? this.userId,
      laooUserId: laooUserId ?? this.laooUserId,
    );
  }
}
