import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/theme/workspace_theme_presets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('workspace theme codes remain unique', () {
    final codes = workspaceThemePresets.map((preset) => preset.code).toList();

    expect(codes.toSet(), hasLength(codes.length));
  });

  test(
    'workspace theme controller restores and saves the selected style',
    () async {
      SharedPreferences.setMockInitialValues({
        'workspace.theme.code': 'STYLE40',
      });
      final controller = WorkspaceThemeController();

      await controller.initialize();
      expect(controller.value.code, 'STYLE40');

      final style01 = workspaceThemeByCode('STYLE01');
      await controller.save(style01);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('workspace.theme.code'), 'STYLE01');
      expect(controller.value.code, 'STYLE01');
    },
  );

  test('removed or unknown theme preference falls back to STYLE01', () async {
    SharedPreferences.setMockInitialValues({'workspace.theme.code': 'STYLE41'});
    final controller = WorkspaceThemeController();

    await controller.initialize();

    expect(controller.value.code, 'STYLE01');
  });
}
