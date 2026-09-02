class CompanySetupModel {
  const CompanySetupModel({
    required this.ownerType,
    required this.ownerCode,
    required this.ownerName,
    this.customerNameTh,
    this.customerNameEn,
    this.addressText,
    this.telephone,
    this.taxId,
    this.customerEmail,
    required this.name,
    required this.titleHeader,
    this.runItem,
    this.markItem,
    this.itemDigit = 3,
    this.runCus,
    this.markCus,
    this.customerDigit = 5,
    required this.rowStd,
    required this.rowCardStd,
    required this.timeAlert,
    required this.orgStructureType,
    required this.passwordPolicyCode,
    required this.isActive,
    required this.hasSuperUser,
    required this.hasPasswordCry,
    required this.hasEmailPasswordCenter,
    required this.hasPasswordEmpDefault,
    required this.hasPasswordDirect,
    this.pkValue,
    this.partnerId,
    this.partnerNameTh,
    this.partnerAddress,
    this.partnerTelephone,
    this.partnerEmail,
    this.companyId,
    this.yearFormat,
    this.versionId,
    this.emailHost,
    this.emailPort,
    this.emailCenter,
    this.emailAdmin,
    this.createDate,
    this.createBy,
    this.updateDate,
    this.updateBy,
  });

  final int? pkValue;
  final String ownerType;
  final int? partnerId;
  final String? partnerNameTh;
  final String? partnerAddress;
  final String? partnerTelephone;
  final String? partnerEmail;
  final int? companyId;
  final String ownerCode;
  final String ownerName;
  final String? customerNameTh;
  final String? customerNameEn;
  final String? addressText;
  final String? telephone;
  final String? taxId;
  final String? customerEmail;
  final String name;
  final String titleHeader;
  final String? runItem;
  final String? markItem;
  final int itemDigit;
  final String? runCus;
  final String? markCus;
  final int customerDigit;
  final int rowStd;
  final int rowCardStd;
  final int timeAlert;
  final int orgStructureType;
  final int passwordPolicyCode;
  final String? yearFormat;
  final String? versionId;
  final String? emailHost;
  final int? emailPort;
  final String? emailCenter;
  final String? emailAdmin;
  final bool isActive;
  final String? createDate;
  final int? createBy;
  final String? updateDate;
  final int? updateBy;
  final bool hasSuperUser;
  final bool hasPasswordCry;
  final bool hasEmailPasswordCenter;
  final bool hasPasswordEmpDefault;
  final bool hasPasswordDirect;

  factory CompanySetupModel.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic value) =>
        value == null ? null : int.tryParse(value.toString());

    bool asBool(dynamic value) =>
        value == true || value?.toString().toLowerCase() == 'true';

    return CompanySetupModel(
      pkValue: asInt(json['pkValue']),
      ownerType: json['ownerType']?.toString() ?? '',
      partnerId: asInt(json['partnerID']) ?? asInt(json['partnerId']),
      partnerNameTh: json['partnerNameTh']?.toString(),
      partnerAddress: json['partnerAddress']?.toString(),
      partnerTelephone: json['partnerTelephone']?.toString(),
      partnerEmail: json['partnerEmail']?.toString(),
      companyId: asInt(json['companyID']) ?? asInt(json['companyId']),
      ownerCode: json['ownerCode']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      customerNameTh: json['customerNameTh']?.toString(),
      customerNameEn: json['customerNameEn']?.toString(),
      addressText: json['addressText']?.toString(),
      telephone: json['telephone']?.toString(),
      taxId: json['taxID']?.toString() ?? json['taxId']?.toString(),
      customerEmail: json['customerEmail']?.toString(),
      name: json['name']?.toString() ?? '',
      titleHeader: json['titleHeader']?.toString() ?? '',
      runItem: json['runItem']?.toString(),
      markItem: json['markItem']?.toString(),
      itemDigit: asInt(json['itemDigit']) ?? 3,
      runCus: json['runCus']?.toString(),
      markCus: json['markCus']?.toString(),
      customerDigit: asInt(json['customerDigit']) ?? 5,
      rowStd: asInt(json['rowSTD']) ?? asInt(json['rowStd']) ?? 30,
      rowCardStd: asInt(json['rowCardSTD']) ?? asInt(json['rowCardStd']) ?? 30,
      timeAlert: asInt(json['timeAlert']) ?? 30,
      orgStructureType: asInt(json['orgStructureType']) ?? 1,
      passwordPolicyCode: asInt(json['passwordPolicyCode']) ?? 3,
      yearFormat: json['yearFormat']?.toString(),
      versionId: json['versionID']?.toString() ?? json['versionId']?.toString(),
      emailHost: json['emailHost']?.toString(),
      emailPort: asInt(json['emailPort']),
      emailCenter: json['emailCenter']?.toString(),
      emailAdmin: json['emailAdmin']?.toString(),
      isActive: asBool(json['isActive']),
      createDate: json['createDate']?.toString(),
      createBy: asInt(json['createBy']),
      updateDate: json['updateDate']?.toString(),
      updateBy: asInt(json['updateBy']),
      hasSuperUser: asBool(json['hasSuperUser']),
      hasPasswordCry: asBool(json['hasPasswordCry']),
      hasEmailPasswordCenter: asBool(json['hasEmailPasswordCenter']),
      hasPasswordEmpDefault: asBool(json['hasPasswordEmpDefault']),
      hasPasswordDirect: asBool(json['hasPasswordDirect']),
    );
  }
}

