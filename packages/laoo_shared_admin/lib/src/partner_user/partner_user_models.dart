class PartnerUserRecord {
  const PartnerUserRecord({
    required this.partnerUserId,
    required this.partnerId,
    required this.username,
    required this.displayName,
    this.email,
    this.mobileNumber,
    required this.isPartnerAdmin,
    required this.isActive,
  });

  factory PartnerUserRecord.fromJson(Map<String, dynamic> json) =>
      PartnerUserRecord(
        partnerUserId: (json['partnerUserId'] as num).toInt(),
        partnerId: (json['partnerId'] as num).toInt(),
        username: (json['username'] ?? '').toString(),
        displayName: (json['displayName'] ?? '').toString(),
        email: json['email'] as String?,
        mobileNumber: json['mobileNumber'] as String?,
        isPartnerAdmin: json['isPartnerAdmin'] == true,
        isActive: json['isActive'] == true,
      );

  final int partnerUserId;
  final int partnerId;
  final String username;
  final String displayName;
  final String? email;
  final String? mobileNumber;
  final bool isPartnerAdmin;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'partnerUserId': partnerUserId,
    'partnerId': partnerId,
    'username': username,
    'displayName': displayName,
    'email': email,
    'mobileNumber': mobileNumber,
    'isPartnerAdmin': isPartnerAdmin,
    'isActive': isActive,
  };

  Object? operator [](String key) => toJson()[key];
}

class PartnerUserUpsertRequest {
  const PartnerUserUpsertRequest({
    required this.username,
    this.password,
    required this.displayName,
    this.email,
    this.mobileNumber,
    required this.isPartnerAdmin,
    this.isActive = true,
  });

  factory PartnerUserUpsertRequest.fromJson(Map<String, dynamic> json) =>
      PartnerUserUpsertRequest(
        username: (json['username'] ?? '').toString(),
        password: json['password'] as String?,
        displayName: (json['displayName'] ?? '').toString(),
        email: json['email'] as String?,
        mobileNumber: json['mobileNumber'] as String?,
        isPartnerAdmin: json['isPartnerAdmin'] == true,
        isActive: json['isActive'] != false,
      );

  final String username;
  final String? password;
  final String displayName;
  final String? email;
  final String? mobileNumber;
  final bool isPartnerAdmin;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'username': username,
    if (password != null && password!.isNotEmpty) 'password': password,
    'displayName': displayName,
    'email': email,
    'mobileNumber': mobileNumber,
    'isPartnerAdmin': isPartnerAdmin,
    'isActive': isActive,
  };
}
