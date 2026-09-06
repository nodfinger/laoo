import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../../profile/pages/user_profile_dialog.dart';
import '../data/meeting_facility_repository.dart';

class MeetingFacilityPage extends StatefulWidget {
  const MeetingFacilityPage({super.key});
  @override
  State<MeetingFacilityPage> createState() => _MeetingFacilityPageState();
}

class _MeetingFacilityPageState extends State<MeetingFacilityPage> {
  final _repo = MeetingFacilityRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _departments = [];
  Map<String, bool> _actions = {};
  bool _loading = true;
  bool _showCards = false;
  String? _message;
  String _caption = '';
  int? _filterDepartmentId;
  static const _pageSize = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _showCards = userDefaultViewModeNotifier.value == 'CARD';
    userDefaultViewModeNotifier.addListener(_syncDefaultViewMode);
    _resolveCaption();
    _load();
  }

  @override
  void dispose() {
    userDefaultViewModeNotifier.removeListener(_syncDefaultViewMode);
    _search.dispose();
    super.dispose();
  }

  void _syncDefaultViewMode() {
    if (mounted) {
      setState(() => _showCards = userDefaultViewModeNotifier.value == 'CARD');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _currentPage = 0;
    });
    try {
      final result = await Future.wait([
        _repo.get(),
        _repo.actions(),
        _repo.departments(),
      ]);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(result[0] as List);
          _actions = result[1] as Map<String, bool>;
          _departments = List<Map<String, dynamic>>.from(result[2] as List);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = _errorText(error, 'โหลดข้อมูลไม่สำเร็จ'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorText(Object error, String fallback) =>
      error is ApiException && error.description != null
      ? '${error.message}\n${error.description}'
      : error is ApiException
      ? error.message
      : '$fallback\n$error';
  Future<void> _resolveCaption() async {
    final caption = await NavigationMenuRepository().resolveMenuName(
      menuCode: '23003',
      routeName: 'meetingFacilities',
      fallback: '',
    );
    if (mounted) setState(() => _caption = caption);
  }

  List<Map<String, dynamic>> get _filtered {
    final term = _search.text.trim().toLowerCase();
    return _items.where((item) {
      if (_filterDepartmentId != null &&
          (item['responsibleDepartmentOrgUnitId'] as num?)?.toInt() !=
              _filterDepartmentId) {
        return false;
      }
      if (term.isEmpty) return true;
      return '${item['code']} ${item['nameTh']} ${item['description'] ?? ''} ${item['responsibleDepartmentName'] ?? ''}'
          .toLowerCase()
          .contains(term);
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleItems {
    final start = _currentPage * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _pageCount => (_filtered.length / _pageSize).ceil();

  Widget _facilityList(WorkspaceThemePreset preset) => LayoutBuilder(
    builder: (context, constraints) {
      final cardMode = _showCards || constraints.maxWidth < 900;
      return cardMode
          ? ListView.separated(
              itemCount: _visibleItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _visibleItems[index];
                return Card(
                  child: ListTile(
                    title: Text('${item['code']} | ${item['nameTh']}'),
                    subtitle: Text(
                      'แผนกรับผิดชอบ: ${item['responsibleDepartmentName'] ?? '-'}\n'
                      '${item['description'] ?? '-'}',
                    ),
                    trailing: _facilityActions(item, preset),
                  ),
                );
              },
            )
          : Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      preset.primary.withValues(alpha: .10),
                    ),
                    headingTextStyle: TextStyle(
                      color: preset.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    border: TableBorder(
                      horizontalInside: BorderSide(
                        color: LaooColors.border.withValues(alpha: .45),
                        width: .25,
                      ),
                    ),
                    columns: const [
                      DataColumn(
                        columnWidth: LaooDataTable.idColumnWidth,
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text('ID'),
                      ),
                      DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text('Action'),
                      ),
                      DataColumn(label: Text('รหัส')),
                      DataColumn(label: Text('ชื่อ')),
                      DataColumn(label: Text('แผนกรับผิดชอบ')),
                      DataColumn(label: Text('รายละเอียด')),
                    ],
                    rows: _visibleItems.asMap().entries.map((entry) {
                      final item = entry.value;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text('${_currentPage * _pageSize + entry.key + 1}'),
                          ),
                          DataCell(
                            Center(child: _facilityActions(item, preset)),
                          ),
                          DataCell(Text('${item['code']}')),
                          DataCell(Text('${item['nameTh']}')),
                          DataCell(
                            Text('${item['responsibleDepartmentName'] ?? '-'}'),
                          ),
                          DataCell(Text('${item['description'] ?? '-'}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
    },
  );

  Widget _facilityActions(
    Map<String, dynamic> item,
    WorkspaceThemePreset preset,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () => _edit(item: item),
          icon: Icon(Icons.edit_outlined, color: preset.primary),
        ),
      if (_actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          onPressed: () => _delete(item),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
    ],
  );

  Widget _pagination(WorkspaceThemePreset preset) {
    final total = _filtered.length;
    final start = total == 0 ? 0 : _currentPage * _pageSize + 1;
    final end = ((_currentPage + 1) * _pageSize).clamp(0, total);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
          onPressed: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
          child: const Icon(Icons.chevron_left),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: preset.primary,
            disabledBackgroundColor: preset.primary,
            disabledForegroundColor: Theme.of(context).colorScheme.onPrimary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            padding: const EdgeInsets.all(14),
          ),
          onPressed: null,
          child: Text('${_pageCount == 0 ? 0 : _currentPage + 1}'),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
          onPressed: _currentPage < _pageCount - 1
              ? () => setState(() => _currentPage++)
              : null,
          child: const Icon(Icons.chevron_right),
        ),
        Text('$start-$end จาก $total'),
      ],
    );
  }

  InputDecoration _facilityInputDecoration(
    String label,
    WorkspaceThemePreset preset,
  ) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      color: preset.primary,
      fontSize: LaooTypography.inputLabel,
    ),
    floatingLabelStyle: TextStyle(
      color: preset.primary,
      fontSize: LaooTypography.inputLabel,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      borderSide: BorderSide(color: preset.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      borderSide: BorderSide(color: preset.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      borderSide: BorderSide(color: preset.primary, width: 1.5),
    ),
  );

  Future<void> _edit({Map<String, dynamic>? item}) async {
    final code = TextEditingController(text: item?['code'] as String? ?? '');
    final name = TextEditingController(text: item?['nameTh'] as String? ?? '');
    final description = TextEditingController(
      text: item?['description'] as String? ?? '',
    );
    int? departmentId = (item?['responsibleDepartmentOrgUnitId'] as num?)
        ?.toInt();
    final preset = workspaceThemeController.value;
    String? codeError;
    String? nameError;
    String? departmentError;
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Row(
            children: [
              Icon(
                item == null ? Icons.add : Icons.edit_outlined,
                color: preset.primary,
              ),
              const SizedBox(width: 8),
              Text(
                item == null
                    ? 'เพิ่มสิ่งอำนวยความสะดวก'
                    : 'แก้ไขสิ่งอำนวยความสะดวก',
                style: LaooTypography.popupTitleStyle,
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(
                  color: preset.primary.withValues(alpha: .45),
                  height: 1,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  onChanged: (_) => refresh(() => codeError = null),
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: LaooTypography.inputText),
                  decoration: _facilityInputDecoration(
                    'รหัสอุปกรณ์ *',
                    preset,
                  ).copyWith(errorText: codeError),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue:
                      _departments.any(
                        (department) =>
                            (department['orgUnitId'] as num?)?.toInt() ==
                            departmentId,
                      )
                      ? departmentId
                      : null,
                  style: TextStyle(
                    fontSize: LaooTypography.comboBox,
                    color: preset.textPrimary,
                  ),
                  decoration: _facilityInputDecoration(
                    'แผนกรับผิดชอบ *',
                    preset,
                  ).copyWith(errorText: departmentError),
                  items: _departments
                      .map(
                        (department) => DropdownMenuItem<int>(
                          value: (department['orgUnitId'] as num).toInt(),
                          child: Text(
                            '${department['nameTh']}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: LaooTypography.comboBox,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => refresh(() {
                    departmentId = value;
                    departmentError = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  onChanged: (_) => refresh(() => nameError = null),
                  style: const TextStyle(fontSize: LaooTypography.inputText),
                  decoration: _facilityInputDecoration(
                    'ชื่อสิ่งอำนวยความสะดวก *',
                    preset,
                  ).copyWith(errorText: nameError),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 3,
                  style: const TextStyle(fontSize: LaooTypography.inputText),
                  decoration: _facilityInputDecoration('รายละเอียด', preset),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: preset.primary),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: preset.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () {
                if (code.text.trim().isEmpty) {
                  codeError = 'กรุณากรอกรหัสอุปกรณ์';
                }
                if (name.text.trim().isEmpty) {
                  nameError = 'กรุณากรอกชื่อสิ่งอำนวยความสะดวก';
                }
                if (departmentId == null) {
                  departmentError = 'กรุณาเลือกแผนกรับผิดชอบ';
                }
                if (codeError != null ||
                    nameError != null ||
                    departmentError != null) {
                  refresh(() {});
                  return;
                }
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, {
                  'code': code.text.trim(),
                  'nameTh': name.text.trim(),
                  'description': description.text.trim(),
                  'responsibleDepartmentOrgUnitId': departmentId,
                });
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
    description.dispose();
    if (value == null) return;
    try {
      await _repo.save(value, id: item?['facilityId'] as int?);
      if (mounted) {
        setState(() => _message = 'บันทึกข้อมูลสำเร็จ');
        await _load();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = _errorText(error, 'บันทึกข้อมูลไม่สำเร็จ'));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final preset = workspaceThemeController.value;
    final red = Theme.of(context).colorScheme.error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: red.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: red.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'ต้องการลบ ${item['code']} - ${item['nameTh']} หรือไม่?\nข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้',
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: preset.primary),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(item['facilityId'] as int);
      if (mounted) {
        setState(() => _message = 'ลบข้อมูลสำเร็จ');
        await _load();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = _errorText(error, 'ลบข้อมูลไม่สำเร็จ'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return SupportWorkspaceShell(
      menuScope: WorkspaceMenuScope.company,
      pageTitle: _caption,
      activeMenu: '23003',
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: WorkspaceSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: WorkspacePageTitle(
                          title: _caption,
                          favoriteKey: '23003',
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 900)
                        IconButton(
                          tooltip: _showCards ? 'แสดง List' : 'แสดง Card',
                          style: IconButton.styleFrom(
                            foregroundColor: preset.primary,
                            side: BorderSide(color: preset.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          onPressed: () =>
                              setState(() => _showCards = !_showCards),
                          icon: Icon(
                            _showCards
                                ? Icons.table_rows_outlined
                                : Icons.grid_view_outlined,
                          ),
                        ),
                      if (MediaQuery.sizeOf(context).width >= 900)
                        const SizedBox(width: 8),
                      if (_actions['create'] == true)
                        FilledButton.icon(
                          onPressed: () => _edit(),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่ม'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth < 600
                              ? constraints.maxWidth
                              : 260,
                          child: TextField(
                            controller: _search,
                            onSubmitted: (_) => setState(() {}),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: const Icon(Icons.arrow_forward),
                              labelText: 'ค้นหารหัสหรือชื่อ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: preset.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          onPressed: () => setState(() => _currentPage = 0),
                          icon: const Icon(Icons.search),
                          label: const Text('ค้นหา'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: preset.primary,
                            side: BorderSide(color: preset.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          onPressed: () {
                            _search.clear();
                            setState(() {
                              _filterDepartmentId = null;
                              _currentPage = 0;
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('ล้าง Filter'),
                        ),
                        SizedBox(
                          width: constraints.maxWidth < 600
                              ? constraints.maxWidth
                              : 280,
                          child: DropdownButtonFormField<int?>(
                            isExpanded: true,
                            initialValue: _filterDepartmentId,
                            style: TextStyle(
                              color: preset.textPrimary,
                              fontSize: LaooTypography.comboBox,
                            ),
                            decoration: _facilityInputDecoration(
                              'แผนกรับผิดชอบ',
                              preset,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('ทั้งหมด'),
                              ),
                              ..._departments.map(
                                (department) => DropdownMenuItem<int?>(
                                  value: (department['orgUnitId'] as num)
                                      .toInt(),
                                  child: Text(
                                    '${department['nameTh']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              _filterDepartmentId = value;
                              _currentPage = 0;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loading) const LinearProgressIndicator(),
                  Expanded(child: _facilityList(preset)),
                  const SizedBox(height: 8),
                  _pagination(preset),
                ],
              ),
            ),
          ),
          if (_message != null)
            Positioned(
              top: 12,
              right: 12,
              child: AutoDismissMessage(
                message: _message!,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }
}
