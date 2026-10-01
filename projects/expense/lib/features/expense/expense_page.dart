import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'expense_feature_host.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({
    required this.menuCode,
    required this.title,
    required this.endpoint,
    super.key,
  });
  final String menuCode, title, endpoint;
  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  late final JsonApiClient api = createExpenseApiClient();
  late Future<Map<String, dynamic>> future;
  final search = TextEditingController();
  String title = '', appliedSearch = '', categoryFilter = '';
  int page = 1;
  int? editingId;
  bool creating = false;
  static const pageSize = 10;
  bool get isSettings => widget.endpoint == 'settings';
  bool get isCategories => widget.endpoint == 'categories';
  bool get isDirect => widget.endpoint == 'direct';
  @override
  void initState() {
    super.initState();
    title = widget.title;
    future = _load();
    resolveExpenseMenuTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
  }

  Future<Map<String, dynamic>> _load() async {
    final actions = _map(
      await api.get('/api/company/expenses/actions/${widget.menuCode}'),
    );
    if (isSettings) {
      return {
        'data': await api.get('/api/company/expenses/settings'),
        'actions': actions,
      };
    }
    if (isCategories) {
      return {
        'data': await api.get('/api/company/expenses/categories'),
        'actions': actions,
      };
    }
    if (isDirect) {
      return {
        'data': await api.get(
          '/api/company/expenses/direct',
          query: {
            'page': '$page',
            'pageSize': '$pageSize',
            if (appliedSearch.isNotEmpty) 'search': appliedSearch,
            if (categoryFilter.isNotEmpty) 'categoryCode': categoryFilter,
          },
        ),
        'actions': actions,
        'options': await api.get('/api/company/expenses/options'),
      };
    }
    return {'data': const {}, 'actions': actions};
  }

  void reload() => setState(() => future = _load());
  @override
  void dispose() {
    search.dispose();
    disposeExpenseApiClient(api);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildExpenseWorkspaceShell(
    pageTitle: title,
    activeMenu: widget.menuCode,
    child: editingId != null || creating
        ? DirectExpenseEditor(
            api: api,
            title: title,
            expenseId: editingId,
            onCancel: _closeEditor,
            onSaved: _closeEditor,
          )
        : Padding(
            padding: expenseUiTokens.contentMargin,
            child: FutureBuilder<Map<String, dynamic>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return _frame(_state('กำลังโหลดข้อมูล...'));
                }
                if (snapshot.hasError) {
                  return _frame(_state('โหลดข้อมูลไม่สำเร็จ', retry: true));
                }
                final value = snapshot.data!, actions = _map(value['actions']);
                if (isSettings) {
                  return ExpenseSettingsView(
                    api: api,
                    title: title,
                    data: _map(value['data']),
                    actions: actions,
                    onSaved: reload,
                  );
                }
                if (isCategories) {
                  return _categories(_rows(value['data']), actions);
                }
                if (isDirect) {
                  return _direct(
                    _map(value['data']),
                    actions,
                    _map(value['options']),
                  );
                }
                return _frame(_state('หน้าจอนี้อยู่ระหว่างพัฒนา'));
              },
            ),
          ),
  );
  void _closeEditor() => setState(() {
    editingId = null;
    creating = false;
    future = _load();
  });
  Widget _caption({Widget? trailing}) => LaooCaptionCard(
    tokens: expenseUiTokens,
    leading: Icon(
      Icons.receipt_long_outlined,
      color: expenseUiTokens.primaryColor,
    ),
    caption: title,
    trailing: trailing,
  );
  Widget _frame(Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _caption(),
      SizedBox(height: expenseUiTokens.sectionSpacing),
      Expanded(child: child),
    ],
  );
  Widget _state(String text, {bool retry = false}) => LaooSurfaceCard(
    tokens: expenseUiTokens,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 42,
            color: expenseUiTokens.primaryColor,
          ),
          const SizedBox(height: 12),
          Text(text),
          if (retry) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.replay_outlined),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _categories(
    List<Map<String, dynamic>> all,
    Map<String, dynamic> actions,
  ) {
    final q = appliedSearch.toLowerCase(),
        rows = all
            .where(
              (r) =>
                  q.isEmpty ||
                  '${r['code']} ${r['name']}'.toLowerCase().contains(q),
            )
            .toList();
    return LaooListWorkspace(
      tokens: expenseUiTokens,
      caption: _caption(
        trailing: actions['create'] == true
            ? FilledButton.icon(
                onPressed: () => _categoryDialog(actions: actions),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่ม'),
              )
            : null,
      ),
      filter: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: search,
              onSubmitted: (_) =>
                  setState(() => appliedSearch = search.text.trim()),
              decoration: expenseInput('ค้นหารหัสหรือชื่อ', icon: Icons.search),
            ),
          ),
          FilledButton.icon(
            onPressed: () => setState(() => appliedSearch = search.text.trim()),
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              search.clear();
              setState(() => appliedSearch = '');
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('ล้าง Filter'),
          ),
        ],
      ),
      table: LayoutBuilder(
        builder: (context, c) => c.maxWidth < expenseUiTokens.compactBreakpoint
            ? _categoryCards(rows, actions)
            : LaooWorkspaceDataTable(
                tokens: expenseUiTokens,
                columns: const [
                  LaooWorkspaceTableColumns.id,
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('รหัส')),
                  DataColumn(label: Text('ชื่อประเภทค่าใช้จ่าย')),
                  DataColumn(label: Text('ลำดับ')),
                  DataColumn(label: Text('สถานะ')),
                ],
                rows: List.generate(rows.length, (i) {
                  final r = rows[i];
                  return DataRow(
                    cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(_categoryActions(r, actions)),
                      DataCell(Text('${r['code']}')),
                      DataCell(Text('${r['name']}')),
                      DataCell(Text('${r['sortOrder']}')),
                      DataCell(
                        Text(r['active'] == true ? 'ใช้งาน' : 'ปิดใช้งาน'),
                      ),
                    ],
                  );
                }),
              ),
      ),
      pagination: LaooPaginationCard(
        tokens: expenseUiTokens,
        page: 1,
        pageCount: 1,
        pageSize: rows.isEmpty ? 1 : rows.length,
        total: rows.length,
        onPrevious: null,
        onNext: null,
      ),
    );
  }

  Widget _categoryCards(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> actions,
  ) => ListView.separated(
    padding: expenseUiTokens.cardPadding,
    itemCount: rows.length,
    separatorBuilder: (_, _) => SizedBox(height: expenseUiTokens.itemSpacing),
    itemBuilder: (_, i) {
      final r = rows[i];
      return LaooSurfaceCard(
        tokens: expenseUiTokens,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['code']} - ${r['name']}',
                    style: expenseUiTokens.sectionStyle,
                  ),
                  Text(
                    'ลำดับ ${r['sortOrder']} • ${r['active'] == true ? 'ใช้งาน' : 'ปิดใช้งาน'}',
                  ),
                ],
              ),
            ),
            _categoryActions(r, actions),
          ],
        ),
      );
    },
  );
  Widget _categoryActions(
    Map<String, dynamic> row,
    Map<String, dynamic> actions,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          color: expenseUiTokens.primaryColor,
          onPressed: () => _categoryDialog(row: row, actions: actions),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          color: Colors.red,
          onPressed: () => _deleteCategory(row),
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );
  Future<void> _categoryDialog({
    Map<String, dynamic>? row,
    required Map<String, dynamic> actions,
  }) async {
    final edit = row != null,
        code = TextEditingController(text: '${row?['code'] ?? ''}'),
        name = TextEditingController(text: '${row?['name'] ?? ''}'),
        sort = TextEditingController(text: '${row?['sortOrder'] ?? 10}'),
        key = GlobalKey<FormState>();
    var active = row?['active'] != false, saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> save() async {
            if (!(key.currentState?.validate() ?? false) || saving) return;
            setLocal(() => saving = true);
            try {
              final body = {
                'code': code.text.trim(),
                'name': name.text.trim(),
                'sortOrder': int.tryParse(sort.text) ?? 0,
                'isActive': active,
              };
              if (edit) {
                await api.put(
                  '/api/company/expenses/categories/${row['code']}',
                  body: body,
                );
              } else {
                await api.post('/api/company/expenses/categories', body: body);
              }
              if (!mounted) return;
              showExpenseMessage(
                this.context,
                message: edit
                    ? 'แก้ไขประเภทค่าใช้จ่ายแล้ว'
                    : 'เพิ่มประเภทค่าใช้จ่ายแล้ว',
              );
              reload();
              if (edit) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } else if (dialogContext.mounted) {
                code.clear();
                name.clear();
                sort.text = '10';
                active = true;
                setLocal(() => saving = false);
              }
            } catch (e) {
              if (mounted) {
                showExpenseMessage(this.context, message: '$e', error: true);
              }
              if (dialogContext.mounted) setLocal(() => saving = false);
            }
          }

          return ExpenseFormDialog(
            title: '$title > ${edit ? 'แก้ไข' : 'เพิ่ม'}',
            icon: Icons.category_outlined,
            saving: saving,
            onCancel: () => Navigator.pop(dialogContext),
            onSave: save,
            content: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('สถานะ'),
                      const SizedBox(width: 8),
                      Switch(
                        value: active,
                        onChanged: saving
                            ? null
                            : (v) => setLocal(() => active = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: code,
                    enabled: !edit && !saving,
                    maxLength: 10,
                    decoration: expenseInput('รหัส *'),
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: name,
                    enabled: !saving,
                    maxLength: 250,
                    decoration: expenseInput('ชื่อประเภทค่าใช้จ่าย *'),
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: sort,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    decoration: expenseInput('ลำดับแสดงผล *'),
                    validator: (v) => int.tryParse(v ?? '') == null
                        ? 'กรุณาระบุตัวเลข'
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    code.dispose();
    name.dispose();
    sort.dispose();
  }

  Future<void> _deleteCategory(Map<String, dynamic> row) async {
    if (!await confirmExpenseDelete(
      context,
      keyText: '${row['code']} - ${row['name']}',
    )) {
      return;
    }
    try {
      await api.delete('/api/company/expenses/categories/${row['code']}');
      if (!mounted) return;
      showExpenseMessage(context, message: 'ลบประเภทค่าใช้จ่ายแล้ว');
      reload();
    } catch (e) {
      if (mounted) showExpenseMessage(context, message: '$e', error: true);
    }
  }

  Widget _direct(
    Map<String, dynamic> data,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    final rows = _rows(data['items']),
        total = (data['total'] as num?)?.toInt() ?? 0,
        pageCount = total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1,
        categories = _rows(options['categories']);
    return LaooListWorkspace(
      tokens: expenseUiTokens,
      caption: _caption(
        trailing: actions['create'] == true
            ? FilledButton.icon(
                onPressed: () => setState(() => creating = true),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่ม'),
              )
            : null,
      ),
      filter: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: search,
              onSubmitted: (_) => _applyDirect(),
              decoration: expenseInput(
                'ค้นหาเลขที่ ผู้รับเงิน หรือเลขบิล',
                icon: Icons.search,
              ),
            ),
          ),
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<String>(
              initialValue: categoryFilter.isEmpty ? null : categoryFilter,
              isExpanded: true,
              decoration: expenseInput('ประเภทค่าใช้จ่าย'),
              items: [
                const DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                ...categories.map(
                  (r) => DropdownMenuItem(
                    value: '${r['code']}',
                    child: Text(
                      '${r['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => categoryFilter = v ?? '',
            ),
          ),
          FilledButton.icon(
            onPressed: _applyDirect,
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              search.clear();
              setState(() {
                appliedSearch = '';
                categoryFilter = '';
                page = 1;
                future = _load();
              });
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('ล้าง Filter'),
          ),
        ],
      ),
      table: LayoutBuilder(
        builder: (context, c) => c.maxWidth < expenseUiTokens.compactBreakpoint
            ? _directCards(rows, actions)
            : LaooWorkspaceDataTable(
                tokens: expenseUiTokens,
                columns: const [
                  LaooWorkspaceTableColumns.id,
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('เลขที่')),
                  DataColumn(label: Text('วันที่')),
                  DataColumn(label: Text('ผู้รับเงิน/ผู้ขาย')),
                  DataColumn(label: Text('เลขบิล')),
                  DataColumn(label: Text('ยอดรวม')),
                  DataColumn(label: Text('สถานะ')),
                ],
                rows: List.generate(rows.length, (i) {
                  final r = rows[i];
                  return DataRow(
                    cells: [
                      DataCell(Text('${((page - 1) * pageSize) + i + 1}')),
                      DataCell(_directActions(r, actions)),
                      DataCell(Text('${r['code']}')),
                      DataCell(Text(expenseDate(r['expenseDate']))),
                      DataCell(Text('${r['payee']}')),
                      DataCell(Text('${r['billNo'] ?? '-'}')),
                      DataCell(
                        Text(expenseMoney(r['total'], '${r['currency']}')),
                      ),
                      DataCell(Text(expenseStatus('${r['status']}'))),
                    ],
                  );
                }),
              ),
      ),
      pagination: LaooPaginationCard(
        tokens: expenseUiTokens,
        page: page,
        pageCount: pageCount,
        pageSize: pageSize,
        total: total,
        onPrevious: page > 1
            ? () {
                setState(() {
                  page--;
                  future = _load();
                });
              }
            : null,
        onNext: page < pageCount
            ? () {
                setState(() {
                  page++;
                  future = _load();
                });
              }
            : null,
      ),
    );
  }

  void _applyDirect() => setState(() {
    appliedSearch = search.text.trim();
    page = 1;
    future = _load();
  });
  Widget _directCards(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> actions,
  ) => ListView.separated(
    padding: expenseUiTokens.cardPadding,
    itemCount: rows.length,
    separatorBuilder: (_, _) => SizedBox(height: expenseUiTokens.itemSpacing),
    itemBuilder: (_, i) {
      final r = rows[i];
      return LaooSurfaceCard(
        tokens: expenseUiTokens,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r['code']}',
                    style: expenseUiTokens.sectionStyle,
                  ),
                ),
                _directActions(r, actions),
              ],
            ),
            Text('${expenseDate(r['expenseDate'])} • ${r['payee']}'),
            Text(
              '${expenseMoney(r['total'], '${r['currency']}')} • ${expenseStatus('${r['status']}')}',
            ),
          ],
        ),
      );
    },
  );
  Widget _directActions(
    Map<String, dynamic> row,
    Map<String, dynamic> actions,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          color: expenseUiTokens.primaryColor,
          onPressed: () =>
              setState(() => editingId = (row['id'] as num).toInt()),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          color: Colors.red,
          onPressed: () => _deleteDirect(row),
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );
  Future<void> _deleteDirect(Map<String, dynamic> row) async {
    if (!await confirmExpenseDelete(
      context,
      keyText: '${row['code']} - ${row['payee']}',
    )) {
      return;
    }
    try {
      await api.delete('/api/company/expenses/direct/${row['id']}');
      if (!mounted) return;
      showExpenseMessage(context, message: 'ลบค่าใช้จ่ายแล้ว');
      reload();
    } catch (e) {
      if (mounted) showExpenseMessage(context, message: '$e', error: true);
    }
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
}

