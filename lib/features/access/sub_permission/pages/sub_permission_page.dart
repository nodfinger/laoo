import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
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
  final Set<String> _expandedMenus = <String>{};

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
    final groups = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final row in _rows) {
      groups
          .putIfAbsent('${row['menuGroupName']}', () => {})
          .putIfAbsent('${row['menuCode']}', () => [])
          .add(row);
    }
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: widget.activeMenu,
      menuScope: WorkspaceMenuScope.company,
      child: ValueListenableBuilder<WorkspaceThemePreset>(
        valueListenable: workspaceThemeController,
        builder: (context, preset, _) {
          final accent = preset.primary;
          return ColoredBox(
            color: preset.toThemeData().scaffoldBackgroundColor,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(LaooLayout.cardMargin),
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: WorkspacePageTitle(
                            title: _caption,
                            favoriteKey: widget.activeMenu,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...groups.entries.map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            margin: EdgeInsets.zero,
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              iconColor: accent,
                              collapsedIconColor: accent,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                              collapsedTextColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                              shape: const Border(),
                              collapsedShape: const Border(),
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              leading: Icon(
                                Icons.folder_outlined,
                                color: accent,
                              ),
                              title: Text(
                                group.key,
                                style: const TextStyle(
                                  fontSize: LaooTypography.sectionTitle,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              children: group.value.values
                                  .map((rows) => _menuCard(rows, accent))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _menuCard(List<Map<String, dynamic>> rows, Color accent) {
    final menuCode = '${rows.first['menuCode']}';
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide.none,
      ),
      child: ExpansionTile(
        iconColor: accent,
        collapsedIconColor: accent,
        textColor: Theme.of(context).colorScheme.onSurface,
        collapsedTextColor: Theme.of(context).colorScheme.onSurface,
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: _expandedMenus.contains(menuCode),
        onExpansionChanged: (value) {
          setState(() {
            value
                ? _expandedMenus.add(menuCode)
                : _expandedMenus.remove(menuCode);
          });
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        leading: Icon(Icons.account_tree_outlined, color: accent, size: 21),
        title: Text(
          '${rows.first['menuName']}',
          style: const TextStyle(
            fontSize: LaooTypography.sectionTitle,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          ...rows.asMap().entries.expand(
            (entry) => [
              _pointRow(entry.value, accent),
              if (entry.key < rows.length - 1)
                Divider(
                  color: workspaceThemeController.value.border,
                  height: .6,
                  thickness: .6,
                ),
            ],
          ),
        ],
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
              Text(
                '${point['permissionPointName']}',
                style: const TextStyle(fontSize: LaooTypography.body),
              ),
              if ('${point['employeeNames'] ?? ''}'.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${point['employeeNames']}',
                    style: TextStyle(
                      color: accent,
                      fontSize: LaooTypography.body,
                    ),
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
              borderRadius: BorderRadius.circular(4),
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
                            style: const TextStyle(
                              color: LaooColors.pageCaption,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(color: Theme.of(context).dividerColor),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: departmentFilter,
                      decoration: InputDecoration(
                        labelText: 'แผนก',
                        labelStyle: TextStyle(
                          color: accent,
                          fontSize: LaooTypography.inputLabel,
                          fontWeight: FontWeight.w500,
                        ),
                        floatingLabelStyle: TextStyle(
                          color: accent,
                          fontSize: LaooTypography.materialFloatingLabelSource,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
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
                                    style: const TextStyle(
                                      fontSize: LaooTypography.comboBox,
                                    ),
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
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
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
                                      color: Theme.of(context).dividerColor,
                                      height: .6,
                                      thickness: .6,
                                    ),
                                ],
                              );
                            })
                            .toList(),
                      ),
                    ),
                    Divider(color: Theme.of(context).dividerColor),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            minimumSize: const Size(84, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text('ยกเลิก'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
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
                            minimumSize: const Size(100, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('บันทึก'),
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
