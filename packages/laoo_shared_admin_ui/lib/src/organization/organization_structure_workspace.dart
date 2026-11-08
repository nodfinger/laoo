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
    this.inputTextStyle,
    this.inputLabelStyle,
    this.floatingLabelStyle,
  });

  final String caption;
  final OrganizationRepository repository;
  final SharedAdminErrorText errorText;
  final SharedAdminTitleBuilder titleBuilder;
  final SharedAdminMessageBuilder messageBuilder;
  final SharedAdminUiTokens tokens;
  final int screenType;
  final TextStyle? inputTextStyle;
  final TextStyle? inputLabelStyle;
  final TextStyle? floatingLabelStyle;

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
  StateSetter? _dialogSetState;
  BuildContext? _dialogContext;

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
    _dialogSetState?.call(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(padding: tokens.contentMargin, child: _buildList()),
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
    final scheme = Theme.of(context).colorScheme;
    final action = _editing == null ? 'เพิ่ม' : 'แก้ไข';
    final unitName = _formType == OrganizationUnitTypes.division
        ? 'ฝ่าย'
        : 'แผนก';
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: scheme.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.caption} > $action$unitName',
                        style: widget.tokens.captionStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Divider(height: 1),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'สถานะ',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          SizedBox(width: tokens.cardSpacing),
                          Switch(
                            value: _active,
                            activeTrackColor: scheme.primary,
                            onChanged: _saving
                                ? null
                                : (value) => _dialogSetState?.call(
                                    () => _active = value,
                                  ),
                          ),
                          Text(
                            _active ? 'ใช้งาน' : 'ไม่ใช้งาน',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_formType == OrganizationUnitTypes.department &&
                          _mode == 2) ...[
                        DropdownButtonFormField<int>(
                          key: ValueKey(_selectedDivisionId),
                          isExpanded: true,
                          initialValue: _selectedDivisionId,
                          style: Theme.of(context).textTheme.titleMedium,
                          decoration: _formDecoration('ฝ่าย *'),
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
                              : (value) => _dialogSetState?.call(
                                  () => _selectedDivisionId = value,
                                ),
                          validator: (value) =>
                              value == null ? 'กรุณาเลือกฝ่าย' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _code,
                        style: widget.inputTextStyle,
                        enabled: !_saving,
                        decoration: _formDecoration('รหัส$unitName *'),
                        validator: _required,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        style: widget.inputTextStyle,
                        enabled: !_saving,
                        decoration: _formDecoration('ชื่อ$unitName *'),
                        validator: _required,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameEn,
                        style: widget.inputTextStyle,
                        enabled: !_saving,
                        decoration: _formDecoration(
                          'ชื่อ$unitName (ภาษาอังกฤษ)',
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          style: TextStyle(
                            color: _messageError
                                ? scheme.error
                                : scheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Divider(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: _formButtons(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null;

  InputDecoration _formDecoration(String label) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.tokens.radius),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: widget.inputLabelStyle,
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => (widget.floatingLabelStyle ?? const TextStyle()).copyWith(
          color: states.contains(WidgetState.error)
              ? scheme.error
              : states.contains(WidgetState.focused)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      disabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 1.5),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.5),
    );
  }

  Widget _formButtons() => Wrap(
    spacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: _saving ? null : _closeForm,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(84, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.tokens.radius),
          ),
        ),
        icon: const Icon(Icons.close),
        label: const Text('ยกเลิก'),
      ),
      if ((_editing == null && _canCreate) || (_editing != null && _canEdit))
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            minimumSize: const Size(100, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.tokens.radius),
            ),
          ),
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
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: .54),
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            return _buildForm();
          },
        );
      },
    ).whenComplete(() {
      _dialogSetState = null;
      _dialogContext = null;
      if (mounted && _formType != null) {
        setState(() {
          _formType = null;
          _editing = null;
        });
      }
    });
  }

  void _closeForm() {
    final dialogContext = _dialogContext;
    _dialogContext = null;
    _dialogSetState = null;
    if (dialogContext != null) Navigator.of(dialogContext).pop();
    setState(() {
      _formType = null;
      _editing = null;
      _message = null;
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    _dialogSetState?.call(() {});
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
      if (mounted) {
        setState(() => _saving = false);
        _dialogSetState?.call(() {});
      }
    }
  }

  Future<void> _confirmDelete(OrganizationUnitRecord item) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.tokens.radius),
          side: BorderSide(color: scheme.error),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: scheme.error),
            SizedBox(width: widget.tokens.cardSpacing),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: widget.tokens.captionStyle.copyWith(color: scheme.error),
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
                  style: TextStyle(color: scheme.error),
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
            style: TextButton.styleFrom(foregroundColor: scheme.primary),
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
