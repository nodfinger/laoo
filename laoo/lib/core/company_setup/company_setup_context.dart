class CompanySetupContext {
  const CompanySetupContext({
    required this.name,
    required this.titleHeader,
    required this.rowStd,
    required this.rowCardStd,
    required this.timeAlert,
    required this.yearFormat,
    required this.versionId,
    required this.themeName,
    required this.hasSuperUser,
    required this.hasPasswordDirect,
  });

  final String name;
  final String titleHeader;
  final int rowStd;
  final int rowCardStd;
  final int timeAlert;
  final String yearFormat;
  final String versionId;
  final String? themeName;
  final bool hasSuperUser;
  final bool hasPasswordDirect;

  factory CompanySetupContext.fromJson(Map<String, dynamic> json) {
    return CompanySetupContext(
      name: _text(json['name'], 'Laoo Solutions'),
      titleHeader: _text(json['titleHeader'], 'Laoo Solutions'),
      rowStd: _positiveInt(json['rowSTD'] ?? json['rowStd'], 50),
      rowCardStd: _positiveInt(json['rowCardSTD'] ?? json['rowCardStd'], 12),
      timeAlert: _positiveInt(json['timeAlert'], 30),
      yearFormat: _text(json['yearFormat'], 'C').toUpperCase(),
      versionId: _text(json['versionID'] ?? json['versionId'], ''),
      themeName: _nullableText(json['themeName']),
      hasSuperUser: json['hasSuperUser'] == true,
      hasPasswordDirect: json['hasPasswordDirect'] == true,
    );
  }

  static String _text(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int _positiveInt(Object? value, int fallback) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }
}
