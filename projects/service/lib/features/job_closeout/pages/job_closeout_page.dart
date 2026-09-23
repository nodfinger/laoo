import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../service_request/data/service_request_api.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';

/// Menu 17003 (ScreenType 2): records the repair result and closes a job.
class JobCloseoutPage extends StatefulWidget {
  const JobCloseoutPage({super.key});

  @override
  State<JobCloseoutPage> createState() => _JobCloseoutPageState();
}

class _JobCloseoutPageState extends State<JobCloseoutPage> {
  final _api = ServiceRequestApi();
  final _search = TextEditingController();
  bool _loading = true;
  bool _canEdit = false;
  int _page = 1;
  int _total = 0;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _api.list(
          search: _search.text.trim(),
          status: 'IN_PROGRESS',
          page: _page,
        ),
        _api.actions(),
      ]);
      if (!mounted) return;
      final list = Map<String, dynamic>.from(values.first as Map);
      final actions = Map<String, dynamic>.from(values.last as Map);
      setState(() {
        _items = ((list['items'] as List?) ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _total = (list['total'] as num?)?.toInt() ?? 0;
        _canEdit = actions['edit'] == true;
      });
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final requestId = (row['requestId'] as num?)?.toInt();
    if (requestId == null) return;
    try {
      final values = await Future.wait([
        _api.detail(requestId),
        _api.attachments(requestId),
      ]);
      if (!mounted) return;
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => _CloseoutDialog(
          api: _api,
          data: Map<String, dynamic>.from(values.first as Map),
          attachments: List<Map<String, dynamic>>.from(values.last as List),
          canEdit: _canEdit,
        ),
      );
      if (changed == true && mounted) await _load();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  void _message(Object error) {
    final message = error is ApiException
        ? '${error.message}\n${error.description ?? 'กรุณาลองใหม่อีกครั้ง'}'
        : 'ไม่สามารถโหลดข้อมูลใบงานได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: message, error: true);
  }

  Future<void> _searchNow() async {
    _page = 1;
    await _load();
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'บันทึกปิดงานและตรวจรับ',
    activeMenu: 'jobCloseout',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) => _searchNow(),
                      decoration: const InputDecoration(
                        labelText: 'ค้นหาเลขที่ ผู้แจ้ง หัวข้อ หรือช่าง',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _searchNow,
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('ไม่พบใบงานที่กำลังดำเนินการ'))
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 900
                        ? ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, index) => _CloseoutCard(
                              row: _items[index],
                              canEdit: _canEdit,
                              onOpen: () => _open(_items[index]),
                            ),
                          )
                        : _CloseoutTable(
                            items: _items,
                            canEdit: _canEdit,
                            onOpen: _open,
                          ),
                  ),
          ),
          if (!_loading && _total > 20)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _page > 1
                      ? () {
                          _page--;
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('หน้า $_page'),
                IconButton(
                  onPressed: _page * 20 < _total
                      ? () {
                          _page++;
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _CloseoutTable extends StatelessWidget {
  const _CloseoutTable({
    required this.items,
    required this.canEdit,
    required this.onOpen,
  });
  final List<Map<String, dynamic>> items;
  final bool canEdit;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('เลขที่ใบแจ้งซ่อม')),
          DataColumn(label: Text('ผู้แจ้ง')),
          DataColumn(label: Text('สถานที่')),
          DataColumn(label: Text('อุปกรณ์')),
          DataColumn(label: Text('หัวข้อ')),
          DataColumn(label: Text('ช่างผู้รับผิดชอบ')),
          DataColumn(label: Text('วันที่เริ่มงาน')),
          DataColumn(label: Text('ระยะเวลาดำเนินการ')),
          DataColumn(label: Text('สถานะ')),
          DataColumn(label: Text('Action')),
        ],
        rows: [
          for (final row in items)
            DataRow(
              cells: [
                DataCell(Text(_text(row['requestNo']))),
                DataCell(Text(_text(row['requesterName']))),
                DataCell(
                  SizedBox(
                    width: 160,
                    child: Text(_text(row['locationSnapshot'])),
                  ),
                ),
                DataCell(Text(_text(row['equipmentName']))),
                DataCell(
                  SizedBox(width: 160, child: Text(_text(row['subject']))),
                ),
                DataCell(Text(_text(row['assignedEmployeeName']))),
                DataCell(Text(_date(row['startedDate']))),
                DataCell(Text(_duration(row['startedDate']))),
                const DataCell(Text('กำลังดำเนินการ')),
                DataCell(
                  FilledButton(
                    onPressed: () => onOpen(row),
                    child: Text(canEdit ? 'บันทึกผล/ปิดงาน' : 'รายละเอียด'),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _CloseoutCard extends StatelessWidget {
  const _CloseoutCard({
    required this.row,
    required this.canEdit,
    required this.onOpen,
  });
  final Map<String, dynamic> row;
  final bool canEdit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _text(row['requestNo']),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _info('ผู้แจ้ง', row['requesterName']),
          _info('สถานที่', row['locationSnapshot']),
          _info('อุปกรณ์', row['equipmentName']),
          _info('หัวข้อ', row['subject']),
          _info('ช่าง', row['assignedEmployeeName']),
          _info('เริ่มงาน', _date(row['startedDate'])),
          _info('ระยะเวลา', _duration(row['startedDate'])),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onOpen,
              child: Text(canEdit ? 'บันทึกผล/ปิดงาน' : 'รายละเอียด'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _info(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text('$label: ${_text(value)}', softWrap: true),
  );
}

class _CloseoutDialog extends StatefulWidget {
  const _CloseoutDialog({
    required this.api,
    required this.data,
    required this.attachments,
    required this.canEdit,
  });
  final ServiceRequestApi api;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> attachments;
  final bool canEdit;

  @override
  State<_CloseoutDialog> createState() => _CloseoutDialogState();
}

class _CloseoutDialogState extends State<_CloseoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _resolution = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _resolution.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.complete(
        (widget.data['requestId'] as num).toInt(),
        _resolution.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? '${error.message}\n${error.description ?? 'กรุณาโหลดข้อมูลใหม่แล้วลองอีกครั้ง'}'
          : 'ไม่สามารถปิดงานได้\nกรุณาโหลดข้อมูลใหม่แล้วลองอีกครั้ง';
      showTimedSnackBar(context, message: message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('บันทึกปิดงาน: ${_text(widget.data['requestNo'])}'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _line('ผู้แจ้ง', widget.data['requesterName']),
              _line('สถานที่', widget.data['locationSnapshot']),
              _line('อุปกรณ์', widget.data['equipmentName']),
              _line('หัวข้อ', widget.data['subject']),
              _line('รายละเอียดแจ้งซ่อม', widget.data['detail']),
              _line('ช่างผู้รับผิดชอบ', widget.data['assignedEmployeeName']),
              _line('วันที่เริ่มงาน', _date(widget.data['startedDate'])),
              if (widget.attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'รูปภาพแนบ ${widget.attachments.length} ไฟล์',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final attachment in widget.attachments)
                      _AttachmentPreview(
                        api: widget.api,
                        requestId: (widget.data['requestId'] as num).toInt(),
                        attachment: attachment,
                      ),
                  ],
                ),
              ],
              if (widget.canEdit) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _resolution,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'ผลการซ่อม *',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาระบุผลการซ่อม'
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: Text(widget.canEdit ? 'ยกเลิก' : 'ปิด'),
      ),
      if (widget.canEdit)
        FilledButton.icon(
          onPressed: _busy ? null : _complete,
          icon: const Icon(Icons.task_alt),
          label: const Text('บันทึกปิดงาน'),
        ),
    ],
  );

  Widget _line(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text('$label: ${_text(value)}', softWrap: true),
  );
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.api,
    required this.requestId,
    required this.attachment,
  });
  final ServiceRequestApi api;
  final int requestId;
  final Map<String, dynamic> attachment;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<int>>(
    future: api.downloadAttachment(
      requestId,
      (attachment['attachmentId'] as num).toInt(),
    ),
    builder: (context, snapshot) => SizedBox(
      width: 76,
      height: 76,
      child: snapshot.hasData
          ? Image.memory(Uint8List.fromList(snapshot.data!), fit: BoxFit.cover)
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );
}

String _text(Object? value) =>
    value?.toString().trim().isNotEmpty == true ? value.toString() : '-';

String _date(Object? value) => value?.toString().split('T').first ?? '-';

String _duration(Object? value) {
  final started = DateTime.tryParse(value?.toString() ?? '');
  if (started == null) return '-';
  final duration = DateTime.now().difference(started);
  if (duration.isNegative) return '-';
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  if (days > 0) return '$days วัน $hours ชม.';
  if (hours > 0) return '$hours ชม. $minutes นาที';
  return '$minutes นาที';
}
