import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'expense_feature_host.dart';

enum ExpenseWorkflowMode {
  advances,
  claims,
  approvals,
  settlements,
  mine,
  reports,
}

class ExpenseWorkflowPage extends StatefulWidget {
  const ExpenseWorkflowPage({
    required this.menuCode,
    required this.title,
    required this.mode,
    super.key,
  });
  final String menuCode, title;
  final ExpenseWorkflowMode mode;
  @override
  State<ExpenseWorkflowPage> createState() => _ExpenseWorkflowPageState();
}

class _ExpenseWorkflowPageState extends State<ExpenseWorkflowPage> {
  late final JsonApiClient api = createExpenseApiClient();
  late Future<Map<String, dynamic>> future;
  final search = TextEditingController();
  final reportFrom = TextEditingController();
  final reportTo = TextEditingController();
  String title = '', status = '', appliedSearch = '';
  String appliedReportFrom = '', appliedReportTo = '';
  String reportPeriod = 'MONTH', reportCategory = '';
  int? reportDepartmentId, reportEmployeeId;
  int page = 1;
  static const pageSize = 10;
  int? editorId;
  String? editorType;
  bool editorReadOnly = false;
  bool get isDocument =>
      widget.mode == ExpenseWorkflowMode.advances ||
      widget.mode == ExpenseWorkflowMode.claims ||
      widget.mode == ExpenseWorkflowMode.mine;
  @override
  void initState() {
    super.initState();
    title = widget.title;
    if (widget.mode == ExpenseWorkflowMode.reports) {
      final now = DateTime.now();
      reportFrom.text = _date(DateTime(now.year));
      reportTo.text = _date(DateTime(now.year, 12, 31));
      appliedReportFrom = reportFrom.text;
      appliedReportTo = reportTo.text;
    }
    future = _load();
    resolveExpenseMenuTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
  }

  @override
  void dispose() {
    search.dispose();
    reportFrom.dispose();
    reportTo.dispose();
    disposeExpenseApiClient(api);
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final actions = _map(
      await api.get('/api/company/expenses/actions/${widget.menuCode}'),
    );
    if (widget.mode == ExpenseWorkflowMode.reports) {
      return {
        'actions': actions,
        'data': await api.get(
          '/api/company/expense-workflow/reports',
          query: {
            'page': '$page',
            'pageSize': '$pageSize',
            if (appliedReportFrom.isNotEmpty)
              'dateFrom': _apiDate(appliedReportFrom),
            if (appliedReportTo.isNotEmpty) 'dateTo': _apiDate(appliedReportTo),
            'period': reportPeriod,
            if (reportCategory.isNotEmpty) 'categoryCode': reportCategory,
            if (reportDepartmentId != null)
              'departmentId': '$reportDepartmentId',
            if (reportEmployeeId != null) 'employeeId': '$reportEmployeeId',
          },
        ),
      };
    }
    final endpoint = switch (widget.mode) {
      ExpenseWorkflowMode.advances => 'advances',
      ExpenseWorkflowMode.claims => 'claims',
      ExpenseWorkflowMode.approvals => 'approvals',
      ExpenseWorkflowMode.settlements => 'settlements',
      ExpenseWorkflowMode.mine => 'mine',
      ExpenseWorkflowMode.reports => 'reports',
    };
    return {
      'actions': actions,
      'data': await api.get(
        '/api/company/expense-workflow/$endpoint',
        query: {
          'page': '$page',
          'pageSize': '$pageSize',
          if (appliedSearch.isNotEmpty) 'search': appliedSearch,
          if (status.isNotEmpty && isDocument) 'status': status,
        },
      ),
    };
  }

