class CompanyFeatureState {
  const CompanyFeatureState({
    required this.companyId,
    required this.featureCode,
    required this.featureName,
    required this.isEnabled,
    required this.isTrial,
    this.startDate,
    this.expireDate,
    this.description,
  });

  final int companyId;
  final String featureCode;
  final String featureName;
  final String? description;
  final bool isEnabled;
  final bool isTrial;
  final DateTime? startDate;
  final DateTime? expireDate;

  factory CompanyFeatureState.fromJson(
    Map<String, dynamic> json, {
    required int companyId,
  }) => CompanyFeatureState(
    companyId: (json['companyId'] as num?)?.toInt() ?? companyId,
    featureCode: json['featureCode'] as String? ?? 'SALES_MANAGEMENT',
    featureName: json['featureName'] as String? ?? 'บริหารงานขาย',
    description: json['featureDescription'] as String?,
    isEnabled: json['isEnabled'] == true,
    isTrial: json['isTrial'] == true,
    startDate: DateTime.tryParse('${json['startDate'] ?? ''}'),
    expireDate: DateTime.tryParse('${json['expireDate'] ?? ''}'),
  );

  CompanyFeatureState copyWith({
    bool? isEnabled,
    bool? isTrial,
    DateTime? startDate,
    DateTime? expireDate,
  }) => CompanyFeatureState(
    companyId: companyId,
    featureCode: featureCode,
    featureName: featureName,
    description: description,
    isEnabled: isEnabled ?? this.isEnabled,
    isTrial: isTrial ?? this.isTrial,
    startDate: startDate ?? this.startDate,
    expireDate: expireDate ?? this.expireDate,
  );
}
