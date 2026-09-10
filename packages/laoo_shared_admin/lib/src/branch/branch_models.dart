class BranchRecord {
  const BranchRecord({
    required this.branchId,
    required this.companyId,
    required this.companyName,
    required this.branchCode,
    required this.branchNameTh,
    this.branchNameEn,
    this.email,
    this.telephone,
    this.addressText,
    this.contName,
    this.contPhone,
    this.contPositionName,
    required this.isActive,
  });

  factory BranchRecord.fromJson(Map<String, dynamic> json) => BranchRecord(
    branchId: (json['branchId'] as num).toInt(),
    companyId: (json['companyId'] as num).toInt(),
    companyName: '${json['companyName'] ?? ''}',
    branchCode: '${json['branchCode'] ?? ''}',
    branchNameTh: '${json['branchNameTh'] ?? ''}',
    branchNameEn: json['branchNameEn'] as String?,
    email: json['email'] as String?,
    telephone: json['telephone'] as String?,
    addressText: json['addressText'] as String?,
    contName: json['contName'] as String?,
    contPhone: json['contPhone'] as String?,
    contPositionName: json['contPositionName'] as String?,
    isActive: json['isActive'] == true,
  );

  final int branchId;
  final int companyId;
  final String companyName;
  final String branchCode;
  final String branchNameTh;
  final String? branchNameEn;
  final String? email;
  final String? telephone;
  final String? addressText;
  final String? contName;
  final String? contPhone;
  final String? contPositionName;
  final bool isActive;

  // Transitional indexer keeps existing screens compatible while they move
  // from dynamic maps to typed properties.
  Object? operator [](String key) => switch (key) {
    'branchId' => branchId,
    'companyId' => companyId,
    'companyName' => companyName,
    'branchCode' => branchCode,
    'branchNameTh' => branchNameTh,
    'branchNameEn' => branchNameEn,
    'email' => email,
    'telephone' => telephone,
    'addressText' => addressText,
    'contName' => contName,
    'contPhone' => contPhone,
    'contPositionName' => contPositionName,
    'isActive' => isActive,
    _ => null,
  };
}

class BranchUpsertRequest {
  const BranchUpsertRequest({
    required this.companyId,
    required this.branchCode,
    required this.branchNameTh,
    this.branchNameEn,
    this.email,
    this.telephone,
    this.addressText,
    this.contName,
    this.contPhone,
    this.contPositionName,
    this.isActive = true,
  });

  final int? companyId;
  final String branchCode;
  final String branchNameTh;
  final String? branchNameEn;
  final String? email;
  final String? telephone;
  final String? addressText;
  final String? contName;
  final String? contPhone;
  final String? contPositionName;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'branchCode': branchCode,
    'branchNameTh': branchNameTh,
    'branchNameEn': branchNameEn,
    'email': email,
    'telephone': telephone,
    'addressText': addressText,
    'contName': contName,
    'contPhone': contPhone,
    'contPositionName': contPositionName,
    'isActive': isActive,
  };
}

class BranchAccessUser {
  const BranchAccessUser({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.isSelected,
  });

  factory BranchAccessUser.fromJson(Map<String, dynamic> json) =>
      BranchAccessUser(
        userId: (json['userId'] as num).toInt(),
        username: '${json['username'] ?? ''}',
        displayName: '${json['displayName'] ?? ''}',
        isSelected: json['isSelected'] == true,
      );

  final int userId;
  final String username;
  final String displayName;
  final bool isSelected;
}

class BranchAccessConfiguration {
  const BranchAccessConfiguration({
    required this.branchId,
    required this.branchCode,
    required this.branchName,
    required this.accessModeCode,
    required this.users,
  });

  factory BranchAccessConfiguration.fromJson(Map<String, dynamic> json) =>
      BranchAccessConfiguration(
        branchId: (json['branchId'] as num).toInt(),
        branchCode: '${json['branchCode'] ?? ''}',
        branchName: '${json['branchName'] ?? ''}',
        accessModeCode: '${json['accessModeCode'] ?? 'RESTRICTED'}',
        users: (json['users'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  BranchAccessUser.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
      );

  final int branchId;
  final String branchCode;
  final String branchName;
  final String accessModeCode;
  final List<BranchAccessUser> users;
}
