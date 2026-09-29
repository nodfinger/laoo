import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../service_request/data/service_request_api.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';

/// ScreenType 3: read-only completed repair history and issued-part costs.
class RepairHistoryPage extends StatefulWidget {
  const RepairHistoryPage({super.key, this.api});
  final ServiceRequestApi? api;
  @override
  State<RepairHistoryPage> createState() => _RepairHistoryPageState();
}

class _RepairHistoryPageState extends State<RepairHistoryPage> {
  late final ServiceRequestApi _api = widget.api ?? ServiceRequestApi();
  final _client = ApiClient();
  final _search = TextEditingController();
  String _caption = 'ประวัติการซ่อมและค่าใช้จ่าย';
  bool _loading = true;
  String? _loadError;
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
    setState(() {
      _loading = true;
      _loadError = null;
    });
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
      if (mounted) {
        setState(() {
          _items = const [];
          _total = 0;
          _loadError = error is ApiException
              ? 'ไม่สามารถโหลดประวัติการซ่อมได้\nรายละเอียดเพิ่มเติม: ${error.description ?? error.message}'
              : 'ไม่สามารถโหลดประวัติการซ่อมได้\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อและลองอีกครั้ง';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final data = await _api.detail(id, menuCode: '19002');
      final attachments = await _api.attachments(id, menuCode: '19002');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _RepairHistoryDetail(
          caption: _caption,
          data: data,
          attachments: attachments,
        ),
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
          const SizedBox(height: LaooLayout.listSectionSpacing),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_loadError!),
                          const SizedBox(height: LaooLayout.cardSpacing),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('ลองอีกครั้ง'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                ? const Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(LaooLayout.cardPadding),
                      child: Text('ไม่พบประวัติการซ่อมที่ปิดงานแล้ว'),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) => box.maxWidth < 900
                        ? ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(
                              height: LaooLayout.listItemSpacing,
                            ),
                            itemBuilder: (_, index) => _HistoryCard(
                              row: _items[index],
                              onOpen: () => _open(_items[index]),
                            ),
                          )
                        : _HistoryTable(items: _items, onOpen: _open),
                  ),
          ),
          const SizedBox(height: LaooLayout.listSectionSpacing),
          if (!_loading) _pagination(),
        ],
      ),
    ),
  );

  Widget _toolbar() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: LaooLayout.cardSpacing,
          runSpacing: LaooLayout.cardSpacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: box.maxWidth < 360 ? box.maxWidth : 360,
              child: TextField(
                controller: _search,
                onSubmitted: (_) => _refresh(),
                decoration: const InputDecoration(
                  labelText: 'ค้นหาเลขที่/ชื่อ/ช่าง',
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
    ),
  );

  Widget _pagination() {
    final primary = Theme.of(context).colorScheme.primary;
    final disabled = Theme.of(context).disabledColor;
    final start = _total == 0 ? 0 : (_page - 1) * 20 + 1;
    final end = _page * 20 < _total ? _page * 20 : _total;
    ButtonStyle arrowStyle(bool enabled) => OutlinedButton.styleFrom(
      fixedSize: const Size(
        LaooLayout.paginationButtonSize,
        LaooLayout.paginationButtonSize,
      ),
      minimumSize: const Size(
        LaooLayout.paginationButtonSize,
        LaooLayout.paginationButtonSize,
      ),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: enabled ? primary : disabled),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        height: LaooLayout.paginationCardHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LaooLayout.cardPadding,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: LaooLayout.listSectionSpacing,
              runSpacing: LaooLayout.listSectionSpacing,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _page > 1
                      ? () {
                          _page--;
                          _load();
                        }
                      : null,
                  style: arrowStyle(_page > 1),
                  child: const Icon(Icons.chevron_left),
                ),
                FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: primary,
                    disabledForegroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimary,
                    fixedSize: const Size(
                      LaooLayout.paginationButtonSize,
                      LaooLayout.paginationButtonSize,
                    ),
                    minimumSize: const Size(
                      LaooLayout.paginationButtonSize,
                      LaooLayout.paginationButtonSize,
                    ),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                  ),
                  child: Text('$_page'),
                ),
                OutlinedButton(
                  onPressed: _page * 20 < _total
                      ? () {
                          _page++;
                          _load();
                        }
                      : null,
                  style: arrowStyle(_page * 20 < _total),
                  child: const Icon(Icons.chevron_right),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text('$start-$end จาก $_total'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(row['requestNo']),
                style: const TextStyle(fontWeight: FontWeight.w700),
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
  const _RepairHistoryDetail({
    required this.caption,
    required this.data,
    required this.attachments,
  });
  final String caption;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> attachments;
  List<Map<String, dynamic>> get _parts =>
      ((data['parts'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    insetPadding: const EdgeInsets.all(16),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: LaooLayout.listSectionSpacing),
            Expanded(
              child: Text(
                '$caption > ${data['requestNo'] ?? 'รายละเอียด'}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: LaooTypography.pageTitle,
                  fontWeight: LaooTypography.pageTitleWeight,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        const Divider(color: LaooColors.border),
      ],
    ),
    content: SizedBox(
      width: (MediaQuery.sizeOf(context).width - 80).clamp(200.0, 640.0),
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
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Divider(color: LaooColors.border),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(96, LaooTypography.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            child: const Text('ปิด'),
          ),
        ],
      ),
    ],
  );
  Widget _line(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: LaooLayout.popupFieldSpacing),
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