class CompanySetupUpdateInput {
  const CompanySetupUpdateInput({
    this.customerNameTh,
    this.customerNameEn,
    this.addressText,
    this.telephone,
    this.taxId,
    this.customerEmail,
    required this.name,
    required this.titleHeader,
    this.runItem,
    this.markItem,
    this.itemDigit = 3,
    this.runCus,
    this.markCus,
    this.customerDigit = 5,
    required this.rowStd,
    required this.rowCardStd,
    required this.timeAlert,
    required this.orgStructureType,
    this.passwordPolicyCode = 3,
    this.yearFormat,
    this.versionId,
    this.emailHost,
    this.emailPort,
    this.emailCenter,
    this.emailAdmin,
    this.superUserName,
    this.passwordCry,
    this.emailPasswordCenter,
    this.passwordEmpDefault,
    this.passwordDirect,
  });

  final String? customerNameTh;
  final String? customerNameEn;
  final String? addressText;
  final String? telephone;
  final String? taxId;
  final String? customerEmail;
  final String name;
  final String titleHeader;
  final String? runItem;
  final String? markItem;
  final int itemDigit;
  final String? runCus;
  final String? markCus;
  final int customerDigit;
  final int rowStd;
  final int rowCardStd;
  final int timeAlert;
  final int orgStructureType;
  final int passwordPolicyCode;
  final String? yearFormat;
  final String? versionId;
  final String? emailHost;
  final int? emailPort;
  final String? emailCenter;
  final String? emailAdmin;
  final String? superUserName;
  final String? passwordCry;
  final String? emailPasswordCenter;
  final String? passwordEmpDefault;
  final String? passwordDirect;

  Map<String, dynamic> toJson() => {
    'customerNameTh': customerNameTh,
    'customerNameEn': customerNameEn,
    'addressText': addressText,
    'telephone': telephone,
    'taxID': taxId,
    'customerEmail': customerEmail,
    'name': name,
    'titleHeader': titleHeader,
    'runItem': runItem,
    'markItem': markItem,
    'itemDigit': itemDigit,
    'runCus': runCus,
    'markCus': markCus,
    'customerDigit': customerDigit,
    'rowSTD': rowStd,
    'rowCardSTD': rowCardStd,
    'timeAlert': timeAlert,
    'orgStructureType': orgStructureType,
    'passwordPolicyCode': passwordPolicyCode,
    'yearFormat': yearFormat,
    'versionID': versionId,
    'emailHost': emailHost,
    'emailPort': emailPort,
    'emailCenter': emailCenter,
    'emailAdmin': emailAdmin,
    'superUserName': superUserName,
    'passwordCry': passwordCry,
    'emailPasswordCenter': emailPasswordCenter,
    'passwordEmpDefault': passwordEmpDefault,
    'passwordDirect': passwordDirect,
  };
}
