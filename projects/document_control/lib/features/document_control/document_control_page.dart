// ignore_for_file: prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures, unnecessary_underscores, use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'document_control_feature_host.dart';

enum DocumentControlPageMode {
  settings,
  types,
  controlled,
  approvals,
  general,
  library,
  acknowledgements,
  reports,
}

class DocumentControlPage extends StatefulWidget {
  const DocumentControlPage({
    required this.menuCode,
    required this.fallbackTitle,
    required this.mode,
    super.key,
  });
  final String menuCode, fallbackTitle;
  final DocumentControlPageMode mode;
  @override
  State<DocumentControlPage> createState() => _DocumentControlPageState();
}

class _DocumentControlPageState extends State<DocumentControlPage> {
  late final JsonApiClient api = createDocumentControlApiClient();
  late Future<Map<String, dynamic>> future;
  final search = TextEditingController();
  String title = '';
  int page = 1;
  @override
  void initState() {
    super.initState();
    title = widget.fallbackTitle;
    future = load();
    resolveDocumentControlMenuTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
  }

  @override
  void dispose() {
    search.dispose();
    disposeDocumentControlApiClient(api);
    super.dispose();
  }

  Future<Map<String, dynamic>> load() async {
    final actions = _map(
      await api.get('/api/company/document-control/actions/' + widget.menuCode),
    );
    final q = Uri.encodeQueryComponent(search.text.trim());
    final path = switch (widget.mode) {
      DocumentControlPageMode.settings => 'settings',
      DocumentControlPageMode.types => 'types',
      DocumentControlPageMode.controlled =>
        'documents?documentClass=CONTROLLED&search=' +
            q +
            '&page=' +
            page.toString() +
            '&pageSize=10',
      DocumentControlPageMode.approvals => 'approval-tasks',
      DocumentControlPageMode.general =>
        'documents?documentClass=GENERAL&search=' +
            q +
            '&page=' +
            page.toString() +
            '&pageSize=10',
      DocumentControlPageMode.library => 'library?search=' + q,
      DocumentControlPageMode.acknowledgements => 'acknowledgements',
      DocumentControlPageMode.reports => 'reports',
    };
    final data = await api.get('/api/company/document-control/' + path);
    dynamic options;
    if ({
      DocumentControlPageMode.types,
      DocumentControlPageMode.controlled,
      DocumentControlPageMode.general,
    }.contains(widget.mode))
      options = await api.get('/api/company/document-control/options');
    return {'actions': actions, 'data': data, 'options': options};
  }

  void reload() => setState(() => future = load());

