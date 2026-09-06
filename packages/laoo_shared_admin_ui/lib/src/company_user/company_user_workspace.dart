import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

import '../shared/shared_admin_ui_tokens.dart';

typedef CompanyUserErrorText = SharedAdminErrorText;
typedef CompanyUserTitleBuilder = SharedAdminTitleBuilder;
typedef CompanyUserMessageBuilder = SharedAdminMessageBuilder;
typedef CompanyUserUiTokens = SharedAdminUiTokens;

class CompanyUserWorkspace extends StatefulWidget {
  const CompanyUserWorkspace({
    super.key,
    required this.caption,
    required this.repository,
    required this.errorText,
    required this.titleBuilder,
    required this.messageBuilder,
    required this.tokens,
    required this.screenType,
    required this.pageSize,
  });

  final String caption;
  final CompanyUserRepository repository;
  final CompanyUserErrorText errorText;
  final CompanyUserTitleBuilder titleBuilder;
  final CompanyUserMessageBuilder messageBuilder;
  final CompanyUserUiTokens tokens;
  final int screenType;
  final int pageSize;

  @override
  State<CompanyUserWorkspace> createState() => _CompanyUserWorkspaceState();
}

enum _CompanyUserView { list, edit }

class _CompanyUserWorkspaceState extends State<CompanyUserWorkspace> {
  final _search = TextEditingController();
  List<CompanyUserRecord> _items = const [];
  int? _companyId;
  String _status = 'all';
  int _page = 0;
  bool _loading = true;
  bool _saving = false;
  bool _canEdit = false;
  String? _message;
  bool _messageError = true;
  _CompanyUserView _view = _CompanyUserView.list;
  CompanyUserRecord? _editing;

  int get _pageSize => widget.pageSize > 0 ? widget.pageSize : 30;

  List<CompanyUserRecord> get _filtered {
    final text = _search.text.trim().toLowerCase();
    return _items
        .where((item) {
          if (_companyId != null && item.companyId != _companyId) return false;
          if (_status == 'active' && !item.isActive) return false;
          if (_status == 'inactive' && item.isActive) return false;
          if (text.isEmpty) return true;
          return item.companyCode.toLowerCase().contains(text) ||
              item.companyName.toLowerCase().contains(text) ||
              item.username.toLowerCase().contains(text) ||
              item.displayName.toLowerCase().contains(text);
        })
        .toList(growable: false);
  }

  int get _pageCount =>
      _filtered.isEmpty ? 1 : (_filtered.length / _pageSize).ceil();

  List<CompanyUserRecord> get _visible {
    final safePage = _page.clamp(0, _pageCount - 1);
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  Map<int, String> get _companies {
    final values = <int, String>{};
    for (final item in _items) {
      values[item.companyId] = item.companyCode.isEmpty
          ? item.companyName
          : '${item.companyCode} - ${item.companyName}';
    }
    return values;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    Map<String, bool> actions = const {};
    try {
      actions = await widget.repository.actions();
    } catch (_) {
      // Permission loading remains fail-closed.
    }
    try {
      final items = await widget.repository.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _canEdit = widget.screenType == 2 && actions['edit'] == true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(widget.errorText(error), error: true);
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final items = await widget.repository.list();
      if (mounted) {
        setState(() {
          _items = items;
          _page = 0;
        });
      }
    } catch (error) {
      if (mounted) _showMessage(widget.errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String value, {required bool error}) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _messageError = error;
    });
  }

  void _openEdit(CompanyUserRecord item) {
    setState(() {
      _editing = item;
      _view = _CompanyUserView.edit;
      _message = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _view = _CompanyUserView.list;
    });
  }

