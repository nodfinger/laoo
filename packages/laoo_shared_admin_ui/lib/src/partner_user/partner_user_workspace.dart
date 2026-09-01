import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

import '../shared/shared_admin_ui_tokens.dart';

typedef PartnerUserOwnerLoader =
    Future<List<PartnerUserOwnerOption>> Function();
typedef PartnerUserErrorText = SharedAdminErrorText;
typedef PartnerUserTitleBuilder = SharedAdminTitleBuilder;
typedef PartnerUserMessageBuilder = SharedAdminMessageBuilder;
typedef PartnerUserUiTokens = SharedAdminUiTokens;

class PartnerUserOwnerOption {
  const PartnerUserOwnerOption({
    required this.id,
    required this.code,
    required this.name,
  });

  factory PartnerUserOwnerOption.fromJson(Map<String, dynamic> json) =>
      PartnerUserOwnerOption(
        id: (json['partnerId'] as num).toInt(),
        code: (json['partnerCode'] ?? '').toString(),
        name: (json['partnerNameTh'] ?? '').toString(),
      );

  final int id;
  final String code;
  final String name;

  String get label => code.isEmpty
      ? name
      : name.isEmpty
      ? code
      : '$code - $name';
}

class PartnerUserWorkspace extends StatefulWidget {
  const PartnerUserWorkspace({
    super.key,
    required this.caption,
    required this.repository,
    required this.loadOwners,
    required this.errorText,
    required this.titleBuilder,
    required this.messageBuilder,
    required this.tokens,
    required this.screenType,
  });

  final String caption;
  final PartnerUserRepository repository;
  final PartnerUserOwnerLoader loadOwners;
  final PartnerUserErrorText errorText;
  final PartnerUserTitleBuilder titleBuilder;
  final PartnerUserMessageBuilder messageBuilder;
  final PartnerUserUiTokens tokens;
  final int screenType;

  @override
  State<PartnerUserWorkspace> createState() => _PartnerUserWorkspaceState();
}

enum _ViewMode { list, create, edit }

