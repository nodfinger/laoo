import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
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
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(Object error, {bool errorState = true}) {
    final text = error is ApiException
        ? error.message +
              '\n' +
              (error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง')
        : 'ไม่สามารถดำเนินการได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: text, error: errorState);
  }

  Future<void> _create() async {
    final lookup = await _api.lookup();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestDialog(
        api: _api,
        lookup: lookup,
        selfService: widget.selfService,
      ),
    );
    if (saved == true && mounted) {
      if (!widget.selfService) {
        _page = 1;
        await _load();
      }
      showTimedSnackBar(context, message: 'บันทึกใบแจ้งซ่อมเรียบร้อยแล้ว');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selfService) {
      return Scaffold(
        appBar: AppBar(title: const Text('แจ้งซ่อมด้วยตนเอง')),
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
      pageTitle: 'รับแจ้งซ่อม',
      activeMenu: 'cmTickets',
      menuScope: WorkspaceMenuScope.company,
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              children: const [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build_outlined),
                    SizedBox(width: 10),
                    Text(
                      'รับแจ้งซ่อม',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มใบแจ้งซ่อม'),
              ),
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
                      hint: 'ค้นหาเลขที่ ผู้แจ้ง หัวข้อ หรือสถานที่',
                      icon: Icons.search,
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _input(label: 'สถานะ'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                      DropdownMenuItem(value: 'NEW', child: Text('สร้างใหม่')),
                      DropdownMenuItem(
                        value: 'RECEIVED',
                        child: Text('รับเรื่องแล้ว'),
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
                    onChanged: (value) {
                      _status = value ?? '';
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
                        DataCell(Text(row['requestNo']?.toString() ?? '-')),
                        DataCell(Text(row['requesterName']?.toString() ?? '-')),
                        DataCell(
                          Text(row['locationSnapshot']?.toString() ?? '-'),
                        ),
                        DataCell(Text(row['subject']?.toString() ?? '-')),
                        DataCell(
                          Text(
                            _statusText(row['statusCode']?.toString() ?? ''),
                          ),
                        ),
                        DataCell(Text(row['requestDate']?.toString() ?? '-')),
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
    final range = total == 0
        ? '0-0 จาก 0'
        : (_page == 1 ? '1-' : (((_page - 1) * 20) + 1).toString() + '-') +
              end.toString() +
              ' จาก ' +
              total.toString();
    return SizedBox(
      height: LaooLayout.paginationCardHeight,
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
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
          FilledButton(onPressed: null, child: Text(_page.toString())),
          OutlinedButton(
            onPressed: _page < pages
                ? () {
                    _page++;
                    _load();
                  }
                : null,
            child: const Text('>'),
          ),
          const SizedBox(width: 6),
          Text(range),
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
        'NEW': 'สร้างใหม่',
        'RECEIVED': 'รับเรื่องแล้ว',
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
  Map<String, dynamic>? _equipment;
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.api.create(
        selfService: widget.selfService,
        requesterId: (_requester?['id'] as num?)?.toInt(),
        requesterType: _requester?['requesterType']?.toString(),
        equipmentItemId: (_equipment?['itemID'] as num?)?.toInt(),
        subject: _subject.text.trim(),
        detail: _detail.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final text = error is ApiException
            ? error.message +
                  '\n' +
                  (error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง')
            : 'บันทึกไม่สำเร็จ\nกรุณาลองใหม่อีกครั้ง';
        showTimedSnackBar(context, message: text, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requesters = _maps(widget.lookup?['requesters']);
    final equipment = _maps(widget.lookup?['equipment']);
    final byKey = {
      for (final item in requesters)
        item['requesterType'].toString() + ':' + item['id'].toString(): item,
    };
    final dialogWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      280.0,
      520.0,
    );
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      title: Row(
        children: [
          const Icon(Icons.build_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.selfService ? 'แจ้งซ่อมด้วยตนเอง' : 'เพิ่มใบแจ้งซ่อม',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                if (!widget.selfService)
                  DropdownButtonFormField<String>(
                    decoration: _input(label: 'ผู้แจ้ง *'),
                    items: [
                      for (final entry in byKey.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            _requesterLabel(entry.value),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (key) => setState(
                      () => _requester = key == null ? null : byKey[key],
                    ),
                    validator: (_) =>
                        _requester == null ? 'กรุณาเลือกผู้แจ้ง' : null,
                  )
                else
                  _infoBox(
                    'ผู้แจ้ง: ผู้ใช้ปัจจุบัน\nสถานที่: ตามสิทธิ์ของผู้ใช้',
                  ),
                if (_requester != null) ...[
                  const SizedBox(height: 12),
                  _infoBox(
                    'สถานที่: ' +
                        (_requester!['locationSnapshot']?.toString() ?? '-'),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _equipment == null
                      ? null
                      : _equipment!['itemID'].toString(),
                  decoration: _input(label: 'อุปกรณ์ที่แจ้งซ่อม *'),
                  items: [
                    for (final item in equipment)
                      DropdownMenuItem(
                        value: item['itemID'].toString(),
                        child: Text(
                          item['itemCode'].toString() +
                              ' | ' +
                              item['itemName'].toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _equipment = value == null
                        ? null
                        : equipment.firstWhere(
                            (item) => item['itemID'].toString() == value,
                          ),
                  ),
                  validator: (_) => _equipment == null
                      ? 'กรุณาเลือกอุปกรณ์ที่แจ้งซ่อม'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subject,
                  decoration: _input(label: 'หัวข้อ *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาระบุหัวข้อ'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _detail,
                  minLines: 4,
                  maxLines: 7,
                  decoration: _input(label: 'รายละเอียด *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาระบุรายละเอียด'
                      : null,
                ),
                const SizedBox(height: 14),
                const Divider(),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'กำลังบันทึก' : 'บันทึก'),
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

  List<Map<String, dynamic>> _maps(Object? value) =>
      ((value as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Widget _infoBox(String text) => Container(
    padding: const EdgeInsets.all(10),
    color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
    child: Text(text, softWrap: true),
  );

  String _requesterLabel(Map<String, dynamic> value) {
    final prefix = value['requesterType']?.toString() == 'SERVICE_CUSTOMER'
        ? 'ผู้ใช้บริการ Walk-in: '
        : '';
    return prefix + (value['name']?.toString() ?? '-');
  }

  InputDecoration _input({String? label}) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
  );
}
