import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../../core/widgets/combo_box_text.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/organization_repository.dart';

class OrganizationStructurePage extends StatefulWidget {
  const OrganizationStructurePage({super.key});

  @override
  State<OrganizationStructurePage> createState() =>
      _OrganizationStructurePageState();
}

class _OrganizationStructurePageState extends State<OrganizationStructurePage> {
  final _repository = OrganizationRepository();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _nameEn = TextEditingController();

  List<Map<String, dynamic>> _units = [];
  String _caption = '';
  int _mode = 1;
  int? _selectedDivisionId;
  Map<String, dynamic>? _editing;
  String? _formType;
  bool _loading = true;
  bool _saving = false;
  bool _active = true;
  bool _canCreate = false, _canEdit = false, _canDelete = false;
  String? _message;
  bool _divisionDialogOpen = false;

  String get _menuCode => appAuthController.isPartnerUser
      ? '11005'
      : appAuthController.isCompanyUser
      ? '10005'
      : '12005';

  String _errorMessage(Object error) =>
      error is ApiException ? error.message : error.toString();
  bool _messageError = false;

  @override
  void initState() {
    super.initState();
    _loadActions();
    _resolveCaption();
    _load();
  }

  Future<void> _loadActions() async {
    try {
      final p = await _repository.actions();
      if (mounted) {
        setState(() {
          _canCreate = p['create'] == true;
          _canEdit = p['edit'] == true;
          _canDelete = p['delete'] == true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _nameEn.dispose();
    super.dispose();
  }

  Future<void> _resolveCaption() async {
    final menuCode = appAuthController.isPartnerUser
        ? '11005'
        : appAuthController.isCompanyUser
        ? '10005'
        : '12005';
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: menuCode,
      routeName: 'organizationStructure',
      fallback: '',
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load({bool clearMessage = true}) async {
    setState(() {
      _loading = true;
      if (clearMessage) _message = null;
    });
    try {
      final result = await _repository.load();
      if (!mounted) return;
      final units = List<Map<String, dynamic>>.from(
        result['units'] as List? ?? const [],
      );
      final divisions = units.where((x) => x['unitType'] == 'DIV').toList();
      setState(() {
        _mode = result['orgStructureType'] as int? ?? 1;
        _units = units;
        if (_mode == 2 &&
            !divisions.any((x) => x['orgUnitId'] == _selectedDivisionId)) {
          _selectedDivisionId = divisions.isEmpty
              ? null
              : divisions.first['orgUnitId'] as int;
        }
      });
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String value, {bool error = false}) {
    setState(() {
      _message = value;
      _messageError = error;
    });
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<WorkspaceThemePreset>(
        valueListenable: workspaceThemeController,
        builder: (context, _, _) => SupportWorkspaceShell(
          pageTitle: _caption,
          activeMenu: 'organizationStructure',
          menuScope: appAuthController.isPartnerUser
              ? WorkspaceMenuScope.partner
              : appAuthController.isCompanyUser
              ? WorkspaceMenuScope.company
              : WorkspaceMenuScope.support,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(LaooLayout.cardMargin),
                child: _formType == null ? _buildList() : _buildForm(),
              ),
              if (_message != null)
                Positioned(top: 12, right: 24, child: _messageBox()),
            ],
          ),
        ),
      );

  Widget _buildList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      WorkspaceSectionCard(
        child: WorkspacePageTitle(title: _caption, favoriteKey: _menuCode),
      ),
      const Divider(height: 1, color: LaooColors.border),
      if (_loading) const LinearProgressIndicator(),
      if (!_loading)
        Expanded(
          child: _mode == 1
              ? _departmentPanel()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 260, child: _divisionPanel()),
                          const SizedBox(height: 8),
                          Expanded(child: _departmentPanel()),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 330, child: _divisionPanel()),
                        const SizedBox(width: 8),
                        Expanded(child: _departmentPanel()),
                      ],
                    );
                  },
                ),
        ),
    ],
  );

  Widget _divisionPanel() {
    final divisions = _units.where((x) => x['unitType'] == 'DIV').toList();
    final colors = Theme.of(context).colorScheme;
    final primary = workspaceThemeController.value.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _panelHeader(
            'ฝ่าย',
            'เพิ่มฝ่าย',
            _canCreate ? () => _openForm('DIV') : null,
          ),
          const Divider(height: 1),
          if (divisions.isEmpty)
            const Expanded(child: Center(child: Text('ยังไม่มีข้อมูลฝ่าย')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: divisions.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: LaooColors.border),
                itemBuilder: (context, index) {
                  final item = divisions[index];
                  final departmentCount = _units
                      .where(
                        (unit) =>
                            unit['unitType'] == 'DEP' &&
                            unit['parentOrgUnitId'] == item['orgUnitId'],
                      )
                      .length;
                  final selected = item['orgUnitId'] == _selectedDivisionId;
                  return ListTile(
                    selected: selected,
                    selectedColor: primary,
                    iconColor: selected ? primary : colors.onSurfaceVariant,
                    textColor: colors.onSurface,
                    leading: const Icon(Icons.account_tree_outlined),
                    title: Text('${item['unitCode']} - ${item['nameTh']}'),
                    subtitle: Text('แผนก $departmentCount รายการ'),
                    onTap: () => setState(
                      () => _selectedDivisionId = item['orgUnitId'] as int,
                    ),
                    trailing: Wrap(
                      children: [
                        if (_canEdit)
                          IconButton(
                            tooltip: 'แก้ไข',
                            onPressed: () => _openForm('DIV', item: item),
                            icon: Icon(Icons.edit_outlined, color: primary),
                          ),
                        if (_canDelete)
                          IconButton(
                            tooltip: 'ลบ',
                            onPressed: () => _confirmDelete(item),
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _departmentPanel() {
    Map<String, dynamic>? selectedDivision;
    for (final item in _units) {
      if (item['orgUnitId'] == _selectedDivisionId) {
        selectedDivision = item;
        break;
      }
    }
    final departmentTitle = _mode == 1
        ? 'รายการแผนก'
        : selectedDivision == null
        ? 'แผนก'
        : 'ฝ่าย: ${selectedDivision['nameTh']} → แผนก';
    final departments = _units.where((item) {
      if (item['unitType'] != 'DEP') return false;
      return _mode == 1 || item['parentOrgUnitId'] == _selectedDivisionId;
    }).toList();
    final enabled = _mode == 1 || _selectedDivisionId != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _panelHeader(
            departmentTitle,
            'เพิ่มแผนก',
            enabled && _canCreate ? () => _openForm('DEP') : null,
          ),
          const Divider(height: 1, color: LaooColors.border),
          if (!enabled)
            const Expanded(child: Center(child: Text('กรุณาเลือกฝ่าย')))
          else if (departments.isEmpty)
            const Expanded(child: Center(child: Text('ยังไม่มีข้อมูลแผนก')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: departments.length,
                separatorBuilder: (_, _) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final item = departments[index];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: LaooColors.border),
                      ),
                    ),
                    child: ListTile(
                      leading: Text('${index + 1}'),
                      title: Text('${item['unitCode']} - ${item['nameTh']}'),
                      trailing: Wrap(
                        children: [
                          if (_canEdit)
                            IconButton(
                              tooltip: 'แก้ไข',
                              onPressed: () => _openForm('DEP', item: item),
                              icon: Icon(
                                Icons.edit_outlined,
                                color: workspaceThemeController.value.primary,
                              ),
                            ),
                          if (_canDelete)
                            IconButton(
                              tooltip: 'ลบ',
                              onPressed: () => _confirmDelete(item),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _panelHeader(String title, String buttonText, VoidCallback? onTap) {
    final preset = workspaceThemeController.value;
    return Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: LaooColors.pageCaption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: preset.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            onPressed: onTap,
            icon: const Icon(Icons.add),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final action = _editing == null ? 'เพิ่ม' : 'แก้ไข';
    final unitName = _formType == 'DIV' ? 'ฝ่าย' : 'แผนก';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkspaceActionHeader(
          title: '$_caption > $action$unitName',
          favoriteKey: _menuCode,
          actions: [_formButtons()],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('สถานะ'),
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: Switch(
                          value: _active,
                          onChanged: (value) => setState(() => _active = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_formType == 'DEP' && _mode == 2) ...[
                    DropdownButtonFormField<int>(
                      key: ValueKey(_selectedDivisionId),
                      initialValue: _selectedDivisionId,
                      decoration: const InputDecoration(labelText: 'ฝ่าย *'),
                      items: _units
                          .where((item) => item['unitType'] == 'DIV')
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item['orgUnitId'] as int,
                              child: LaooComboBoxText(
                                '${item['unitCode']} - ${item['nameTh']}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedDivisionId = value),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _code,
                    decoration: InputDecoration(labelText: 'รหัส$unitName *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(labelText: 'ชื่อ$unitName *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameEn,
                    decoration: InputDecoration(
                      labelText: 'ชื่อ$unitName (ภาษาอังกฤษ)',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _formButtons() => Wrap(
    spacing: 8,
    children: [
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: workspaceThemeController.value.primary,
          side: BorderSide(color: workspaceThemeController.value.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
        ),
        onPressed: _saving ? null : _closeForm,
        child: const Text('ยกเลิก'),
      ),
      if ((_editing == null && _canCreate) || (_editing != null && _canEdit))
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: workspaceThemeController.value.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
          onPressed: _saving ? null : _save,
          child: const Text('บันทึก'),
        ),
    ],
  );

  Widget _messageBox() {
    return AutoDismissMessage(
      key: ValueKey(_message),
      message: _message!,
      error: _messageError,
      onClose: () => setState(() => _message = null),
    );
  }

  void _openForm(String type, {Map<String, dynamic>? item}) {
    _openUnitDialog(type, item: item);
  }

  Future<void> _openUnitDialog(
    String type, {
    Map<String, dynamic>? item,
  }) async {
    _code.text = item?['unitCode']?.toString() ?? '';
    _name.text = item?['nameTh']?.toString() ?? '';
    _nameEn.text = item?['nameEn']?.toString() ?? '';
    _active = item?['isActive'] as bool? ?? true;
    _editing = item;
    _formType = type;
    if (type == 'DEP') {
      _selectedDivisionId =
          item?['parentOrgUnitId'] as int? ?? _selectedDivisionId;
    }
    _divisionDialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final preset = workspaceThemeController.value;
        final isDivision = type == 'DIV';
        final unitName = isDivision ? 'ฝ่าย' : 'แผนก';
        final inputBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        );
        final enabledInputBorder = inputBorder.copyWith(
          borderSide: const BorderSide(color: LaooColors.border),
        );
        final focusedInputBorder = inputBorder.copyWith(
          borderSide: BorderSide(color: preset.primary, width: 2),
        );
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final popupWidth = viewportWidth < 420 ? viewportWidth - 32 : 680.0;
        final parentMatches = _units
            .where((unit) => unit['orgUnitId'] == _selectedDivisionId)
            .toList();
        final parent = parentMatches.isEmpty ? null : parentMatches.first;
        return StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            backgroundColor: LaooColors.background,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            constraints: const BoxConstraints(maxWidth: 720),
            contentPadding: const EdgeInsets.fromLTRB(
              LaooLayout.cardPadding,
              0,
              LaooLayout.cardPadding,
              LaooLayout.cardPadding,
            ),
            titlePadding: const EdgeInsets.fromLTRB(
              LaooLayout.cardPadding,
              LaooLayout.cardPadding,
              LaooLayout.cardPadding,
              12,
            ),
            title: Row(
              children: [
                Icon(
                  isDivision
                      ? Icons.account_tree_outlined
                      : Icons.subdirectory_arrow_right,
                  color: preset.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item == null ? 'เพิ่ม$unitName' : 'แก้ไข$unitName',
                    style: LaooTypography.popupTitleStyle,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: popupWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1, color: LaooColors.border),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  if (!isDivision) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      color: preset.primary.withValues(alpha: .10),
                      child: Text(
                        parent == null
                            ? 'เลือกฝ่ายที่สังกัด'
                            : 'ฝ่าย: ${parent['unitCode']} | ${parent['nameTh']}',
                        style: TextStyle(
                          color: preset.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: LaooLayout.cardSpacing),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedDivisionId,
                      style: const TextStyle(
                        color: LaooColors.pageCaption,
                        fontSize: LaooTypography.inputText,
                      ),
                      decoration: InputDecoration(
                        labelText: 'ฝ่าย *',
                        labelStyle: TextStyle(color: preset.primary),
                        floatingLabelStyle: TextStyle(color: preset.primary),
                        border: enabledInputBorder,
                        enabledBorder: enabledInputBorder,
                        focusedBorder: focusedInputBorder,
                      ),
                      items: _units
                          .where((unit) => unit['unitType'] == 'DIV')
                          .map(
                            (unit) => DropdownMenuItem<int>(
                              value: unit['orgUnitId'] as int,
                              child: Text(
                                '${unit['unitCode']} - ${unit['nameTh']}',
                                style: TextStyle(color: LaooColors.pageCaption),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        _selectedDivisionId = value;
                        refresh(() {});
                      },
                    ),
                    const SizedBox(height: LaooLayout.cardSpacing),
                  ],
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      color: LaooColors.pageCaption,
                      fontSize: LaooTypography.inputText,
                    ),
                    decoration: InputDecoration(
                      labelText: 'รหัส$unitName *',
                      labelStyle: TextStyle(color: preset.primary),
                      floatingLabelStyle: TextStyle(color: preset.primary),
                      border: enabledInputBorder,
                      enabledBorder: enabledInputBorder,
                      focusedBorder: focusedInputBorder,
                    ),
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  TextField(
                    controller: _name,
                    style: const TextStyle(
                      color: LaooColors.pageCaption,
                      fontSize: LaooTypography.inputText,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ชื่อ$unitName *',
                      labelStyle: TextStyle(color: preset.primary),
                      floatingLabelStyle: TextStyle(color: preset.primary),
                      border: enabledInputBorder,
                      enabledBorder: enabledInputBorder,
                      focusedBorder: focusedInputBorder,
                    ),
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  TextField(
                    controller: _nameEn,
                    style: const TextStyle(
                      color: LaooColors.pageCaption,
                      fontSize: LaooTypography.inputText,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ชื่อ$unitName (ภาษาอังกฤษ)',
                      labelStyle: TextStyle(color: preset.primary),
                      floatingLabelStyle: TextStyle(color: preset.primary),
                      border: enabledInputBorder,
                      enabledBorder: enabledInputBorder,
                      focusedBorder: focusedInputBorder,
                    ),
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  Row(
                    children: [
                      Text(
                        'สถานะ',
                        style: TextStyle(color: preset.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _active,
                        thumbColor: const WidgetStatePropertyAll(Colors.white),
                        trackColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? preset.primary
                              : LaooColors.border,
                        ),
                        onChanged: (value) {
                          _active = value;
                          refresh(() {});
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: LaooColors.border),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: preset.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(dialogContext),
                        child: const Text('ยกเลิก'),
                      ),
                      if ((_editing == null && _canCreate) ||
                          (_editing != null && _canEdit)) ...[
                        const SizedBox(width: 8),
                        FilledButton(
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
                          onPressed: _saving
                              ? null
                              : () {
                                  refresh(() {});
                                  _save();
                                },
                          child: const Text('บันทึก'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _divisionDialogOpen = false;
    _editing = null;
    _formType = null;
  }

  void _closeForm() => setState(() {
    _formType = null;
    _editing = null;
    _message = null;
  });

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty) {
      _showMessage('กรุณากรอกรหัสและชื่อให้ครบ', error: true);
      return;
    }
    if (_formType == 'DEP' && _mode == 2 && _selectedDivisionId == null) {
      _showMessage('กรุณาเลือกฝ่าย', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'unitType': _formType,
        'parentOrgUnitId': _formType == 'DEP' && _mode == 2
            ? _selectedDivisionId
            : null,
        'unitCode': _code.text.trim().toUpperCase(),
        'nameTh': _name.text.trim(),
        'nameEn': _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        'isActive': _active,
      };
      if (_editing == null) {
        await _repository.create(body);
        _code.clear();
        _name.clear();
        _nameEn.clear();
        _showMessage('เพิ่มข้อมูลสำเร็จ');
        await _load(clearMessage: false);
      } else {
        await _repository.update(_editing!['orgUnitId'] as int, body);
        _closeForm();
        await _load(clearMessage: false);
        _showMessage('แก้ไขข้อมูลสำเร็จ');
      }
      if (_divisionDialogOpen && mounted) {
        _divisionDialogOpen = false;
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final red = Theme.of(dialogContext).colorScheme.error;
        return AlertDialog(
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ต้องการลบ ${item['unitCode']} - ${item['nameTh']} หรือไม่?',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
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
        );
      },
    );
    if (confirmed != true) return;
    try {
      await _repository.delete(item['orgUnitId'] as int);
      await _load(clearMessage: false);
      _showMessage('ลบข้อมูลสำเร็จ', error: true);
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    }
  }
}