  void reload() => setState(() => future = _load());
  void closeEditor() => setState(() {
    editorId = null;
    editorType = null;
    editorReadOnly = false;
    future = _load();
  });
  @override
  Widget build(BuildContext context) => buildExpenseWorkspaceShell(
    pageTitle: title,
    activeMenu: widget.menuCode,
    child: editorType != null
        ? ExpenseWorkflowEditor(
            api: api,
            title: title,
            type: editorType!,
            documentId: editorId,
            personal: widget.mode == ExpenseWorkflowMode.mine,
            readOnly: editorReadOnly,
            onClose: closeEditor,
          )
        : Padding(
            padding: expenseUiTokens.contentMargin,
            child: FutureBuilder<Map<String, dynamic>>(
              future: future,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return _frame(_state('กำลังโหลดข้อมูล...'));
                }
                if (s.hasError) {
                  return _frame(_state('โหลดข้อมูลไม่สำเร็จ', retry: true));
                }
                final value = s.data!,
                    actions = _map(value['actions']),
                    data = _map(value['data']);
                return widget.mode == ExpenseWorkflowMode.reports
                    ? _report(data)
                    : _list(data, actions);
              },
            ),
          ),
  );
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
  Widget _list(Map<String, dynamic> data, Map<String, dynamic> actions) {
    final rows = _rows(data['items']),
        total = _int(data['total']),
        pages = (total / pageSize).ceil().clamp(1, 999999);
    return LaooListWorkspace(
      tokens: expenseUiTokens,
      caption: _caption(
        trailing: isDocument && actions['create'] == true
            ? FilledButton.icon(
                onPressed: () {
                  setState(() {
                    editorId = null;
                    editorType = widget.mode == ExpenseWorkflowMode.advances
                        ? 'ADVANCE'
                        : 'CLAIM';
                  });
                },
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
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applySearch(),
              decoration: _input(
                'ค้นหาเลขที่เอกสารหรือผู้รับเงิน',
                icon: Icons.search,
              ),
            ),
          ),
          if (isDocument)
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: status,
                isExpanded: true,
                decoration: _input('สถานะ'),
                items: _statusOptions,
                onChanged: (v) => setState(() => status = v ?? ''),
              ),
            ),
          FilledButton.icon(
            onPressed: _applySearch,
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              search.clear();
              setState(() {
                appliedSearch = '';
                status = '';
                page = 1;
                future = _load();
              });
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('ล้าง Filter'),
          ),
        ],
      ),
      table: rows.isEmpty
          ? _state('ไม่พบข้อมูล')
          : LayoutBuilder(
              builder: (context, c) =>
                  c.maxWidth < expenseUiTokens.compactBreakpoint
                  ? _cards(rows, actions)
                  : _table(rows, actions),
            ),
      pagination: LaooPaginationCard(
        tokens: expenseUiTokens,
        page: page,
        pageCount: pages,
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
        onNext: page < pages
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

  void _applySearch() => setState(() {
    appliedSearch = search.text.trim();
    page = 1;
    future = _load();
  });
  Widget _table(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> actions,
  ) => LaooWorkspaceDataTable(
    tokens: expenseUiTokens,
    columns: const [
      LaooWorkspaceTableColumns.id,
      DataColumn(label: Text('จัดการ')),
      DataColumn(label: Text('เลขที่เอกสาร')),
      DataColumn(label: Text('วันที่')),
      DataColumn(label: Text('ผู้รับเงิน')),
      DataColumn(label: Text('ยอดรวม')),
      DataColumn(label: Text('สถานะ')),
    ],
    rows: List.generate(rows.length, (i) {
      final r = rows[i];
      return DataRow(
        cells: [
          DataCell(Text('${(page - 1) * pageSize + i + 1}')),
          DataCell(_actions(r, actions)),
          DataCell(Text(_safe(r['code']))),
          DataCell(Text(_date(r['documentDate']))),
          DataCell(Text(_safe(r['payee']))),
          DataCell(Text(_money(r['total'], _safe(r['currency'])))),
          DataCell(Text(_status(_safe(r['status'])))),
        ],
      );
    }),
  );
  Widget _cards(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> actions,
  ) => ListView.separated(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: EdgeInsets.fromLTRB(
      10,
      10,
      10,
      10 + MediaQuery.viewPaddingOf(context).bottom,
    ),
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
                  Text(_safe(r['code']), style: expenseUiTokens.sectionStyle),
                  Text('${_date(r['documentDate'])} • ${_safe(r['payee'])}'),
                  Text(
                    '${_money(r['total'], _safe(r['currency']))} • ${_status(_safe(r['status']))}',
                  ),
                ],
              ),
            ),
            _actions(r, actions),
          ],
        ),
      );
    },
  );
  Widget _actions(Map<String, dynamic> row, Map<String, dynamic> actions) {
    final id = _int(row['id']),
        type = _safe(row['type']),
        st = _safe(row['status']);
    return Wrap(
      spacing: 0,
      children: [
        IconButton(
          tooltip: 'ดู',
          onPressed: () => setState(() {
            editorId = id;
            editorType = type;
            editorReadOnly = true;
          }),
          icon: const Icon(Icons.visibility_outlined),
        ),
        if (isDocument && st == 'DRAFT' && actions['edit'] == true)
          IconButton(
            tooltip: 'แก้ไข',
            color: expenseUiTokens.primaryColor,
            onPressed: () => setState(() {
              editorId = id;
              editorType = type;
            }),
            icon: const Icon(Icons.edit_outlined),
          ),
        if (isDocument && st == 'DRAFT' && actions['submit'] == true)
          IconButton(
            tooltip: 'ส่งอนุมัติ',
            color: expenseUiTokens.primaryColor,
            onPressed: () => _transition(id, 'submit', 'ส่งอนุมัติ'),
            icon: const Icon(Icons.send_outlined),
          ),
        if (isDocument &&
            (st == 'DRAFT' || st == 'SUBMITTED') &&
            actions['cancel'] == true)
          IconButton(
            tooltip: 'ยกเลิกเอกสาร',
            color: Colors.red,
            onPressed: () =>
                _transition(id, 'cancel', 'ยกเลิกเอกสาร', danger: true),
            icon: const Icon(Icons.cancel_outlined),
          ),
        if (isDocument && st == 'DRAFT' && actions['delete'] == true)
          IconButton(
            tooltip: 'ลบ',
            color: Colors.red,
            onPressed: () => _delete(row),
            icon: const Icon(Icons.delete_outline),
          ),
        if (widget.mode == ExpenseWorkflowMode.approvals &&
            actions['approve'] == true) ...[
          IconButton(
            tooltip: 'อนุมัติ',
            color: expenseUiTokens.primaryColor,
            onPressed: () => _decision(id, 'approve', 'อนุมัติรายการ'),
            icon: const Icon(Icons.check_circle_outline),
          ),
          IconButton(
            tooltip: 'ไม่อนุมัติ',
            color: Colors.red,
            onPressed: () => _decision(
              id,
              'reject',
              'ไม่อนุมัติ',
              requireRemark: true,
              danger: true,
            ),
            icon: const Icon(Icons.cancel_outlined),
          ),
        ],
        if (widget.mode == ExpenseWorkflowMode.settlements &&
            st == 'APPROVED' &&
            actions['confirmPayment'] == true)
          IconButton(
            tooltip: 'ยืนยันจ่ายเงิน',
            color: expenseUiTokens.primaryColor,
            onPressed: () => _decision(id, 'payment', 'ยืนยันจ่ายเงิน'),
            icon: const Icon(Icons.payments_outlined),
          ),
        if (widget.mode == ExpenseWorkflowMode.settlements &&
            st == 'PAID' &&
            actions['confirmSettlement'] == true &&
            '${row['type']}' == 'CLAIM')
          IconButton(
            tooltip: 'ยืนยันเคลียร์เงิน',
            color: expenseUiTokens.primaryColor,
            onPressed: () => _decision(id, 'settle', 'ยืนยันเคลียร์เงิน'),
            icon: const Icon(Icons.task_alt_outlined),
          ),
      ],
    );
  }

  Future<void> _transition(
    int id,
    String action,
    String label, {
    bool danger = false,
  }) async {
    if (!await _confirm(label, 'เลขอ้างอิง $id', danger: danger)) return;
    try {
      await api.post(
        '/api/company/expense-workflow/documents/$id/$action',
        body: {},
      );
      if (mounted) {
        showExpenseMessage(context, message: '$label สำเร็จ');
        reload();
      }
    } catch (e) {
      if (mounted) showExpenseMessage(context, message: '$e', error: true);
    }
  }

  Future<void> _decision(
    int id,
    String action,
    String label, {
    bool requireRemark = false,
    bool danger = false,
  }) async {
    final remark = await _remarkDialog(
      label,
      required: requireRemark,
      danger: danger,
    );
    if (remark == null) return;
    final base = widget.mode == ExpenseWorkflowMode.approvals
        ? 'approvals'
        : 'settlements';
    try {
      await api.post(
        '/api/company/expense-workflow/$base/$id/$action',
        body: {'remark': remark},
      );
      if (mounted) {
        showExpenseMessage(context, message: '$label สำเร็จ');
        reload();
      }
    } catch (e) {
      if (mounted) showExpenseMessage(context, message: '$e', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!await _confirm(
      'ยืนยันการลบข้อมูล',
      _safe(row['code']),
      danger: true,
    )) {
      return;
    }
    final type = _safe(row['type']),
        personal = widget.mode == ExpenseWorkflowMode.mine,
        path = personal
            ? 'mine/${type == 'ADVANCE' ? 'advances' : 'claims'}'
            : type == 'ADVANCE'
            ? 'advances'
            : 'claims';
    try {
      await api.delete('/api/company/expense-workflow/$path/${row['id']}');
      if (mounted) {
        showExpenseMessage(context, message: 'ลบข้อมูลแล้ว');
        reload();
      }
    } catch (e) {
      if (mounted) showExpenseMessage(context, message: '$e', error: true);
    }
  }

  Widget _report(Map<String, dynamic> data) {
    final metrics = _map(data['metrics']),
        summary = _rows(data['summary']),
        trend = _rows(data['trend']),
        byCategory = _rows(data['byCategory']),
        byDepartment = _rows(data['byDepartment']),
        byEmployee = _rows(data['byEmployee']),
        items = _rows(data['items']),
        total = _int(data['total']),
        pages = (_int(data['total']) / pageSize).ceil().clamp(1, 999999),
        departmentOptions = _uniqueRows(_rows(data['departmentOptions']), 'id'),
        employeeOptions = _uniqueRows(_rows(data['employeeOptions']), 'id'),
        categoryOptions = _uniqueRows(_rows(data['categoryOptions']), 'code');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _caption(),
        SizedBox(height: expenseUiTokens.sectionSpacing),
        _reportFilter(departmentOptions, employeeOptions, categoryOptions),
        SizedBox(height: expenseUiTokens.sectionSpacing),
        Expanded(
          child: Scrollbar(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _metricCards(metrics),
                SizedBox(height: expenseUiTokens.sectionSpacing),
                _trendPanel(trend),
                SizedBox(height: expenseUiTokens.sectionSpacing),
                LayoutBuilder(
                  builder: (context, box) {
                    final columns = box.maxWidth >= 1080
                        ? 3
                        : box.maxWidth >= 700
                        ? 2
                        : 1;
                    final width =
                        (box.maxWidth -
                            expenseUiTokens.itemSpacing * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: expenseUiTokens.itemSpacing,
                      runSpacing: expenseUiTokens.itemSpacing,
                      children: [
                        SizedBox(
                          width: width,
                          child: _dimensionPanel(
                            title: 'ตามประเภทค่าใช้จ่าย',
                            icon: Icons.category_outlined,
                            rows: byCategory,
                            name: (r) => _safe(r['name']),
                            onTap: (r) => _selectReportDimension(
                              category: _safe(r['code'], empty: ''),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _dimensionPanel(
                            title: 'ตามแผนก',
                            icon: Icons.account_tree_outlined,
                            rows: byDepartment,
                            name: (r) => _safe(r['name']),
                            onTap: (r) {
                              final id = _nullableInt(r['id']);
                              if (id != null) {
                                _selectReportDimension(departmentId: id);
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _dimensionPanel(
                            title: 'ตามพนักงาน',
                            icon: Icons.badge_outlined,
                            rows: byEmployee,
                            name: (r) =>
                                '${_safe(r['code'])} • ${_safe(r['name'])}',
                            onTap: (r) {
                              final id = _nullableInt(r['id']);
                              if (id != null) {
                                _selectReportDimension(employeeId: id);
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: expenseUiTokens.sectionSpacing),
                _dimensionPanel(
                  title: 'ตามสถานะ',
                  icon: Icons.fact_check_outlined,
                  rows: summary,
                  name: (r) => _status(_safe(r['status'])),
                ),
                SizedBox(height: expenseUiTokens.sectionSpacing),
                _reportDetails(items),
              ],
            ),
          ),
        ),
        SizedBox(height: expenseUiTokens.sectionSpacing),
        LaooPaginationCard(
          tokens: expenseUiTokens,
          page: page,
          pageCount: pages,
          pageSize: pageSize,
          total: total,
          onPrevious: page > 1
              ? () => setState(() {
                  page--;
                  future = _load();
                })
              : null,
          onNext: page < pages
              ? () => setState(() {
                  page++;
                  future = _load();
                })
              : null,
        ),
      ],
    );
  }

  Widget _reportFilter(
    List<Map<String, dynamic>> departments,
    List<Map<String, dynamic>> employees,
    List<Map<String, dynamic>> categories,
  ) => LaooSurfaceCard(
    tokens: expenseUiTokens,
    child: LayoutBuilder(
      builder: (context, box) {
        final fieldWidth = box.maxWidth < 460 ? box.maxWidth : 190.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue: reportPeriod,
                    isExpanded: true,
                    decoration: _input('สรุปตามช่วงเวลา'),
                    items: const [
                      DropdownMenuItem(value: 'YEAR', child: Text('ปี')),
                      DropdownMenuItem(value: 'MONTH', child: Text('เดือน')),
                      DropdownMenuItem(value: 'DAY', child: Text('วัน')),
                    ],
                    onChanged: (v) =>
                        setState(() => reportPeriod = v ?? 'MONTH'),
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    controller: reportFrom,
                    readOnly: true,
                    onTap: () => _pickReportDate(reportFrom),
                    decoration: _input(
                      'วันที่เริ่มต้น',
                      icon: Icons.calendar_month_outlined,
                    ),
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    controller: reportTo,
                    readOnly: true,
                    onTap: () => _pickReportDate(reportTo),
                    decoration: _input(
                      'วันที่สิ้นสุด',
                      icon: Icons.event_outlined,
                    ),
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        categories.any(
                          (r) => _safe(r['code'], empty: '') == reportCategory,
                        )
                        ? reportCategory
                        : '',
                    isExpanded: true,
                    decoration: _input('ประเภทค่าใช้จ่าย'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                      ...categories.map(
                        (r) => DropdownMenuItem(
                          value: _safe(r['code'], empty: ''),
                          child: Text(
                            _safe(r['name']),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => reportCategory = v ?? ''),
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        departments.any(
                          (r) => _nullableInt(r['id']) == reportDepartmentId,
                        )
                        ? reportDepartmentId
                        : null,
                    isExpanded: true,
                    decoration: _input('แผนก'),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      ...departments.map(
                        (r) => DropdownMenuItem(
                          value: _nullableInt(r['id']),
                          child: Text(
                            _safe(r['name']),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => reportDepartmentId = v),
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        employees.any(
                          (r) => _nullableInt(r['id']) == reportEmployeeId,
                        )
                        ? reportEmployeeId
                        : null,
                    isExpanded: true,
                    decoration: _input('พนักงาน'),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      ...employees.map(
                        (r) => DropdownMenuItem(
                          value: _nullableInt(r['id']),
                          child: Text(
                            '${_safe(r['code'])} • ${_safe(r['name'])}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => reportEmployeeId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _reportPreset('YEAR'),
                  child: const Text('ปีนี้'),
                ),
                OutlinedButton(
                  onPressed: () => _reportPreset('MONTH'),
                  child: const Text('เดือนนี้'),
                ),
                OutlinedButton(
                  onPressed: () => _reportPreset('DAY'),
                  child: const Text('วันนี้'),
                ),
                FilledButton.icon(
                  onPressed: _applyReportFilters,
                  icon: const Icon(Icons.search),
                  label: const Text('แสดง Dashboard'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearReportFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('ล้าง Filter'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _metricCards(Map<String, dynamic> metrics) {
    final cards = [
      ('ยอดค่าใช้จ่ายรวม', metrics['totalAmount'], Icons.payments_outlined),
      ('จำนวนเอกสาร', metrics['documentCount'], Icons.description_outlined),
      (
        'ค่าเฉลี่ยต่อเอกสาร',
        metrics['averageAmount'],
        Icons.analytics_outlined,
      ),
      ('รออนุมัติ', metrics['pendingAmount'], Icons.hourglass_top_outlined),
      ('จ่าย/บันทึกแล้ว', metrics['paidAmount'], Icons.task_alt_outlined),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 1100
            ? 5
            : box.maxWidth >= 700
            ? 3
            : box.maxWidth >= 420
            ? 2
            : 1;
        final width =
            (box.maxWidth - expenseUiTokens.itemSpacing * (columns - 1)) /
            columns;
        return Wrap(
          spacing: expenseUiTokens.itemSpacing,
          runSpacing: expenseUiTokens.itemSpacing,
          children: List.generate(cards.length, (i) {
            final item = cards[i];
            final isCount = i == 1;
            return SizedBox(
              width: width,
              child: LaooSurfaceCard(
                tokens: expenseUiTokens,
                child: Row(
                  children: [
                    Icon(item.$3, color: expenseUiTokens.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1),
                          const SizedBox(height: 4),
                          Text(
                            isCount
                                ? '${_int(item.$2)} รายการ'
                                : _money(item.$2, 'THB'),
                            style: expenseUiTokens.sectionStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _trendPanel(List<Map<String, dynamic>> rows) {
    final shown = rows.length > 24 ? rows.sublist(rows.length - 24) : rows;
    final maxValue = shown.fold<double>(
      0,
      (m, r) => (_double(r['total']) > m) ? _double(r['total']) : m,
    );
    return LaooSurfaceCard(
      tokens: expenseUiTokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart_outlined,
                color: expenseUiTokens.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'แนวโน้มค่าใช้จ่ายตาม${_periodLabel(reportPeriod)}',
                  style: expenseUiTokens.sectionStyle,
                ),
              ),
              if (rows.length > shown.length)
                Text('แสดง ${shown.length} ช่วงล่าสุด'),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('ไม่พบข้อมูล')),
            )
          else
            ...shown.map((r) {
              final ratio = maxValue <= 0
                  ? 0.0
                  : _double(r['total']) / maxValue;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 82, child: Text(_safe(r['bucket']))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Container(
                              height: 28,
                              color: expenseUiTokens.primaryColor.withValues(
                                alpha: .10,
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: ratio.clamp(0.0, 1.0),
                              child: Container(
                                height: 28,
                                color: expenseUiTokens.primaryColor.withValues(
                                  alpha: .55,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(_money(r['total'], 'THB')),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _dimensionPanel({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> rows,
    required String Function(Map<String, dynamic>) name,
    void Function(Map<String, dynamic>)? onTap,
  }) => LaooSurfaceCard(
    tokens: expenseUiTokens,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: expenseUiTokens.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: expenseUiTokens.sectionStyle)),
          ],
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('ไม่พบข้อมูล')),
          )
        else
          ...rows
              .take(10)
              .map(
                (r) => InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: onTap == null ? null : () => onTap(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name(r),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _money(r['total'], 'THB'),
                          style: expenseUiTokens.sectionStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        if (rows.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('แสดง 10 อันดับแรกจาก ${rows.length} รายการ'),
          ),
      ],
    ),
  );

  Widget _reportDetails(List<Map<String, dynamic>> items) => LaooSurfaceCard(
    tokens: expenseUiTokens,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: expenseUiTokens.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'รายละเอียดค่าใช้จ่าย',
                style: expenseUiTokens.sectionStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('ไม่พบข้อมูล')),
          )
        else
          ...List.generate(items.length, (i) {
            final r = items[i];
            return Column(
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    final compact = box.maxWidth < 620;
                    final info = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _safe(r['code']),
                          style: expenseUiTokens.sectionStyle,
                        ),
                        Text(
                          '${_date(r['documentDate'])} • ${_safe(r['payee'])}',
                        ),
                        Text(
                          '${_safe(r['employeeName'])} • ${_safe(r['departmentName'])}',
                        ),
                      ],
                    );
                    final amount = Text(
                      '${_money(r['total'], 'THB')}\n${_status(_safe(r['status']))}',
                      textAlign: compact ? TextAlign.left : TextAlign.right,
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: compact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                info,
                                const SizedBox(height: 8),
                                amount,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: info),
                                const SizedBox(width: 12),
                                amount,
                              ],
                            ),
                    );
                  },
                ),
                if (i < items.length - 1)
                  Divider(color: expenseUiTokens.borderColor),
              ],
            );
          }),
      ],
    ),
  );

  void _applyReportFilters() {
    final from = _parseDate(reportFrom.text), to = _parseDate(reportTo.text);
    if (from != null && to != null && from.isAfter(to)) {
      showExpenseMessage(
        context,
        message: 'วันที่เริ่มต้นต้องไม่มากกว่าวันที่สิ้นสุด',
        error: true,
      );
      return;
    }
    setState(() {
      appliedReportFrom = reportFrom.text.trim();
      appliedReportTo = reportTo.text.trim();
      page = 1;
      future = _load();
    });
  }

  void _reportPreset(String value) {
    final now = DateTime.now();
    final (from, to) = switch (value) {
      'DAY' => (
        DateTime(now.year, now.month, now.day),
        DateTime(now.year, now.month, now.day),
      ),
      'MONTH' => (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1, 0),
      ),
      _ => (DateTime(now.year), DateTime(now.year, 12, 31)),
    };
    reportFrom.text = _date(from);
    reportTo.text = _date(to);
    setState(() => reportPeriod = value);
    _applyReportFilters();
  }

  void _clearReportFilters() {
    final now = DateTime.now();
    reportFrom.text = _date(DateTime(now.year));
    reportTo.text = _date(DateTime(now.year, 12, 31));
    setState(() {
      reportPeriod = 'MONTH';
      reportCategory = '';
      reportDepartmentId = null;
      reportEmployeeId = null;
      appliedReportFrom = reportFrom.text;
      appliedReportTo = reportTo.text;
      page = 1;
      future = _load();
    });
  }

  void _selectReportDimension({
    String? category,
    int? departmentId,
    int? employeeId,
  }) {
    setState(() {
      if (category != null) reportCategory = category;
      if (departmentId != null) reportDepartmentId = departmentId;
      if (employeeId != null) reportEmployeeId = employeeId;
      page = 1;
      future = _load();
    });
  }

  Future<void> _pickReportDate(TextEditingController controller) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final value = await showDatePicker(
      context: context,
      initialDate: _parseDate(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) controller.text = _date(value);
  }

  Future<bool> _confirm(
    String title,
    String key, {
    bool danger = false,
  }) async =>
      (await showDialog<bool>(
        context: context,
        builder: (c) => _ExpenseDialog(
          title: title,
          icon: danger ? Icons.delete_outline : Icons.help_outline,
          danger: danger,
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: danger ? Colors.red.withValues(alpha: .08) : null,
            child: Text(key),
          ),
          cancelText: 'ยกเลิก',
          saveText: danger ? 'ยืนยัน' : 'ตกลง',
          onSave: () => Navigator.pop(c, true),
        ),
      )) ??
      false;
  Future<String?> _remarkDialog(
    String title, {
    bool required = false,
    bool danger = false,
  }) async {
    final controller = TextEditingController();
    final key = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (c) => _ExpenseDialog(
        title: title,
        icon: danger ? Icons.cancel_outlined : Icons.check_circle_outline,
        danger: danger,
        content: Form(
          key: key,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            maxLength: 1000,
            decoration: _input(required ? 'เหตุผล *' : 'หมายเหตุ'),
            validator: (v) =>
                required && v!.trim().isEmpty ? 'กรุณาระบุเหตุผล' : null,
          ),
        ),
        cancelText: 'ยกเลิก',
        saveText: 'ยืนยัน',
        onSave: () {
          if (key.currentState!.validate()) {
            Navigator.pop(c, controller.text.trim());
          }
        },
      ),
    );
    controller.dispose();
    return value;
  }
}

class ExpenseWorkflowEditor extends StatefulWidget {
  const ExpenseWorkflowEditor({
    required this.api,
    required this.title,
    required this.type,
    required this.personal,
    required this.readOnly,
    required this.onClose,
    this.documentId,
    super.key,
  });
  final JsonApiClient api;
  final String title, type;
  final int? documentId;
  final bool personal, readOnly;
  final VoidCallback onClose;
  @override
  State<ExpenseWorkflowEditor> createState() => _ExpenseWorkflowEditorState();
}

class _ExpenseWorkflowEditorState extends State<ExpenseWorkflowEditor> {
  final form = GlobalKey<FormState>(),
      number = TextEditingController(),
      date = TextEditingController(),
      requiredDate = TextEditingController(),
      payee = TextEditingController(),
      purpose = TextEditingController(),
      currency = TextEditingController(text: 'THB'),
      remark = TextEditingController();
  List<Map<String, dynamic>> categories = [], advances = [], projects = [];
  List<_Line> lines = [];
  int? advanceId, businessProjectId;
  bool loading = true, saving = false;
  @override
  void initState() {
    super.initState();
    date.text = _date(DateTime.now());
    requiredDate.text = _date(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    try {
      final o = _map(
        await widget.api.get('/api/company/expense-workflow/options'),
      );
      categories = _rows(o['categories']);
      advances = _rows(o['advances']);
      final seenProjects = <int>{};
      projects = _rows(
        o['projects'],
      ).where((r) => seenProjects.add(_int(r['id']))).toList();
      if (widget.documentId != null) {
        final d = _map(
              await widget.api.get(
                '/api/company/expense-workflow/documents/${widget.documentId}',
              ),
            ),
            h = _map(d['header']);
        number.text = _safe(h['code']);
        date.text = _date(h['documentDate']);
        requiredDate.text = _date(h['requiredDate']);
        payee.text = _safe(h['payee']);
        purpose.text = _safe(h['purpose']);
        currency.text = _safe(h['currency']);
        remark.text = _safe(h['remark'], empty: '');
        advanceId = h['advanceId'] as int?;
        businessProjectId = h['projectId'] as int?;
        lines = _rows(d['details'])
            .map(
              (r) => _Line(
                category: _safe(r['categoryCode']),
                description: _safe(r['description'], empty: ''),
                amount: '${r['amount']}',
              ),
            )
            .toList();
      } else {
        lines = [
          _Line(
            category: categories.isEmpty ? '' : _safe(categories.first['code']),
          ),
        ];
      }
    } catch (e) {
      if (mounted) showExpenseMessage(context, message: '$e', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    for (final l in lines) {
      l.dispose();
    }
    for (final c in [
      number,
      date,
      requiredDate,
      payee,
      purpose,
      currency,
      remark,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: expenseUiTokens.contentMargin,
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LaooCaptionCard(
                  tokens: expenseUiTokens,
                  leading: Icon(
                    Icons.description_outlined,
                    color: expenseUiTokens.primaryColor,
                  ),
                  caption:
                      '${widget.title} > ${widget.readOnly
                          ? 'ดู'
                          : widget.documentId == null
                          ? 'เพิ่ม'
                          : 'แก้ไข'}',
                ),
                SizedBox(height: expenseUiTokens.sectionSpacing),
                Expanded(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      child: Column(
                        children: [
                          _header(),
                          SizedBox(height: expenseUiTokens.sectionSpacing),
                          _details(),
                          SizedBox(height: expenseUiTokens.sectionSpacing),
                          _footer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
  Widget _header() => LaooSurfaceCard(
    tokens: expenseUiTokens,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ข้อมูลเอกสาร', style: expenseUiTokens.sectionStyle),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, b) {
            final compact = b.maxWidth < 760,
                w = compact ? b.maxWidth : (b.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: w,
                  child: TextFormField(
                    controller: number,
                    enabled: !widget.readOnly && widget.documentId == null,
                    textInputAction: TextInputAction.next,
                    decoration: _input('เลขที่เอกสาร (สร้างอัตโนมัติ)'),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: TextFormField(
                    controller: date,
                    readOnly: true,
                    enabled: !widget.readOnly,
                    onTap: () => _pick(date),
                    decoration: _input(
                      'วันที่เอกสาร *',
                      icon: Icons.calendar_month_outlined,
                    ),
                    validator: _required,
                  ),
                ),
                SizedBox(
                  width: w,
                  child: TextFormField(
                    controller: requiredDate,
                    readOnly: true,
                    enabled: !widget.readOnly,
                    onTap: () => _pick(requiredDate),
                    decoration: _input(
                      widget.type == 'ADVANCE'
                          ? 'วันที่ต้องการใช้เงิน'
                          : 'วันที่เกิดค่าใช้จ่าย',
                      icon: Icons.event_outlined,
                    ),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: TextFormField(
                    controller: payee,
                    enabled: !widget.readOnly,
                    textInputAction: TextInputAction.next,
                    decoration: _input('ผู้รับเงิน/ผู้ขาย *'),
                    validator: _required,
                  ),
                ),
                SizedBox(
                  width: w,
                  child: TextFormField(
                    controller: currency,
                    enabled: !widget.readOnly,
                    maxLength: 3,
                    textInputAction: TextInputAction.next,
                    decoration: _input('สกุลเงิน *'),
                    validator: _required,
                  ),
                ),
                SizedBox(
                  width: w,
                  child: DropdownButtonFormField<int?>(
                    initialValue:
                        projects.any((r) => _int(r['id']) == businessProjectId)
                        ? businessProjectId
                        : null,
                    isExpanded: true,
                    decoration: _input('โครงการ'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ไม่ระบุโครงการ'),
                      ),
                      ...projects.map(
                        (r) => DropdownMenuItem<int?>(
                          value: _int(r['id']),
                          child: Text(
                            '${_safe(r['code'])} - ${_safe(r['name'])}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: widget.readOnly
                        ? null
                        : (v) => setState(() => businessProjectId = v),
                  ),
                ),
                if (widget.type == 'CLAIM')
                  SizedBox(
                    width: w,
                    child: DropdownButtonFormField<int>(
                      initialValue: advanceId,
                      isExpanded: true,
                      decoration: _input('อ้างอิงเงินทดรอง'),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('ไม่อ้างอิงเงินทดรอง'),
                        ),
                        ...advances.map(
                          (r) => DropdownMenuItem(
                            value: _int(r['id']),
                            child: Text(
                              '${_safe(r['code'])} • ${_money(r['total'], 'THB')}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: widget.readOnly
                          ? null
                          : (v) => setState(() => advanceId = v),
                    ),
                  ),
                SizedBox(
                  width: b.maxWidth,
                  child: TextFormField(
                    controller: purpose,
                    enabled: !widget.readOnly,
                    maxLines: 2,
                    maxLength: 1000,
                    textInputAction: TextInputAction.next,
                    decoration: _input('วัตถุประสงค์ *'),
                    validator: _required,
                  ),
                ),
                SizedBox(
                  width: b.maxWidth,
                  child: TextFormField(
                    controller: remark,
                    enabled: !widget.readOnly,
                    maxLines: 2,
                    maxLength: 2000,
                    textInputAction: TextInputAction.done,
                    decoration: _input('หมายเหตุ'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
  Widget _details() => LaooSurfaceCard(
    tokens: expenseUiTokens,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('รายละเอียด', style: expenseUiTokens.sectionStyle),
            ),
            if (!widget.readOnly)
              OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () => setState(
                        () => lines.add(
                          _Line(
                            category: categories.isEmpty
                                ? ''
                                : _safe(categories.first['code']),
                          ),
                        ),
                      ),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มรายการ'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(lines.length, _line),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'ยอดรวม ${_money(total, currency.text)}',
            style: expenseUiTokens.sectionStyle,
          ),
        ),
      ],
    ),
  );
  Widget _line(int i) {
    final l = lines[i],
        seen = <String>{},
        unique = categories.where((r) => seen.add(_safe(r['code']))).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'รายการ ${i + 1}',
                  style: expenseUiTokens.sectionStyle,
                ),
              ),
              if (!widget.readOnly)
                IconButton(
                  color: Colors.red,
                  onPressed: lines.length == 1
                      ? null
                      : () => setState(() => lines.removeAt(i).dispose()),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          LayoutBuilder(
            builder: (context, b) {
              final compact = b.maxWidth < 720;
              return Wrap(
                spacing: 8,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: compact ? b.maxWidth : b.maxWidth * .28,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          unique.any((r) => _safe(r['code']) == l.category)
                          ? l.category
                          : null,
                      isExpanded: true,
                      decoration: _input('ประเภทค่าใช้จ่าย *'),
                      items: unique
                          .map(
                            (r) => DropdownMenuItem(
                              value: _safe(r['code']),
                              child: Text(
                                _safe(r['name']),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'กรุณาเลือกประเภท' : null,
                      onChanged: widget.readOnly
                          ? null
                          : (v) => setState(() => l.category = v ?? ''),
                    ),
                  ),
                  SizedBox(
                    width: compact ? b.maxWidth : b.maxWidth * .5,
                    child: TextFormField(
                      controller: l.description,
                      enabled: !widget.readOnly,
                      maxLength: 500,
                      textInputAction: TextInputAction.next,
                      decoration: _input('รายละเอียด *'),
                      validator: _required,
                    ),
                  ),
                  SizedBox(
                    width: compact ? b.maxWidth : b.maxWidth * .18 - 16,
                    child: TextFormField(
                      controller: l.amount,
                      enabled: !widget.readOnly,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      decoration: _input('จำนวนเงิน *'),
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                          ? 'ต้องมากกว่า 0'
                          : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              );
            },
          ),
          if (i < lines.length - 1)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Divider(height: 1, color: expenseUiTokens.borderColor),
            ),
        ],
      ),
    );
  }

  Widget _footer() => LaooSurfaceCard(
    tokens: expenseUiTokens,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 84,
          height: expenseUiTokens.buttonHeight,
          child: OutlinedButton(
            onPressed: saving ? null : widget.onClose,
            child: const Text('ยกเลิก'),
          ),
        ),
        if (!widget.readOnly) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            height: expenseUiTokens.buttonHeight,
            child: FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'กำลังบันทึก' : 'บันทึก'),
            ),
          ),
        ],
      ],
    ),
  );
  double get total =>
      lines.fold(0, (s, l) => s + (double.tryParse(l.amount.text) ?? 0));
  Future<void> _pick(TextEditingController c) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final value = await showDatePicker(
      context: context,
      initialDate: _parseDate(c.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => c.text = _date(value));
  }

  Future<void> _save() async {
    if (!(form.currentState?.validate() ?? false) || saving) return;
    setState(() => saving = true);
    final body = {
      'documentNo': number.text.trim().isEmpty ? null : number.text.trim(),
      'documentDate': _apiDate(date.text),
      'requiredDate': requiredDate.text.trim().isEmpty
          ? null
          : _apiDate(requiredDate.text),
      'payeeName': payee.text.trim(),
      'purpose': purpose.text.trim(),
      'currencyCode': currency.text.trim().toUpperCase(),
      'advanceId': advanceId,
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
    final base = widget.personal
        ? 'mine/${widget.type == 'ADVANCE' ? 'advances' : 'claims'}'
        : widget.type == 'ADVANCE'
        ? 'advances'
        : 'claims';
    try {
      if (widget.documentId == null) {
        await widget.api.post(
          '/api/company/expense-workflow/$base',
          body: body,
        );
      } else {
        await widget.api.put(
          '/api/company/expense-workflow/$base/${widget.documentId}',
          body: body,
        );
      }
      if (mounted) {
        showExpenseMessage(context, message: 'บันทึกเอกสารแล้ว');
        widget.onClose();
      }
    } catch (e) {
      if (mounted) showExpenseMessage(context, message: '$e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _Line {
  _Line({required this.category, String description = '', String amount = ''})
    : description = TextEditingController(text: description),
      amount = TextEditingController(text: amount);
  String category;
  final TextEditingController description, amount;
  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

class _ExpenseDialog extends StatelessWidget {
  const _ExpenseDialog({
    required this.title,
    required this.icon,
    required this.content,
    required this.cancelText,
    required this.saveText,
    required this.onSave,
    this.danger = false,
  });
  final String title, cancelText, saveText;
  final IconData icon;
  final Widget content;
  final VoidCallback onSave;
  final bool danger;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: danger ? const BorderSide(color: Colors.red) : BorderSide.none,
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.sizeOf(context).height - 48,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: danger ? Colors.red : expenseUiTokens.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: expenseUiTokens.captionStyle.copyWith(
                        color: danger ? Colors.red : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: expenseUiTokens.borderColor),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  height: expenseUiTokens.buttonHeight,
                  child: FilledButton.icon(
                    style: danger
                        ? FilledButton.styleFrom(backgroundColor: Colors.red)
                        : null,
                    onPressed: onSave,
                    icon: Icon(danger ? Icons.delete_outline : Icons.check),
                    label: Text(saveText),
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

InputDecoration _input(String label, {IconData? icon}) {
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

String? _required(String? v) =>
    v == null || v.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null;
Map<String, dynamic> _map(dynamic v) =>
    v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v as Map? ?? {});
List<Map<String, dynamic>> _rows(dynamic v) =>
    v is List ? v.map((e) => _map(e)).toList() : [];
int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
int? _nullableInt(dynamic v) => v == null ? null : int.tryParse('$v');
double _double(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
List<Map<String, dynamic>> _uniqueRows(
  List<Map<String, dynamic>> rows,
  String key,
) {
  final seen = <String>{};
  return rows.where((r) {
    final value = '${r[key] ?? ''}';
    return value.isNotEmpty && seen.add(value);
  }).toList();
}

String _periodLabel(String value) => switch (value) {
  'YEAR' => 'ปี',
  'DAY' => 'วัน',
  _ => 'เดือน',
};
String _safe(dynamic v, {String empty = '-'}) {
  final s = '${v ?? ''}'.trim();
  return s.isEmpty || s.toLowerCase() == 'null' ? empty : s;
}

String _date(dynamic v) {
  final d = v is DateTime ? v : DateTime.tryParse('${v ?? ''}');
  if (d == null) return '-';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

DateTime? _parseDate(String v) {
  final p = v.split('/');
  return p.length == 3
      ? DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}')
      : DateTime.tryParse(v);
}

String _apiDate(String v) {
  final d = _parseDate(v);
  return d == null
      ? v
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _money(dynamic v, String currency) {
  final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  final parts = n.toStringAsFixed(2).split('.'),
      digits = parts[0],
      out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '${out.toString()}.${parts[1]} ${currency.isEmpty ? 'THB' : currency}';
}

String _status(String v) =>
    const {
      'DRAFT': 'ร่าง',
      'SUBMITTED': 'รออนุมัติ',
      'APPROVED': 'อนุมัติแล้ว',
      'REJECTED': 'ไม่อนุมัติ',
      'PAID': 'จ่ายเงินแล้ว',
      'SETTLED': 'เคลียร์เงินแล้ว',
      'CANCELLED': 'ยกเลิก',
      'RECORDED': 'บันทึกแล้ว',
    }[v] ??
    v;
const _statusOptions = [
  DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
  DropdownMenuItem(value: 'DRAFT', child: Text('ร่าง')),
  DropdownMenuItem(value: 'SUBMITTED', child: Text('รออนุมัติ')),
  DropdownMenuItem(value: 'APPROVED', child: Text('อนุมัติแล้ว')),
  DropdownMenuItem(value: 'REJECTED', child: Text('ไม่อนุมัติ')),
  DropdownMenuItem(value: 'PAID', child: Text('จ่ายเงินแล้ว')),
  DropdownMenuItem(value: 'SETTLED', child: Text('เคลียร์เงินแล้ว')),
  DropdownMenuItem(value: 'CANCELLED', child: Text('ยกเลิก')),
];
