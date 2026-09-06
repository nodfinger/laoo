import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme_controller.dart';
import '../app_theme_key.dart';

final appThemeKeyProvider = Provider<AppThemeKey>(
  (ref) => ref.watch(appThemeControllerProvider),
);
