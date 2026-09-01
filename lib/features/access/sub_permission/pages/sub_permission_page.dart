import 'package:flutter/material.dart';

import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/sub_permission_api.dart';

class SubPermissionPage extends StatefulWidget {
  const SubPermissionPage({super.key, required this.activeMenu});
  final String activeMenu;

  @override
  State<SubPermissionPage> createState() => _SubPermissionPageState();
}

class _SubPermissionPageState extends State<SubPermissionPage> {
  final _api = SubPermissionApi();
  String _caption = '';
  List<Map<String, dynamic>> _rows = const [];
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
      final data = await _api.list();
      if (!mounted) return;
      setState(() {
        _caption = '${data['caption'] ?? ''}';
        _rows = List<Map<String, dynamic>>.from(data['rows'] ?? []);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showTimedSnackBar(context, message: error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in _rows) {
      groups.putIfAbsent('${row['menuGroupName']}', () => []).add(row);
    }
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: widget.activeMenu,
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: const Color(0xFFF8F9FB),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide.none,
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE1E5E8)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _caption,
                            style: LaooTypography.screenCaptionStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 0),
                  ...groups.entries.map(
                    (group) => _groupCard(group.value, accent),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _groupCard(List<Map<String, dynamic>> rows, Color accent) {
    final menus = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      menus.putIfAbsent('${row['menuCode']}', () => []).add(row);
    }
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...menus.values.expand(
              (points) => [
                Text(
                  '${points.first['menuName']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...points.asMap().entries.expand(
                  (entry) => [
                    _pointRow(entry.value, accent),
                    if (entry.key < points.length - 1)
                      const Divider(
                        color: Color(0xFFF5F6F7),
                        height: 1,
                        thickness: 1,
                      ),
                  ],
                ),
                const SizedBox(height: 0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pointRow(Map<String, dynamic> point, Color accent) => Padding(
    padding: const EdgeInsets.only(left: 12, bottom: 4),
    child: Row(
      children: [
        IconButton(
          tooltip: 'กำหนดพนักงาน',
          onPressed: () => _assign(point, accent),
          icon: Icon(Icons.manage_accounts_outlined, color: accent),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${point['permissionPointName']}'),
              if ('${point['employeeNames'] ?? ''}'.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${point['employeeNames']}',
                    style: TextStyle(color: accent, fontSize: 12),
                  ),
                ),
              if ('${point['permissionPointDescription'] ?? ''}'
                  .trim()
                  .isNotEmpty)
                Text(
                  '${point['permissionPointDescription']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _assign(Map<String, dynamic> point, Color accent) async {
    try {
      final menuCode = '${point['menuCode']}';
      final pointCode = '${point['permissionPointCode']}';
      final employees = await _api.employees(menuCode, pointCode);
      final selected = <int>{
        for (final employee in employees)
          if (employee['isSelected'] == true)
            (employee['employeeId'] as num).toInt(),
      };
      final firstDepartment = <String>{
        for (final employee in employees)
          if ('${employee['departmentName'] ?? ''}'.trim().isNotEmpty)
            '${employee['departmentName']}'.trim(),
      }.firstOrNull;
      String? departmentFilter = firstDepartment;
      if (!mounted) return;
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: accent),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 650),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.manage_accounts_outlined, color: accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${point['permissionPointName']}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(color: accent),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: departmentFilter,
                      decoration: InputDecoration(
                        labelText: 'แผนก',
                        labelStyle: TextStyle(
                          color: accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: accent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: accent, width: 2),
                        ),
                      ),
                      items:
                          <String>{
                                for (final employee in employees)
                                  if ('${employee['departmentName'] ?? ''}'
                                      .trim()
                                      .isNotEmpty)
                                    '${employee['departmentName']}'.trim(),
                              }
                              .map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setDialogState(() => departmentFilter = value),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: employees
                            .where(
                              (employee) =>
                                  departmentFilter == null ||
                                  '${employee['departmentName'] ?? ''}'
                                          .trim() ==
                                      departmentFilter,
                            )
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) {
                              final employee = entry.value;
                              final id = (employee['employeeId'] as num)
                                  .toInt();
                              return Column(
                                children: [
                                  CheckboxListTile(
                                    value: selected.contains(id),
                                    activeColor: accent,
                                    title: Text(
                                      '${employee['employeeCode']} - ${employee['fullName']}',
                                    ),
                                    subtitle:
                                        '${employee['nickName'] ?? ''}'
                                            .trim()
                                            .isEmpty
                                        ? null
                                        : Text('${employee['nickName']}'),
                                    onChanged: (value) => setDialogState(() {
                                      value == true
                                          ? selected.add(id)
                                          : selected.remove(id);
                                    }),
                                  ),
                                  if (entry.key <
                                      employees
                                              .where(
                                                (e) =>
                                                    departmentFilter == null ||
                                                    '${e['departmentName'] ?? ''}'
                                                            .trim() ==
                                                        departmentFilter,
                                              )
                                              .length -
                                          1)
                                    Divider(
                                      color: accent.withValues(alpha: .25),
                                      height: 1,
                                    ),
                                ],
                              );
                            })
                            .toList(),
                      ),
                    ),
                    Divider(color: accent),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(
                            'ยกเลิก',
                            style: TextStyle(color: accent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            try {
                              await _api.saveEmployees(
                                menuCode,
                                pointCode,
                                selected.toList(),
                              );
                              if (dialogContext.mounted) {
                                showTimedSnackBar(
                                  dialogContext,
                                  message: 'บันทึกสิทธิ์ระดับย่อยสำเร็จ',
                                );
                              }
                              await _load();
                            } catch (error) {
                              if (dialogContext.mounted) {
                                showTimedSnackBar(
                                  dialogContext,
                                  message: error.toString(),
                                  error: true,
                                );
                              }
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
      if (save == true) {
        await _api.saveEmployees(menuCode, pointCode, selected.toList());
        if (mounted) {
          showTimedSnackBar(context, message: 'บันทึกสิทธิ์ระดับย่อยสำเร็จ');
        }
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(context, message: error.toString(), error: true);
      }
    }
  }
}
