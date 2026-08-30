import 'package:flutter/material.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
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
      if (mounted)
        showTimedSnackBar(context, message: e.toString(), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in _rows)
      groups.putIfAbsent('${row['menuGroupCode']}', () => []).add(row);
    final caption = _rows
        .where((row) => '${row['menuCode']}'.trim() == '01006')
        .map((row) => '${row['menuName']}'.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'สิทธิ์เมนู');
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: 'globalPermissionSettings',
      menuScope: WorkspaceMenuScope.support,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _caption,
                        style: TextStyle(
                          color: accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...groups.values.map(
                  (items) => _menuCard(context, items, accent),
                ),
              ],
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
    for (final item in items)
      menus.putIfAbsent('${item['menuCode']}', () => []).add(item);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
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
  ) async {
    final code = TextEditingController();
    final name = TextEditingController();
    final description = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(color: accent),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent, width: 2),
            ),
          ),
        ),
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: accent, width: 1.5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เพิ่มประเภทสิทธิ์',
                    style: TextStyle(
                      color: accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${menu['menuName']}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: accent),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'รหัส'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'ประเภท'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'รายละเอียด'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('ยกเลิก', style: TextStyle(color: accent)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          try {
                            await _api.addPoint(
                              menuCode: '${menu['menuCode']}',
                              code: code.text,
                              name: name.text,
                              description: description.text,
                            );
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (e) {
                            if (context.mounted)
                              showTimedSnackBar(
                                context,
                                message: e.toString(),
                                error: true,
                              );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('บันทึก'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    code.dispose();
    name.dispose();
    description.dispose();
    if (saved == true) _load();
  }

  Future<void> _showEdit(
    BuildContext context,
    Map<String, dynamic> menu,
    Map<String, dynamic> point,
    Color accent,
  ) async {
    final name = TextEditingController(
      text: '${point['permissionPointName'] ?? ''}',
    );
    final description = TextEditingController(
      text: '${point['permissionPointDescription'] ?? ''}',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(color: accent),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent, width: 2),
            ),
          ),
        ),
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: accent, width: 1.5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'แก้ไขประเภทสิทธิ์',
                    style: TextStyle(
                      color: accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${menu['menuName']}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: accent),
                  TextField(
                    controller: TextEditingController(
                      text: '${point['permissionPointCode']}',
                    ),
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'รหัส'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'ประเภท'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'รายละเอียด'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        icon: const Icon(Icons.close),
                        label: Text('ยกเลิก', style: TextStyle(color: accent)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          try {
                            await _api.updatePoint(
                              menuCode: '${menu['menuCode']}',
                              code: '${point['permissionPointCode']}',
                              name: name.text,
                              description: description.text,
                            );
                            if (dialogContext.mounted)
                              Navigator.pop(dialogContext, true);
                          } catch (error) {
                            if (dialogContext.mounted)
                              showTimedSnackBar(
                                dialogContext,
                                message: error.toString(),
                                error: true,
                              );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('บันทึก'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
                        color: accent.withOpacity(.12),
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
                    color: accent.withOpacity(.10),
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
        if (context.mounted)
          showTimedSnackBar(context, message: e.toString(), error: true);
      }
    }
  }
}
