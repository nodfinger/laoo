import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;

import '../../app/theme/laoo_design_tokens.dart';
import '../../app/theme/laoo_typography.dart';
import '../../app/theme/workspace_theme_presets.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/list_display_preferences.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/shared/registry_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';
import 'ai_chat_review_panel.dart';

class AiCapabilitiesPage extends StatefulWidget {
  const AiCapabilitiesPage({super.key});
  @override
  State<AiCapabilitiesPage> createState() => _AiCapabilitiesPageState();
}

class _AiCapabilitiesPageState extends State<AiCapabilitiesPage> {
  String _approvalDate(Map<String, dynamic> row) {
    final value = DateTime.tryParse(
      '${row['lastApprovedAt'] ?? ''}',
    )?.toLocal();
    if (value == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  String _projectName(Map<String, dynamic> row) {
    final name = '${row['projectNameTh'] ?? ''}'.trim();
    return name.isEmpty ? 'ไม่ระบุ' : name;
  }

  String _systemName(Map<String, dynamic> row) {
    final name = '${row['systemName'] ?? ''}'.trim();
    return name.isEmpty ? 'ไม่ระบุ' : name;
  }

  final _api = ApiClient();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _projects = [];
  String _caption = '', _query = '';
  String _project = '', _menu = '', _status = '';
  bool _loading = true, _canEdit = false, _canManageAccess = false;
  bool _cards = false;
  bool _reviewTab = false;
  ListDisplayPreferences _displayPreferences = const ListDisplayPreferences();
  int _page = 1;
  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    listDisplayPreferencesRevision.addListener(_loadDisplayPreferences);
    _loadDisplayPreferences();
    _load();
  }

  @override
  void dispose() {
    listDisplayPreferencesRevision.removeListener(_loadDisplayPreferences);
    _api.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadDisplayPreferences() async {
    try {
      final value = await _api.get('/api/user-list-display/10008');
      if (mounted && value is Map) {
        setState(
          () => _displayPreferences = ListDisplayPreferences.fromJson(
            Map<String, dynamic>.from(value),
          ),
        );
      }
    } catch (_) {
      // The standard layout remains available if preferences cannot be loaded.
    }
  }

  Widget _displayValue(String key, Map<String, dynamic> row, Color primary) {
    return switch (key) {
      'system' => Text(_projectName(row)),
      'menu' => Text(_systemName(row)),
      'name' => Text('${row['name'] ?? '-'}'),
      'description' => Text('${row['description'] ?? '-'}'),
      'approvedBy' => Text('${row['lastApprovedByUsername'] ?? '-'}'),
      'approvedAt' => Text(_approvalDate(row)),
      'status' => _statusBadge(row['isEnabled'] == true, primary),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _displayActions(Map<String, dynamic> row, Color primary) => Wrap(
    children: [
      if (_canEdit)
        IconButton(
          tooltip: 'แก้ไข',
          icon: Icon(Icons.edit_outlined, color: primary),
          onPressed: () => _edit(row),
        ),
      if (_canManageAccess)
        IconButton(
          tooltip: 'กำหนดสิทธิ',
          icon: Icon(Icons.manage_accounts_outlined, color: primary),
          onPressed: () => _manageAccess(row),
        ),
    ],
  );

  Future<void> _load() async {
    try {
      final value = await _api.get('/api/assistant/registry');
      final subscriptions = await _api.get('/api/company/subscriptions');
      if (!mounted) return;
      final data = Map<String, dynamic>.from(value as Map);
      setState(() {
        _caption = '${data['caption'] ?? ''}';
        _canEdit = data['canEdit'] == true;
        _canManageAccess = data['canManageAccess'] == true;
        _rows = (data['rows'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        _projects = (subscriptions as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((p) {
              final start = DateTime.tryParse('${p['startDate'] ?? ''}');
              return p['accessMode'] == 'FULL' &&
                  (start == null ||
                      !DateTime(
                        start.year,
                        start.month,
                        start.day,
                      ).isAfter(today));
            })
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showTimedSnackBar(
        context,
        message: 'ไม่สามารถโหลดความสามารถ AI ได้ กรุณาตรวจสอบสิทธิ์แล้วลองใหม่',
        error: true,
      );
    }
  }

  Future<void> _manageAccess(Map<String, dynamic> row) async {
    final code = '${row['code']}';
    try {
      final result = await _api.get(
        '/api/assistant/registry/$code/role-access',
      );
      if (!mounted) return;
      final access = Map<String, dynamic>.from(result as Map);
      final roles = (access['roles'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final selected = <int>{
        for (final role in roles)
          if (role['allowed'] == true) (role['id'] as num).toInt(),
      };
      var query = '';
      var page = 0;
      var selectedOnly = false;
      var useMenuPermissions = access['useMenuPermissions'] == true;
      var saving = false;
      String? error;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) {
            final primary = workspaceThemeController.value.primary;
            final filtered = roles
                .where(
                  (r) =>
                      (!selectedOnly ||
                          selected.contains((r['id'] as num).toInt())) &&
                      '${r['name']}'.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
            final lastPage = filtered.isEmpty ? 0 : (filtered.length - 1) ~/ 10;
            final currentPage = page.clamp(0, lastPage);
            final start = currentPage * 10;
            final shown = filtered.skip(start).take(10).toList();
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
              title: Row(
                children: [
                  Icon(Icons.manage_accounts_outlined, color: primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'กำหนดสิทธิ์ > ${row['name']}',
                      style: LaooTypography.popupTitleStyle,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: (MediaQuery.sizeOf(context).height * .55).clamp(
                  220,
                  480,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      style: const TextStyle(
                        fontSize: LaooTypography.inputText,
                      ),
                      decoration:
                          registryInput(
                            context,
                            label: 'ค้นหากลุ่มสิทธิ์',
                          ).copyWith(
                            prefixIcon: const Icon(Icons.search),
                            floatingLabelStyle: TextStyle(
                              color: primary,
                              fontSize:
                                  LaooTypography.materialFloatingLabelSource,
                            ),
                          ),
                      onChanged: (value) => update(() {
                        query = value.trim();
                        page = 0;
                      }),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: primary,
                      title: const Text(
                        'ใช้งานได้ทั้งหมดตามกลุ่มสิทธิ์ของเมนู',
                      ),
                      value: useMenuPermissions,
                      onChanged: saving
                          ? null
                          : (value) => update(() {
                              useMenuPermissions = value == true;
                              if (useMenuPermissions) selectedOnly = false;
                              page = 0;
                            }),
                    ),
                    Text(
                      useMenuPermissions
                          ? 'ใช้สิทธิ์ตามเมนูและแพ็กเกจของผู้ใช้ โดยเก็บการเลือกกลุ่มเดิมไว้'
                          : 'เลือกกลุ่มที่อนุญาตให้ใช้ความสามารถนี้ โดยยังต้องมีสิทธิ์เมนูและแพ็กเกจที่เกี่ยวข้อง',
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: primary,
                      title: Text(
                        'แสดงเฉพาะรายการที่เลือก (${selected.length})',
                      ),
                      value: selectedOnly,
                      onChanged: saving || useMenuPermissions
                          ? null
                          : (value) => update(() {
                              selectedOnly = value == true;
                              page = 0;
                            }),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    Expanded(
                      child: shown.isEmpty
                          ? const Center(child: Text('ไม่พบกลุ่มสิทธิ์'))
                          : ListView.separated(
                              itemCount: shown.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: .6, thickness: .6),
                              itemBuilder: (context, i) {
                                final role = shown[i];
                                final id = (role['id'] as num).toInt();
                                return CheckboxListTile(
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  activeColor: primary,
                                  title: Text('${role['name']}'),
                                  value: selected.contains(id),
                                  onChanged: saving || useMenuPermissions
                                      ? null
                                      : (checked) => update(() {
                                          if (checked == true) {
                                            selected.add(id);
                                          } else {
                                            selected.remove(id);
                                          }
                                        }),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: LaooLayout.paginationButtonSize,
                          height: LaooLayout.paginationButtonSize,
                          child: FilledButton(
                            onPressed: currentPage > 0
                                ? () => update(() => page = currentPage - 1)
                                : null,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                            child: const Icon(Icons.chevron_left),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: LaooLayout.paginationButtonSize,
                          height: LaooLayout.paginationButtonSize,
                          child: FilledButton(
                            onPressed: () {},
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                            child: Text('${currentPage + 1}'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: LaooLayout.paginationButtonSize,
                          height: LaooLayout.paginationButtonSize,
                          child: FilledButton(
                            onPressed: start + shown.length < filtered.length
                                ? () => update(() => page = currentPage + 1)
                                : null,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                            child: const Icon(Icons.chevron_right),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${filtered.isEmpty ? 0 : start + 1}-${start + shown.length} จาก ${filtered.length}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(color: LaooColors.border, thickness: .6),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: registryButton(primary),
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                          label: const Text('ยกเลิก'),
                        ),
                        FilledButton.icon(
                          style: registryButton(primary, filled: true),
                          onPressed: saving
                              ? null
                              : () async {
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    await _api.put(
                                      '/api/assistant/registry/$code/role-access',
                                      body: {
                                        'roleGroupIds': selected.toList(),
                                        'useMenuPermissions':
                                            useMenuPermissions,
                                      },
                                    );
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                    if (mounted) {
                                      showTimedSnackBar(
                                        this.context,
                                        message: 'บันทึกสิทธิ์เรียบร้อย',
                                      );
                                    }
                                  } catch (_) {
                                    if (dialogContext.mounted) {
                                      update(() {
                                        saving = false;
                                        error =
                                            'บันทึกไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่';
                                      });
                                    }
                                  }
                                },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('บันทึก'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ไม่สามารถโหลดกลุ่มสิทธิ์ได้',
          error: true,
        );
      }
    }
  }

  InputDecoration _popupInput(
    BuildContext context,
    String label,
    TextEditingValue value,
  ) {
    final theme = Theme.of(context);
    final primary = workspaceThemeController.value.primary;
    return registryInput(context, label: label).copyWith(
      counterText: '',
      labelStyle: const TextStyle(fontSize: LaooTypography.inputLabel),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          fontSize: LaooTypography.materialFloatingLabelSource,
          color: states.contains(WidgetState.error)
              ? theme.colorScheme.error
              : states.contains(WidgetState.disabled)
              ? theme.disabledColor
              : states.contains(WidgetState.focused) || value.text.isNotEmpty
              ? primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    var enabled = row['isEnabled'] == true;
    var pdf = row['allowPdf'] == true,
        png = row['allowPng'] == true,
        html = row['allowHtml'] == true,
        email = row['allowEmail'] == true;
    final name = TextEditingController(text: '${row['name']}');
    final description = TextEditingController(text: '${row['description']}');
    final examples = TextEditingController(
      text: (row['examples'] as List).join('\n'),
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(LaooRadius.xs)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: LaooLayout.popupHeaderMinHeight,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: workspaceThemeController.value.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$_caption > แก้ไข',
                            style: LaooTypography.popupTitleStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(height: 1, color: LaooColors.border),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text('สถานะ'),
                            const SizedBox(width: 8),
                            Switch(
                              value: enabled,
                              activeTrackColor:
                                  workspaceThemeController.value.primary,
                              onChanged: (v) => refresh(() => enabled = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: LaooLayout.popupFieldSpacing),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: name,
                          builder: (context, value, _) => TextField(
                            controller: name,
                            maxLength: 200,
                            style: const TextStyle(
                              fontSize: LaooTypography.inputText,
                            ),
                            cursorColor: workspaceThemeController.value.primary,
                            decoration: _popupInput(context, 'ชื่อ *', value),
                          ),
                        ),
                        const SizedBox(height: LaooLayout.popupFieldSpacing),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: description,
                          builder: (context, value, _) => TextField(
                            controller: description,
                            maxLines: 2,
                            maxLength: 1000,
                            style: const TextStyle(
                              fontSize: LaooTypography.inputText,
                            ),
                            cursorColor: workspaceThemeController.value.primary,
                            decoration: _popupInput(context, 'คำอธิบาย', value),
                          ),
                        ),
                        const SizedBox(height: LaooLayout.popupFieldSpacing),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: examples,
                          builder: (context, value, _) => TextField(
                            controller: examples,
                            readOnly: true,
                            maxLines: 7,
                            style: const TextStyle(
                              fontSize: LaooTypography.inputText,
                            ),
                            cursorColor: workspaceThemeController.value.primary,
                            decoration: _popupInput(
                              context,
                              'ตัวอย่างคำถาม (หนึ่งคำถามต่อบรรทัด - ต้องผ่านมาอนุมัติก่อน)',
                              value,
                            ),
                          ),
                        ),
                        const SizedBox(height: LaooLayout.popupFieldSpacing),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 8.0;
                            final columns = constraints.maxWidth >= 500 ? 4 : 2;
                            final itemWidth =
                                (constraints.maxWidth -
                                    spacing * (columns - 1)) /
                                columns;
                            Widget option(
                              String label,
                              bool selected,
                              ValueChanged<bool> onChanged,
                            ) => SizedBox(
                              width: itemWidth,
                              child: Column(
                                children: [
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    child: Center(
                                      child: Text(
                                        label,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Semantics(
                                    label: label,
                                    child: Switch(
                                      value: selected,
                                      activeTrackColor: workspaceThemeController
                                          .value
                                          .primary,
                                      onChanged: onChanged,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                option(
                                  'ส่งออก PDF',
                                  pdf,
                                  (v) => refresh(() => pdf = v),
                                ),
                                option(
                                  'ส่งออกภาพ PNG',
                                  png,
                                  (v) => refresh(() => png = v),
                                ),
                                option(
                                  'ส่งออก HTML',
                                  html,
                                  (v) => refresh(() => html = v),
                                ),
                                option(
                                  'ส่งอีเมลเมื่อผู้ใช้ยืนยัน',
                                  email,
                                  (v) => refresh(() => email = v),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(height: 1, color: LaooColors.border),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: registryButton(
                          workspaceThemeController.value.primary,
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('ยกเลิก'),
                      ),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: registryButton(
                          workspaceThemeController.value.primary,
                          filled: true,
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('บันทึก'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == true) {
      try {
        await _api.put(
          '/api/assistant/registry/${Uri.encodeComponent('${row['code']}')}',
          body: {
            'isEnabled': enabled,
            'displayName': name.text,
            'description': description.text,
            'examples': examples.text.split('\n'),
            'allowPdf': pdf,
            'allowPng': png,
            'allowHtml': html,
            'allowEmail': email,
          },
        );
        if (mounted) {
          showTimedSnackBar(context, message: 'บันทึกความสามารถ AI แล้ว');
          await _load();
        }
      } catch (_) {
        if (mounted) {
          showTimedSnackBar(
            context,
            message: 'บันทึกไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์',
            error: true,
          );
        }
      }
    }
    name.dispose();
    description.dispose();
    examples.dispose();
  }

  Future<void> _chooseCapability() async {
    final row = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(LaooRadius.xs)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: workspaceThemeController.value.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'เลือกความสามารถที่ระบบรองรับ',
                        style: LaooTypography.popupTitleStyle,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: LaooColors.border),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _rows.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: LaooColors.border),
                  itemBuilder: (_, index) {
                    final item = _rows[index];
                    return ListTile(
                      title: Text('${item['name']}'),
                      subtitle: Text(_systemName(item)),
                      onTap: () => Navigator.pop(dialogContext, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && row != null) await _edit(row);
  }

  Widget _statusBadge(bool enabled, Color primary) {
    final color = enabled ? primary : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        enabled ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
        style: TextStyle(color: color, fontSize: LaooTypography.tableBody),
      ),
    );
  }

  Widget _pagination(int page, int pages, int start, int total, Color primary) {
    Widget button(Widget child, {VoidCallback? onTap, bool selected = false}) =>
        SizedBox.square(
          dimension: LaooLayout.paginationButtonSize,
          child: Material(
            color: selected || onTap != null ? primary : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(LaooRadius.xs),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(LaooRadius.xs),
              child: Center(child: child),
            ),
          ),
        );
    return registrySurface(
      SizedBox(
        height: LaooLayout.paginationCardHeight - 20,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              button(
                Icon(
                  Icons.chevron_left,
                  size: 22,
                  color: page > 1 ? Colors.white : Colors.grey.shade600,
                ),
                onTap: page > 1 ? () => setState(() => _page = page - 1) : null,
              ),
              const SizedBox(width: 6),
              button(
                Text('$page', style: const TextStyle(color: Colors.white)),
                selected: true,
              ),
              const SizedBox(width: 6),
              button(
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: page < pages ? Colors.white : Colors.grey.shade600,
                ),
                onTap: page < pages
                    ? () => setState(() => _page = page + 1)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                '${total == 0 ? 0 : start + 1}-${(start + _pageSize).clamp(0, total)} จาก $total',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<WorkspaceThemePreset>(
        valueListenable: workspaceThemeController,
        builder: (context, _, _) => _buildContent(context),
      );

  Widget _buildContent(BuildContext context) {
    final visible = _rows
        .where(
          (r) =>
              '${r['name']} ${r['description']}'.toLowerCase().contains(
                _query.toLowerCase(),
              ) &&
              (_project.isEmpty || r['projectCode'] == _project) &&
              (_menu.isEmpty || _systemName(r) == _menu) &&
              (_status.isEmpty ||
                  (r['isEnabled'] == true) == (_status == 'enabled')),
        )
        .toList();
    final primary = workspaceThemeController.value.primary;
    final pages = ((visible.length + _pageSize - 1) ~/ _pageSize).clamp(
      1,
      1 << 20,
    );
    final page = _page.clamp(1, pages);
    final start = (page - 1) * _pageSize;
    final pageRows = visible.skip(start).take(_pageSize).toList();
    final displayFields = _displayPreferences
        .resolve(aiCapabilityDisplayFields)
        .where(_displayPreferences.isVisible)
        .toList();
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: 'companyAiCapabilities',
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: workspaceThemeController.value
            .toThemeData()
            .scaffoldBackgroundColor,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final small = constraints.maxWidth < 600;
                  return ListView(
                    padding: const EdgeInsets.all(LaooLayout.cardMargin),
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        color: Colors.white,
                        elevation: 0,
                        surfaceTintColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: WorkspacePageTitle(
                                  title: _caption,
                                  favoriteKey: 'companyAiCapabilities',
                                ),
                              ),
                              if (!small)
                                SizedBox.square(
                                  dimension: LaooTypography.buttonHeight,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(
                                        LaooRadius.xs,
                                      ),
                                    ),
                                    child: IconButton(
                                      tooltip: _cards
                                          ? 'แสดงแบบรายการ'
                                          : 'แสดงแบบการ์ด',
                                      onPressed: () =>
                                          setState(() => _cards = !_cards),
                                      icon: Icon(
                                        _cards
                                            ? Icons.view_list
                                            : Icons.grid_view,
                                        color: primary,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_canEdit && !_reviewTab) ...[
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: _chooseCapability,
                                  style: registryButton(primary, filled: true),
                                  icon: const Icon(Icons.add),
                                  label: const Text('เพิ่มข้อมูล'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      registrySurface(
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  setState(() => _reviewTab = false),
                              child: Text(
                                'ความสามารถ',
                                style: TextStyle(
                                  color: primary,
                                  fontSize: LaooTypography.sectionTitle,
                                  fontWeight: !_reviewTab
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _reviewTab = true),
                              child: Text(
                                'คำถามจาก Chat',
                                style: TextStyle(
                                  color: primary,
                                  fontSize: LaooTypography.sectionTitle,
                                  fontWeight: _reviewTab
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_reviewTab)
                        AiChatReviewPanel(
                          capabilities: _rows,
                          canEdit: _canEdit,
                          cards: _cards || small,
                        )
                      else ...[
                        Card(
                          margin: EdgeInsets.zero,
                          color: Colors.white,
                          elevation: 0,
                          surfaceTintColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: FilterHeightSync(
                              builder: (context, searchKey, height) => Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: small
                                        ? (constraints.maxWidth - 60)
                                              .clamp(120, 350)
                                              .toDouble()
                                        : 350,
                                    child: TextField(
                                      key: searchKey,
                                      controller: _search,
                                      onSubmitted: (v) => setState(() {
                                        _query = v;
                                        _page = 1;
                                      }),
                                      decoration: registryInput(
                                        context,
                                        hint: 'ค้นหาความสามารถ',
                                        icon: Icons.search,
                                      ),
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => setState(() {
                                      _query = _search.text;
                                      _page = 1;
                                    }),
                                    style: registryButton(
                                      primary,
                                      filled: true,
                                    ).merge(filterActionHeightStyle(height)),
                                    icon: const Icon(Icons.search),
                                    label: const Text('ค้นหา'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => setState(() {
                                      _search.clear();
                                      _query = '';
                                      _project = '';
                                      _menu = '';
                                      _status = '';
                                      _page = 1;
                                    }),
                                    icon: const Icon(Icons.filter_alt_off),
                                    style: registryButton(
                                      primary,
                                    ).merge(filterActionHeightStyle(height)),
                                    label: const Text('ล้าง Filter'),
                                  ),
                                  SizedBox(
                                    width: 180,
                                    child: DropdownButtonFormField<String>(
                                      key: ValueKey('project:$_project'),
                                      initialValue: _project,
                                      decoration: registryInput(
                                        context,
                                        label: 'ระบบ',
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: '',
                                          child: Text('ทั้งหมด'),
                                        ),
                                        ..._projects.map(
                                          (p) => DropdownMenuItem(
                                            value: '${p['projectCode']}',
                                            child: Text(
                                              '${p['projectNameTh']}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) => setState(() {
                                        _project = v ?? '';
                                        _menu = '';
                                        _page = 1;
                                      }),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 200,
                                    child: DropdownButtonFormField<String>(
                                      key: ValueKey('menu:$_project:$_menu'),
                                      initialValue: _menu,
                                      isExpanded: true,
                                      decoration: registryInput(
                                        context,
                                        label: 'เมนู',
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: '',
                                          child: Text('ทั้งหมด'),
                                        ),
                                        ..._rows
                                            .where(
                                              (r) =>
                                                  _project.isEmpty ||
                                                  r['projectCode'] == _project,
                                            )
                                            .map(_systemName)
                                            .toSet()
                                            .map(
                                              (name) => DropdownMenuItem(
                                                value: name,
                                                child: Text(
                                                  name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                      ],
                                      onChanged: (v) => setState(() {
                                        _menu = v ?? '';
                                        _page = 1;
                                      }),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 180,
                                    child: DropdownButtonFormField<String>(
                                      key: ValueKey('status:$_status'),
                                      initialValue: _status,
                                      decoration: registryInput(
                                        context,
                                        label: 'สถานะ',
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: '',
                                          child: Text('ทั้งหมด'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'enabled',
                                          child: Text('เปิด'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'disabled',
                                          child: Text('ปิด'),
                                        ),
                                      ],
                                      onChanged: (v) => setState(() {
                                        _status = v ?? '';
                                        _page = 1;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!_cards && !small)
                          Card(
                            margin: EdgeInsets.zero,
                            color: Colors.white,
                            elevation: 0,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                LaooLayout.cardPadding,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Table(
                                    defaultVerticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    border: const TableBorder(
                                      horizontalInside: BorderSide(
                                        color: LaooColors.border,
                                        width: .6,
                                      ),
                                    ),
                                    columnWidths: {
                                      0: const FixedColumnWidth(45),
                                      if (!_displayPreferences.actionOnRight)
                                        1: const FixedColumnWidth(110),
                                      if (_displayPreferences.actionOnRight)
                                        displayFields.length + 1:
                                            const FixedColumnWidth(110),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: primary.withValues(alpha: .12),
                                        ),
                                        children: [
                                          for (final label in [
                                            'ID',
                                            if (!_displayPreferences
                                                .actionOnRight)
                                              'Action',
                                            ...displayFields.map(
                                              (f) => f.label,
                                            ),
                                            if (_displayPreferences
                                                .actionOnRight)
                                              'Action',
                                          ])
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 16,
                                                  ),
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  color: primary,
                                                  fontSize: LaooTypography
                                                      .tableHeader,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      for (var i = 0; i < pageRows.length; i++)
                                        TableRow(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(6),
                                              child: Text('${start + i + 1}'),
                                            ),
                                            if (!_displayPreferences
                                                .actionOnRight)
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: _displayActions(
                                                  pageRows[i],
                                                  primary,
                                                ),
                                              ),
                                            for (final field in displayFields)
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                child: _displayValue(
                                                  field.key,
                                                  pageRows[i],
                                                  primary,
                                                ),
                                              ),
                                            if (_displayPreferences
                                                .actionOnRight)
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: _displayActions(
                                                  pageRows[i],
                                                  primary,
                                                ),
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  if (pageRows.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Center(child: Text('ไม่พบข้อมูล')),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (_cards || small)
                          ...pageRows.asMap().entries.map((entry) {
                            final row = entry.value;
                            return Card(
                              margin: EdgeInsets.only(
                                bottom: entry.key == pageRows.length - 1
                                    ? 0
                                    : 8,
                              ),
                              color: Colors.white,
                              elevation: 0,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  LaooLayout.cardPadding,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!_displayPreferences.actionOnRight)
                                      _displayActions(row, primary),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (final field in displayFields)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 3,
                                                  ),
                                              child: field.key == 'name'
                                                  ? DefaultTextStyle.merge(
                                                      style: TextStyle(
                                                        color: primary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                      child: _displayValue(
                                                        field.key,
                                                        row,
                                                        primary,
                                                      ),
                                                    )
                                                  : Wrap(
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      spacing: 4,
                                                      children: [
                                                        Text(
                                                          '${field.label}: ',
                                                        ),
                                                        _displayValue(
                                                          field.key,
                                                          row,
                                                          primary,
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (_displayPreferences.actionOnRight)
                                      _displayActions(row, primary),
                                  ],
                                ),
                              ),
                            );
                          }),
                        if ((_cards || small) && pageRows.isEmpty)
                          registrySurface(
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: Text('ไม่พบข้อมูล')),
                            ),
                          ),
                        const SizedBox(height: 8),
                        _pagination(
                          page,
                          pages,
                          start,
                          visible.length,
                          primary,
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }
}
