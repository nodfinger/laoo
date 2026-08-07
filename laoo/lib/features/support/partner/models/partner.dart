class Partner {
  const Partner({
    required this.partnerId,
    required this.partnerCode,
    required this.partnerNameTh,
    required this.isActive,
    this.partnerNameEn,
    this.email,
    this.telephone,
    this.addressText,
    this.shortName,
    this.province,
    this.startContactDate,
    this.contactName1,
    this.contactPosition1,
    this.contactPhone1,
    this.contactEmail1,
    this.contactName2,
    this.contactPosition2,
    this.contactPhone2,
    this.contactEmail2,
    this.remark,
  });

  final int partnerId;
  final String partnerCode;
  final String partnerNameTh;
  final String? partnerNameEn;

  final String? email;
  final String? telephone;
  final String? addressText;

  final String? shortName;
  final String? province;
  final DateTime? startContactDate;

  final String? contactName1;
  final String? contactPosition1;
  final String? contactPhone1;
  final String? contactEmail1;

  final String? contactName2;
  final String? contactPosition2;
  final String? contactPhone2;
  final String? contactEmail2;

  final String? remark;
  final bool isActive;

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      partnerId: (json['partnerId'] as num).toInt(),
      partnerCode: json['partnerCode'] as String,
      partnerNameTh: json['partnerNameTh'] as String,
      partnerNameEn: json['partnerNameEn'] as String?,
      email: json['email'] as String?,
      telephone: json['telephone'] as String?,
      addressText: json['addressText'] as String?,
      shortName: json['shortName'] as String?,
      province: json['province'] as String?,
      startContactDate: json['startContactDate'] == null
          ? null
          : DateTime.parse(json['startContactDate'] as String),
      contactName1: json['contactName1'] as String?,
      contactPosition1: json['contactPosition1'] as String?,
      contactPhone1: json['contactPhone1'] as String?,
      contactEmail1: json['contactEmail1'] as String?,
      contactName2: json['contactName2'] as String?,
      contactPosition2: json['contactPosition2'] as String?,
      contactPhone2: json['contactPhone2'] as String?,
      contactEmail2: json['contactEmail2'] as String?,
      remark: json['remark'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class PartnerUpsertInput {
  const PartnerUpsertInput({
    required this.partnerNameTh,
    this.partnerNameEn,
    this.email,
    this.telephone,
    this.addressText,
    this.shortName,
    this.province,
    this.startContactDate,
    this.contactName1,
    this.contactPosition1,
    this.contactPhone1,
    this.contactEmail1,
    this.contactName2,
    this.contactPosition2,
    this.contactPhone2,
    this.contactEmail2,
    this.remark,
  });

  final String partnerNameTh;
  final String? partnerNameEn;

  final String? email;
  final String? telephone;
  final String? addressText;

  final String? shortName;
  final String? province;
  final DateTime? startContactDate;

  final String? contactName1;
  final String? contactPosition1;
  final String? contactPhone1;
  final String? contactEmail1;

  final String? contactName2;
  final String? contactPosition2;
  final String? contactPhone2;
  final String? contactEmail2;

  final String? remark;

  Map<String, dynamic> toJson() {
    return {
      'partnerNameTh': partnerNameTh,
      'partnerNameEn': partnerNameEn,
      'email': email,
      'telephone': telephone,
      'addressText': addressText,
      'shortName': shortName,
      'province': province,
      'startContactDate': startContactDate?.toIso8601String(),
      'contactName1': contactName1,
      'contactPosition1': contactPosition1,
      'contactPhone1': contactPhone1,
      'contactEmail1': contactEmail1,
      'contactName2': contactName2,
      'contactPosition2': contactPosition2,
      'contactPhone2': contactPhone2,
      'contactEmail2': contactEmail2,
      'remark': remark,
    };
  }
}
