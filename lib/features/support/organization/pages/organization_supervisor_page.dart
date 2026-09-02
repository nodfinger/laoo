import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../meeting/data/meeting_company_directory_repository.dart';
import '../data/organization_supervisor_repository.dart';
import '../../presentation/widgets/support_workspace_shell.dart';

class OrganizationSupervisorPage extends StatefulWidget {
  const OrganizationSupervisorPage({super.key});

  @override
  State<OrganizationSupervisorPage> createState() =>
      _OrganizationSupervisorPageState();
}

class _OrganizationSupervisorPageState
    extends State<OrganizationSupervisorPage> {
  final _repository = OrganizationSupervisorRepository();
  final _employeeRepository = MeetingEmployeeDirectoryRepository();
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _employees = [];
  String _caption = 'กำหนดผู้บังคับบัญชา';
  String? _message;
  bool _loading = true;
  final Set<int> _saving = {};

  @override
  void initState() {
    super.initState();
    _loadCaption();
    _load();
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: '23005',
      routeName: 'companySupervisors',
      fallback: 'กำหนดผู้บังคับบัญชา',
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await Future.wait([
        _repository.list(),
        _employeeRepository.list(isActive: true, page: 1, pageSize: 500),
      ]);
      final employeeResult = result[1] as Map;
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(result[0] as List);
        _employees = List<Map<String, dynamic>>.from(
          employeeResult['items'] as List? ?? const [],
        );
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _message = _error(error, 'โหลดข้อมูลผู้บังคับบัญชาไม่สำเร็จ');
        });
    }
  }

  String _error(Object error, String fallback) => error is ApiException
      ? '${error.message}${error.description == null ? '' : '\n${error.description}'}'
      : '$fallback\n$error';

  String _type(Map<String, dynamic> row) =>
      row['unitType'] == 'DIV' ? 'DIVISION_MANAGER' : 'DEPARTMENT_HEAD';
  String _label(Map<String, dynamic> row) =>
      row['unitType'] == 'DIV' ? 'ผู้จัดการฝ่าย' : 'หัวหน้าแผนก';
  int? _selected(Map<String, dynamic> row) =>
      (row['employeeId'] as num?)?.toInt();

  Future<void> _save(
    Map<String, dynamic> row,
    int? employeeId,
    WorkspaceThemePreset preset,
  ) async {
    if (employeeId == null) return;
    final unitId = (row['orgUnitId'] as num).toInt();
    setState(() => _saving.add(unitId));
    try {
      await _repository.save(unitId, employeeId, _type(row));
      if (!mounted) return;
      setState(() => _message = 'บันทึกผู้บังคับบัญชาสำเร็จ');
      await _load();
    } catch (error) {
      if (mounted)
        setState(
          () => _message = _error(error, 'บันทึกผู้บังคับบัญชาไม่สำเร็จ'),
        );
    } finally {
      if (mounted) setState(() => _saving.remove(unitId));
    }
  }

  Widget _employeeDropdown(
    Map<String, dynamic> row,
    WorkspaceThemePreset preset, {
    double? width,
  }) {
    final unitId = (row['orgUnitId'] as num).toInt();
    final selectedId = _selected(row);
    final employees = _employees.where((employee) {
      final assignedUnitId = row['unitType'] == 'DIV'
          ? (employee['divisionOrgUnitId'] as num?)?.toInt()
          : (employee['departmentOrgUnitId'] as num?)?.toInt();
      return assignedUnitId == unitId ||
          (selectedId != null && employee['employeeId'] == selectedId);
    }).toList();
    return SizedBox(
      width: width ?? 300,
      child: DropdownButtonFormField<int>(
        initialValue: selectedId,
        style: TextStyle(
          color: preset.textPrimary,
          fontSize: LaooTypography.inputText,
        ),
        decoration: InputDecoration(
          labelText: _label(row),
          labelStyle: TextStyle(
            color: preset.primary,
            fontSize: LaooTypography.inputLabel,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: preset.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: preset.primary, width: 2),
          ),
        ),
        items: employees.map((employee) {
          final id = (employee['employeeId'] as num).toInt();
          final nick = employee['nickName']?.toString() ?? '';
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              '${employee['employeeCode']} | ${employee['fullName']}${nick.isEmpty ? '' : ' | $nick'}',
              style: TextStyle(
                color: preset.textPrimary,
                fontSize: LaooTypography.inputText,
              ),
            ),
          );
        }).toList(),
        onChanged: _saving.contains(unitId)
            ? null
            : (value) => _save(row, value, preset),
      ),
    );
  }

  Widget _row(Map<String, dynamic> row, WorkspaceThemePreset preset) {
    final isDivision = row['unitType'] == 'DIV';
    return Card(
      margin: EdgeInsets.only(left: isDivision ? 0 : 28),
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            final title = Row(
              children: [
                Icon(
                  isDivision
                      ? Icons.account_balance_outlined
                      : Icons.subdirectory_arrow_right,
                  color: preset.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${row['unitCode']} | ${row['nameTh']}',
                    style: TextStyle(
                      color: preset.textPrimary,
                      fontSize: LaooTypography.inputText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 8),
                  _employeeDropdown(row, preset, width: double.infinity),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                _employeeDropdown(row, preset),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _groupBlock(
    Map<String, dynamic> division,
    List<Map<String, dynamic>> departments,
    WorkspaceThemePreset preset,
  ) {
    final divisionId = (division['orgUnitId'] as num).toInt();
    final children = departments
        .where(
          (department) =>
              (department['parentOrgUnitId'] as num?)?.toInt() == divisionId,
        )
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: LaooLayout.cardSpacing),
      decoration: BoxDecoration(
        color: LaooColors.white,
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Column(
        children: [
          _row(division, preset),
          ...children.map((department) => _row(department, preset)),
        ],
      ),
    );
  }

  List<Widget> _groupBlocks(WorkspaceThemePreset preset) {
    final divisions = _rows.where((row) => row['unitType'] == 'DIV').toList();
    final departments = _rows.where((row) => row['unitType'] == 'DEP').toList();
    final used = <int>{};
    final blocks = <Widget>[];
    for (final division in divisions) {
      final divisionId = (division['orgUnitId'] as num).toInt();
      final children = departments
          .where(
            (department) =>
                (department['parentOrgUnitId'] as num?)?.toInt() == divisionId,
          )
          .toList();
      used.addAll(children.map((row) => (row['orgUnitId'] as num).toInt()));
      blocks.add(_groupBlock(division, departments, preset));
    }
    for (final department in departments) {
      final id = (department['orgUnitId'] as num).toInt();
      if (!used.contains(id))
        blocks.add(_groupBlock(department, const [], preset));
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return SupportWorkspaceShell(
      menuScope: WorkspaceMenuScope.company,
      pageTitle: _caption,
      activeMenu: '23005',
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSectionCard(
                  child: WorkspacePageTitle(
                    title: _caption,
                    favoriteKey: '23005',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(children: _groupBlocks(preset)),
                ),
              ],
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