  Future<void> _save(CompanyUserUpdateRequest request) async {
    final item = _editing;
    if (item == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.update(item.userId, request);
      await _reload();
      if (!mounted) return;
      setState(() {
        _editing = null;
        _view = _CompanyUserView.list;
      });
      _showMessage('บันทึกผู้ใช้งานสำเร็จ', error: false);
    } catch (error) {
      if (mounted) _showMessage(widget.errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_view == _CompanyUserView.list)
          _buildList(context)
        else
          _CompanyUserAction(
            key: ValueKey(_editing!.userId),
            caption: widget.caption,
            item: _editing!,
            saving: _saving,
            tokens: widget.tokens,
            titleBuilder: widget.titleBuilder,
            onCancel: _cancelEdit,
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

  Widget _buildList(BuildContext context) {
    final tokens = widget.tokens;
    return Padding(
      padding: tokens.contentMargin,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.radius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: tokens.cardPadding,
              child: widget.titleBuilder(context, widget.caption, true),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Padding(
              padding: tokens.cardPadding,
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth < tokens.compactBreakpoint
                    ? Column(
                        children: [
                          _searchField(),
                          SizedBox(height: tokens.cardSpacing),
                          _companyFilter(),
                          SizedBox(height: tokens.cardSpacing),
                          _statusFilter(),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(flex: 2, child: _searchField()),
                          SizedBox(width: tokens.cardSpacing),
                          Expanded(child: _companyFilter()),
                          SizedBox(width: tokens.cardSpacing),
                          Expanded(child: _statusFilter()),
                        ],
                      ),
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                  ? const Center(child: Text('ไม่พบผู้ใช้งานบริษัท'))
                  : LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth < tokens.compactBreakpoint
                          ? _cards(context)
                          : _table(context, constraints.maxWidth),
                    ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            _pagination(context),
          ],
        ),
      ),
    );
  }

  Widget _searchField() => TextField(
    controller: _search,
    decoration: const InputDecoration(
      labelText: 'ค้นหา',
      hintText: 'บริษัท, Username หรือชื่อผู้ใช้งาน',
      prefixIcon: Icon(Icons.search),
    ),
    onChanged: (_) => setState(() => _page = 0),
  );

  Widget _companyFilter() => DropdownButtonFormField<int?>(
    isExpanded: true,
    initialValue: _companyId,
    decoration: const InputDecoration(labelText: 'บริษัท'),
    items: [
      const DropdownMenuItem<int?>(value: null, child: Text('ทั้งหมด')),
      ..._companies.entries.map(
        (entry) => DropdownMenuItem<int?>(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
      ),
    ],
    onChanged: (value) => setState(() {
      _companyId = value;
      _page = 0;
    }),
  );

  Widget _statusFilter() => DropdownButtonFormField<String>(
    initialValue: _status,
    decoration: const InputDecoration(labelText: 'สถานะ'),
    items: const [
      DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
      DropdownMenuItem(value: 'active', child: Text('ใช้งาน')),
      DropdownMenuItem(value: 'inactive', child: Text('ไม่ใช้งาน')),
    ],
    onChanged: (value) => setState(() {
      _status = value ?? 'all';
      _page = 0;
    }),
  );

  Widget _table(BuildContext context, double width) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: width),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              scheme.primary.withValues(alpha: .10),
            ),
            columns: const [
              DataColumn(label: Text('ลำดับ')),
              DataColumn(label: Text('Action')),
              DataColumn(label: Text('บริษัท')),
              DataColumn(label: Text('Username')),
              DataColumn(label: Text('ชื่อผู้ใช้งาน')),
              DataColumn(label: Text('ประเภท')),
              DataColumn(label: Text('สถานะ')),
            ],
            rows: List.generate(_visible.length, (index) {
              final item = _visible[index];
              return DataRow(
                cells: [
                  DataCell(Text('${_page * _pageSize + index + 1}')),
                  DataCell(_editAction(item)),
                  DataCell(
                    Text(
                      '${item.companyCode} - ${item.companyName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(Text(item.username)),
                  DataCell(Text(item.displayName)),
                  DataCell(
                    Text(item.isCompanyAdmin ? 'Company Admin' : 'ผู้ใช้งาน'),
                  ),
                  DataCell(_statusIcon(item.isActive)),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _cards(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: ListView.separated(
      padding: EdgeInsets.all(widget.tokens.itemSpacing),
      itemCount: _visible.length,
      separatorBuilder: (_, _) => SizedBox(height: widget.tokens.itemSpacing),
      itemBuilder: (context, index) {
        final item = _visible[index];
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(widget.tokens.radius),
          child: Padding(
            padding: widget.tokens.cardPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.isCompanyAdmin
                      ? Icons.admin_panel_settings_outlined
                      : Icons.person_outline,
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
                      Text(
                        '${item.companyCode} - ${item.companyName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(item.isCompanyAdmin ? 'Company Admin' : 'ผู้ใช้งาน'),
                    ],
                  ),
                ),
                _editAction(item),
                _statusIcon(item.isActive),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _editAction(CompanyUserRecord item) => _canEdit
      ? IconButton(
          tooltip: 'แก้ไข',
          onPressed: _loading ? null : () => _openEdit(item),
          icon: const Icon(Icons.edit_outlined),
        )
      : const SizedBox.shrink();

  Widget _statusIcon(bool active) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: active ? 'ใช้งาน' : 'ไม่ใช้งาน',
      child: Icon(
        active ? Icons.check_circle_outline : Icons.block,
        color: active ? scheme.primary : scheme.error,
      ),
    );
  }

  Widget _pagination(BuildContext context) {
    final total = _filtered.length;
    final start = total == 0 ? 0 : _page * _pageSize + 1;
    final end = total == 0 ? 0 : (_page * _pageSize + _visible.length);
    return SizedBox(
      height: widget.tokens.paginationHeight,
      child: Padding(
        padding: widget.tokens.cardPadding,
        child: Row(
          children: [
            IconButton(
              tooltip: 'หน้าก่อน',
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'หน้าถัดไป',
              onPressed: _page + 1 < _pageCount
                  ? () => setState(() => _page++)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            const Spacer(),
            Text('$start-$end จาก $total'),
          ],
        ),
      ),
    );
  }
}

class _CompanyUserAction extends StatefulWidget {
  const _CompanyUserAction({
    super.key,
    required this.caption,
    required this.item,
    required this.saving,
    required this.tokens,
    required this.titleBuilder,
    required this.onCancel,
    required this.onSave,
  });

  final String caption;
  final CompanyUserRecord item;
  final bool saving;
  final CompanyUserUiTokens tokens;
  final CompanyUserTitleBuilder titleBuilder;
  final VoidCallback onCancel;
  final Future<void> Function(CompanyUserUpdateRequest request) onSave;

  @override
  State<_CompanyUserAction> createState() => _CompanyUserActionState();
}

class _CompanyUserActionState extends State<_CompanyUserAction> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _displayName;
  late final TextEditingController _email;
  late final TextEditingController _mobile;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.item.username);
    _password = TextEditingController();
    _displayName = TextEditingController(text: widget.item.displayName);
    _email = TextEditingController(text: widget.item.email ?? '');
    _mobile = TextEditingController(text: widget.item.mobile ?? '');
    _active = widget.item.isActive;
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

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'รูปแบบ Email ไม่ถูกต้อง';
    }
    return null;
  }

  void _submit() {
    if (widget.saving || !_formKey.currentState!.validate()) return;
    widget.onSave(
      CompanyUserUpdateRequest(
        username: _username.text.trim(),
        password: _password.text.isEmpty ? null : _password.text,
        displayName: _displayName.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        mobile: _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
        isActive: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return Padding(
      padding: tokens.contentMargin,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.radius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: tokens.cardPadding,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final title = widget.titleBuilder(
                    context,
                    '${widget.caption} > แก้ไข',
                    false,
                  );
                  final actions = [
                    OutlinedButton.icon(
                      onPressed: widget.saving ? null : widget.onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('ยกเลิก'),
                    ),
                    FilledButton.icon(
                      onPressed: widget.saving ? null : _submit,
                      icon: widget.saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('บันทึก'),
                    ),
                  ];
                  if (constraints.maxWidth < tokens.compactBreakpoint) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        SizedBox(height: tokens.cardSpacing),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            actions.first,
                            SizedBox(width: tokens.cardSpacing),
                            actions.last,
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      ...actions.expand(
                        (button) => [
                          SizedBox(width: tokens.cardSpacing),
                          button,
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: SingleChildScrollView(
                padding: tokens.cardPadding,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _statusRow(context),
                      SizedBox(height: tokens.cardSpacing),
                      _companyContext(context),
                      SizedBox(height: tokens.cardSpacing),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final fieldWidth =
                              constraints.maxWidth < tokens.compactBreakpoint
                              ? constraints.maxWidth
                              : (constraints.maxWidth - tokens.cardSpacing) / 2;
                          return Wrap(
                            spacing: tokens.cardSpacing,
                            runSpacing: 12,
                            children: [
                              _field(
                                width: fieldWidth,
                                controller: _username,
                                label: 'Username *',
                                validator: _required,
                              ),
                              _field(
                                width: fieldWidth,
                                controller: _password,
                                label: 'Password ใหม่',
                                obscureText: true,
                                helperText: 'เว้นว่างหากไม่ต้องการเปลี่ยน',
                              ),
                              _field(
                                width: fieldWidth,
                                controller: _displayName,
                                label: 'ชื่อผู้ใช้งาน *',
                                validator: _required,
                              ),
                              _field(
                                width: fieldWidth,
                                controller: _email,
                                label: 'Email',
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              _field(
                                width: fieldWidth,
                                controller: _mobile,
                                label: 'เบอร์โทร',
                                keyboardType: TextInputType.phone,
                              ),
                              _readOnlyField(
                                width: fieldWidth,
                                label: 'ประเภทผู้ใช้',
                                value: widget.item.isCompanyAdmin
                                    ? 'Company Admin'
                                    : 'ผู้ใช้งาน',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('สถานะ'),
      SizedBox(width: widget.tokens.cardSpacing),
      Switch(
        value: _active,
        onChanged: widget.saving
            ? null
            : (value) => setState(() => _active = value),
      ),
      Text(_active ? 'ใช้งาน' : 'ไม่ใช้งาน'),
    ],
  );

  Widget _companyContext(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(widget.tokens.radius),
    ),
    child: Padding(
      padding: widget.tokens.cardPadding,
      child: Row(
        children: [
          Icon(
            Icons.apartment_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: widget.tokens.cardSpacing),
          Expanded(
            child: Text(
              '${widget.item.companyCode} - ${widget.item.companyName}',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field({
    required double width,
    required TextEditingController controller,
    required String label,
    String? helperText,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => SizedBox(
    width: width,
    child: TextFormField(
      controller: controller,
      enabled: !widget.saving,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label, helperText: helperText),
    ),
  );

  Widget _readOnlyField({
    required double width,
    required String label,
    required String value,
  }) => SizedBox(
    width: width,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value),
    ),
  );
}
