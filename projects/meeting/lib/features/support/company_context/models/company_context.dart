class CompanyContextItem {
  const CompanyContextItem({
    required this.companyId,
    required this.companyCode,
    required this.companyName,
  });

  final int companyId;
  final String companyCode;
  final String companyName;

  factory CompanyContextItem.fromJson(Map<String, dynamic> json) {
    return CompanyContextItem(
      companyId: int.tryParse(
            (json['companyID'] ?? json['companyId']).toString(),
          ) ??
          0,
      companyCode: json['companyCode']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
    );
  }
}
