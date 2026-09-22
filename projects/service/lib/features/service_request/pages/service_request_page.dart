import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_request_api.dart';

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({super.key, this.selfService = false});
  final bool selfService;
  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  final _api = ServiceRequestApi();
  final _search = TextEditingController();
  String _status = '';
  int _page = 1;
  bool _loading = true;
  Map<String, dynamic> _data = const {'items': <dynamic>[], 'total': 0};

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
      final value = widget.selfService
          ? <String, dynamic>{}
          : await _api.list(
              search: _search.text.trim(),
              status: _status,
              page: _page,
            );
      if (mounted) setState(() => _data = value);
    } catch (error) {
      if (mounted) _error(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (widget.selfService) {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _RequestDialog(api: _api, selfService: true),
      );
      if (saved == true && mounted)
        showTimedSnackBar(context, message: 'ส่งคำขอแจ้งซ่อมสำเร็จ');
      return;
    }
    final lookup = await _api.lookup();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestDialog(api: _api, lookup: lookup),
    );
    if (saved == true) {
      _page = 1;
      await _load();
      if (mounted) showTimedSnackBar(context, message: 'บันทึกแจ้งซ่อมสำเร็จ');
    }
  }

  void _error(Object error) {
    final message = error is ApiException
        ? error.message +
              '\nรายละเอียดเพิ่มเติม: ' +
              (error.description ?? 'กรุณาตรวจสอบข้อมูล')
        : 'ดำเนินการไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาลองใหม่';
    showTimedSnackBar(context, message: message, error: true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selfService) {
      return Scaffold(
        appBar: AppBar(title: const Text('แจ้งซ่อม / ขอใช้บริการ')),
        body: Center(
          child: FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.build_outlined),
            label: const Text('แจ้งซ่อม'),
          ),
        ),
      );
    }
    final items = List<Map<String, dynamic>>.from(
      (_data['items'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final total = (_data['total'] as num?)?.toInt() ?? 0;
    return SupportWorkspaceShell(
      pageTitle: 'รายการแจ้งซ่อมทั้งหมด',
      activeMenu: 'cmTickets',
      menuScope: WorkspaceMenuScope.company,
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.build_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'รายการแจ้งซ่อมทั้งหมด',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มแจ้งซ่อม'),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) {
                      _page = 1;
                      _load();
                    },
                    decoration: _input(
                      hint: 'ค้นหาเลขที่ ผู้แจ้ง หรือหัวข้อ',
                      icon: Icons.search,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _input(label: 'สถานะ'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                      DropdownMenuItem(value: 'NEW', child: Text('ใหม่')),
                      DropdownMenuItem(
                        value: 'RECEIVED',
                        child: Text('รับเรื่อง'),
                      ),
                      DropdownMenuItem(
                        value: 'IN_PROGRESS',
                        child: Text('กำลังดำเนินการ'),
                      ),
                      DropdownMenuItem(
                        value: 'COMPLETED',
                        child: Text('เสร็จสิ้น'),
                      ),
                      DropdownMenuItem(
                        value: 'CANCELLED',
                        child: Text('ยกเลิก'),
                      ),
                    ],
                    onChanged: (v) {
                      _status = v ?? '';
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    _search.clear();
                    _status = '';
                    _page = 1;
                    _load();
                  },
                  child: const Text('ล้าง Filter'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('เลขที่')),
                  DataColumn(label: Text('ผู้แจ้ง')),
                  DataColumn(label: Text('สถานที่')),
                  DataColumn(label: Text('หัวข้อ')),
                  DataColumn(label: Text('สถานะ')),
                  DataColumn(label: Text('วันที่')),
                ],
                rows: [
                  for (final row in items)
                    DataRow(
                      cells: [
                        DataCell(Text((row['requestNo'] ?? '-').toString())),
                        DataCell(
                          Text((row['requesterName'] ?? '-').toString()),
                        ),
                        DataCell(
                          Text((row['locationSnapshot'] ?? '-').toString()),
                        ),
                        DataCell(Text((row['subject'] ?? '-').toString())),
                        DataCell(
                          Text(
                            _statusText((row['statusCode'] ?? '').toString()),
                          ),
                        ),
                        DataCell(Text((row['requestDate'] ?? '-').toString())),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _pagination(total),
          ],
        ),
      ),
    );
  }

  Widget _pagination(int total) {
    final pages = total == 0 ? 1 : (total / 20).ceil();
    final end = (_page * 20).clamp(0, total);
    return SizedBox(
      height: LaooLayout.paginationCardHeight,
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _page > 1
                ? () {
                    _page--;
                    _load();
                  }
                : null,
            child: const Text('<'),
          ),
          const SizedBox(width: 6),
          FilledButton(onPressed: null, child: Text(_page.toString())),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: _page < pages
                ? () {
                    _page++;
                    _load();
                  }
                : null,
            child: const Text('>'),
          ),
          const SizedBox(width: 12),
          Text(
            total == 0
                ? '0-0 จาก 0'
                : (_page == 1
                          ? '1-'
                          : (((_page - 1) * 20) + 1).toString() + '-') +
                      end.toString() +
                      ' จาก ' +
                      total.toString(),
          ),
        ],
      ),
    );
  }

  InputDecoration _input({String? label, String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      );
  String _statusText(String code) =>
      const {
        'NEW': 'ใหม่',
        'RECEIVED': 'รับเรื่อง',
        'IN_PROGRESS': 'กำลังดำเนินการ',
        'COMPLETED': 'เสร็จสิ้น',
        'CANCELLED': 'ยกเลิก',
      }[code] ??
      code;
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({
    required this.api,
    this.lookup,
    this.selfService = false,
  });
  final ServiceRequestApi api;
  final Map<String, dynamic>? lookup;
  final bool selfService;
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _detail = TextEditingController();
  Map<String, dynamic>? _requester;
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    if (!widget.selfService && _requester == null) {
      showTimedSnackBar(
        context,
        message:
            'กรุณาเลือกผู้แจ้ง\nรายละเอียดเพิ่มเติม: เลือกผู้พักอาศัย ผู้ติดต่อ หรือผู้ใช้บริการ',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.create(
        selfService: widget.selfService,
        requesterId: (_requester?['id'] as num?)?.toInt(),
        requesterType: _requester?['requesterType']?.toString(),
        subject: _subject.text.trim(),
        detail: _detail.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? error.message +
                    '\nรายละเอียดเพิ่มเติม: ' +
                    (error.description ?? 'กรุณาตรวจสอบข้อมูล')
              : 'บันทึกไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาลองใหม่',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requesters = List<Map<String, dynamic>>.from(
      ((widget.lookup?['requesters'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final keys = {
      for (final r in requesters)
        r['requesterType'].toString() + ':' + r['id'].toString(): r,
    };
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      title: Row(
        children: [
          const Icon(Icons.build_outlined),
          const SizedBox(width: 10),
          Text(
            widget.selfService
                ? 'แจ้งซ่อม / ขอใช้บริการ'
                : 'รายการแจ้งซ่อม > เพิ่ม',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                if (!widget.selfService) ...[
                  DropdownButtonFormField<String>(
                    decoration: _input('ผู้แจ้ง *'),
                    items: [
                      for (final entry in keys.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value['name'].toString()),
                        ),
                    ],
                    onChanged: (key) => setState(
                      () => _requester = key == null ? null : keys[key],
                    ),
                    validator: (_) =>
                        _requester == null ? 'กรุณาเลือกผู้แจ้ง' : null,
                  ),
                  if (_requester != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .08),
                      child: Text(
                        'สถานที่: ' +
                            ((_requester!['locationSnapshot'] ??
                                    'ผู้ใช้บริการภายนอก')
                                .toString()),
                      ),
                    ),
                  ],
                ] else
                  Container(
                    padding: const EdgeInsets.all(10),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .08),
                    child: const Text(
                      'ผู้แจ้ง: ผู้ใช้ปัจจุบัน\nสถานที่: ระบบตรวจสอบจากข้อมูลผู้ใช้',
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subject,
                  decoration: _input(label: 'หัวข้อแจ้งซ่อม *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'กรุณาระบุหัวข้อแจ้งซ่อม'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _detail,
                  minLines: 4,
                  maxLines: 7,
                  decoration: _input(label: 'รายละเอียด *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'กรุณาระบุรายละเอียด'
                      : null,
                ),
                const SizedBox(height: 14),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('บันทึก'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
  );
}
