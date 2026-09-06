import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_controller.dart';
import '../../../app/theme/app_theme_key.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';

class ThemeDemoPage extends ConsumerWidget {
  const ThemeDemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTheme = ref.watch(appThemeControllerProvider);

    return Scaffold(
      backgroundColor: LaooColors.background,
      appBar: AppBar(title: const Text('Laoo Theme Engine')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            children: [
              const Text(
                'ตั้งค่าประสบการณ์ของฉัน',
                style: LaooTypography.pageCaptionStyle,
              ),
              const SizedBox(height: LaooLayout.cardSpacing),
              const Text(
                'เลือกโทนสีที่ระบบเตรียมไว้ สีจะเปลี่ยนทันทีและถูกจำไว้ในเครื่อง',
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(LaooLayout.cardPadding),
                  child: SegmentedButton<AppThemeKey>(
                    segments: AppThemeKey.values
                        .map(
                          (theme) => ButtonSegment<AppThemeKey>(
                            value: theme,
                            label: Text(theme.displayName),
                            icon: Icon(
                              theme == AppThemeKey.green
                                  ? Icons.eco_outlined
                                  : Icons.water_drop_outlined,
                            ),
                          ),
                        )
                        .toList(),
                    selected: {selectedTheme},
                    onSelectionChanged: (selection) {
                      ref
                          .read(appThemeControllerProvider.notifier)
                          .selectTheme(selection.first);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: const Text('ตัวอย่างข้อมูลผู้ใช้งาน'),
                  subtitle: Text(
                    'Theme ปัจจุบัน: ${selectedTheme.displayName}',
                  ),
                  trailing: FilledButton(
                    onPressed: () {},
                    child: const Text('บันทึก'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
