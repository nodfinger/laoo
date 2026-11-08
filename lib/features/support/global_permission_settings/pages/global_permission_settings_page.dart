import 'package:flutter/material.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/global_permission_settings_api.dart';

class GlobalPermissionSettingsPage extends StatefulWidget {
  const GlobalPermissionSettingsPage({super.key});
  @override
  State<GlobalPermissionSettingsPage> createState() =>
      _GlobalPermissionSettingsPageState();
}

class _GlobalPermissionSettingsPageState
    extends State<GlobalPermissionSettingsPage> {
  final _api = GlobalPermissionSettingsApi();
  List<Map<String, dynamic>> _rows = const [];
  String _caption = '';
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await Future.wait([_api.caption(), _api.menus()]);
      _caption = result[0] as String;
      _rows = result[1] as List<Map<String, dynamic>>;
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(context, message: e.toString(), error: true);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in _rows) {
      groups.putIfAbsent('${row['menuGroupCode']}', () => []).add(row);
    }
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: 'globalPermissionSettings',
      menuScope: WorkspaceMenuScope.support,
      child: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: EdgeInsets.all(constraints.maxWidth < 600 ? 10 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: WorkspacePageTitle(
                    title: _caption,
                    favoriteKey: 'globalPermissionSettings',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : groups.isEmpty
                    ? const Center(child: Text('ไม่พบข้อมูลสิทธิ์'))
                    : ListView(
                        children: groups.values
                            .map((items) => _menuCard(context, items, accent))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context,
    List<Map<String, dynamic>> items,
    Color accent,
  ) {
    final first = items.first;
    final menus = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      menus.putIfAbsent('${item['menuCode']}', () => []).add(item);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${first['menuGroupName']}',
              style: TextStyle(
                color: accent,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Divider(),
            ...menus.values.map((menuRows) {
              final menu = menuRows.first;
              final points = menuRows
                  .where((e) => e['permissionPointName'] != null)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${menu['menuName']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text('${menu['menuCode']}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => _showAdd(context, menu, accent),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('เพิ่มประเภทสิทธิ์'),
                        ),
                      ],
                    ),
                  ),
                  ...points.asMap().entries.map(
                    (entry) => Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 8),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'แก้ไข',
                                onPressed: () => _showEdit(
                                  context,
                                  menu,
                                  entry.value,
                                  accent,
                                ),
                                icon: Icon(Icons.edit_outlined, color: accent),
                              ),
                              IconButton(
                                onPressed: () => _confirmDelete(
                                  context,
                                  menu,
                                  entry.value,
                                  accent,
                                ),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${entry.value['permissionPointCode']} - ${entry.value['permissionPointName']}',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (entry.key < points.length - 1)
                          const Divider(height: 1),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdd(
    BuildContext context,
    Map<String, dynamic> menu,
    Color accent,
  ) => _showPointDialog(context, menu, accent);

  Future<void> _showEdit(
    BuildContext context,
    Map<String, dynamic> menu,
    Map<String, dynamic> point,
    Color accent,
  ) => _showPointDialog(context, menu, accent, point: point);

  Future<void> _showPointDialog(
    BuildContext context,
    Map<String, dynamic> menu,
    Color accent, {
    Map<String, dynamic>? point,
  }) async {
    final editing = point != null;
    final code = TextEditingController(
      text: editing ? '${point['permissionPointCode'] ?? ''}' : '',
    );
    final name = TextEditingController(
      text: editing ? '${point['permissionPointName'] ?? ''}' : '',
    );
    final description = TextEditingController(
      text: editing ? '${point['permissionPointDescription'] ?? ''}' : '',
    );
    var saving = false;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          final theme = Theme.of(dialogContext);
          final shape = RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          );
          return PopScope(
            canPop: !saving,
            child: Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(24),
              shape: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                editing
                                    ? 'แก้ไขประเภทสิทธิ์'
                                    : 'เพิ่มประเภทสิทธิ์',
                                style: LaooTypography.pageCaptionStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: theme.dividerColor),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${menu['menuName']}',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: code,
                                readOnly: editing,
                                style: const TextStyle(
                                  fontSize: LaooTypography.inputText,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'รหัส',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: name,
                                style: const TextStyle(
                                  fontSize: LaooTypography.inputText,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'ประเภท',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: description,
                                maxLines: 3,
                                style: const TextStyle(
                                  fontSize: LaooTypography.inputText,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'รายละเอียด',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(color: theme.dividerColor),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(dialogContext, false),
                            style: OutlinedButton.styleFrom(
                              shape: shape,
                              minimumSize: const Size(
                                84,
                                LaooTypography.buttonHeight,
                              ),
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('ยกเลิก'),
                          ),
                          FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    update(() => saving = true);
                                    try {
                                      if (editing) {
                                        await _api.updatePoint(
                                          menuCode: '${menu['menuCode']}',
                                          code: code.text,
                                          name: name.text,
                                          description: description.text,
                                        );
                                      } else {
                                        await _api.addPoint(
                                          menuCode: '${menu['menuCode']}',
                                          code: code.text,
                                          name: name.text,
                                          description: description.text,
                                        );
                                      }
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext, true);
                                      }
                                    } catch (_) {
                                      if (dialogContext.mounted) {
                                        showTimedSnackBar(
                                          dialogContext,
                                          message:
                                              'ไม่สามารถบันทึกประเภทสิทธิ์ได้\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบข้อมูลและลองใหม่',
                                          error: true,
                                        );
                                      }
                                    } finally {
                                      if (dialogContext.mounted) {
                                        update(() => saving = false);
                                      }
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              shape: shape,
                              minimumSize: const Size(
                                100,
                                LaooTypography.buttonHeight,
                              ),
                            ),
                            icon: const Icon(Icons.save_outlined),
                            label: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    code.dispose();
    name.dispose();
    description.dispose();
    if (saved == true) await _load();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Map<String, dynamic> menu,
    Map<String, dynamic> point,
    Color accent,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: accent, width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_outline, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ยืนยันการลบข้อมูล',
                      style: TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ต้องการลบ ${point['permissionPointCode']} - ${point['permissionPointName']} หรือไม่?',
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('ยกเลิก', style: TextStyle(color: accent)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 6),
                          Text('ลบ'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) {
      try {
        await _api.deletePoint(
          menuCode: '${menu['menuCode']}',
          code: '${point['permissionPointCode']}',
        );
        await _load();
      } catch (e) {
        if (context.mounted) {
          showTimedSnackBar(context, message: e.toString(), error: true);
        }
      }
    }
  }
}
