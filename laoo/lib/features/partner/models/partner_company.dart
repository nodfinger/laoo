class PartnerCompany {
  const PartnerCompany({
    required this.companyId,
    required this.companyCode,
    required this.companyNameTh,
    required this.isActive,
    this.partnerNameTh,
    this.companyNameEn,
    this.taxId,
    this.email,
    this.telephone,
    this.addressText,
    this.adminUsername,
  });
  final int companyId;
  final String companyCode;
  final String companyNameTh;
  final String? partnerNameTh;
  final String? companyNameEn;
  final String? taxId;
  final String? email;
  final String? telephone;
  final String? addressText;
  final bool isActive;
  final String? adminUsername;
  factory PartnerCompany.fromJson(Map<String, dynamic> json) => PartnerCompany(
    companyId: (json['companyId'] as num).toInt(),
    companyCode: json['companyCode'] as String,
    companyNameTh: json['companyNameTh'] as String,
    partnerNameTh: json['partnerNameTh'] as String?,
    companyNameEn: json['companyNameEn'] as String?,
    taxId: json['taxId'] as String?,
    email: json['email'] as String?,
    telephone: json['telephone'] as String?,
    addressText: json['addressText'] as String?,
    isActive: json['isActive'] as bool? ?? true,
    adminUsername: json['adminUsername'] as String?,
  );
}

class PartnerCompanyInput {
  const PartnerCompanyInput({
    required this.companyNameTh,
    this.isActive = true,
    this.companyNameEn,
    this.taxId,
    this.email,
    this.telephone,
    this.addressText,
    this.adminUsername,
    this.adminPassword,
  });
  final String companyNameTh;
  final bool isActive;
  final String? companyNameEn;
  final String? taxId;
  final String? email;
  final String? telephone;
  final String? addressText;
  final String? adminUsername;
  final String? adminPassword;
  Map<String, dynamic> toJson() => {
    'companyNameTh': companyNameTh,
    'isActive': isActive,
    'companyNameEn': companyNameEn,
    'taxId': taxId,
    'email': email,
    'telephone': telephone,
    'addressText': addressText,
    'adminUsername': adminUsername,
    'adminPassword': adminPassword,
  };
}
