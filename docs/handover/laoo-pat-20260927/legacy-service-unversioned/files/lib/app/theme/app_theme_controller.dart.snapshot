import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme_key.dart';
import 'app_theme_storage.dart';

final appThemeStorageProvider = Provider<AppThemeStorage>(
  (ref) => AppThemeStorage(),
);

final appThemeControllerProvider =
    NotifierProvider<AppThemeController, AppThemeKey>(AppThemeController.new);

class AppThemeController extends Notifier<AppThemeKey> {
  @override
  AppThemeKey build() {
    return AppThemeKey.green;
  }

  Future<void> load() async {
    state = await ref.read(appThemeStorageProvider).load();
  }

  Future<void> selectTheme(AppThemeKey theme) async {
    if (state == theme) {
      return;
    }

    state = theme;
    await ref.read(appThemeStorageProvider).save(theme);
  }
}
