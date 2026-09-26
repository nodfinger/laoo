import 'package:flutter/material.dart';

import '../../core/api/visitor_api_client.dart';
import 'visitor_feature_host.dart';

const _appointmentMenu = '32001';
const _approvalMenu = '32002';

class VisitorAppointmentsPage extends StatefulWidget {
  const VisitorAppointmentsPage({super.key});
  @override
  State<VisitorAppointmentsPage> createState() =>
      _VisitorAppointmentsPageState();
}

class _VisitorAppointmentsPageState extends State<VisitorAppointmentsPage> {
  final _api = VisitorApiClient();
  final _search = TextEditingController();
  List<dynamic> _items = const [];
  Map<String, dynamic> _actions = const {};
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _total = 0;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        _api.get(
          '/api/visitor/appointments',
          query: {
            'search': _search.text.trim(),
            'page': '$_page',
            'pageSize': '$_pageSize',
          },
        ),
        _api.get('/api/visitor/appointments/actions'),
      ]);
      if (!mounted) return;
      setState(() {
        final result = Map<String, dynamic>.from(values[0] as Map);
        _items = result['items'] as List? ?? const [];
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _actions = Map<String, dynamic>.from(values[1] as Map);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _can(String action) => _actions[action] == true;

  Future<void> _editor([Map<dynamic, dynamic>? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AppointmentEditor(api: _api, item: item),
    );
    if (saved == true) await _load();
  }

  Future<void> _cancel(Map<dynamic, dynamic> item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _CancelDialog(name: '${item['visitorName'] ?? '-'}'),
    );
    if (result != true) return;
    try {
      await _api.delete(
        '/api/visitor/appointments/${item['visitorAppointmentId']}',
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => buildVisitorWorkspaceShell(
    pageTitle: 'นัดหมายล่วงหน้า',
    activeMenu: _appointmentMenu,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'นัดหมายล่วงหน้า',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      if (_can('create'))
                        FilledButton.icon(
                          onPressed: _editor,
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่มนัดหมาย'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final input = TextField(
                        controller: _search,
                        onSubmitted: (_) => _load(resetPage: true),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'ค้นหาชื่อหรือเบอร์โทร',
                        ),
                      );
                      final button = FilledButton.icon(
                        onPressed: () => _load(resetPage: true),
                        icon: const Icon(Icons.search),
                        label: const Text('ค้นหา'),
                      );
                      return box.maxWidth < 560
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                input,
                                const SizedBox(height: 8),
                                button,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: input),
                                const SizedBox(width: 8),
                                button,
                              ],
                            );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                _ErrorCard(_error!)
              else if (_items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: Text('ไม่พบรายการนัดหมาย')),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: _items.map((raw) {
                      final item = Map<dynamic, dynamic>.from(raw as Map);
                      final pending = item['statusCode'] == 'PENDING';
                      return _AppointmentTile(
                        item: item,
                        canEdit: pending && _can('edit'),
                        canDelete: pending && _can('delete'),
                        onEdit: () => _editor(item),
                        onCancel: () => _cancel(item),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 12),
              _pagination(),
            ],
          ),
  );

  Widget _pagination() {
    final pageCount = _total == 0 ? 1 : (_total / _pageSize).ceil();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          children: [
            Text('แสดง ${_items.length} รายการจากทั้งหมด $_total'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'หน้าก่อนหน้า',
                  onPressed: _loading || _page <= 1
                      ? null
                      : () {
                          _page--;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('$_page / $pageCount'),
                IconButton(
                  tooltip: 'หน้าถัดไป',
                  onPressed: _loading || _page >= pageCount
                      ? null
                      : () {
                          _page++;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.item,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onCancel,
  });
  final Map<dynamic, dynamic> item;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final status = '${item['statusCode'] ?? '-'}';
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${item['visitorName'] ?? '-'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('วันนัด: ${_dateTime(item['appointmentDate'])}'),
        if ('${item['phone'] ?? ''}'.isNotEmpty) Text('โทร: ${item['phone']}'),
        if ('${item['visitPurpose'] ?? ''}'.isNotEmpty)
          Text('วัตถุประสงค์: ${item['visitPurpose']}'),
        if ('${item['approvalNote'] ?? ''}'.isNotEmpty)
          Text('หมายเหตุอนุมัติ: ${item['approvalNote']}'),
      ],
    );
    final actions = Wrap(
      spacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(label: Text(_statusLabel(status))),
        if (canEdit)
          IconButton(
            onPressed: onEdit,
            tooltip: 'แก้ไข',
            icon: const Icon(Icons.edit_outlined),
          ),
        if (canDelete)
          IconButton(
            onPressed: onCancel,
            tooltip: 'ยกเลิกนัดหมาย',
            color: Colors.red,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, box) => box.maxWidth < 600
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [details, const SizedBox(height: 8), actions],
                  )
                : Row(
                    children: [
                      Expanded(child: details),
                      actions,
                    ],
                  ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _AppointmentEditor extends StatefulWidget {
  const _AppointmentEditor({required this.api, this.item});
  final VisitorApiClient api;
  final Map<dynamic, dynamic>? item;
  @override
  State<_AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<_AppointmentEditor> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _purpose = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  List<Map<String, dynamic>> _identities = const [];
  Map<String, dynamic>? _identity;
  List<Map<String, dynamic>> _contactPoints = const [];
  int? _contactPointId;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool get _editing => widget.item != null;
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_editing) {
      _name.text = '${widget.item!['visitorName'] ?? ''}';
      _phone.text = '${widget.item!['phone'] ?? ''}';
      _purpose.text = '${widget.item!['visitPurpose'] ?? ''}';
      _date =
          DateTime.tryParse('${widget.item!['appointmentDate'] ?? ''}') ??
          _date;
    }
    try {
      final values = await Future.wait<dynamic>([
        if (!_editing)
          widget.api.get('/api/company/current-user/host-identities')
        else
          Future.value(null),
        widget.api.get('/api/visitor/appointments/contact-points'),
      ]);
      final root = values[0] == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(values[0] as Map);
      final pointRoot = Map<String, dynamic>.from(values[1] as Map);
      final points = (pointRoot['items'] as List? ?? const [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList(growable: false);
      int? initialContactPointId;
      if (points.length == 1) {
        initialContactPointId = (points.first['contactPointId'] as num).toInt();
      } else if (_editing) {
        final existingName = '${widget.item!['contactPointName'] ?? ''}'.trim();
        for (final point in points) {
          if ('${point['name'] ?? ''}'.trim() == existingName) {
            initialContactPointId = (point['contactPointId'] as num).toInt();
            break;
          }
        }
      }
      final identities = <Map<String, dynamic>>[];
      void add(String type, String key, String field) {
        for (final value in root[key] as List? ?? const []) {
          identities.add({'hostType': type, field: value});
        }
      }

      add('EMPLOYEE', 'employeeIds', 'hostEmployeeId');
      add('RESIDENT', 'residentIds', 'hostResidentId');
      add('SERVICE_CUSTOMER', 'serviceCustomerIds', 'hostServiceCustomerId');
      for (final raw in root['tenantContacts'] as List? ?? const []) {
        final contact = Map<String, dynamic>.from(raw as Map);
        identities.add({
          'hostType': 'RENTAL_OFFICE',
          'hostTenantId': contact['tenantId'],
          'hostTenantContactId': contact['tenantContactId'],
        });
      }
      if (!_editing && identities.isEmpty) {
        throw const VisitorApiException(
          403,
          'ไม่พบข้อมูลผู้รับรองที่ผูกกับผู้ใช้ที่เข้าสู่ระบบ',
        );
      }
      if (mounted) {
        setState(() {
          _identities = identities;
          _identity = identities.isEmpty ? null : identities.first;
          _contactPoints = points;
          _contactPointId = initialContactPointId;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _dateTimePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time != null && mounted) {
      setState(
        () => _date = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'กรุณาระบุชื่อผู้มาติดต่อ');
      return;
    }
    if (!_editing && _identity == null) {
      setState(() => _error = 'กรุณาเลือกผู้รับรอง');
      return;
    }
    if (_contactPointId == null) {
      setState(() => _error = 'กรุณาเลือกจุดติดต่อ');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'visitorName': _name.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'appointmentDate': _date.toUtc().toIso8601String(),
      'visitPurpose': _purpose.text.trim().isEmpty
          ? null
          : _purpose.text.trim(),
      'contactPointId': _contactPointId,
      'contactPointNameSnapshot': null,
    };
    try {
      if (_editing) {
        await widget.api.put(
          '/api/visitor/appointments/${widget.item!['visitorAppointmentId']}',
          body: body,
        );
      } else {
        await widget.api.post(
          '/api/visitor/appointments',
          body: {...body, ..._identity!},
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        Icon(
          Icons.event_note_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(_editing ? 'นัดหมายล่วงหน้า > แก้ไข' : 'นัดหมายล่วงหน้า > เพิ่ม'),
      ],
    ),
    content: SizedBox(
      width: 560,
      child: _loading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) _InlineError(_error!),
                  if (!_editing) ...[
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: _identity,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'ผู้รับรอง *',
                      ),
                      items: _identities
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                _identityLabel(value),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _identity = value),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<int>(
                    initialValue: _contactPointId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'จุดติดต่อ *'),
                    items: _contactPoints
                        .map(
                          (point) => DropdownMenuItem(
                            value: (point['contactPointId'] as num).toInt(),
                            child: Text(
                              '${point['code'] ?? '-'} — ${point['name'] ?? '-'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _contactPointId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อผู้มาติดต่อ *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'เบอร์โทรศัพท์',
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _saving ? null : _dateTimePicker,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'วันเวลานัดหมาย *',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_dateTime(_date)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _purpose,
                    enabled: !_saving,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'วัตถุประสงค์',
                    ),
                  ),
                ],
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: _loading || _saving ? null : _save,
        child: Text(_saving ? 'กำลังบันทึก' : 'บันทึก'),
      ),
    ],
  );
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _purpose.dispose();
    super.dispose();
  }
}

class VisitorAppointmentApprovalsPage extends StatefulWidget {
  const VisitorAppointmentApprovalsPage({super.key});
  @override
  State<VisitorAppointmentApprovalsPage> createState() =>
      _VisitorAppointmentApprovalsPageState();
}

class _VisitorAppointmentApprovalsPageState
    extends State<VisitorAppointmentApprovalsPage> {
  final _api = VisitorApiClient();
  List<dynamic> _items = const [];
  Map<String, dynamic> _actions = const {};
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        _api.get('/api/visitor/appointments/pending-approval'),
        _api.get('/api/visitor/appointments/actions'),
      ]);
      if (!mounted) return;
      setState(() {
        _items =
            Map<String, dynamic>.from(values[0] as Map)['items'] as List? ??
            const [];
        _actions = Map<String, dynamic>.from(values[1] as Map);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<dynamic, dynamic> item, String status) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ApprovalDialog(approved: status == 'APPROVED'),
    );
    if (note == null) return;
    try {
      await _api.post(
        '/api/visitor/appointments/${item['visitorAppointmentId']}/approval',
        body: {'statusCode': status, 'note': note.isEmpty ? null : note},
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => buildVisitorWorkspaceShell(
    pageTitle: 'สถานะการอนุมัติ',
    activeMenu: _approvalMenu,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.fact_check_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'สถานะการอนุมัติ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                _ErrorCard(_error!)
              else if (_items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: Text('ไม่มีนัดหมายรออนุมัติ')),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: _items.map((raw) {
                      final item = Map<dynamic, dynamic>.from(raw as Map);
                      return _ApprovalTile(
                        item: item,
                        enabled: _actions['approvalEdit'] == true,
                        onAction: _approve,
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
  );
  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}

class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({
    required this.item,
    required this.enabled,
    required this.onAction,
  });
  final Map<dynamic, dynamic> item;
  final bool enabled;
  final Future<void> Function(Map<dynamic, dynamic>, String) onAction;
  @override
  Widget build(BuildContext context) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${item['visitorName'] ?? '-'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('วันนัด: ${_dateTime(item['appointmentDate'])}'),
        if ('${item['phone'] ?? ''}'.isNotEmpty) Text('โทร: ${item['phone']}'),
        if ('${item['visitPurpose'] ?? ''}'.isNotEmpty)
          Text('วัตถุประสงค์: ${item['visitPurpose']}'),
        if ('${item['contactPointName'] ?? ''}'.isNotEmpty)
          Text('จุดติดต่อ: ${item['contactPointName']}'),
      ],
    );
    final buttons = Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: enabled ? () => onAction(item, 'REJECTED') : null,
          icon: const Icon(Icons.close),
          label: const Text('ปฏิเสธ'),
        ),
        FilledButton.icon(
          onPressed: enabled ? () => onAction(item, 'APPROVED') : null,
          icon: const Icon(Icons.check),
          label: const Text('อนุมัติ'),
        ),
      ],
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, box) => box.maxWidth < 600
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [details, const SizedBox(height: 12), buttons],
                  )
                : Row(
                    children: [
                      Expanded(child: details),
                      buttons,
                    ],
                  ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({required this.approved});
  final bool approved;
  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final _note = TextEditingController();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.approved ? 'ยืนยันการอนุมัตินัดหมาย' : 'ยืนยันการปฏิเสธนัดหมาย',
    ),
    content: TextField(
      controller: _note,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'หมายเหตุ'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _note.text.trim()),
        child: const Text('ยืนยัน'),
      ),
    ],
  );
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }
}

