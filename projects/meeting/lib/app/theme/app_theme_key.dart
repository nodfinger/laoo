enum AppThemeKey {
  green('green', 'โทนสีเขียว'),
  blue('blue', 'โทนสีฟ้า');

  const AppThemeKey(this.code, this.displayName);

  final String code;
  final String displayName;

  static AppThemeKey fromCode(String? code) {
    return AppThemeKey.values.firstWhere(
      (item) => item.code == code,
      orElse: () => AppThemeKey.green,
    );
  }
}
