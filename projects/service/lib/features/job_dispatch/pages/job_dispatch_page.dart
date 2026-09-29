import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../service_request/data/service_request_api.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';

class JobDispatchPage extends StatefulWidget {
  const JobDispatchPage({super.key, this.api});
  final ServiceRequestApi? api;

  @override
  State<JobDispatchPage> createState() => _JobDispatchPageState();
}

class _JobDispatchPageState extends State<JobDispatchPage> {
  late final ServiceRequestApi _api = widget.api ?? ServiceRequestApi();
  final _search = TextEditingController();
  String _caption = 'กระดานจ่ายงานช่าง';
  bool _canDispatch = false;
  bool _loading = true;
  int _page = 1;
  int _total = 0;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadActions();
    _loadCaption();
  }

  Future<void> _loadActions() async {
    try {
      final actions = await _api.actions();
      if (mounted) {
        setState(() => _canDispatch = actions['dispatchEdit'] == true);
      }
    } catch (_) {
      // Keep mutation actions hidden when permissions cannot be loaded.
    }
  }

  Future<void> _loadCaption() async {
    try {
      final caption = await NavigationMenuRepository().resolveMenuName(
        menuCode: '17001',
        routeName: 'jobDispatch',
        fallback: _caption,
      );
      if (mounted) setState(() => _caption = caption);
    } catch (_) {}
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final value = await _api.list(
        search: _search.text.trim(),
        status: 'NEW',
        page: _page,
        menuCode: '17001',
      );
      if (!mounted) return;
      setState(() {
        _items = ((value['items'] as List?) ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _total = (value['total'] as num?)?.toInt() ?? 0;
      });
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dispatch(Map<String, dynamic> row) async {
    if (!_canDispatch) return;
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = await _api.detail(id, menuCode: '17001');
      final attachments = await _api.attachments(id, menuCode: '17001');
      final technicians = await _api.technicians();
      if (!mounted) return;
      final selected = await showDialog<int>(
        context: context,
        builder: (_) => _DispatchDialog(
          api: _api,
          caption: _caption,
          data: detail,
          attachments: attachments,
          technicians: technicians,
        ),
      );
      if (selected != null && mounted) {
        showTimedSnackBar(context, message: 'มอบหมายงานเรียบร้อยแล้ว');
        await _load();
      }
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  void _message(Object error) {
    final text = error is ApiException
        ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง'}'
        : 'ไม่สามารถโหลดรายการจัดส่งงานได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: text, error: true);
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'jobDispatch',
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
              child: Row(
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _caption,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LaooLayout.listSectionSpacing),
          _toolbar(),
          const SizedBox(height: LaooLayout.listSectionSpacing),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(child: Text('ไม่มีงานใหม่ที่รอจัดส่ง'))
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 900
                        ? ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, index) => _JobCard(
                              row: _items[index],
                              onDispatch: _canDispatch
                                  ? () => _dispatch(_items[index])
                                  : null,
                            ),
                          )
                        : _JobTable(
                            items: _items,
                            onDispatch: _canDispatch ? _dispatch : null,
                          ),
                  ),
          ),
          const SizedBox(height: LaooLayout.listSectionSpacing),
          Card(
            margin: EdgeInsets.zero,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'หน้าก่อน',
                    onPressed: _loading || _page <= 1
                        ? null
                        : () {
                            _page--;
                            _load();
                          },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('หน้า $_page · $_total รายการ'),
                  IconButton(
                    tooltip: 'หน้าถัดไป',
                    onPressed: _loading || _page * 20 >= _total
                        ? null
                        : () {
                            _page++;
                            _load();
                          },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _toolbar() => Card(
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
              onSubmitted: (_) {
                _page = 1;
                _load();
              },
              decoration: const InputDecoration(
                labelText: 'ค้นหาเลขที่ ผู้แจ้ง หรือหัวข้อ',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _loading
                ? null
                : () {
                    _page = 1;
                    _load();
                  },
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
          Text('งานใหม่ $_total รายการ'),
        ],
      ),
    ),
  );
}

