import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_request_qr_api.dart';

class ServiceRequestQrPage extends StatefulWidget {
  const ServiceRequestQrPage({super.key});

  @override
  State<ServiceRequestQrPage> createState() => _ServiceRequestQrPageState();
}

class _ServiceRequestQrPageState extends State<ServiceRequestQrPage> {
  final _api = ServiceRequestQrApi();
  final _search = TextEditingController();
  String _status = '';
  int _page = 1;
  bool _loading = true;
  bool _canCreate = false;
  bool _canEdit = false;
  Map<String, dynamic> _data = const {'items': <dynamic>[], 'total': 0};

  @override
  void initState() {
    super.initState();
    _load();
    _loadActions();
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

  Future<void> _loadActions() async {
    try {
      final actions = await _api.actions();
      if (mounted) {
        setState(() {
          _canCreate = actions['create'] == true;
          _canEdit = actions['edit'] == true;
        });
      }
    } catch (_) {}
  }

  void _message(Object error, {bool errorState = true}) {
    final text = error is ApiException
        ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่'}'
        : 'ไม่สามารถดำเนินการได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: text, error: errorState);
  }

  Future<void> _create() async {
    try {
      final choices = await _api.lookup();
      if (!mounted) return;
      final created = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _CreateQrDialog(api: _api, choices: choices),
      );
      if (created == null || !mounted) return;
      await _load();
      if (!mounted) return;
      await _showQr(created['qrToken']?.toString() ?? '');
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  Future<void> _showQr(String token) async {
    if (token.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _QrDialog(token: token),
    );
  }

  Future<void> _setActive(Map<String, dynamic> row) async {
    final id = (row['qrPortalId'] as num?)?.toInt();
    if (id == null) return;
    try {
      await _api.setActive(id, row['isActive'] != true);
      if (!mounted) return;
      showTimedSnackBar(
        context,
        message: row['isActive'] == true
            ? 'ปิดใช้งาน QR Code แล้ว'
            : 'เปิดใช้งาน QR Code แล้ว',
      );
      await _load();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ((_data['items'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final total = (_data['total'] as num?)?.toInt() ?? 0;
    return SupportWorkspaceShell(
      pageTitle: 'จัดการ QR Code แจ้งซ่อม',
      activeMenu: 'cmQrPortal',
      menuScope: WorkspaceMenuScope.company,
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(total),
            const SizedBox(height: LaooLayout.cardSpacing),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? const Center(child: Text('ยังไม่มี QR Code แจ้งซ่อม'))
                  : LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth < 900
                          ? ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) => _QrCard(
                                row: items[index],
                                canEdit: _canEdit,
                                onShow: () => _showQr(
                                  items[index]['qrToken']?.toString() ?? '',
                                ),
                                onToggle: () => _setActive(items[index]),
                              ),
                            )
                          : _QrTable(
                              items: items,
                              canEdit: _canEdit,
                              onShow: (row) =>
                                  _showQr(row['qrToken']?.toString() ?? ''),
                              onToggle: _setActive,
                            ),
                    ),
            ),
            _Pagination(
              page: _page,
              total: total,
              onPrevious: _page > 1
                  ? () {
                      setState(() => _page--);
                      _load();
                    }
                  : null,
              onNext: items.length >= 20
                  ? () {
                      setState(() => _page++);
                      _load();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(int total) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: TextField(
              controller: _search,
              onSubmitted: (_) {
                _page = 1;
                _load();
              },
              decoration: const InputDecoration(
                labelText: 'ค้นหา QR, Serial หรืออุปกรณ์',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'สถานะ'),
              items: const [
                DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                DropdownMenuItem(value: 'ACTIVE', child: Text('ใช้งาน')),
                DropdownMenuItem(value: 'INACTIVE', child: Text('ปิดใช้งาน')),
              ],
              onChanged: (value) => setState(() => _status = value ?? ''),
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
          OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _search.clear();
                      _status = '';
                      _page = 1;
                    });
                    _load();
                  },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('ล้าง Filter'),
          ),
          if (_canCreate)
            FilledButton.icon(
              onPressed: _loading ? null : _create,
              icon: const Icon(Icons.qr_code_2),
              label: const Text('สร้าง QR Code'),
            ),
          Text('ทั้งหมด $total รายการ'),
        ],
      ),
    ),
  );
}