class _CancelDialog extends StatelessWidget {
  const _CancelDialog({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.delete_outline, color: Colors.red),
        SizedBox(width: 8),
        Text('ยืนยันการยกเลิกนัดหมาย'),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.red.shade50,
          child: Text(name),
        ),
        const SizedBox(height: 12),
        const Text('รายการที่ยกเลิกแล้วไม่สามารถเรียกคืนได้'),
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
        label: const Text('ยกเลิกนัดหมาย'),
      ),
    ],
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: _InlineError(message),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ],
  );
}

String _identityLabel(Map<String, dynamic> value) {
  final id =
      value['hostTenantContactId'] ??
      value['hostEmployeeId'] ??
      value['hostResidentId'] ??
      value['hostServiceCustomerId'];
  return '${_hostTypeLabel('${value['hostType']}')} (${id ?? '-'})';
}

String _hostTypeLabel(String type) => switch (type) {
  'EMPLOYEE' => 'พนักงาน',
  'RESIDENT' => 'ผู้พักอาศัย',
  'SERVICE_CUSTOMER' => 'ผู้ใช้บริการ',
  'RENTAL_OFFICE' => 'ผู้ติดต่อบริษัทผู้เช่า',
  _ => type,
};
String _statusLabel(String code) => switch (code) {
  'PENDING' => 'รออนุมัติ',
  'APPROVED' => 'อนุมัติแล้ว',
  'REJECTED' => 'ปฏิเสธ',
  'CANCELLED' => 'ยกเลิกแล้ว',
  'USED' => 'ใช้งานแล้ว',
  _ => code,
};
String _dateTime(Object? value) {
  final date = value is DateTime
      ? value.toLocal()
      : DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '-';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}
