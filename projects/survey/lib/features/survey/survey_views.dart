// ignore_for_file: curly_braces_in_flow_control_structures

part of 'survey_pages.dart';

extension _SurveyViews on _SurveyPageState {
  Widget _list(
    List<Map<String, dynamic>> source,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    final term = appliedSearch.toLowerCase();
    final filtered = source.where((row) {
      final matchText =
          term.isEmpty || row.values.join(' ').toLowerCase().contains(term);
      return matchText &&
          (status.isEmpty ||
              _SurveyPageState._text(row, 'status', '') == status);
    }).toList();
    final pageCount = (filtered.length / _SurveyPageState.pageSize)
        .ceil()
        .clamp(1, 999);
    if (page > pageCount) page = pageCount;
    final visible = filtered
        .skip((page - 1) * _SurveyPageState.pageSize)
        .take(_SurveyPageState.pageSize)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _caption(
          trailing: LayoutBuilder(
            builder: (context, constraints) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (MediaQuery.sizeOf(context).width >=
                    surveyUiTokens.compactBreakpoint)
                  LaooListCardToggle(
                    tokens: surveyUiTokens,
                    cards: cards,
                    onChanged: (value) => mutate(() => cards = value),
                  ),
                if (widget.endpoint.isEmpty && actions['create'] == true) ...[
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: () => _editDocument(null, options),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่ม'),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: surveyUiTokens.captionFilterSpacing),
        LaooFilterCard(
          tokens: surveyUiTokens,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: search,
                  decoration: _input('ค้นหารหัสหรือชื่อ', icon: Icons.search),
                  onSubmitted: (_) => _applyFilter(),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: _input('สถานะ'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                    DropdownMenuItem(value: 'DRAFT', child: Text('ร่าง')),
                    DropdownMenuItem(
                      value: 'PENDING_APPROVAL',
                      child: Text('รออนุมัติ'),
                    ),
                    DropdownMenuItem(
                      value: 'APPROVED',
                      child: Text('อนุมัติแล้ว'),
                    ),
                    DropdownMenuItem(
                      value: 'PUBLISHED',
                      child: Text('เผยแพร่แล้ว'),
                    ),
                    DropdownMenuItem(value: 'CLOSED', child: Text('ปิดแล้ว')),
                    DropdownMenuItem(value: 'WAITING', child: Text('รอตอบ')),
                    DropdownMenuItem(
                      value: 'COMPLETED',
                      child: Text('ตอบแล้ว'),
                    ),
                  ],
                  onChanged: (value) => mutate(() {
                    status = value ?? '';
                    page = 1;
                  }),
                ),
              ),
              FilledButton.icon(
                onPressed: _applyFilter,
                icon: const Icon(Icons.search),
                label: const Text('ค้นหา'),
              ),
              OutlinedButton.icon(
                onPressed: _clearFilter,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('ล้าง Filter'),
              ),
            ],
          ),
        ),
        SizedBox(height: surveyUiTokens.sectionSpacing),
        Expanded(
          child: LaooTableCard(
            tokens: surveyUiTokens,
            child: visible.isEmpty
                ? _state('ไม่พบข้อมูล')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final useCards =
                          cards ||
                          MediaQuery.sizeOf(context).width <
                              surveyUiTokens.compactBreakpoint;
                      return useCards
                          ? _cardRows(visible, actions, options)
                          : _tableRows(visible, actions, options);
                    },
                  ),
          ),
        ),
        SizedBox(height: surveyUiTokens.sectionSpacing),
        LaooPaginationCard(
          tokens: surveyUiTokens,
          page: page,
          pageCount: pageCount,
          pageSize: _SurveyPageState.pageSize,
          total: filtered.length,
          onPrevious: page > 1 ? () => mutate(() => page--) : null,
          onNext: page < pageCount ? () => mutate(() => page++) : null,
        ),
      ],
    );
  }

  void _applyFilter() => mutate(() {
    appliedSearch = search.text.trim();
    page = 1;
  });

  void _clearFilter() {
    search.clear();
    mutate(() {
      appliedSearch = '';
      status = '';
      page = 1;
    });
  }

  Widget _tableRows(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) => LaooWorkspaceDataTable(
    tokens: surveyUiTokens,
    columns: const [
      LaooWorkspaceTableColumns.id,
      DataColumn(label: Text('จัดการ')),
      DataColumn(label: Text('รหัส')),
      DataColumn(label: Text('ชื่อแบบสอบถาม')),
      DataColumn(label: Text('เปิด')),
      DataColumn(label: Text('ปิด')),
      DataColumn(label: Text('สถานะ')),
      DataColumn(label: Text('ผู้ตอบ')),
    ],
    rows: rows.asMap().entries.map((entry) {
      final row = entry.value;
      return DataRow(
        cells: [
          DataCell(
            Text('${entry.key + 1 + (page - 1) * _SurveyPageState.pageSize}'),
          ),
          DataCell(_actions(row, actions, options)),
          DataCell(Text(_SurveyPageState._text(row, 'code'))),
          DataCell(Text(_SurveyPageState._text(row, 'name'))),
          DataCell(Text(_SurveyPageState._date(row['openAt']))),
          DataCell(Text(_SurveyPageState._date(row['closeAt']))),
          DataCell(_statusLabel(_SurveyPageState._text(row, 'status'))),
          DataCell(
            Text('${row['respondedCount'] ?? 0}/${row['audienceCount'] ?? 0}'),
          ),
        ],
      );
    }).toList(),
  );

  Widget _cardRows(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) => SingleChildScrollView(
    padding: surveyUiTokens.cardPadding,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rows
          .map(
            (row) => SizedBox(
              width: 340,
              child: LaooSurfaceCard(
                tokens: surveyUiTokens,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_SurveyPageState._text(row, 'code')} · ${_SurveyPageState._text(row, 'name')}',
                      style: surveyUiTokens.sectionStyle,
                    ),
                    const SizedBox(height: 8),
                    _statusLabel(_SurveyPageState._text(row, 'status')),
                    const SizedBox(height: 8),
                    Text(
                      'เปิด ${_SurveyPageState._date(row['openAt'])} ถึง ${_SurveyPageState._date(row['closeAt'])}',
                    ),
                    Text(
                      'ผู้ตอบ ${row['respondedCount'] ?? 0}/${row['audienceCount'] ?? 0}',
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _actions(row, actions, options),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _actions(
    Map<String, dynamic> row,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    final id = _SurveyPageState._id(row);
    final state = _SurveyPageState._text(row, 'status', '');
    final items = <Widget>[];
    void add(String tip, IconData icon, VoidCallback run, {Color? color}) =>
        items.add(
          IconButton(
            tooltip: tip,
            onPressed: run,
            color: color,
            icon: Icon(icon),
          ),
        );
    if (widget.endpoint.isEmpty) {
      add('ดู', Icons.visibility_outlined, () => _viewDocument(id));
      if (actions['edit'] == true && (state == 'DRAFT' || state == 'RETURNED'))
        add('แก้ไข', Icons.edit_outlined, () => _editDocument(id, options));
      if (actions['submit'] == true &&
          (state == 'DRAFT' || state == 'RETURNED'))
        add(
          'ส่งอนุมัติ',
          Icons.send_outlined,
          () => _run(
            () => api.post('/api/company/surveys/$id/submit'),
            'ส่งอนุมัติแล้ว',
          ),
        );
      if (actions['delete'] == true && state == 'DRAFT')
        add(
          'ลบ',
          Icons.delete_outline,
          () => _confirmDelete(row),
          color: Theme.of(context).colorScheme.error,
        );
      if (actions['cancel'] == true &&
          !{'CLOSED', 'CANCELLED', 'PUBLISHED'}.contains(state))
        add(
          'ยกเลิกเอกสาร',
          Icons.cancel_outlined,
          () => _run(
            () => api.post('/api/company/surveys/$id/cancel'),
            'ยกเลิกแบบสอบถามแล้ว',
          ),
        );
    } else if (widget.endpoint == 'approvals') {
      if (actions['approve'] == true) {
        add(
          'ตรวจสอบและอนุมัติ',
          Icons.fact_check_outlined,
          () => _approval(row),
        );
      }
    } else if (widget.endpoint == 'deliveries') {
      if (state == 'APPROVED' && actions['edit'] == true)
        add(
          'กำหนดผู้ตอบ',
          Icons.group_add_outlined,
          () => _targets(id, options),
        );
      if (state == 'PUBLISHED' && actions['resend'] == true)
        add(
          'แจ้งเตือนซ้ำ',
          Icons.notifications_active_outlined,
          () => _run(
            () => api.post('/api/company/surveys/$id/resend'),
            'บันทึกการแจ้งเตือนแล้ว',
          ),
        );
      if (state == 'PUBLISHED' && actions['edit'] == true)
        add(
          'ปิดแบบสอบถาม',
          Icons.lock_outline,
          () => _run(
            () => api.post('/api/company/surveys/$id/close'),
            'ปิดแบบสอบถามแล้ว',
          ),
        );
    } else if (widget.endpoint == 'results') {
      add('ดูผล', Icons.analytics_outlined, () => _result(id));
    } else if (widget.endpoint == 'mine') {
      if (row['respondedAt'] == null)
        add('ตอบแบบสอบถาม', Icons.edit_note_outlined, () => _respond(id));
      else
        add(
          'ส่งคำตอบแล้ว',
          Icons.check_circle_outline,
          () {},
          color: surveyUiTokens.primaryColor,
        );
    }
    return Wrap(spacing: 2, children: items);
  }

  Widget _statusLabel(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: surveyUiTokens.primaryColor.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      value == '-' ? 'ไม่ระบุ' : value,
      style: TextStyle(color: surveyUiTokens.primaryColor),
    ),
  );

  Widget _settings(
    Map<String, dynamic> data,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _caption(),
      SizedBox(height: surveyUiTokens.sectionSpacing),
      Expanded(
        child: LaooSurfaceCard(
          tokens: surveyUiTokens,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ค่าการทำงานปัจจุบัน', style: surveyUiTokens.sectionStyle),
                const SizedBox(height: 12),
                Divider(color: surveyUiTokens.borderColor),
                _settingRow(
                  'เปิดใช้งานระบบ',
                  data['isEnabled'] == true ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                ),
                _settingRow(
                  'ระยะเวลาเริ่มต้น',
                  '${data['defaultDurationDays'] ?? 14} วัน',
                ),
                _settingRow(
                  'ต้องผ่านอนุมัติ',
                  data['requireApproval'] == true ? 'ใช่' : 'ไม่',
                ),
                _settingRow(
                  'ค่าเริ่มต้นไม่เปิดเผยชื่อ',
                  data['defaultAnonymous'] == true ? 'ใช่' : 'ไม่',
                ),
                _settingRow(
                  'แสดงผลหลังปิด',
                  data['resultsAfterClose'] == true ? 'ใช่' : 'ไม่',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: actions['edit'] == true
                      ? FilledButton.icon(
                          onPressed: () => _editSettings(data, options),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('แก้ไขการตั้งค่า'),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _settingRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            color: surveyUiTokens.primaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _reports(Map<String, dynamic> data) {
    final summary =
        _SurveyPageState._rows(data['summary']).firstOrNull ??
        <String, dynamic>{};
    final surveys = _SurveyPageState._rows(data['surveys']);
    final audience = (summary['audienceCount'] as num?)?.toInt() ?? 0;
    final responded = (summary['respondedCount'] as num?)?.toInt() ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _caption(),
        SizedBox(height: surveyUiTokens.sectionSpacing),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _metric('ทั้งหมด', summary['totalCount'] ?? 0),
            _metric('รออนุมัติ', summary['pendingCount'] ?? 0),
            _metric('กำลังเปิด', summary['publishedCount'] ?? 0),
            _metric('ปิดแล้ว', summary['closedCount'] ?? 0),
            _metric(
              'อัตราตอบ',
              audience == 0
                  ? '0%'
                  : '${(responded * 100 / audience).toStringAsFixed(1)}%',
            ),
          ],
        ),
        SizedBox(height: surveyUiTokens.sectionSpacing),
        Expanded(
          child: LaooTableCard(
            tokens: surveyUiTokens,
            child: surveys.isEmpty
                ? _state('ยังไม่มีข้อมูลรายงาน')
                : _tableRows(surveys, const {}, const {}),
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, Object value) => SizedBox(
    width: 190,
    child: LaooSurfaceCard(
      tokens: surveyUiTokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: surveyUiTokens.captionStyle.copyWith(
              color: surveyUiTokens.primaryColor,
            ),
          ),
        ],
      ),
    ),
  );
}
