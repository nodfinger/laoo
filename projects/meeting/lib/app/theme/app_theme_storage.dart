import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_key.dart';

class AppThemeStorage {
  AppThemeStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _themeKey = 'laoo.user.preference.theme';

  final SharedPreferencesAsync _preferences;

  Future<AppThemeKey> load() async {
    final code = await _preferences.getString(_themeKey);
    return AppThemeKey.fromCode(code);
  }

  Future<void> save(AppThemeKey theme) async {
    await _preferences.setString(_themeKey, theme.code);
  }
}
