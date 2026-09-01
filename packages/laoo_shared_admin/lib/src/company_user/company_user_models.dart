class CompanyUserRecord {
  const CompanyUserRecord({
    required this.userId,
    required this.companyId,
    required this.companyCode,
    required this.companyName,
    required this.username,
    required this.displayName,
    this.email,
    this.mobile,
    required this.isCompanyAdmin,
    required this.isActive,
  });

  factory CompanyUserRecord.fromJson(Map<String, dynamic> json) =>
      CompanyUserRecord(
        userId: (json['userId'] as num).toInt(),
        companyId: (json['companyId'] as num).toInt(),
        companyCode: (json['companyCode'] ?? '').toString(),
        companyName: (json['companyName'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        displayName: (json['displayName'] ?? '').toString(),
        email: json['email'] as String?,
        mobile: json['mobile'] as String?,
        isCompanyAdmin: json['isCompanyAdmin'] == true,
        isActive: json['isActive'] == true,
      );

  final int userId;
  final int companyId;
  final String companyCode;
  final String companyName;
  final String username;
  final String displayName;
  final String? email;
  final String? mobile;
  final bool isCompanyAdmin;
  final bool isActive;
}

class CompanyUserUpdateRequest {
  const CompanyUserUpdateRequest({
    required this.username,
    this.password,
    required this.displayName,
    this.email,
    this.mobile,
    required this.isActive,
  });

  final String username;
  final String? password;
  final String displayName;
  final String? email;
  final String? mobile;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'username': username,
    if (password != null && password!.isNotEmpty) 'password': password,
    'displayName': displayName,
    'email': email,
    'mobile': mobile,
    'isActive': isActive,
  };
}