  @override
  Widget build(BuildContext context) => buildDocumentControlWorkspaceShell(
    pageTitle: title,
    activeMenu: widget.menuCode,
    child: Padding(
      padding: documentControlUiTokens.contentMargin,
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return _state(const CircularProgressIndicator());
          if (snapshot.hasError)
            return _state(
              OutlinedButton.icon(
                onPressed: reload,
                icon: const Icon(Icons.replay),
                label: const Text('โหลดไม่สำเร็จ ลองอีกครั้ง'),
              ),
            );
          final b = snapshot.data!,
              a = _map(b['actions']),
              o = _map(b['options']);
          return switch (widget.mode) {
            DocumentControlPageMode.settings => _settings(_map(b['data']), a),
            DocumentControlPageMode.types => _types(_rows(b['data']), a, o),
            DocumentControlPageMode.controlled => _documents(
              _map(b['data']),
              a,
              o,
              false,
            ),
            DocumentControlPageMode.general => _documents(
              _map(b['data']),
              a,
              o,
              true,
            ),
            DocumentControlPageMode.approvals => _approvals(
              _rows(b['data']),
              a,
            ),
            DocumentControlPageMode.library => _library(
              _rows(b['data']),
              a,
              false,
            ),
            DocumentControlPageMode.acknowledgements => _library(
              _rows(b['data']),
              a,
              true,
            ),
            DocumentControlPageMode.reports => _reports(_map(b['data'])),
          };
        },
      ),
    ),
  );
  Widget _caption({Widget? trailing}) => LaooCaptionCard(
    tokens: documentControlUiTokens,
    leading: Icon(
      Icons.folder_copy_outlined,
      color: documentControlUiTokens.primaryColor,
    ),
    caption: title,
    favoriteKey: widget.menuCode,
    trailing: trailing,
  );
  Widget _state(Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _caption(),
      SizedBox(height: documentControlUiTokens.sectionSpacing),
      Expanded(
        child: LaooSurfaceCard(
          tokens: documentControlUiTokens,
          child: Center(child: child),
        ),
      ),
    ],
  );
  Widget _layout({required Widget body, Widget? trailing, Widget? filter}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _caption(trailing: trailing),
          SizedBox(height: documentControlUiTokens.captionFilterSpacing),
          if (filter != null) ...[
            LaooFilterCard(tokens: documentControlUiTokens, child: filter),
            SizedBox(height: documentControlUiTokens.sectionSpacing),
          ],
          Expanded(child: body),
        ],
      );
  Widget _search() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      SizedBox(
        width: 320,
        child: TextField(
          controller: search,
          decoration: _input('ค้นหาเลขที่หรือชื่อเอกสาร', Icons.search),
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
          page = 1;
          reload();
        },
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('ล้าง Filter'),
      ),
    ],
  );

  Widget _settings(Map<String, dynamic> data, Map<String, dynamic> actions) {
    final p = TextEditingController(text: _text(data['maxPrimaryFileMb'])),
        x = TextEditingController(text: _text(data['maxAttachmentFileMb'])),
        e = TextEditingController(
          text: _text(data['allowedAttachmentExtensions']),
        ),
        r = TextEditingController(text: _text(data['reminderDays']));
    return _layout(
      body: LaooSurfaceCard(
        tokens: documentControlUiTokens,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ค่าการทำงานปัจจุบัน',
                  style: documentControlUiTokens.sectionStyle,
                ),
                const SizedBox(height: 16),
                _field(p, 'ขนาดไฟล์หลัก PDF สูงสุด (MB)'),
                const SizedBox(height: 16),
                _field(x, 'ขนาดไฟล์แนบสูงสุด (MB)'),
                const SizedBox(height: 16),
                _field(e, 'นามสกุลไฟล์แนบที่อนุญาต'),
                const SizedBox(height: 16),
                _field(r, 'แจ้งเตือนก่อนครบกำหนด (วัน)'),
                const SizedBox(height: 20),
                if (actions['edit'] == true)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await api.put(
                          '/api/company/document-control/settings',
                          body: {
                            'maxPrimaryFileMb': int.tryParse(p.text),
                            'maxAttachmentFileMb': int.tryParse(x.text),
                            'allowedAttachmentExtensions': e.text,
                            'reminderDays': int.tryParse(r.text),
                          },
                        );
                        if (mounted)
                          showDocumentControlMessage(
                            context,
                            message: 'บันทึกการตั้งค่าแล้ว',
                          );
                        reload();
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('บันทึก'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _types(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) => _layout(
    trailing: actions['create'] == true
        ? FilledButton.icon(
            onPressed: () => _typeDialog(null, options),
            icon: const Icon(Icons.add),
            label: const Text('เพิ่ม'),
          )
        : null,
    filter: _search(),
    body: _listWithPagination(
      _table(items, actions, options, false, true),
      items.length,
    ),
  );
  Widget _documents(
    Map<String, dynamic> result,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
    bool general,
  ) {
    final items = _rows(result['items']),
        total = (result['total'] as num?)?.toInt() ?? 0,
        pages = (((result['total'] as num?)?.toInt() ?? 0) / 10).ceil().clamp(
          1,
          9999,
        );
    return _layout(
      trailing: actions['create'] == true
          ? FilledButton.icon(
              onPressed: () => _documentDialog(null, options, general),
              icon: const Icon(Icons.add),
              label: const Text('เพิ่ม'),
            )
          : null,
      filter: _search(),
      body: Column(
        children: [
          Expanded(child: _table(items, actions, options, general, false)),
          SizedBox(height: documentControlUiTokens.sectionSpacing),
          _pager(pages, total),
        ],
      ),
    );
  }

  Widget _approvals(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> actions,
  ) => _layout(
    body: _listWithPagination(
      _simpleList(items, (row) => _workflowActions(row, actions)),
      items.length,
    ),
  );
  Widget _library(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> actions,
    bool ack,
  ) => _layout(
    filter: ack ? null : _search(),
    body: _listWithPagination(
      _simpleList(items, (row) => _libraryActions(row, actions, ack)),
      items.length,
    ),
  );
  Widget _reports(Map<String, dynamic> data) {
    final s = _map(data['summary']);
    final values = [
      ('เอกสารทั้งหมด', s['total']),
      ('มีผลบังคับใช้', s['effective']),
      ('เผยแพร่ทั่วไป', s['published']),
      ('รอดำเนินการ', s['pending']),
      ('ใกล้หมดอายุ', s['expiring']),
    ];
    return _layout(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: values
                  .map(
                    (v) => SizedBox(
                      width: 210,
                      height: 105,
                      child: LaooSurfaceCard(
                        tokens: documentControlUiTokens,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _text(v.$2),
                              style: documentControlUiTokens.captionStyle
                                  .copyWith(fontSize: 26),
                            ),
                            Text(v.$1),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: documentControlUiTokens.sectionSpacing),
            LaooSurfaceCard(
              tokens: documentControlUiTokens,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'รายการ Audit ล่าสุด',
                    style: documentControlUiTokens.sectionStyle,
                  ),
                  const SizedBox(height: 12),
                  ..._rows(data['audit']).map(
                    (row) => ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.history,
                        color: documentControlUiTokens.primaryColor,
                      ),
                      title: Text(
                        _text(row['documentNo']) + ' · ' + _text(row['action']),
                      ),
                      subtitle: Text(
                        _text(row['detail']) + ' · ' + _text(row['actionDate']),
                      ),
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

  Widget _table(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
    bool general,
    bool types,
  ) => LayoutBuilder(
    builder: (context, box) {
      if (items.isEmpty)
        return LaooSurfaceCard(
          tokens: documentControlUiTokens,
          child: const Center(child: Text('ไม่พบข้อมูล')),
        );
      if (box.maxWidth < 900)
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              SizedBox(height: documentControlUiTokens.itemSpacing),
          itemBuilder: (_, i) {
            final row = items[i];
            return LaooSurfaceCard(
              tokens: documentControlUiTokens,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          types
                              ? _text(row['code']) + ' · ' + _text(row['name'])
                              : _text(row['documentNo']) +
                                    ' · Rev. ' +
                                    _text(row['revisionNo']),
                          style: documentControlUiTokens.sectionStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          types
                              ? _className(row['documentClass'])
                              : _text(row['title']) +
                                    '\n' +
                                    _text(row['typeName']),
                        ),
                      ],
                    ),
                  ),
                  types
                      ? _rowActions(
                          row,
                          actions,
                          () => _typeDialog(row, options),
                          () => _deleteType(row),
                        )
                      : _documentActions(row, actions, options, general),
                ],
              ),
            );
          },
        );
      final columns = types
          ? const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Center(child: Text('Action'))),
              DataColumn(label: Text('รหัส')),
              DataColumn(label: Text('ชื่อประเภท')),
              DataColumn(label: Text('กลุ่ม')),
              DataColumn(label: Text('รับทราบ')),
              DataColumn(label: Text('สถานะ')),
            ]
          : const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Center(child: Text('Action'))),
              DataColumn(label: Text('เลขที่เอกสาร')),
              DataColumn(label: Text('ชื่อเอกสาร')),
              DataColumn(label: Text('ประเภท')),
              DataColumn(label: Text('Rev.')),
              DataColumn(label: Text('สถานะ')),
            ];
      return LaooTableCard(
        tokens: documentControlUiTokens,
        child: LaooWorkspaceDataTable(
          tokens: documentControlUiTokens,
          columns: columns,
          rows: List.generate(items.length, (i) {
            final row = items[i];
            return DataRow(
              cells: types
                  ? [
                      DataCell(Text((i + 1).toString())),
                      DataCell(
                        _rowActions(
                          row,
                          actions,
                          () => _typeDialog(row, options),
                          () => _deleteType(row),
                        ),
                      ),
                      DataCell(Text(_text(row['code']))),
                      DataCell(Text(_text(row['name']))),
                      DataCell(Text(_className(row['documentClass']))),
                      DataCell(
                        Text(
                          row['requireAcknowledgement'] == true
                              ? 'กำหนด'
                              : 'ไม่กำหนด',
                        ),
                      ),
                      DataCell(
                        Text(row['active'] == true ? 'ใช้งาน' : 'ปิดใช้งาน'),
                      ),
                    ]
                  : [
                      DataCell(Text(((page - 1) * 10 + i + 1).toString())),
                      DataCell(
                        _documentActions(row, actions, options, general),
                      ),
                      DataCell(Text(_text(row['documentNo']))),
                      DataCell(
                        SizedBox(
                          width: 280,
                          child: Text(
                            _text(row['title']),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(_text(row['typeName']))),
                      DataCell(Text(_text(row['revisionNo']))),
                      DataCell(_statusChip(_text(row['status']))),
                    ],
            );
          }),
        ),
      );
    },
  );

  Widget _simpleList(
    List<Map<String, dynamic>> items,
    Widget Function(Map<String, dynamic>) actions,
  ) {
    if (items.isEmpty)
      return LaooSurfaceCard(
        tokens: documentControlUiTokens,
        child: const Center(child: Text('ไม่พบรายการ')),
      );
    return LaooSurfaceCard(
      tokens: documentControlUiTokens,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            Divider(color: documentControlUiTokens.borderColor, height: 1),
        itemBuilder: (_, i) {
          final row = items[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 6,
            ),
            leading: CircleAvatar(
              backgroundColor: documentControlUiTokens.primaryColor.withValues(
                alpha: .1,
              ),
              child: Icon(
                Icons.description_outlined,
                color: documentControlUiTokens.primaryColor,
              ),
            ),
            title: Text(
              _text(row['documentNo']) + ' · ' + _text(row['title']),
              style: documentControlUiTokens.sectionStyle,
            ),
            subtitle: Text(
              'Rev. ' +
                  _text(row['revisionNo']) +
                  ' · ' +
                  _text(row['typeName'] ?? row['taskType'] ?? row['status']),
            ),
            trailing: actions(row),
          );
        },
      ),
    );
  }

  Widget _rowActions(
    Map<String, dynamic> row,
    Map<String, dynamic> actions,
    VoidCallback edit,
    VoidCallback remove,
  ) => Wrap(
    spacing: 2,
    children: [
      if (actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: edit,
          icon: const Icon(Icons.edit_outlined),
        ),
      if (actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          onPressed: remove,
          color: Colors.red,
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );
  Widget _documentActions(
    Map<String, dynamic> row,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
    bool general,
  ) => Wrap(
    spacing: 2,
    children: [
      IconButton(
        tooltip: 'ดู',
        onPressed: () => _viewDocument(row),
        icon: const Icon(Icons.visibility_outlined),
      ),
      if (actions['edit'] == true &&
          (general || {'DRAFT', 'RETURNED'}.contains(_text(row['status']))))
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () => _editDocument(row, options, general),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (!general &&
          actions['submit'] == true &&
          {'DRAFT', 'RETURNED'}.contains(_text(row['status'])))
        IconButton(
          tooltip: 'ส่งตรวจทาน',
          onPressed: () => _submit(row),
          icon: const Icon(Icons.send_outlined),
        ),
      if (actions['delete'] == true &&
          (general || _text(row['status']) == 'DRAFT'))
        IconButton(
          tooltip: 'ลบ',
          onPressed: () => _deleteDocument(row),
          color: Colors.red,
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );
  Widget _workflowActions(
    Map<String, dynamic> row,
    Map<String, dynamic> actions,
  ) => Wrap(
    spacing: 4,
    children: [
      IconButton(
        tooltip: 'ดูเอกสาร',
        onPressed: () => _viewDocument(row),
        icon: const Icon(Icons.visibility_outlined),
      ),
      if (_text(row['taskType']) == 'REVIEW' && actions['review'] == true)
        FilledButton(
          onPressed: () => _workflow(row, 'review'),
          child: const Text('ตรวจทาน'),
        ),
      if (_text(row['taskType']) == 'APPROVE' && actions['approve'] == true)
        FilledButton(
          onPressed: () => _workflow(row, 'approve'),
          child: const Text('อนุมัติ'),
        ),
      if (actions['return'] == true)
        OutlinedButton(
          onPressed: () => _returnDocument(row),
          child: const Text('ส่งกลับ'),
        ),
    ],
  );
  Widget _libraryActions(
    Map<String, dynamic> row,
    Map<String, dynamic> actions,
    bool ack,
  ) => Wrap(
    spacing: 4,
    children: [
      IconButton(
        tooltip: 'ดูรายละเอียด',
        onPressed: () => _viewDocument(row),
        icon: const Icon(Icons.visibility_outlined),
      ),
      if (ack &&
          row['acknowledgedDate'] == null &&
          actions['acknowledge'] == true)
        FilledButton.icon(
          onPressed: () => _acknowledge(row),
          icon: const Icon(Icons.done_all),
          label: const Text('รับทราบ'),
        ),
    ],
  );

  Future<void> _typeDialog(
    Map<String, dynamic>? row,
    Map<String, dynamic> options,
  ) async {
    final code = TextEditingController(text: _text(row?['code'])),
        name = TextEditingController(text: _text(row?['name']));
    var kind = _text(row?['documentClass']).isEmpty
        ? 'CONTROLLED'
        : _text(row?['documentClass']);
    var audience = _text(row?['defaultAudienceMode']).isEmpty
        ? 'ALL'
        : _text(row?['defaultAudienceMode']);
    var ack = row?['requireAcknowledgement'] == true,
        active = row?['active'] != false;
    final users = _rows(options['users']);
    int? reviewer = (row?['defaultReviewerUserId'] as num?)?.toInt();
    int? approver = (row?['defaultApproverUserId'] as num?)?.toInt();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => _popup(
          caption: 'ประเภทเอกสาร > ' + (row == null ? 'เพิ่ม' : 'แก้ไข'),
          icon: Icons.category_outlined,
          content: Column(
            children: [
              _field(code, 'รหัสประเภท *'),
              const SizedBox(height: 16),
              _field(name, 'ชื่อประเภท *'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: _input('กลุ่มเอกสาร *'),
                items: const [
                  DropdownMenuItem(
                    value: 'CONTROLLED',
                    child: Text('เอกสารควบคุม'),
                  ),
                  DropdownMenuItem(
                    value: 'GENERAL',
                    child: Text('เอกสารทั่วไป'),
                  ),
                ],
                onChanged: (v) => setLocal(() => kind = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: reviewer,
                decoration: _input('ผู้ตรวจทานเริ่มต้น'),
                items: _userItems(users),
                onChanged: (value) => setLocal(() => reviewer = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: approver,
                decoration: _input('ผู้อนุมัติเริ่มต้น'),
                items: _userItems(users),
                onChanged: (value) => setLocal(() => approver = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: audience,
                decoration: _input('สิทธิ์เริ่มต้น *'),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('ทุกคนในบริษัท')),
                  DropdownMenuItem(
                    value: 'RESTRICTED',
                    child: Text('เฉพาะแผนกหรือบุคคล'),
                  ),
                ],
                onChanged: (v) => setLocal(() => audience = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('กำหนดให้รับทราบ'),
                value: ack,
                onChanged: (v) => setLocal(() => ack = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('สถานะใช้งาน'),
                value: active,
                onChanged: (v) => setLocal(() => active = v),
              ),
            ],
          ),
          onSave: () async {
            final body = {
              'code': code.text,
              'name': name.text,
              'documentClass': kind,
              'requireAcknowledgement': ack,
              'defaultReviewerUserId': reviewer,
              'defaultApproverUserId': approver,
              'defaultAudienceMode': audience,
              'active': active,
            };
            if (row == null)
              await api.post('/api/company/document-control/types', body: body);
            else
              await api.put(
                '/api/company/document-control/types/' + _text(row['id']),
                body: body,
              );
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (mounted)
              showDocumentControlMessage(
                context,
                message: 'บันทึกประเภทเอกสารแล้ว',
              );
            reload();
          },
        ),
      ),
    );
  }

  Future<void> _editDocument(
    Map<String, dynamic> row,
    Map<String, dynamic> options,
    bool general,
  ) async {
    final detail = _map(
      await api.get(
        '/api/company/document-control/documents/' + _text(row['id']),
      ),
    );
    if (mounted)
      await _documentDialog(
        _map(detail['header'])..['access'] = detail['access'],
        options,
        general,
      );
  }

  Future<void> _documentDialog(
    Map<String, dynamic>? row,
    Map<String, dynamic> options,
    bool general,
  ) async {
    final no = TextEditingController(text: _text(row?['documentNo'])),
        name = TextEditingController(text: _text(row?['title'])),
        revision = TextEditingController(
          text: _text(row?['revisionNo']).isEmpty
              ? '00'
              : _text(row?['revisionNo']),
        ),
        summary = TextEditingController(text: _text(row?['changeSummary']));
    final types = _rows(options['types'])
        .where(
          (x) =>
              _text(x['documentClass']) == (general ? 'GENERAL' : 'CONTROLLED'),
        )
        .toList();
    final users = _rows(options['users']),
        departments = _rows(options['departments']);
    final typeIds = types.map((x) => (x['id'] as num).toInt()).toSet();
    int? typeId = (row?['documentTypeId'] as num?)?.toInt();
    if (!typeIds.contains(typeId))
      typeId = types.isEmpty ? null : (types.first['id'] as num).toInt();
    var audience = _text(row?['audienceMode']).isEmpty
            ? 'ALL'
            : _text(row?['audienceMode']),
        ack = row?['requireAcknowledgement'] == true,
        download = false;
    int? reviewer = (row?['reviewerUserId'] as num?)?.toInt(),
        approver = (row?['approverUserId'] as num?)?.toInt();
    final selectedDepartments = <int>{}, selectedUsers = <int>{};
    for (final access in _rows(row?['access'])) {
      if (access['subjectType'] == 'DEPARTMENT' && access['subjectId'] is num)
        selectedDepartments.add((access['subjectId'] as num).toInt());
      if (access['subjectType'] == 'USER' && access['subjectId'] is num)
        selectedUsers.add((access['subjectId'] as num).toInt());
      if (access['canDownload'] == true) download = true;
    }
    PlatformFile? primary;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => _popup(
          caption:
              (general ? 'เอกสารทั่วไป' : 'ทะเบียนเอกสารควบคุม') +
              ' > ' +
              (row == null ? 'เพิ่ม' : 'แก้ไข'),
          icon: Icons.description_outlined,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(no, 'เลขที่เอกสาร *'),
              const SizedBox(height: 16),
              _field(name, 'ชื่อเอกสาร *'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: typeId,
                decoration: _input('ประเภทเอกสาร *'),
                items: types
                    .map(
                      (x) => DropdownMenuItem(
                        value: (x['id'] as num).toInt(),
                        child: Text(
                          _text(x['name']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() {
                  typeId = v;
                  if (row == null && v != null) {
                    final selected = types.firstWhere(
                      (x) => (x['id'] as num).toInt() == v,
                    );
                    reviewer = (selected['reviewerUserId'] as num?)?.toInt();
                    approver = (selected['approverUserId'] as num?)?.toInt();
                    audience = _text(selected['audienceMode']).isEmpty
                        ? 'ALL'
                        : _text(selected['audienceMode']);
                    ack = selected['requireAcknowledgement'] == true;
                  }
                }),
              ),
              const SizedBox(height: 16),
              _field(revision, 'Revision *'),
              const SizedBox(height: 16),
              _field(summary, 'รายละเอียดการเปลี่ยนแปลง', maxLines: 3),
              const SizedBox(height: 16),
              if (!general) ...[
                DropdownButtonFormField<int>(
                  initialValue: reviewer,
                  decoration: _input('ผู้ตรวจทาน *'),
                  items: _userItems(users),
                  onChanged: (v) => setLocal(() => reviewer = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: approver,
                  decoration: _input('ผู้อนุมัติ *'),
                  items: _userItems(users),
                  onChanged: (v) => setLocal(() => approver = v),
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                initialValue: audience,
                decoration: _input('ขอบเขตการเข้าถึง *'),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('ทุกคนในบริษัท')),
                  DropdownMenuItem(
                    value: 'RESTRICTED',
                    child: Text('เฉพาะแผนกหรือบุคคล'),
                  ),
                ],
                onChanged: (v) => setLocal(() => audience = v!),
              ),
              const SizedBox(height: 12),
              if (audience == 'RESTRICTED') ...[
                Text('แผนก', style: documentControlUiTokens.sectionStyle),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: departments.map((x) {
                    final id = (x['id'] as num).toInt();
                    return FilterChip(
                      label: Text(_text(x['name'])),
                      selected: selectedDepartments.contains(id),
                      onSelected: (v) => setLocal(
                        () => v
                            ? selectedDepartments.add(id)
                            : selectedDepartments.remove(id),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text('บุคคล', style: documentControlUiTokens.sectionStyle),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: users.map((x) {
                    final id = (x['id'] as num).toInt();
                    return FilterChip(
                      label: Text(_text(x['name'])),
                      selected: selectedUsers.contains(id),
                      onSelected: (v) => setLocal(
                        () => v
                            ? selectedUsers.add(id)
                            : selectedUsers.remove(id),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('อนุญาต Download'),
                value: download,
                onChanged: (v) => setLocal(() => download = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ต้องรับทราบเอกสาร'),
                value: ack,
                onChanged: (v) => setLocal(() => ack = v),
              ),
              if (row == null)
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const ['pdf'],
                      withData: true,
                    );
                    if (picked != null)
                      setLocal(() => primary = picked.files.single);
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(primary?.name ?? 'เลือกไฟล์หลัก PDF'),
                ),
            ],
          ),
          onSave: () async {
            if (typeId == null ||
                no.text.trim().isEmpty ||
                name.text.trim().isEmpty ||
                revision.text.trim().isEmpty ||
                (!general && (reviewer == null || approver == null))) {
              showDocumentControlMessage(
                context,
                message: 'กรุณากรอกข้อมูลบังคับให้ครบ',
                error: true,
              );
              return;
            }
            if (audience == 'RESTRICTED' &&
                selectedDepartments.isEmpty &&
                selectedUsers.isEmpty) {
              showDocumentControlMessage(
                context,
                message: 'เลือกแผนกหรือบุคคลอย่างน้อย 1 รายการ',
                error: true,
              );
              return;
            }
            final body = {
              'documentTypeId': typeId,
              'documentNo': no.text,
              'title': name.text,
              'documentClass': general ? 'GENERAL' : 'CONTROLLED',
              'ownerDepartmentId': null,
              'revisionNo': revision.text,
              'changeSummary': summary.text,
              'effectiveDate': null,
              'reviewerUserId': reviewer,
              'approverUserId': approver,
              'audienceMode': audience,
              'departmentIds': selectedDepartments.toList(),
              'userIds': selectedUsers.toList(),
              'allowDownload': download,
              'requireAcknowledgement': ack,
              'publishDate': general ? DateTime.now().toIso8601String() : null,
              'expireDate': null,
            };
            final result = row == null
                ? _map(
                    await api.post(
                      '/api/company/document-control/documents',
                      body: body,
                    ),
                  )
                : _map(
                    await api.put(
                      '/api/company/document-control/documents/' +
                          _text(row['id']),
                      body: body,
                    ),
                  );
            if (primary != null && primary!.bytes != null)
              await uploadDocumentControlFile(
                '/api/company/document-control/documents/' +
                    _text(result['id']) +
                    '/files',
                fileName: primary!.name,
                bytes: primary!.bytes!,
                fields: {'fileRole': 'PRIMARY'},
              );
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (mounted)
              showDocumentControlMessage(context, message: 'บันทึกเอกสารแล้ว');
            reload();
          },
        ),
      ),
    );
  }

  Future<void> _viewDocument(Map<String, dynamic> row) async {
    final detail = _map(
      await api.get(
        '/api/company/document-control/documents/' + _text(row['id']),
      ),
    );
    final h = _map(detail['header']),
        files = _rows(detail['files']),
        revisions = _rows(detail['revisions']);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _popup(
        caption: _text(h['documentNo']) + ' > ดู',
        icon: Icons.visibility_outlined,
        saveText: 'ปิด',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _info('ชื่อเอกสาร', h['title']),
            _info('ประเภท', _className(h['documentClass'])),
            _info('Revision', h['revisionNo']),
            _info('สถานะ', h['status']),
            _info('รายละเอียดการเปลี่ยนแปลง', h['changeSummary']),
            const SizedBox(height: 12),
            Text('ไฟล์เอกสาร', style: documentControlUiTokens.sectionStyle),
            if (files.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('ยังไม่มีไฟล์'),
              ),
            ...files.map(
              (f) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file),
                title: Text(_text(f['fileName'])),
                subtitle: Text(
                  _text(f['fileRole']) +
                      ' · ' +
                      _text(f['sizeBytes']) +
                      ' bytes',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'เปิดดู',
                      onPressed: () => presentDocumentControlFile(
                        dialogContext,
                        path:
                            '/api/company/document-control/files/' +
                            _text(f['id']) +
                            '/preview',
                        fileName: _text(f['fileName']),
                        contentType: _text(f['contentType']),
                        download: false,
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                    IconButton(
                      tooltip: 'ดาวน์โหลด',
                      onPressed: () => presentDocumentControlFile(
                        dialogContext,
                        path:
                            '/api/company/document-control/files/' +
                            _text(f['id']) +
                            '/download',
                        fileName: _text(f['fileName']),
                        contentType: _text(f['contentType']),
                        download: true,
                      ),
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ประวัติ Revision',
              style: documentControlUiTokens.sectionStyle,
            ),
            ...revisions.map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(
                  'Rev. ' + _text(r['revisionNo']) + ' · ' + _text(r['status']),
                ),
                subtitle: Text(_text(r['changeSummary'])),
              ),
            ),
          ],
        ),
        onSave: () async {
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        },
        cancelVisible: false,
      ),
    );
  }

  Future<void> _submit(Map<String, dynamic> row) async {
    await api.post(
      '/api/company/document-control/documents/' + _text(row['id']) + '/submit',
    );
    if (mounted)
      showDocumentControlMessage(context, message: 'ส่งเอกสารเข้าตรวจทานแล้ว');
    reload();
  }

  Future<void> _workflow(Map<String, dynamic> row, String action) async {
    await api.post(
      '/api/company/document-control/documents/' +
          _text(row['id']) +
          '/workflow/' +
          action,
      body: {'note': null},
    );
    if (mounted)
      showDocumentControlMessage(
        context,
        message: action == 'review' ? 'ตรวจทานเอกสารแล้ว' : 'อนุมัติเอกสารแล้ว',
      );
    reload();
  }

  Future<void> _returnDocument(Map<String, dynamic> row) async {
    final note = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _popup(
        caption: 'ส่งกลับเอกสาร',
        icon: Icons.undo_outlined,
        content: _field(note, 'เหตุผลที่ส่งกลับ *', maxLines: 4),
        saveText: 'ส่งกลับ',
        onSave: () async {
          if (note.text.trim().isEmpty) return;
          await api.post(
            '/api/company/document-control/documents/' +
                _text(row['id']) +
                '/workflow/return',
            body: {'note': note.text},
          );
          if (dialogContext.mounted) Navigator.pop(dialogContext);
          reload();
        },
      ),
    );
  }

  Future<void> _acknowledge(Map<String, dynamic> row) async {
    await api.post(
      '/api/company/document-control/documents/' +
          _text(row['id']) +
          '/acknowledge',
    );
    if (mounted)
      showDocumentControlMessage(context, message: 'บันทึกการรับทราบแล้ว');
    reload();
  }

  Future<void> _deleteType(Map<String, dynamic> row) async {
    if (await _confirmDelete(_text(row['code']) + ' · ' + _text(row['name']))) {
      await api.delete(
        '/api/company/document-control/types/' + _text(row['id']),
      );
      if (mounted)
        showDocumentControlMessage(context, message: 'ลบประเภทเอกสารแล้ว');
      reload();
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> row) async {
    if (await _confirmDelete(
      _text(row['documentNo']) + ' · ' + _text(row['title']),
    )) {
      await api.delete(
        '/api/company/document-control/documents/' + _text(row['id']),
      );
      if (mounted) showDocumentControlMessage(context, message: 'ลบเอกสารแล้ว');
      reload();
    }
  }

  Future<bool> _confirmDelete(String name) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_outline, color: Colors.red, size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'ยืนยันการลบ',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.withValues(alpha: .08),
                    child: Text(name),
                  ),
                  const SizedBox(height: 10),
                  const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('ยกเลิก'),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ) ??
      false;

  Widget _popup({
    required String caption,
    required IconData icon,
    required Widget content,
    required Future<void> Function() onSave,
    String saveText = 'บันทึก',
    bool cancelVisible = true,
  }) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: documentControlUiTokens.primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: documentControlUiTokens.borderColor,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: content,
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: documentControlUiTokens.borderColor,
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (cancelVisible)
                  SizedBox(
                    height: 48,
                    width: 84,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                if (cancelVisible) const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  width: 100,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: onSave,
                    icon: Icon(
                      cancelVisible ? Icons.save_outlined : Icons.close,
                    ),
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

  Widget _listWithPagination(Widget body, int total) => Column(
    children: [
      Expanded(child: body),
      SizedBox(height: documentControlUiTokens.sectionSpacing),
      _pager(1, total, remote: false),
    ],
  );

  Widget _pager(int pages, int total, {bool remote = true}) {
    final currentPage = remote ? page : 1;
    return LaooPaginationCard(
      tokens: documentControlUiTokens,
      page: currentPage,
      pageCount: pages,
      pageSize: remote ? 10 : (total == 0 ? 10 : total),
      total: total,
      onPrevious: remote && currentPage > 1
          ? () {
              page--;
              reload();
            }
          : null,
      onNext: remote && currentPage < pages
          ? () {
              page++;
              reload();
            }
          : null,
    );
  }

  Widget _statusChip(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: documentControlUiTokens.primaryColor.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      _statusName(value),
      style: TextStyle(
        color: documentControlUiTokens.primaryColor,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    style: documentControlUiTokens.inputStyle,
    decoration: _input(label),
  );
  InputDecoration _input(String label, [IconData? icon]) => InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon),
    filled: false,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: documentControlUiTokens.borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: documentControlUiTokens.borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: documentControlUiTokens.primaryColor),
    ),
  );
  Widget _info(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(_text(value))),
      ],
    ),
  );
  List<DropdownMenuItem<int>> _userItems(List<Map<String, dynamic>> users) {
    final seen = <int>{};
    return users
        .where((x) => x['id'] is num && seen.add((x['id'] as num).toInt()))
        .map(
          (x) => DropdownMenuItem<int>(
            value: (x['id'] as num).toInt(),
            child: Text(_text(x['name']), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
  }

  static Map<String, dynamic> _map(dynamic value) => value is Map
      ? value.map((k, v) => MapEntry(k.toString(), v))
      : <String, dynamic>{};
  static List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((x) => x.map((k, v) => MapEntry(k.toString(), v)))
            .toList()
      : <Map<String, dynamic>>[];
  static String _text(Object? value) => value?.toString() ?? '';
  static String _className(Object? value) =>
      value == 'CONTROLLED' ? 'เอกสารควบคุม' : 'เอกสารทั่วไป';
  static String _statusName(String value) =>
      const {
        'DRAFT': 'ร่าง',
        'IN_REVIEW': 'รอตรวจทาน',
        'IN_APPROVAL': 'รออนุมัติ',
        'APPROVED': 'อนุมัติแล้ว',
        'EFFECTIVE': 'มีผลบังคับใช้',
        'PUBLISHED': 'เผยแพร่',
        'OBSOLETE': 'ยกเลิกใช้',
        'RETURNED': 'ส่งกลับ',
        'REVIEW': 'ตรวจทาน',
        'APPROVE': 'อนุมัติ',
      }[value] ??
      value;
}