class _JobTable extends StatelessWidget {
  const _JobTable({required this.items, required this.onDispatch});
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>>? onDispatch;

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
          DataColumn(label: Text('หัวข้อ')),
          DataColumn(label: Text('สถานะ')),
          DataColumn(label: Text('Action')),
        ],
        rows: [
          for (final row in items)
            DataRow(
              cells: [
                DataCell(Text(row['requestNo']?.toString() ?? '-')),
                DataCell(Text(row['requesterName']?.toString() ?? '-')),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(row['locationSnapshot']?.toString() ?? '-'),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(row['subject']?.toString() ?? '-'),
                  ),
                ),
                const DataCell(Text('งานใหม่')),
                DataCell(
                  onDispatch == null
                      ? const SizedBox.shrink()
                      : FilledButton.icon(
                          onPressed: () => onDispatch!(row),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('มอบหมาย'),
                        ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.row, required this.onDispatch});
  final Map<String, dynamic> row;
  final VoidCallback? onDispatch;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row['requestNo']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Text('งานใหม่'),
            ],
          ),
          const Divider(),
          Text('ผู้แจ้ง: ${row['requesterName'] ?? '-'}'),
          Text('สถานที่: ${row['locationSnapshot'] ?? '-'}', softWrap: true),
          Text('หัวข้อ: ${row['subject'] ?? '-'}', softWrap: true),
          const SizedBox(height: 10),
          if (onDispatch != null)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onDispatch,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('มอบหมายช่าง'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _DispatchDialog extends StatefulWidget {
  const _DispatchDialog({
    required this.api,
    required this.caption,
    required this.data,
    required this.attachments,
    required this.technicians,
  });
  final ServiceRequestApi api;
  final String caption;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> technicians;

  @override
  State<_DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<_DispatchDialog> {
  int? _employeeId;
  bool _saving = false;

  Future<void> _save() async {
    if (_employeeId == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.api.receive(
        (_data['requestId'] as num).toInt(),
        _employeeId!,
      );
      if (mounted) Navigator.pop(context, _employeeId);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? '${error.message}\n${error.description ?? 'กรุณาโหลดข้อมูลใหม่'}'
            : error.toString();
        showTimedSnackBar(context, message: message, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> get _data => widget.data;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    title: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: LaooLayout.popupHeaderMinHeight,
          ),
          child: Row(
            children: [
              Icon(
                Icons.engineering_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.caption} > มอบหมายช่าง',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: LaooColors.border, height: 1),
      ],
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _line('เลขที่', _data['requestNo']),
            _line('ผู้แจ้ง', _data['requesterName']),
            _line('สถานที่', _data['locationSnapshot']),
            _line('อุปกรณ์', _data['equipmentName']),
            _line('หัวข้อ', _data['subject']),
            _line('รายละเอียด', _data['detail']),
            if (widget.attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'รูปภาพแนบ ${widget.attachments.length} ไฟล์',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in widget.attachments)
                    _AttachmentPreview(
                      api: widget.api,
                      requestId: (_data['requestId'] as num).toInt(),
                      item: item,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'ช่างผู้รับผิดชอบ *',
              ),
              initialValue: _employeeId,
              items: [
                for (final item in widget.technicians)
                  DropdownMenuItem(
                    value: (item['employeeId'] as num).toInt(),
                    child: Text(
                      '${item['fullName']} (${item['employeeCode']})',
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _employeeId = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(color: LaooColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                  ),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton.icon(
                  onPressed: _employeeId == null || _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                  ),
                  icon: const Icon(Icons.send_outlined),
                  label: Text(_saving ? 'กำลังบันทึก...' : 'มอบหมายงาน'),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  Widget _line(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: LaooLayout.popupFieldSpacing),
    child: Text(
      '$label: ${value?.toString().isNotEmpty == true ? value : '-'}',
      softWrap: true,
    ),
  );
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.api,
    required this.requestId,
    required this.item,
  });
  final ServiceRequestApi api;
  final int requestId;
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<int>>(
    future: api.downloadAttachment(
      requestId,
      (item['attachmentId'] as num).toInt(),
      menuCode: '17001',
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