class _QrTable extends StatelessWidget {
  const _QrTable({
    required this.items,
    required this.canEdit,
    required this.onShow,
    required this.onToggle,
  });
  final List<Map<String, dynamic>> items;
  final bool canEdit;
  final ValueChanged<Map<String, dynamic>> onShow;
  final ValueChanged<Map<String, dynamic>> onToggle;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('QR Code')),
          DataColumn(label: Text('อุปกรณ์ / Serial')),
          DataColumn(label: Text('สถานที่')),
          DataColumn(label: Text('สถานะ')),
          DataColumn(label: Text('Action')),
        ],
        rows: [
          for (final row in items)
            DataRow(
              cells: [
                DataCell(Text(_tokenLabel(row['qrToken']))),
                DataCell(
                  SizedBox(
                    width: 260,
                    child: Text(
                      '${row['itemCode'] ?? '-'} | ${row['itemName'] ?? '-'}\nSerial: ${row['serialNo'] ?? '-'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(
                      row['locationSnapshot']?.toString() ?? '-',
                      softWrap: true,
                    ),
                  ),
                ),
                DataCell(_StatusChip(active: row['isActive'] == true)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'แสดง QR Code',
                        onPressed: () => onShow(row),
                        icon: const Icon(Icons.qr_code_2),
                      ),
                      if (canEdit)
                        IconButton(
                          tooltip: row['isActive'] == true
                              ? 'ปิดใช้งาน'
                              : 'เปิดใช้งาน',
                          onPressed: () => onToggle(row),
                          icon: Icon(
                            row['isActive'] == true
                                ? Icons.toggle_on_outlined
                                : Icons.toggle_off_outlined,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.row,
    required this.canEdit,
    required this.onShow,
    required this.onToggle,
  });
  final Map<String, dynamic> row;
  final bool canEdit;
  final VoidCallback onShow;
  final VoidCallback onToggle;
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
                  '${row['itemCode'] ?? '-'} | ${row['itemName'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  softWrap: true,
                ),
              ),
              _StatusChip(active: row['isActive'] == true),
            ],
          ),
          const Divider(),
          Text('Serial: ${row['serialNo'] ?? '-'}'),
          Text('สถานที่: ${row['locationSnapshot'] ?? '-'}', softWrap: true),
          Text('QR: ${_tokenLabel(row['qrToken'])}'),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onShow,
                icon: const Icon(Icons.qr_code_2),
                label: const Text('แสดง QR'),
              ),
              if (canEdit)
                FilledButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    row['isActive'] == true
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    row['isActive'] == true ? 'ปิดใช้งาน' : 'เปิดใช้งาน',
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(active ? 'ใช้งาน' : 'ปิดใช้งาน'),
    avatar: Icon(
      active ? Icons.check_circle_outline : Icons.block_outlined,
      size: 18,
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });
  final int page;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: LaooLayout.paginationCardHeight,
    child: Row(
      children: [
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Text('หน้า $page · $total รายการ'),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    ),
  );
}

class _CreateQrDialog extends StatefulWidget {
  const _CreateQrDialog({required this.api, required this.choices});
  final ServiceRequestQrApi api;
  final List<Map<String, dynamic>> choices;
  @override
  State<_CreateQrDialog> createState() => _CreateQrDialogState();
}

class _CreateQrDialogState extends State<_CreateQrDialog> {
  int? _instanceId;
  bool _saving = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(16),
    title: const Row(
      children: [
        Icon(Icons.qr_code_2),
        SizedBox(width: 8),
        Expanded(child: Text('สร้าง QR Code แจ้งซ่อม')),
      ],
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'อุปกรณ์ / Serial *',
              ),
              items: [
                for (final item in widget.choices)
                  DropdownMenuItem(
                    value: (item['itemInstanceId'] as num).toInt(),
                    child: Text(
                      '${item['itemCode']} | ${item['itemName']} | ${item['serialNo']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _instanceId = value),
            ),
            if (_instanceId != null) ...[
              const SizedBox(height: 12),
              _location(),
            ],
            const SizedBox(height: 8),
            const Text('เลือกได้เฉพาะอุปกรณ์ที่ติดตั้งและมีอาคาร ชั้น ห้องครบ'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: _instanceId == null || _saving ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
      ),
    ],
  );

  Widget _location() {
    final item = widget.choices.firstWhere(
      (row) => (row['itemInstanceId'] as num).toInt() == _instanceId,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(color: LaooColors.surfaceSoft),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('สถานที่: ${item['locationSnapshot'] ?? '-'}'),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final value = await widget.api.create(_instanceId!);
      if (mounted) Navigator.pop(context, value);
    } catch (error) {
      if (mounted)
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? '${error.message}\n${error.description ?? 'กรุณาลองใหม่'}'
              : 'บันทึก QR Code ไม่สำเร็จ',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _QrDialog extends StatelessWidget {
  const _QrDialog({required this.token});
  final String token;
  String get _url =>
      '${Uri.base.scheme}://${Uri.base.authority}/#/portal/request?qr=$token';
  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(16),
    title: const Row(
      children: [
        Icon(Icons.qr_code_2),
        SizedBox(width: 8),
        Expanded(child: Text('QR Code แจ้งซ่อม')),
      ],
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: QrImageView(
                  data: _url,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  semanticsLabel: 'QR Code แจ้งซ่อม',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(_url),
            const SizedBox(height: 8),
            const Text('สแกนเพื่อเปิดแบบฟอร์มแจ้งซ่อมพร้อมอุปกรณ์และสถานที่'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
      FilledButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: _url));
          if (context.mounted)
            showTimedSnackBar(context, message: 'คัดลอกลิงก์ QR แล้ว');
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('คัดลอกลิงก์'),
      ),
    ],
  );
}

String _tokenLabel(Object? token) {
  final value = token?.toString() ?? '';
  return value.length <= 12 ? value : '${value.substring(0, 12)}…';
}
