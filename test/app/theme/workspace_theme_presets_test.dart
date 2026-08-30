import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/theme/workspace_theme_presets.dart';

void main() {
  test('workspace theme codes remain unique', () {
    final codes = workspaceThemePresets.map((preset) => preset.code).toList();

    expect(codes.toSet(), hasLength(codes.length));
  });

  test(
    'workspace theme controller keeps the profile/API selection in memory',
    () async {
      final controller = WorkspaceThemeController();

      await controller.initialize();
      expect(controller.value.code, 'STYLE01');

      final profileTheme = workspaceThemeByCode('STYLE40');
      await controller.save(profileTheme);

      expect(controller.value, same(profileTheme));
    },
  );

  test('unknown profile theme code falls back to STYLE01', () {
    expect(workspaceThemeByCode('STYLE41').code, 'STYLE01');
  });

  test('ThemeData follows each workspace preset', () {
    for (final code in ['STYLE31', 'STYLE21']) {
      final preset = workspaceThemeByCode(code);
      final theme = preset.toThemeData();

      expect(theme.colorScheme.primary, preset.primary);
      expect(theme.scaffoldBackgroundColor, preset.background);
      expect(theme.colorScheme.surface, preset.surface);
      expect(
        theme.brightness,
        preset.isDark ? Brightness.dark : Brightness.light,
      );
    }
  });
}
