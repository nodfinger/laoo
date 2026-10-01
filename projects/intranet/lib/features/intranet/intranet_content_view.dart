// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use, prefer_interpolation_to_compose_strings

part of 'intranet_pages.dart';

extension _IntranetContentView on _IntranetPageState {
  Widget settingsView(
    Map<String, dynamic> data,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    if (!settingsReady) {
      settingsReady = true;
      enabled = data['isEnabled'] != false;
      requireApproval = data['requireApproval'] != false;
      allowSelfApproval = data['allowSelfApproval'] == true;
      defaultApprover = data['defaultApproverEmployeeID'] == null
          ? null
          : _IntranetPageState.intOf(data['defaultApproverEmployeeID']);
      days.text = (data['defaultPublishDays'] ?? 30).toString();
    }
    final canEdit = actions['edit'] == true;
    final employees = _IntranetPageState.rowsOf(options['employees']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: intranetUiTokens.sectionSpacing),
        Expanded(
          child: LaooSurfaceCard(
            tokens: intranetUiTokens,
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ค่าการทำงานปัจจุบัน',
                        style: intranetUiTokens.sectionStyle,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('เปิดใช้งานระบบ Intranet'),
                        value: enabled,
                        onChanged: canEdit
                            ? (value) => setState(() => enabled = value)
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'เนื้อหาต้องผ่านการอนุมัติก่อนเผยแพร่',
                        ),
                        value: requireApproval,
                        onChanged: canEdit
                            ? (value) => setState(() => requireApproval = value)
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'อนุญาตให้ผู้สร้างอนุมัติเนื้อหาของตนเอง',
                        ),
                        value: allowSelfApproval,
                        onChanged: canEdit
                            ? (value) =>
                                  setState(() => allowSelfApproval = value)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        value:
                            employees.any(
                              (row) =>
                                  _IntranetPageState.idOf(row) ==
                                  defaultApprover,
                            )
                            ? defaultApprover
                            : null,
                        decoration: input('ผู้อนุมัติเริ่มต้น'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('ไม่กำหนด'),
                          ),
                          ...employees.map(
                            (row) => DropdownMenuItem<int?>(
                              value: _IntranetPageState.idOf(row),
                              child: Text(
                                _IntranetPageState.textOf(row, 'name'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: canEdit
                            ? (value) => setState(() => defaultApprover = value)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: days,
                        enabled: canEdit,
                        keyboardType: TextInputType.number,
                        decoration: input('จำนวนวันเผยแพร่เริ่มต้น *'),
                      ),
                      if (canEdit) ...[
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => run(
                              () => api.put(
                                '/api/company/intranet/settings',
                                body: {
                                  'isEnabled': enabled,
                                  'requireApproval': requireApproval,
                                  'allowSelfApproval': allowSelfApproval,
                                  'defaultApproverEmployeeID': defaultApprover,
                                  'defaultPublishDays':
                                      int.tryParse(days.text) ?? 0,
                                },
                              ),
                              'บันทึกการตั้งค่าแล้ว',
                            ),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('บันทึก'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget contentsView(
    Map<String, dynamic> data,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    final rows = _IntranetPageState.rowsOf(data['items']);
    final total = _IntranetPageState.intOf(data['total']);
    final pageCount = total == 0
        ? 1
        : (total / _IntranetPageState.pageSize).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LaooListCardToggle(
                tokens: intranetUiTokens,
                cards: cards,
                onChanged: (value) => setState(() => cards = value),
              ),
              if (actions['create'] == true)
                FilledButton.icon(
                  onPressed: () => openContent(null, options),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่ม'),
                ),
            ],
          ),
        ),
        SizedBox(height: intranetUiTokens.captionFilterSpacing),
        LaooFilterCard(
          tokens: intranetUiTokens,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: search,
                  onSubmitted: (_) {
                    page = 1;
                    reload();
                  },
                  decoration: input('ค้นหารหัสหรือชื่อ', icon: Icons.search),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: status,
                  decoration: input('สถานะ'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                    DropdownMenuItem(value: 'DRAFT', child: Text('ฉบับร่าง')),
                    DropdownMenuItem(
                      value: 'PENDING_APPROVAL',
                      child: Text('รออนุมัติ'),
                    ),
                    DropdownMenuItem(
                      value: 'PUBLISHED',
                      child: Text('เผยแพร่'),
                    ),
                    DropdownMenuItem(
                      value: 'RETURNED',
                      child: Text('ส่งกลับแก้ไข'),
                    ),
                  ],
                  onChanged: (value) => status = value ?? '',
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  page = 1;
                  reload();
                },
                icon: const Icon(Icons.search),
                label: const Text('ค้นหา'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  search.clear();
                  status = '';
                  page = 1;
                  reload();
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('ล้าง Filter'),
              ),
            ],
          ),
        ),
        SizedBox(height: intranetUiTokens.sectionSpacing),
        Expanded(
          child: LaooTableCard(
            tokens: intranetUiTokens,
            child: rows.isEmpty
                ? const Center(child: Text('ไม่พบข้อมูล'))
                : cards
                ? contentCards(rows, actions, options)
                : contentTable(rows, actions, options),
          ),
        ),
        SizedBox(height: intranetUiTokens.sectionSpacing),
        LaooPaginationCard(
          tokens: intranetUiTokens,
          page: page,
          pageCount: pageCount,
          pageSize: _IntranetPageState.pageSize,
          total: total,
          onPrevious: page > 1
              ? () {
                  page--;
                  reload();
                }
              : null,
          onNext: page < pageCount
              ? () {
                  page++;
                  reload();
                }
              : null,
        ),
      ],
    );
  }

  Widget contentTable(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) => LaooWorkspaceDataTable(
    tokens: intranetUiTokens,
    columns: const [
      LaooWorkspaceTableColumns.id,
      DataColumn(label: Text('จัดการ')),
      DataColumn(label: Text('รหัส')),
      DataColumn(label: Text('ชื่อเนื้อหา')),
      DataColumn(label: Text('ประเภท')),
      DataColumn(label: Text('สถานะ')),
      DataColumn(label: Text('วันที่เผยแพร่')),
    ],
    rows: rows.asMap().entries.map((entry) {
      final row = entry.value;
      return DataRow(
        cells: [
          DataCell(
            Text(
              (((page - 1) * _IntranetPageState.pageSize) + entry.key + 1)
                  .toString(),
            ),
          ),
          DataCell(contentActions(row, actions, options)),
          DataCell(Text(_IntranetPageState.textOf(row, 'code'))),
          DataCell(
            SizedBox(
              width: 280,
              child: Text(
                _IntranetPageState.textOf(row, 'title'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          DataCell(
            Text(
              _IntranetPageState.typeLabel(
                _IntranetPageState.textOf(row, 'type'),
              ),
            ),
          ),
          DataCell(
            Text(
              _IntranetPageState.statusLabel(
                _IntranetPageState.textOf(row, 'status'),
              ),
            ),
          ),
          DataCell(Text(_IntranetPageState.dateOf(row['publishAt']))),
        ],
      );
    }).toList(),
  );

  Widget contentCards(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) => ListView.separated(
    padding: intranetUiTokens.cardPadding,
    itemCount: rows.length,
    separatorBuilder: (_, _) => SizedBox(height: intranetUiTokens.itemSpacing),
    itemBuilder: (_, index) {
      final row = rows[index];
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: intranetUiTokens.borderColor),
        ),
        child: Padding(
          padding: intranetUiTokens.cardPadding,
          child: Row(
            children: [
              Icon(
                Icons.article_outlined,
                color: intranetUiTokens.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _IntranetPageState.textOf(row, 'title'),
                      style: intranetUiTokens.sectionStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _IntranetPageState.textOf(row, 'code') +
                          ' • ' +
                          _IntranetPageState.statusLabel(
                            _IntranetPageState.textOf(row, 'status'),
                          ),
                    ),
                  ],
                ),
              ),
              contentActions(row, actions, options),
            ],
          ),
        ),
      );
    },
  );

  Widget contentActions(
    Map<String, dynamic> row,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    final editable = const {
      'DRAFT',
      'RETURNED',
    }.contains(_IntranetPageState.textOf(row, 'status'));
    return Wrap(
      spacing: 2,
      children: [
        if (actions['edit'] == true && editable)
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => openContent(row, options),
            icon: const Icon(Icons.edit_outlined),
            color: intranetUiTokens.primaryColor,
          ),
        if (actions['submit'] == true && editable)
          IconButton(
            tooltip: 'ส่งอนุมัติ',
            onPressed: () => run(
              () => api.post(
                '/api/company/intranet/contents/' +
                    _IntranetPageState.idOf(row).toString() +
                    '/submit',
              ),
              'ส่งเนื้อหาเข้าสู่ Flow แล้ว',
            ),
            icon: const Icon(Icons.send_outlined),
            color: intranetUiTokens.primaryColor,
          ),
        if (actions['delete'] == true && editable)
          IconButton(
            tooltip: 'ลบ',
            onPressed: () => deleteContent(row),
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
          ),
      ],
    );
  }

  Future<void> openContent(
    Map<String, dynamic>? row,
    Map<String, dynamic> options,
  ) async {
    Map<String, dynamic>? detail;
    if (row != null) {
      detail = _IntranetPageState.mapOf(
        await api.get(
          '/api/company/intranet/contents/' +
              _IntranetPageState.idOf(row).toString(),
        ),
      );
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ContentDialog(api: api, detail: detail, options: options),
    );
    if (saved == true && mounted) {
      showIntranetMessage(
        context,
        message: row == null ? 'เพิ่มเนื้อหาแล้ว' : 'แก้ไขเนื้อหาแล้ว',
      );
      reload();
    }
  }

  Future<void> deleteContent(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => LaooActionDialog(
        tokens: intranetUiTokens,
        width: 480,
        icon: Icons.delete_outline,
        title: 'ลบเนื้อหา',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _IntranetPageState.textOf(row, 'title'),
              style: intranetUiTokens.sectionStyle.copyWith(color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text('ข้อมูลนี้จะถูกลบถาวรและไม่สามารถเรียกคืนได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await run(
        () => api.delete(
          '/api/company/intranet/contents/' +
              _IntranetPageState.idOf(row).toString(),
        ),
        'ลบเนื้อหาแล้ว',
      );
    }
  }

  Widget approvalsView(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> actions,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      caption(),
      SizedBox(height: intranetUiTokens.sectionSpacing),
      Expanded(
        child: LaooSurfaceCard(
          tokens: intranetUiTokens,
          child: rows.isEmpty
              ? const Center(child: Text('ไม่มีรายการรออนุมัติ'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: intranetUiTokens.borderColor),
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.approval_outlined,
                        color: intranetUiTokens.primaryColor,
                      ),
                      title: Text(
                        _IntranetPageState.textOf(row, 'title'),
                        style: intranetUiTokens.sectionStyle,
                      ),
                      subtitle: Text(
                        _IntranetPageState.textOf(row, 'code') +
                            ' • ' +
                            _IntranetPageState.typeLabel(
                              _IntranetPageState.textOf(row, 'type'),
                            ),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          if (actions['return'] == true)
                            OutlinedButton(
                              onPressed: () => decision(row, false),
                              child: const Text('ส่งกลับ'),
                            ),
                          if (actions['approve'] == true)
                            FilledButton.icon(
                              onPressed: () => decision(row, true),
                              icon: const Icon(Icons.check),
                              label: const Text('อนุมัติ'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    ],
  );

  Future<void> decision(Map<String, dynamic> row, bool approve) async {
    var reason = '';
    if (!approve) {
      final controller = TextEditingController();
      final value = await showDialog<String>(
        context: context,
        builder: (context) => LaooActionDialog(
          tokens: intranetUiTokens,
          width: 480,
          icon: Icons.undo_outlined,
          title: 'ส่งกลับแก้ไข',
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: input('เหตุผล *'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (value == null || value.isEmpty) return;
      reason = value;
    }
    await run(
      () => api.post(
        '/api/company/intranet/approvals/' +
            _IntranetPageState.idOf(row).toString() +
            '/decision',
        body: {'action': approve ? 'APPROVE' : 'RETURN', 'reason': reason},
      ),
      approve ? 'อนุมัติและเผยแพร่แล้ว' : 'ส่งกลับให้แก้ไขแล้ว',
    );
  }
}

class _ContentDialog extends StatefulWidget {
  const _ContentDialog({
    required this.api,
    required this.detail,
    required this.options,
  });
  final JsonApiClient api;
  final Map<String, dynamic>? detail;
  final Map<String, dynamic> options;

  @override
  State<_ContentDialog> createState() => _ContentDialogState();
}

class _ContentDialogState extends State<_ContentDialog> {
  final key = GlobalKey<FormState>();
  late final TextEditingController code;
  late final TextEditingController title;
  late final TextEditingController summary;
  late final TextEditingController body;
  late final TextEditingController url;
  late final TextEditingController publish;
  late final TextEditingController expire;
  String type = 'NEWS';
  String target = 'ALL';
  bool pinned = false;
  bool ack = false;
  int? approver;
  final departments = <int>{};
  final employees = <int>{};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final rows = _IntranetPageState.rowsOf(widget.detail?['header']);
    final row = rows.isEmpty ? <String, dynamic>{} : rows.first;
    code = TextEditingController(
      text: _IntranetPageState.textOf(row, 'code', ''),
    );
    title = TextEditingController(
      text: _IntranetPageState.textOf(row, 'title', ''),
    );
    summary = TextEditingController(
      text: _IntranetPageState.textOf(row, 'summary', ''),
    );
    body = TextEditingController(
      text: _IntranetPageState.textOf(row, 'body', ''),
    );
    url = TextEditingController(
      text: _IntranetPageState.textOf(row, 'sourceUrl', ''),
    );
    publish = TextEditingController(
      text: row['publishAt'] == null
          ? DateTime.now().toIso8601String().substring(0, 16)
          : _IntranetPageState.dateOf(row['publishAt']),
    );
    expire = TextEditingController(
      text: row['expireAt'] == null
          ? ''
          : _IntranetPageState.dateOf(row['expireAt']),
    );
    type = _IntranetPageState.textOf(row, 'type', 'NEWS');
    target = _IntranetPageState.textOf(row, 'targetMode', 'ALL');
    pinned = row['pinned'] == true;
    ack = row['requiresAck'] == true;
    approver = row['approverId'] == null
        ? null
        : _IntranetPageState.intOf(row['approverId']);
    departments.addAll(
      _IntranetPageState.rowsOf(
        widget.detail?['departments'],
      ).map(_IntranetPageState.idOf),
    );
    employees.addAll(
      _IntranetPageState.rowsOf(
        widget.detail?['employees'],
      ).map(_IntranetPageState.idOf),
    );
  }

  @override
  void dispose() {
    for (final item in [code, title, summary, body, url, publish, expire]) {
      item.dispose();
    }
    super.dispose();
  }

  InputDecoration field(String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: intranetUiTokens.borderColor),
    );
    return InputDecoration(
      labelText: label,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: intranetUiTokens.primaryColor,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeeOptions = _IntranetPageState.rowsOf(
      widget.options['employees'],
    );
    final departmentOptions = _IntranetPageState.rowsOf(
      widget.options['departments'],
    );
    return LaooActionDialog(
      tokens: intranetUiTokens,
      width: 480,
      icon: Icons.article_outlined,
      title:
          'เนื้อหา Intranet > ' + (widget.detail == null ? 'เพิ่ม' : 'แก้ไข'),
      content: Form(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: code,
              decoration: field('รหัส (สร้างอัตโนมัติได้)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: title,
              decoration: field('ชื่อเนื้อหา *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'กรุณาระบุชื่อเนื้อหา'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: type,
              decoration: field('ประเภท *'),
              items: const [
                DropdownMenuItem(value: 'NEWS', child: Text('ข่าว')),
                DropdownMenuItem(value: 'ANNOUNCEMENT', child: Text('ประกาศ')),
                DropdownMenuItem(value: 'ACTIVITY', child: Text('กิจกรรม')),
                DropdownMenuItem(value: 'DOCUMENT', child: Text('เอกสาร')),
              ],
              onChanged: (value) => setState(() => type = value ?? 'NEWS'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: summary,
              maxLines: 2,
              decoration: field('ข้อความสรุป'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: body,
              maxLines: 5,
              decoration: field('รายละเอียด'),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: url, decoration: field('ลิงก์อ้างอิง')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: target,
              decoration: field('กลุ่มเป้าหมาย *'),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('พนักงานทุกคน')),
                DropdownMenuItem(value: 'DEPARTMENT', child: Text('เลือกแผนก')),
                DropdownMenuItem(
                  value: 'EMPLOYEE',
                  child: Text('เลือกพนักงาน'),
                ),
              ],
              onChanged: (value) => setState(() => target = value ?? 'ALL'),
            ),
            if (target == 'DEPARTMENT') ...[
              const SizedBox(height: 12),
              Text('เลือกแผนก *', style: intranetUiTokens.sectionStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: departmentOptions.map((row) {
                  final id = _IntranetPageState.idOf(row);
                  return FilterChip(
                    label: Text(_IntranetPageState.textOf(row, 'name')),
                    selected: departments.contains(id),
                    onSelected: (selected) => setState(
                      () => selected
                          ? departments.add(id)
                          : departments.remove(id),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (target == 'EMPLOYEE') ...[
              const SizedBox(height: 12),
              Text('เลือกพนักงาน *', style: intranetUiTokens.sectionStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: employeeOptions.map((row) {
                  final id = _IntranetPageState.idOf(row);
                  return FilterChip(
                    label: Text(_IntranetPageState.textOf(row, 'name')),
                    selected: employees.contains(id),
                    onSelected: (selected) => setState(
                      () => selected ? employees.add(id) : employees.remove(id),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: publish,
              decoration: field('วันเวลาเผยแพร่ * (yyyy-MM-dd HH:mm)'),
              validator: dateValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: expire,
              decoration: field('วันเวลาสิ้นสุด (yyyy-MM-dd HH:mm)'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? null
                  : dateValidator(value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value:
                  employeeOptions.any(
                    (row) => _IntranetPageState.idOf(row) == approver,
                  )
                  ? approver
                  : null,
              decoration: field('ผู้อนุมัติ'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('ใช้ผู้อนุมัติเริ่มต้น'),
                ),
                ...employeeOptions.map(
                  (row) => DropdownMenuItem<int?>(
                    value: _IntranetPageState.idOf(row),
                    child: Text(
                      _IntranetPageState.textOf(row, 'name'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => approver = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ปักหมุดเนื้อหา'),
              value: pinned,
              onChanged: (value) => setState(() => pinned = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ผู้ใช้งานต้องกดรับทราบ'),
              value: ack,
              onChanged: (value) => setState(() => ack = value),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(saving ? 'กำลังบันทึก' : 'บันทึก'),
        ),
      ],
    );
  }

  String? dateValidator(String? value) =>
      DateTime.tryParse((value ?? '').replaceFirst(' ', 'T')) == null
      ? 'รูปแบบวันเวลาไม่ถูกต้อง'
      : null;

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    if ((target == 'DEPARTMENT' && departments.isEmpty) ||
        (target == 'EMPLOYEE' && employees.isEmpty)) {
      showIntranetMessage(
        context,
        message: 'กรุณาเลือกกลุ่มเป้าหมายอย่างน้อย 1 รายการ',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    final rows = _IntranetPageState.rowsOf(widget.detail?['header']);
    final id = rows.isEmpty ? null : _IntranetPageState.idOf(rows.first);
    final payload = {
      'code': code.text.trim(),
      'type': type,
      'title': title.text.trim(),
      'summary': summary.text.trim(),
      'body': body.text.trim(),
      'sourceUrl': url.text.trim(),
      'targetMode': target,
      'isPinned': pinned,
      'requiresAcknowledgement': ack,
      'publishAt': DateTime.parse(
        publish.text.replaceFirst(' ', 'T'),
      ).toIso8601String(),
      'expireAt': expire.text.trim().isEmpty
          ? null
          : DateTime.parse(
              expire.text.replaceFirst(' ', 'T'),
            ).toIso8601String(),
      'approverEmployeeID': approver,
      'departmentIDs': target == 'DEPARTMENT' ? departments.toList() : <int>[],
      'employeeIDs': target == 'EMPLOYEE' ? employees.toList() : <int>[],
    };
    try {
      if (id == null) {
        await widget.api.post('/api/company/intranet/contents', body: payload);
      } else {
        await widget.api.put(
          '/api/company/intranet/contents/' + id.toString(),
          body: payload,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        showIntranetMessage(context, message: error.toString(), error: true);
      }
    }
  }
}
