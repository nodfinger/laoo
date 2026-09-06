import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

import '../shared/shared_admin_ui_tokens.dart';

class OrganizationStructureWorkspace extends StatefulWidget {
  const OrganizationStructureWorkspace({
    super.key,
    required this.caption,
    required this.repository,
    required this.errorText,
    required this.titleBuilder,
    required this.messageBuilder,
    required this.tokens,
    required this.screenType,
  });

  final String caption;
  final OrganizationRepository repository;
  final SharedAdminErrorText errorText;
  final SharedAdminTitleBuilder titleBuilder;
  final SharedAdminMessageBuilder messageBuilder;
  final SharedAdminUiTokens tokens;
  final int screenType;

  @override
  State<OrganizationStructureWorkspace> createState() =>
      _OrganizationStructureWorkspaceState();
}

class _OrganizationStructureWorkspaceState
    extends State<OrganizationStructureWorkspace> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _nameEn = TextEditingController();

  List<OrganizationUnitRecord> _units = const [];
  int _mode = 1;
  int? _selectedDivisionId;
  OrganizationUnitRecord? _editing;
  String? _formType;
  bool _loading = true;
  bool _saving = false;
  bool _active = true;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  String? _message;
  bool _messageError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _nameEn.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    Map<String, bool> actions = const {};
    try {
      actions = await widget.repository.actions();
    } catch (_) {
      // Permission loading is fail-closed.
    }
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      final divisions = snapshot.units
          .where((unit) => unit.unitType == OrganizationUnitTypes.division)
          .toList(growable: false);
      final crud = widget.screenType == 1;
      setState(() {
        _mode = snapshot.orgStructureType;
        _units = snapshot.units;
        _selectedDivisionId = _mode == 2 && divisions.isNotEmpty
            ? divisions.first.orgUnitId
            : null;
        _canCreate = crud && actions['create'] == true;
        _canEdit = crud && actions['edit'] == true;
        _canDelete = crud && actions['delete'] == true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(widget.errorText(error), error: true);
    }
  }

  Future<void> _load({bool clearMessage = true}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        if (clearMessage) _message = null;
      });
    }
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      final divisions = snapshot.units
          .where((unit) => unit.unitType == OrganizationUnitTypes.division)
          .toList(growable: false);
      setState(() {
        _mode = snapshot.orgStructureType;
        _units = snapshot.units;
        if (_mode == 2 &&
            !divisions.any(
              (division) => division.orgUnitId == _selectedDivisionId,
            )) {
          _selectedDivisionId = divisions.isEmpty
              ? null
              : divisions.first.orgUnitId;
        }
      });
    } catch (error) {
      if (mounted) _showMessage(widget.errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String value, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _messageError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: tokens.contentMargin,
            child: _formType == null ? _buildList() : _buildForm(),
          ),
          if (_message != null)
            Positioned(
              top: tokens.contentMargin.top,
              left: tokens.contentMargin.left,
              right: tokens.contentMargin.right,
              child: Align(
                alignment: Alignment.topRight,
                child: widget.messageBuilder(
                  context,
                  _message!,
                  _messageError,
                  () => setState(() => _message = null),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final tokens = widget.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _surface(
          child: Padding(
            padding: tokens.cardPadding,
            child: widget.titleBuilder(context, widget.caption, true),
          ),
        ),
        SizedBox(height: tokens.cardSpacing),
        if (_loading) const LinearProgressIndicator(),
        if (!_loading)
          Expanded(
            child: _mode == 1
                ? _departmentPanel()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < tokens.compactBreakpoint) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 260, child: _divisionPanel()),
                            SizedBox(height: tokens.cardSpacing),
                            Expanded(child: _departmentPanel()),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 330, child: _divisionPanel()),
                          SizedBox(width: tokens.cardSpacing),
                          Expanded(child: _departmentPanel()),
                        ],
                      );
                    },
                  ),
          ),
      ],
    );
  }

  Widget _surface({required Widget child, BorderRadius? borderRadius}) {
    final tokens = widget.tokens;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: borderRadius ?? BorderRadius.circular(tokens.radius),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _divisionPanel() {
    final divisions = _units
        .where((unit) => unit.unitType == OrganizationUnitTypes.division)
        .toList(growable: false);
    final scheme = Theme.of(context).colorScheme;
    return _surface(
      child: Column(
        children: [
          _panelHeader(
            'ฝ่าย',
            'เพิ่มฝ่าย',
            _canCreate ? () => _openForm(OrganizationUnitTypes.division) : null,
            showButton: _canCreate,
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          if (divisions.isEmpty)
            const Expanded(child: Center(child: Text('ยังไม่มีข้อมูลฝ่าย')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: divisions.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                itemBuilder: (context, index) {
                  final item = divisions[index];
                  final count = _units
                      .where(
                        (unit) =>
                            unit.unitType == OrganizationUnitTypes.department &&
                            unit.parentOrgUnitId == item.orgUnitId,
                      )
                      .length;
                  final selected = item.orgUnitId == _selectedDivisionId;
                  return ListTile(
                    selected: selected,
                    selectedColor: scheme.primary,
                    iconColor: selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    leading: const Icon(Icons.account_tree_outlined),
                    title: Text('${item.unitCode} - ${item.nameTh}'),
                    subtitle: Text('แผนก $count รายการ'),
                    onTap: () =>
                        setState(() => _selectedDivisionId = item.orgUnitId),
                    trailing: _rowActions(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _departmentPanel() {
    OrganizationUnitRecord? selectedDivision;
    for (final unit in _units) {
      if (unit.orgUnitId == _selectedDivisionId) {
        selectedDivision = unit;
        break;
      }
    }
    final title = _mode == 1
        ? 'รายการแผนก'
        : selectedDivision == null
        ? 'แผนก'
        : 'ฝ่าย: ${selectedDivision.nameTh} → แผนก';
    final departments = _units
        .where((unit) {
          if (unit.unitType != OrganizationUnitTypes.department) return false;
          return _mode == 1 || unit.parentOrgUnitId == _selectedDivisionId;
        })
        .toList(growable: false);
    final enabled = _mode == 1 || _selectedDivisionId != null;
    return _surface(
      child: Column(
        children: [
          _panelHeader(
            title,
            'เพิ่มแผนก',
            enabled && _canCreate
                ? () => _openForm(OrganizationUnitTypes.department)
                : null,
            showButton: _canCreate,
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          if (!enabled)
            const Expanded(child: Center(child: Text('กรุณาเลือกฝ่าย')))
          else if (departments.isEmpty)
            const Expanded(child: Center(child: Text('ยังไม่มีข้อมูลแผนก')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: departments.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                itemBuilder: (context, index) {
                  final item = departments[index];
                  return ListTile(
                    leading: Text('${index + 1}'),
                    title: Text('${item.unitCode} - ${item.nameTh}'),
                    subtitle: item.isActive
                        ? null
                        : Text(
                            'ไม่ใช้งาน',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                    trailing: _rowActions(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _rowActions(OrganizationUnitRecord item) => Wrap(
    children: [
      if (_canEdit)
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () => _openForm(item.unitType, item: item),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (_canDelete)
        IconButton(
          tooltip: 'ลบ',
          onPressed: () => _confirmDelete(item),
          color: Theme.of(context).colorScheme.error,
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );

  Widget _panelHeader(
    String title,
    String buttonText,
    VoidCallback? onTap, {
    required bool showButton,
  }) {
    final tokens = widget.tokens;
    return Padding(
      padding: tokens.cardPadding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (showButton)
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: Text(buttonText),
            ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final tokens = widget.tokens;
    final action = _editing == null ? 'เพิ่ม' : 'แก้ไข';
    final unitName = _formType == OrganizationUnitTypes.division
        ? 'ฝ่าย'
        : 'แผนก';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _surface(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radius),
          ),
          child: Padding(
            padding: tokens.cardPadding,
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final title = widget.titleBuilder(
                      context,
                      '${widget.caption} > $action$unitName',
                      false,
                    );
                    final buttons = _formButtons();
                    if (constraints.maxWidth < tokens.compactBreakpoint) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          title,
                          SizedBox(height: tokens.cardSpacing),
                          Align(
                            alignment: Alignment.centerRight,
                            child: buttons,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: title),
                        buttons,
                      ],
                    );
                  },
                ),
                Divider(color: Theme.of(context).dividerColor),
              ],
            ),
          ),
        ),
        Expanded(
          child: _surface(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(tokens.radius),
            ),
            child: SingleChildScrollView(
              padding: tokens.cardPadding,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('สถานะ'),
                        SizedBox(width: tokens.cardSpacing),
                        Switch(
                          value: _active,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _active = value),
                        ),
                        Text(_active ? 'ใช้งาน' : 'ไม่ใช้งาน'),
                      ],
                    ),
                    SizedBox(height: tokens.cardSpacing + 2),
                    if (_formType == OrganizationUnitTypes.department &&
                        _mode == 2) ...[
                      DropdownButtonFormField<int>(
                        key: ValueKey(_selectedDivisionId),
                        isExpanded: true,
                        initialValue: _selectedDivisionId,
                        decoration: const InputDecoration(labelText: 'ฝ่าย *'),
                        items: _units
                            .where(
                              (unit) =>
                                  unit.unitType ==
                                  OrganizationUnitTypes.division,
                            )
                            .map(
                              (unit) => DropdownMenuItem<int>(
                                value: unit.orgUnitId,
                                child: Text(
                                  '${unit.unitCode} - ${unit.nameTh}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _selectedDivisionId = value),
                        validator: (value) =>
                            value == null ? 'กรุณาเลือกฝ่าย' : null,
                      ),
                      SizedBox(height: tokens.cardSpacing + 2),
                    ],
                    TextFormField(
                      controller: _code,
                      enabled: !_saving,
                      decoration: InputDecoration(labelText: 'รหัส$unitName *'),
                      validator: _required,
                    ),
                    SizedBox(height: tokens.cardSpacing + 2),
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: InputDecoration(labelText: 'ชื่อ$unitName *'),
                      validator: _required,
                    ),
                    SizedBox(height: tokens.cardSpacing + 2),
                    TextFormField(
                      controller: _nameEn,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: 'ชื่อ$unitName (ภาษาอังกฤษ)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null;

  Widget _formButtons() => Wrap(
    spacing: widget.tokens.cardSpacing,
    children: [
      OutlinedButton.icon(
        onPressed: _saving ? null : _closeForm,
        icon: const Icon(Icons.close),
        label: const Text('ยกเลิก'),
      ),
      if ((_editing == null && _canCreate) || (_editing != null && _canEdit))
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('บันทึก'),
        ),
    ],
  );

  void _openForm(String type, {OrganizationUnitRecord? item}) {
    setState(() {
      _formType = type;
      _editing = item;
      _code.text = item?.unitCode ?? '';
      _name.text = item?.nameTh ?? '';
      _nameEn.text = item?.nameEn ?? '';
      _active = item?.isActive ?? true;
      if (type == OrganizationUnitTypes.department && item != null) {
        _selectedDivisionId = item.parentOrgUnitId;
      }
      _message = null;
    });
  }

  void _closeForm() => setState(() {
    _formType = null;
    _editing = null;
    _message = null;
  });

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final request = OrganizationUnitUpsertRequest(
        unitType: _formType!,
        parentOrgUnitId:
            _formType == OrganizationUnitTypes.department && _mode == 2
            ? _selectedDivisionId
            : null,
        unitCode: _code.text.trim().toUpperCase(),
        nameTh: _name.text.trim(),
        nameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        isActive: _active,
      );
      if (_editing == null) {
        await widget.repository.create(request);
        _code.clear();
        _name.clear();
        _nameEn.clear();
        await _load(clearMessage: false);
        _showMessage('เพิ่มข้อมูลสำเร็จ');
      } else {
        await widget.repository.update(_editing!.orgUnitId, request);
        _closeForm();
        await _load(clearMessage: false);
        _showMessage('แก้ไขข้อมูลสำเร็จ');
      }
    } catch (error) {
      _showMessage(widget.errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(OrganizationUnitRecord item) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: scheme.error),
            SizedBox(width: widget.tokens.cardSpacing),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: widget.tokens.captionStyle,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(color: Theme.of(context).dividerColor),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(widget.tokens.radius),
              ),
              child: Padding(
                padding: widget.tokens.cardPadding,
                child: Text(
                  '${item.unitCode} - ${item.nameTh}',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
            SizedBox(height: widget.tokens.cardSpacing),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
            Divider(color: Theme.of(context).dividerColor),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.delete(item.orgUnitId);
      await _load(clearMessage: false);
      _showMessage('ลบข้อมูลสำเร็จ');
    } catch (error) {
      _showMessage(widget.errorText(error), error: true);
    }
  }
}
