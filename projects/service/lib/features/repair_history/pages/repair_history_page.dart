import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../service_request/data/service_request_api.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';

/// ScreenType 3: read-only completed repair history and issued-part costs.
class RepairHistoryPage extends StatefulWidget {
  const RepairHistoryPage({super.key});
  @override
  State<RepairHistoryPage> createState() => _RepairHistoryPageState();
}

class _RepairHistoryPageState extends State<RepairHistoryPage> {
  final _api = ServiceRequestApi();
  final _client = ApiClient();
  final _search = TextEditingController();
  String _caption = 'ประวัติการซ่อมและค่าใช้จ่าย';
  bool _loading = true;
  int _page = 1;
  int _total = 0;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _resolveCaption();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<void> _resolveCaption() async {
    try {
      final value = await NavigationMenuRepository(apiClient: _client)
          .resolveMenuName(
            menuCode: '19002',
            routeName: 'reportsHistory',
            fallback: _caption,
          );
      if (mounted) setState(() => _caption = value);
    } catch (_) {
      /* Keep the database-aligned fallback. */
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final value = await _api.repairHistory(
        search: _search.text.trim(),
        page: _page,
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

  Future<void> _open(Map<String, dynamic> row) async {
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final data = await _api.detail(id);
      final attachments = await _api.attachments(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            _RepairHistoryDetail(data: data, attachments: attachments),
      );
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  void _message(Object error) {
    final text = error is ApiException
        ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง'}'
        : 'ไม่สามารถโหลดประวัติการซ่อมได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: text, error: true);
  }

  Future<void> _refresh() async {
    _page = 1;
    await _load();
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'reportsHistory',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('ไม่พบประวัติการซ่อมที่ปิดงานแล้ว'))
                : LayoutBuilder(
                    builder: (context, box) => box.maxWidth < 900
                        ? ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, index) => _HistoryCard(
                              row: _items[index],
                              onOpen: () => _open(_items[index]),
                            ),
                          )
                        : _HistoryTable(items: _items, onOpen: _open),
                  ),
          ),
          if (!_loading && _total > 20) _pagination(),
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
            width: 360,
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _refresh(),
              decoration: const InputDecoration(
                labelText: 'ค้นหาเลขที่ ผู้แจ้ง หัวข้อ หรือช่าง',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
          Text(
            'พบ $_total รายการ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );

  Widget _pagination() => SizedBox(
    height: LaooLayout.paginationCardHeight,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'หน้าก่อนหน้า',
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
          tooltip: 'หน้าถัดไป',
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
  );
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.items, required this.onOpen});
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('เลขที่แจ้งซ่อม')),
          DataColumn(label: Text('ผู้แจ้ง')),
          DataColumn(label: Text('สถานที่')),
          DataColumn(label: Text('อุปกรณ์')),
          DataColumn(label: Text('หัวข้อ')),
          DataColumn(label: Text('ช่าง')),
          DataColumn(label: Text('วันปิดงาน')),
          DataColumn(numeric: true, label: Text('ค่าอะไหล่')),
          DataColumn(label: Text('รายละเอียด')),
        ],
        rows: [
          for (final row in items)
            DataRow(
              onSelectChanged: (_) => onOpen(row),
              cells: [
                DataCell(
                  TextButton(
                    onPressed: () => onOpen(row),
                    child: Text(_text(row['requestNo'])),
                  ),
                ),
                DataCell(Text(_text(row['requesterName']))),
                DataCell(
                  SizedBox(
                    width: 160,
                    child: Text(_text(row['locationSnapshot'])),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(_text(row['equipmentName'])),
                  ),
                ),
                DataCell(
                  SizedBox(width: 180, child: Text(_text(row['subject']))),
                ),
                DataCell(Text(_text(row['assignedEmployeeName']))),
                DataCell(Text(_date(row['completedDate']))),
                DataCell(Text('${_money(row['partsTotal'])} บาท')),
                DataCell(
                  IconButton(
                    tooltip: 'เปิดรายละเอียด',
                    onPressed: () => onOpen(row),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.row, required this.onOpen});
  final Map<String, dynamic> row;
  final VoidCallback onOpen;
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
                  _text(row['requestNo']),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(_date(row['completedDate'])),
            ],
          ),
          const Divider(),
          Text('ผู้แจ้ง: ${_text(row['requesterName'])}'),
          Text('สถานที่: ${_text(row['locationSnapshot'])}', softWrap: true),
          Text('อุปกรณ์: ${_text(row['equipmentName'])}', softWrap: true),
          Text('หัวข้อ: ${_text(row['subject'])}', softWrap: true),
          Text('ช่าง: ${_text(row['assignedEmployeeName'])}'),
          const SizedBox(height: 8),
          Text(
            'ค่าอะไหล่ ${_money(row['partsTotal'])} บาท',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('ดูรายละเอียด'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RepairHistoryDetail extends StatelessWidget {
  const _RepairHistoryDetail({required this.data, required this.attachments});
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> attachments;
  List<Map<String, dynamic>> get _parts =>
      ((data['parts'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(16),
    title: Text(data['requestNo']?.toString() ?? 'รายละเอียดประวัติการซ่อม'),
    content: SizedBox(
      width: (MediaQuery.sizeOf(context).width - 32).clamp(280.0, 640.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _line('ผู้แจ้ง', data['requesterName']),
            _line('สถานที่', data['locationSnapshot']),
            _line(
              'อุปกรณ์',
              '${data['equipmentCode'] ?? '-'} | ${data['equipmentName'] ?? '-'}',
            ),
            _line('หัวข้อ', data['subject']),
            _line('รายละเอียดแจ้งซ่อม', data['detail']),
            _line('ช่างผู้รับผิดชอบ', data['assignedEmployeeName']),
            _line('วันเริ่มงาน', _date(data['startedDate'])),
            _line('วันปิดงาน', _date(data['completedDate'])),
            _line('ผลการซ่อม', data['resolutionDetail']),
            const Divider(height: 28),
            const Text(
              'อะไหล่ที่ใช้ซ่อม',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_parts.isEmpty) const Text('ไม่มีการตัดอะไหล่ในงานนี้'),
            for (final part in _parts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_text(part['itemCode'])} | ${_text(part['itemName'])}\n${_text(part['warehouseName'])} • จำนวน ${part['quantity'] ?? 0} ${part['unitCode'] ?? ''}\nต้นทุน ${_money(part['totalCost'])} บาท${((part['serialNos'] as List?) ?? const []).isEmpty ? '' : '\nSerial: ${(part['serialNos'] as List).join(', ')}'}',
                  softWrap: true,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'ต้นทุนอะไหล่รวม ${_money(data['partsTotal'])} บาท',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (attachments.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                'รูปภาพแนบ ${attachments.length} ไฟล์',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
    ],
  );
  Widget _line(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text('$label: ${_text(value)}', softWrap: true),
  );
}

String _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? '-' : text;
}

String _date(Object? value) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? '-' : text.replaceFirst('T', ' ').split('.').first;
}

String _money(Object? value) =>
    ((value as num?)?.toDouble() ?? 0).toStringAsFixed(2);