class _PartnerUserWorkspaceState extends State<PartnerUserWorkspace> {
  List<PartnerUserOwnerOption> _owners = const [];
  List<PartnerUserRecord> _items = const [];
  int? _ownerId;
  bool _loading = true;
  bool _saving = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  String? _message;
  bool _messageError = true;
  _ViewMode _view = _ViewMode.list;
  PartnerUserRecord? _editing;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    Map<String, bool> actions = const {};
    try {
      actions = await widget.repository.actions();
    } catch (_) {
      // Permission loading is fail-closed.
    }
    try {
      final owners = await widget.loadOwners();
      final ownerId = owners.isEmpty ? null : owners.first.id;
      final items = ownerId == null
          ? const <PartnerUserRecord>[]
          : await widget.repository.list(ownerId);
      if (!mounted) return;
      final crud = widget.screenType == 1;
      setState(() {
        _owners = owners;
        _ownerId = ownerId;
        _items = items;
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

  Future<void> _loadUsers() async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    setState(() => _loading = true);
    try {
      final items = await widget.repository.list(ownerId);
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) _showMessage(widget.errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String text, {required bool error}) {
    if (!mounted) return;
    setState(() {
      _message = text;
      _messageError = error;
    });
  }

  void _openAction([PartnerUserRecord? item]) {
    setState(() {
      _editing = item;
      _view = item == null ? _ViewMode.create : _ViewMode.edit;
      _message = null;
    });
  }

  void _cancelAction() => setState(() {
    _editing = null;
    _view = _ViewMode.list;
  });

  Future<void> _save(PartnerUserUpsertRequest request) async {
    final ownerId = _ownerId;
    if (ownerId == null || _saving) return;
    final creating = _view == _ViewMode.create;
    setState(() => _saving = true);
    try {
      if (creating) {
        await widget.repository.create(ownerId, request);
      } else {
        await widget.repository.update(_editing!.partnerUserId, request);
      }
      final items = await widget.repository.list(ownerId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _editing = null;
        _view = _ViewMode.list;
      });
      _showMessage(
        creating ? 'สร้างบัญชี Partner สำเร็จ' : 'แก้ไขบัญชี Partner สำเร็จ',
        error: false,
      );
    } catch (error) {
      if (mounted) _showMessage(widget.errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(PartnerUserRecord item) async {
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
                  '${item.username} — ${item.displayName}',
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
      await widget.repository.delete(item.partnerUserId);
      await _loadUsers();
      if (mounted) _showMessage('ลบบัญชี Partner สำเร็จ', error: false);
    } catch (error) {
      if (mounted) _showMessage(widget.errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_view == _ViewMode.list)
          _list(context)
        else
          _PartnerUserActionForm(
            key: ValueKey((_view, _editing?.partnerUserId)),
            caption: widget.caption,
            initial: _editing,
            saving: _saving,
            tokens: widget.tokens,
            titleBuilder: widget.titleBuilder,
            onCancel: _cancelAction,
            onSave: _save,
          ),
        if (_message != null)
          Positioned(
            top: widget.tokens.contentMargin.top,
            left: widget.tokens.contentMargin.left,
            right: widget.tokens.contentMargin.right,
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
    );
  }

  Widget _list(BuildContext context) {
    final t = widget.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: t.contentMargin,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(t.radius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: t.cardPadding,
              child: Row(
                children: [
                  Expanded(
                    child: widget.titleBuilder(context, widget.caption, true),
                  ),
                  if (_ownerId != null && _canCreate)
                    FilledButton.icon(
                      onPressed: _loading ? null : _openAction,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Padding(
              padding: t.cardPadding,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _ownerId,
                    decoration: const InputDecoration(labelText: 'Partner'),
                    items: _owners
                        .map(
                          (owner) => DropdownMenuItem(
                            value: owner.id,
                            child: Text(
                              owner.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _loading
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _ownerId = value);
                            _loadUsers();
                          },
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(child: Text('ยังไม่มีบัญชี Partner'))
                  : LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth < t.compactBreakpoint
                          ? _cards(context)
                          : _table(context, constraints.maxWidth),
                    ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            SizedBox(
              height: t.paginationHeight,
              child: Padding(
                padding: t.cardPadding,
                child: Row(
                  children: [
                    const IconButton(
                      onPressed: null,
                      icon: Icon(Icons.chevron_left),
                    ),
                    const IconButton(
                      onPressed: null,
                      icon: Icon(Icons.chevron_right),
                    ),
                    const Spacer(),
                    Text(
                      _items.isEmpty
                          ? '0-0 จาก 0'
                          : '1-${_items.length} จาก ${_items.length}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table(BuildContext context, double width) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: width),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: .10),
          ),
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('Username')),
            DataColumn(label: Text('ชื่อผู้ใช้งาน')),
            DataColumn(label: Text('ประเภท')),
            DataColumn(label: Text('สถานะ')),
          ],
          rows: List.generate(_items.length, (index) {
            final item = _items[index];
            return DataRow(
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(_actions(item)),
                DataCell(Text(item.username)),
                DataCell(Text(item.displayName)),
                DataCell(
                  Text(item.isPartnerAdmin ? 'Partner Admin' : 'ผู้ใช้งาน'),
                ),
                DataCell(_status(item.isActive)),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _cards(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: ListView.separated(
      padding: EdgeInsets.all(widget.tokens.cardSpacing),
      itemCount: _items.length,
      separatorBuilder: (_, _) => SizedBox(height: widget.tokens.itemSpacing),
      itemBuilder: (context, index) {
        final item = _items[index];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(widget.tokens.radius),
          ),
          child: Padding(
            padding: widget.tokens.cardPadding,
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: widget.tokens.cardSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.username,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(item.displayName),
                      Text(item.isPartnerAdmin ? 'Partner Admin' : 'ผู้ใช้งาน'),
                    ],
                  ),
                ),
                _actions(item),
                _status(item.isActive),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _actions(PartnerUserRecord item) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_canEdit)
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: _loading ? null : () => _openAction(item),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (_canDelete)
        IconButton(
          tooltip: 'ลบ',
          onPressed: _loading ? null : () => _delete(item),
          color: Theme.of(context).colorScheme.error,
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );

  Widget _status(bool active) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: active ? 'ใช้งาน' : 'ไม่ใช้งาน',
      child: Icon(
        active ? Icons.check_circle_outline : Icons.block,
        color: active ? scheme.primary : scheme.error,
      ),
    );
  }
}

class _PartnerUserActionForm extends StatefulWidget {
  const _PartnerUserActionForm({
    super.key,
    required this.caption,
    required this.initial,
    required this.saving,
    required this.tokens,
    required this.titleBuilder,
    required this.onCancel,
    required this.onSave,
  });

  final String caption;
  final PartnerUserRecord? initial;
  final bool saving;
  final PartnerUserUiTokens tokens;
  final PartnerUserTitleBuilder titleBuilder;
  final VoidCallback onCancel;
  final Future<void> Function(PartnerUserUpsertRequest request) onSave;

  @override
  State<_PartnerUserActionForm> createState() => _PartnerUserActionFormState();
}

class _PartnerUserActionFormState extends State<_PartnerUserActionForm> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  bool _admin = true;
  bool _active = true;

  bool get _editMode => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    if (value == null) return;
    _username.text = value.username;
    _displayName.text = value.displayName;
    _email.text = value.email ?? '';
    _mobile.text = value.mobileNumber ?? '';
    _admin = value.isPartnerAdmin;
    _active = value.isActive;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _displayName.dispose();
    _email.dispose();
    _mobile.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null;

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (_editMode && password.isEmpty) return null;
    if (password.length < 6 ||
        !RegExp('[A-Z]').hasMatch(password) ||
        !RegExp('[a-z]').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'อย่างน้อย 6 ตัว มีพิมพ์ใหญ่ พิมพ์เล็ก และอักขระพิเศษ';
    }
    return null;
  }

  void _submit() {
    if (widget.saving || !_formKey.currentState!.validate()) return;
    widget.onSave(
      PartnerUserUpsertRequest(
        username: _username.text.trim(),
        password: _password.text.isEmpty ? null : _password.text,
        displayName: _displayName.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        mobileNumber: _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
        isPartnerAdmin: _admin,
        isActive: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final scheme = Theme.of(context).colorScheme;
    final action = _editMode ? 'แก้ไข' : 'เพิ่ม';
    return Padding(
      padding: t.contentMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: scheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: t.cardPadding,
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final title = widget.titleBuilder(
                        context,
                        '${widget.caption} > $action',
                        false,
                      );
                      final actions = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: widget.saving ? null : widget.onCancel,
                            icon: const Icon(Icons.close),
                            label: const Text('ยกเลิก'),
                          ),
                          SizedBox(width: t.cardSpacing),
                          FilledButton.icon(
                            onPressed: widget.saving ? null : _submit,
                            icon: widget.saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('บันทึก'),
                          ),
                        ],
                      );
                      if (constraints.maxWidth < t.compactBreakpoint) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            title,
                            SizedBox(height: t.cardSpacing),
                            Align(
                              alignment: Alignment.centerRight,
                              child: actions,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: title),
                          actions,
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
            child: Material(
              color: scheme.surface,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(t.radius),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: t.cardPadding,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('สถานะ'),
                          SizedBox(width: t.cardSpacing),
                          Switch(
                            value: _active,
                            onChanged: widget.saving
                                ? null
                                : (value) => setState(() => _active = value),
                          ),
                          Text(_active ? 'ใช้งาน' : 'ไม่ใช้งาน'),
                        ],
                      ),
                      SizedBox(height: t.cardSpacing + 2),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final fields = <Widget>[
                            TextFormField(
                              controller: _username,
                              enabled: !widget.saving,
                              decoration: const InputDecoration(
                                labelText: 'Username *',
                              ),
                              validator: _required,
                            ),
                            TextFormField(
                              controller: _password,
                              enabled: !widget.saving,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: _editMode
                                    ? 'Password ใหม่'
                                    : 'Password *',
                                helperText: _editMode
                                    ? 'เว้นว่างหากไม่ต้องการเปลี่ยน'
                                    : 'อย่างน้อย 6 ตัว มีพิมพ์ใหญ่ พิมพ์เล็ก และอักขระพิเศษ',
                              ),
                              validator: _validatePassword,
                            ),
                            TextFormField(
                              controller: _displayName,
                              enabled: !widget.saving,
                              decoration: const InputDecoration(
                                labelText: 'ชื่อผู้ใช้งาน *',
                              ),
                              validator: _required,
                            ),
                            TextFormField(
                              controller: _email,
                              enabled: !widget.saving,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                            ),
                            TextFormField(
                              controller: _mobile,
                              enabled: !widget.saving,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'เบอร์โทร',
                              ),
                            ),
                          ];
                          if (constraints.maxWidth < t.compactBreakpoint) {
                            return Column(
                              children: [
                                for (var i = 0; i < fields.length; i++) ...[
                                  fields[i],
                                  if (i < fields.length - 1)
                                    SizedBox(height: t.cardSpacing + 2),
                                ],
                              ],
                            );
                          }
                          return Wrap(
                            spacing: t.cardSpacing,
                            runSpacing: t.cardSpacing + 2,
                            children: fields
                                .map(
                                  (field) => SizedBox(
                                    width:
                                        (constraints.maxWidth - t.cardSpacing) /
                                        2,
                                    child: field,
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                      ),
                      SizedBox(height: t.cardSpacing + 2),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Partner Admin'),
                        value: _admin,
                        onChanged: widget.saving
                            ? null
                            : (value) => setState(() => _admin = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