class ExpenseSettingsView extends StatefulWidget {
  const ExpenseSettingsView({
    required this.api,
    required this.title,
    required this.data,
    required this.actions,
    required this.onSaved,
    super.key,
  });
  final JsonApiClient api;
  final String title;
  final Map<String, dynamic> data, actions;
  final VoidCallback onSaved;
  @override
  State<ExpenseSettingsView> createState() => _ExpenseSettingsViewState();
}

class _ExpenseSettingsViewState extends State<ExpenseSettingsView> {
  late bool enabled = widget.data['isEnabled'] == true,
      direct = widget.data['allowDirectEntry'] == true;
  late final currency = TextEditingController(
    text: '${widget.data['defaultCurrencyCode'] ?? 'THB'}',
  );
  bool saving = false;
  @override
  void dispose() {
    currency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LaooCaptionCard(
        tokens: expenseUiTokens,
        leading: Icon(
          Icons.settings_outlined,
          color: expenseUiTokens.primaryColor,
        ),
        caption: widget.title,
      ),
      SizedBox(height: expenseUiTokens.sectionSpacing),
      Expanded(
        child: LaooSurfaceCard(
          tokens: expenseUiTokens,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ค่าการทำงานปัจจุบัน',
                  style: expenseUiTokens.sectionStyle,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('เปิดใช้งานระบบค่าใช้จ่าย'),
                  value: enabled,
                  onChanged: widget.actions['edit'] == true && !saving
                      ? (v) => setState(() => enabled = v)
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'อนุญาตบันทึกค่าใช้จ่ายโดยตรงโดยไม่ผ่านอนุมัติ',
                  ),
                  value: direct,
                  onChanged: widget.actions['edit'] == true && !saving
                      ? (v) => setState(() => direct = v)
                      : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: currency,
                    enabled: widget.actions['edit'] == true && !saving,
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    decoration: expenseInput('สกุลเงินเริ่มต้น *'),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.actions['edit'] == true)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: expenseUiTokens.buttonHeight,
                      child: FilledButton.icon(
                        onPressed: saving ? null : _save,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(saving ? 'กำลังบันทึก' : 'บันทึก'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  Future<void> _save() async {
    final code = currency.text.trim().toUpperCase();
    if (code.length != 3) {
      showExpenseMessage(
        context,
        message: 'กรุณาระบุสกุลเงิน 3 ตัว',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.api.put(
        '/api/company/expenses/settings',
        body: {
          'isEnabled': enabled,
          'allowDirectEntry': direct,
          'defaultCurrencyCode': code,
        },
      );
      if (!mounted) return;
      showExpenseMessage(context, message: 'บันทึกการตั้งค่าแล้ว');
      widget.onSaved();
    } catch (e) {
      if (mounted) showExpenseMessage(context, message: '$e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class DirectExpenseEditor extends StatefulWidget {
  const DirectExpenseEditor({
    required this.api,
    required this.title,
    required this.expenseId,
    required this.onCancel,
    required this.onSaved,
    super.key,
  });
  final JsonApiClient api;
  final String title;
  final int? expenseId;
  final VoidCallback onCancel, onSaved;
  @override
  State<DirectExpenseEditor> createState() => _DirectExpenseEditorState();
}

class _DirectExpenseEditorState extends State<DirectExpenseEditor> {
  final formKey = GlobalKey<FormState>(),
      number = TextEditingController(),
      date = TextEditingController(),
      payee = TextEditingController(),
      bill = TextEditingController(),
      currency = TextEditingController(text: 'THB'),
      remark = TextEditingController();
  String payment = 'BANK';
  bool loading = true, saving = false;
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> projects = [];
  int? businessProjectId;
  final lines = <ExpenseLineDraft>[];
  @override
  void initState() {
    super.initState();
    date.text = expenseDate(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    try {
      final options = Map<String, dynamic>.from(
        await widget.api.get('/api/company/expenses/options') as Map,
      );
      categories = (options['categories'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final seenProjects = <int>{};
      projects = (options['projects'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) {
            final id = (e['id'] as num?)?.toInt();
            return id != null && seenProjects.add(id);
          })
          .toList();
      final settings = options['settings'] as List?;
      if (settings != null && settings.isNotEmpty) {
        currency.text = '${(settings.first as Map)['currency'] ?? 'THB'}';
      }
      if (widget.expenseId != null) {
        final data = Map<String, dynamic>.from(
              await widget.api.get(
                    '/api/company/expenses/direct/${widget.expenseId}',
                  )
                  as Map,
            ),
            header = Map<String, dynamic>.from(data['header'] as Map);
        number.text = '${header['code'] ?? ''}';
        date.text = expenseDate(header['expenseDate']);
        payee.text = '${header['payee'] ?? ''}';
        bill.text = '${header['billNo'] ?? ''}';
        payment = '${header['paymentMethod'] ?? 'BANK'}';
        currency.text = '${header['currency'] ?? 'THB'}';
        remark.text = '${header['remark'] ?? ''}';
        for (final raw in data['details'] as List? ?? const []) {
          final r = Map<String, dynamic>.from(raw as Map);
          lines.add(
            ExpenseLineDraft(
              category: '${r['categoryCode']}',
              description: '${r['description']}',
              amount: '${r['amount']}',
            ),
          );
        }
      } else {
        lines.add(
          ExpenseLineDraft(
            category: categories.isEmpty ? '' : '${categories.first['code']}',
          ),
        );
      }
    } catch (e) {
      if (mounted) showExpenseMessage(context, message: '$e', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [number, date, payee, bill, currency, remark]) {
      c.dispose();
    }
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: expenseUiTokens.contentMargin,
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LaooCaptionCard(
                  tokens: expenseUiTokens,
                  leading: Icon(
                    Icons.receipt_long_outlined,
                    color: expenseUiTokens.primaryColor,
                  ),
                  caption:
                      '${widget.title} > ${widget.expenseId == null ? 'เพิ่ม' : 'แก้ไข'}',
                ),
                SizedBox(height: expenseUiTokens.sectionSpacing),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LaooSurfaceCard(
                          tokens: expenseUiTokens,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Header',
                                style: expenseUiTokens.sectionStyle,
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, box) {
                                  final compact = box.maxWidth < 760,
                                      width = compact
                                          ? box.maxWidth
                                          : (box.maxWidth - 16) / 3;
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 16,
                                    children: [
                                      SizedBox(
                                        width: width,
                                        child: TextFormField(
                                          controller: number,
                                          decoration: expenseInput(
                                            'เลขที่เอกสาร (สร้างอัตโนมัติ)',
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: width,
                                        child: TextFormField(
                                          controller: date,
                                          readOnly: true,
                                          onTap: _pickDate,
                                          decoration: expenseInput(
                                            'วันที่ค่าใช้จ่าย *',
                                            icon: Icons.calendar_month_outlined,
                                          ),
                                          validator: _required,
                                        ),
                                      ),
                                      SizedBox(
                                        width: width,
                                        child: TextFormField(
                                          controller: payee,
                                          decoration: expenseInput(
                                            'ผู้รับเงิน/ผู้ขาย *',
                                          ),
                                          validator: _required,
                                        ),
                                      ),
                                      SizedBox(
                                        width: width,
                                        child: TextFormField(
                                          controller: bill,
                                          decoration: expenseInput(
                                            'เลขที่บิล/ใบเสร็จ',
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: width,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: payment,
                                          isExpanded: true,
                                          decoration: expenseInput(
                                            'วิธีชำระ *',
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'CASH',
                                              child: Text('เงินสด'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'BANK',
                                              child: Text('โอนธนาคาร'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'CARD',
                                              child: Text('บัตร'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'OTHER',
                                              child: Text('อื่น ๆ'),
                                            ),
                                          ],
                                          onChanged: (v) => setState(
                                            () => payment = v ?? 'BANK',
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: width,
                                        child: DropdownButtonFormField<int?>(
                                          initialValue:
                                              projects.any(
                                                (p) =>
                                                    (p['id'] as num).toInt() ==
                                                    businessProjectId,
                                              )
                                              ? businessProjectId
                                              : null,
                                          isExpanded: true,
                                          decoration: expenseInput('โครงการ'),
                                          items: [
                                            const DropdownMenuItem<int?>(
                                              value: null,
                                              child: Text('ไม่ระบุโครงการ'),
                                            ),
                                            ...projects.map(
                                              (p) => DropdownMenuItem<int?>(
                                                value: (p['id'] as num).toInt(),
                                                child: Text(
                                                  '${p['code']} - ${p['name']}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (v) => setState(
                                            () => businessProjectId = v,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: width,
                                        child: TextFormField(
                                          controller: currency,
                                          maxLength: 3,
                                          decoration: expenseInput(
                                            'สกุลเงิน *',
                                          ),
                                          validator: _required,
                                        ),
                                      ),
                                      SizedBox(
                                        width: box.maxWidth,
                                        child: TextFormField(
                                          controller: remark,
                                          maxLines: 2,
                                          maxLength: 2000,
                                          decoration: expenseInput('หมายเหตุ'),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: expenseUiTokens.sectionSpacing),
                        LaooSurfaceCard(
                          tokens: expenseUiTokens,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Detail',
                                      style: expenseUiTokens.sectionStyle,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: saving ? null : _addLine,
                                    icon: const Icon(Icons.add),
                                    label: const Text('เพิ่มรายการ'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...List.generate(lines.length, _lineEditor),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'ยอดรวม ${expenseMoney(_total, currency.text.toUpperCase())}',
                                  style: expenseUiTokens.sectionStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: expenseUiTokens.sectionSpacing),
                        LaooSurfaceCard(
                          tokens: expenseUiTokens,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 84,
                                height: expenseUiTokens.buttonHeight,
                                child: OutlinedButton(
                                  onPressed: saving ? null : widget.onCancel,
                                  child: const Text('ยกเลิก'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 120,
                                height: expenseUiTokens.buttonHeight,
                                child: FilledButton.icon(
                                  onPressed: saving ? null : _save,
                                  icon: saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    saving ? 'กำลังบันทึก' : 'บันทึก',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
  Widget _lineEditor(int index) {
    final line = lines[index],
        seen = <String>{},
        unique = categories.where((r) => seen.add('${r['code']}')).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 720;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'รายการ ${index + 1}',
                      style: expenseUiTokens.sectionStyle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'ลบรายการ',
                    color: Colors.red,
                    onPressed: lines.length == 1 || saving
                        ? null
                        : () {
                            setState(() {
                              lines.removeAt(index).dispose();
                            });
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: compact ? box.maxWidth : box.maxWidth * .28,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          unique.any((r) => '${r['code']}' == line.category)
                          ? line.category
                          : null,
                      isExpanded: true,
                      decoration: expenseInput('ประเภทค่าใช้จ่าย *'),
                      items: unique
                          .map(
                            (r) => DropdownMenuItem(
                              value: '${r['code']}',
                              child: Text(
                                '${r['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'กรุณาเลือกประเภท' : null,
                      onChanged: (v) => setState(() => line.category = v ?? ''),
                    ),
                  ),
                  SizedBox(
                    width: compact ? box.maxWidth : box.maxWidth * .5,
                    child: TextFormField(
                      controller: line.description,
                      maxLength: 500,
                      decoration: expenseInput('รายละเอียด *'),
                      validator: _required,
                    ),
                  ),
                  SizedBox(
                    width: compact ? box.maxWidth : box.maxWidth * .18 - 16,
                    child: TextFormField(
                      controller: line.amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: expenseInput('จำนวนเงิน *'),
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                          ? 'ต้องมากกว่า 0'
                          : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (index < lines.length - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Divider(height: 1, color: expenseUiTokens.borderColor),
                ),
            ],
          );
        },
      ),
    );
  }

  double get _total => lines.fold(
    0,
    (sum, line) => sum + (double.tryParse(line.amount.text) ?? 0),
  );
  void _addLine() => setState(
    () => lines.add(
      ExpenseLineDraft(
        category: categories.isEmpty ? '' : '${categories.first['code']}',
      ),
    ),
  );
  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(date.text) ?? DateTime.now(),
        value = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
    if (value != null) setState(() => date.text = expenseDate(value));
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false) || saving) return;
    setState(() => saving = true);
    final body = {
      'expenseNo': number.text.trim().isEmpty ? null : number.text.trim(),
      'expenseDate': date.text,
      'payeeName': payee.text.trim(),
      'billNo': bill.text.trim().isEmpty ? null : bill.text.trim(),
      'paymentMethodCode': payment,
      'currencyCode': currency.text.trim().toUpperCase(),
      'businessProjectId': businessProjectId,
      'remark': remark.text.trim().isEmpty ? null : remark.text.trim(),
      'details': lines
          .map(
            (l) => {
              'expenseTypeCode': l.category,
              'description': l.description.text.trim(),
              'amount': double.tryParse(l.amount.text) ?? 0,
            },
          )
          .toList(),
    };
    try {
      if (widget.expenseId == null) {
        await widget.api.post('/api/company/expenses/direct', body: body);
      } else {
        await widget.api.put(
          '/api/company/expenses/direct/${widget.expenseId}',
          body: body,
        );
      }
      if (!mounted) return;
      showExpenseMessage(
        context,
        message: 'บันทึกค่าใช้จ่ายแล้ว สถานะบันทึกแล้ว',
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) showExpenseMessage(context, message: '$e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class ExpenseLineDraft {
  ExpenseLineDraft({
    required this.category,
    String description = '',
    String amount = '',
  }) : description = TextEditingController(text: description),
       amount = TextEditingController(text: amount);
  String category;
  final TextEditingController description, amount;
  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

class ExpenseFormDialog extends StatelessWidget {
  const ExpenseFormDialog({
    required this.title,
    required this.icon,
    required this.content,
    required this.saving,
    required this.onCancel,
    required this.onSave,
    super.key,
  });
  final String title;
  final IconData icon;
  final Widget content;
  final bool saving;
  final VoidCallback onCancel, onSave;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: size.height - 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(icon, size: 24, color: expenseUiTokens.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title, style: expenseUiTokens.captionStyle),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: expenseUiTokens.borderColor),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: content,
              ),
            ),
            Divider(height: 1, color: expenseUiTokens.borderColor),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 84,
                    height: expenseUiTokens.buttonHeight,
                    child: OutlinedButton(
                      onPressed: saving ? null : onCancel,
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    height: expenseUiTokens.buttonHeight,
                    child: FilledButton.icon(
                      onPressed: saving ? null : onSave,
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('บันทึก'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration expenseInput(String label, {IconData? icon}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: expenseUiTokens.borderColor),
  );
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: expenseUiTokens.primaryColor, width: 1.5),
    ),
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null;
String expenseDate(dynamic value) {
  if (value is DateTime) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
  final text = '${value ?? ''}';
  return text.length >= 10 ? text.substring(0, 10) : text;
}

String expenseMoney(dynamic value, String currency) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? 0;
  return '${number.toStringAsFixed(2)} $currency';
}

String expenseStatus(String code) => code == 'RECORDED'
    ? 'บันทึกแล้ว'
    : code == 'CANCELLED'
    ? 'ยกเลิก'
    : code;
Future<bool> confirmExpenseDelete(
  BuildContext context, {
  required String keyText,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Colors.red),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(keyText),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    ) ??
    false;
