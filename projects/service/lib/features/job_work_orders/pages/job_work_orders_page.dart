import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../service_request/data/service_request_api.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';

class JobWorkOrdersPage extends StatefulWidget {
  const JobWorkOrdersPage({super.key, this.initialStatus = 'OPEN', this.api});
  final String initialStatus;
  final ServiceRequestApi? api;

  @override
  State<JobWorkOrdersPage> createState() => _JobWorkOrdersPageState();
}

class _JobWorkOrdersPageState extends State<JobWorkOrdersPage> {
  late final ServiceRequestApi _api = widget.api ?? ServiceRequestApi();
  final _search = TextEditingController();
  String _caption = 'ทะเบียนใบงานทั้งหมด';
  bool _canEdit = false;
  String _status = 'OPEN';
  bool _loading = true;
  String? _loadError;
  int _page = 1;
  int _total = 0;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _load();
    _loadActions();
    _loadCaption();
  }

  Future<void> _loadActions() async {
    try {
      final actions = await _api.actions();
      if (mounted) {
        setState(() => _canEdit = actions['workOrderEdit'] == true);
      }
    } catch (_) {
      // Keep mutation actions hidden if permission lookup fails.
    }
  }

  Future<void> _loadCaption() async {
    try {
      final caption = await NavigationMenuRepository().resolveMenuName(
        menuCode: '17002',
        routeName: 'jobWorkOrders',
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
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final value = await _api.list(
        search: _search.text.trim(),
        status: _status,
        page: _page,
        menuCode: '17002',
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
              ? '${error.message}\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาตรวจสอบการเชื่อมต่อและลองอีกครั้ง'}'
              : 'ไม่สามารถโหลดทะเบียนใบงานได้\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อและลองอีกครั้ง';
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
      final data = await _api.detail(id, menuCode: '17002');
      final attachments = await _api.attachments(id, menuCode: '17002');
      if (!mounted) return;
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => _WorkOrderDialog(
          api: _api,
          data: data,
          attachments: attachments,
          canEdit: _canEdit,
          caption: _caption,
        ),
      );
      if (changed == true && mounted) await _load();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  void _message(Object error) {
    final text = error is ApiException
        ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง'}'
        : 'ไม่สามารถโหลดทะเบียนใบงานได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: text, error: true);
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'jobWorkOrders',
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
                    Icons.star_border,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: LaooLayout.cardPadding),
                  Expanded(
                    child: Text(
                      _caption,
                      style: LaooTypography.screenCaptionStyle,
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
                ? const Card(
                    margin: EdgeInsets.zero,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _loadError != null
                ? Card(
                    margin: EdgeInsets.zero,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(LaooLayout.cardPadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_loadError!, textAlign: TextAlign.center),
                            const SizedBox(
                              height: LaooLayout.listSectionSpacing,
                            ),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('ลองอีกครั้ง'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : _items.isEmpty
                ? const Card(
                    margin: EdgeInsets.zero,
                    child: Center(child: Text('ไม่พบใบงาน')),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 900
                        ? ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, index) => _WorkOrderCard(
                              row: _items[index],
                              onOpen: () => _open(_items[index]),
                            ),
                          )
                        : _WorkOrderTable(items: _items, onOpen: _open),
                  ),
          ),
          const SizedBox(height: LaooLayout.listSectionSpacing),
          _pagination(),
        ],
      ),
    ),
  );

  Widget _toolbar() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: constraints.maxWidth < 320 ? constraints.maxWidth : 320,
              child: TextField(
                controller: _search,
                onSubmitted: (_) => _refresh(),
                decoration: const InputDecoration(
                  labelText: 'ค้นหาเลขที่ ผู้แจ้ง หัวข้อ หรือช่าง',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: constraints.maxWidth < 240 ? constraints.maxWidth : 240,
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'สถานะ'),
                items: const [
                  DropdownMenuItem(
                    value: 'OPEN',
                    child: Text('งานที่ยังไม่เสร็จ'),
                  ),
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
                  DropdownMenuItem(value: 'CANCELLED', child: Text('ยกเลิก')),
                  DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                      _page = 1;
                    });
                  }
                  _load();
                },
              ),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.search),
              label: const Text('ค้นหา'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _refresh() async {
    _page = 1;
    await _load();
  }

  Widget _pagination() {
    final primary = Theme.of(context).colorScheme.primary;
    final first = _total == 0 ? 0 : (_page - 1) * 20 + 1;
    final last = _total == 0 ? 0 : (_page * 20).clamp(0, _total);
    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        height: LaooLayout.paginationCardHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LaooLayout.cardPadding,
          ),
          child: Row(
            children: [
              _pageButton(
                Icons.chevron_left,
                _loading || _page <= 1
                    ? null
                    : () {
                        _page--;
                        _load();
                      },
              ),
              const SizedBox(width: LaooLayout.listSectionSpacing),
              SizedBox(
                width: LaooLayout.paginationButtonSize,
                height: LaooLayout.paginationButtonSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                  child: Center(
                    child: Text(
                      '$_page',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: LaooLayout.listSectionSpacing),
              _pageButton(
                Icons.chevron_right,
                _loading || _page * 20 >= _total
                    ? null
                    : () {
                        _page++;
                        _load();
                      },
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '$first-$last จาก $_total',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageButton(IconData icon, VoidCallback? onPressed) {
    final color = onPressed == null
        ? Theme.of(context).colorScheme.outline
        : Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: LaooLayout.paginationButtonSize,
      height: LaooLayout.paginationButtonSize,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _WorkOrderTable extends StatelessWidget {
  const _WorkOrderTable({required this.items, required this.onOpen});
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('เลขที่ใบงาน')),
          DataColumn(label: Text('เลขที่แจ้งซ่อม')),
          DataColumn(label: Text('ผู้แจ้ง')),
          DataColumn(label: Text('สถานที่')),
          DataColumn(label: Text('อุปกรณ์')),
          DataColumn(label: Text('หัวข้อ')),
          DataColumn(label: Text('ช่าง')),
          DataColumn(label: Text('วันที่รับเรื่อง')),
          DataColumn(label: Text('วันที่เริ่มงาน')),
          DataColumn(label: Text('สถานะ')),
          DataColumn(label: Text('Action')),
        ],
        rows: [
          for (final row in items)
            DataRow(
              onSelectChanged: (_) => onOpen(row),
              cells: [
                DataCell(
                  Tooltip(
                    message: 'เปิดรายละเอียดใบงาน',
                    child: TextButton(
                      onPressed: () => onOpen(row),
                      child: Text(row['requestNo']?.toString() ?? '-'),
                    ),
                  ),
                ),
                DataCell(Text(row['requestNo']?.toString() ?? '-')),
                DataCell(Text(row['requesterName']?.toString() ?? '-')),
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(row['locationSnapshot']?.toString() ?? '-'),
                  ),
                ),
                DataCell(Text(row['equipmentName']?.toString() ?? '-')),
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(row['subject']?.toString() ?? '-'),
                  ),
                ),
                DataCell(Text(row['assignedEmployeeName']?.toString() ?? '-')),
                DataCell(Text(_date(row['receivedDate']))),
                DataCell(Text(_date(row['startedDate']))),
                DataCell(Text(_status(row['statusCode']))),
                DataCell(
                  FilledButton(
                    onPressed: () => onOpen(row),
                    child: const Text('เปิด'),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({required this.row, required this.onOpen});
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
                  row['requestNo']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(_status(row['statusCode'])),
            ],
          ),
          const Divider(),
          Text('ผู้แจ้ง: ${row['requesterName'] ?? '-'}'),
          Text('สถานที่: ${row['locationSnapshot'] ?? '-'}', softWrap: true),
          Text('อุปกรณ์: ${row['equipmentName'] ?? '-'}'),
          Text('หัวข้อ: ${row['subject'] ?? '-'}', softWrap: true),
          Text('ช่าง: ${row['assignedEmployeeName'] ?? '-'}'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onOpen,
              child: const Text('เปิดรายละเอียด'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WorkOrderDialog extends StatefulWidget {
  const _WorkOrderDialog({
    required this.api,
    required this.data,
    required this.attachments,
    required this.canEdit,
    required this.caption,
  });
  final ServiceRequestApi api;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> attachments;
  final bool canEdit;
  final String caption;

  @override
  State<_WorkOrderDialog> createState() => _WorkOrderDialogState();
}

class _WorkOrderDialogState extends State<_WorkOrderDialog> {
  bool _busy = false;
  bool _partsLoading = false;
  Map<String, dynamic>? _partsLookup;
  final List<Map<String, dynamic>> _parts = [];
  final _resolution = TextEditingController();
  String get status => widget.data['statusCode']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _parts.addAll(
      ((widget.data['parts'] as List?) ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    if (widget.canEdit && status == 'IN_PROGRESS') _loadPartsLookup();
  }

  @override
  void dispose() {
    _resolution.dispose();
    super.dispose();
  }

  Future<void> _loadPartsLookup() async {
    setState(() => _partsLoading = true);
    try {
      final value = await widget.api.partsLookup();
      if (mounted) setState(() => _partsLookup = value);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? '${error.message}\n${error.description ?? 'กรุณาลองโหลดข้อมูลอะไหล่อีกครั้ง'}'
            : 'โหลดข้อมูลอะไหล่ไม่สำเร็จ';
        showTimedSnackBar(context, message: message, error: true);
      }
    } finally {
      if (mounted) setState(() => _partsLoading = false);
    }
  }

  Future<void> _addPart() async {
    if (!widget.canEdit) return;
    final lookup = _partsLookup;
    if (lookup == null) {
      await _loadPartsLookup();
      return;
    }
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _PartPickerDialog(lookup: lookup, caption: widget.caption),
    );
    if (value == null || !mounted) return;
    final duplicate = _parts.any(
      (part) =>
          part['warehouseId'] == value['warehouseId'] &&
          part['itemId'] == value['itemId'],
    );
    if (duplicate) {
      showTimedSnackBar(
        context,
        message:
            'มีอะไหล่นี้ในรายการแล้ว\nรายละเอียดเพิ่มเติม: กรุณาลบรายการเดิมแล้วระบุจำนวนใหม่',
        error: true,
      );
      return;
    }
    setState(() => _parts.add(value));
  }

  Future<void> _start() async {
    if (_busy || !widget.canEdit) return;
    setState(() => _busy = true);
    try {
      await widget.api.start((widget.data['requestId'] as num).toInt());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? '${error.message}\n${error.description ?? 'กรุณาโหลดใบงานใหม่'}'
            : error.toString();
        showTimedSnackBar(context, message: message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    if (!widget.canEdit) return;
    final resolution = _resolution.text.trim();
    if (resolution.isEmpty) {
      showTimedSnackBar(
        context,
        message:
            'กรุณาระบุผลการซ่อม\nรายละเอียดเพิ่มเติม: ผลการซ่อมเป็นข้อมูลบังคับก่อนปิดงาน',
        error: true,
      );
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.complete(
        (widget.data['requestId'] as num).toInt(),
        resolution,
        parts: _parts
            .map(
              (part) => <String, dynamic>{
                'warehouseId': part['warehouseId'],
                'itemId': part['itemId'],
                'quantity': part['quantity'],
                'serialInstanceIds': part['serialInstanceIds'] ?? const [],
              },
            )
            .toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? '${error.message}\n${error.description ?? 'กรุณาโหลดใบงานใหม่'}'
            : 'ปิดงานไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาลองใหม่';
        showTimedSnackBar(context, message: message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double get _partsTotal => _parts.fold<double>(
    0,
    (sum, part) =>
        sum +
        ((part['totalCost'] as num?)?.toDouble() ??
            ((part['quantity'] as num?)?.toDouble() ?? 0) *
                ((part['unitCost'] as num?)?.toDouble() ?? 0)),
  );

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
                Icons.build_circle_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: LaooLayout.cardPadding),
              Expanded(
                child: Text(
                  '${widget.caption} > ${widget.data['requestNo'] ?? 'รายละเอียด'}',
                  style: const TextStyle(
                    color: LaooColors.pageCaption,
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
      width:
          (MediaQuery.sizeOf(context).width - LaooLayout.dialogInsetPadding * 2)
              .clamp(0.0, 480.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _line('ผู้แจ้ง', widget.data['requesterName']),
            _line('สถานที่', widget.data['locationSnapshot']),
            _line('อุปกรณ์', widget.data['equipmentName']),
            _line('หัวข้อ', widget.data['subject']),
            _line('รายละเอียด', widget.data['detail']),
            _line('ช่าง', widget.data['assignedEmployeeName']),
            _line('วันที่รับเรื่อง', _date(widget.data['receivedDate'])),
            _line('วันที่เริ่มงาน', _date(widget.data['startedDate'])),
            if (status == 'COMPLETED') ...[
              _line('วันที่ปิดงาน', _date(widget.data['completedDate'])),
              _line('ผลการซ่อม', widget.data['resolutionDetail']),
            ],
            if (status == 'CANCELLED')
              _line('เหตุผลการยกเลิก', widget.data['cancellationReason']),
            _line('สถานะ', _status(status)),
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
                      requestId: (widget.data['requestId'] as num).toInt(),
                      item: item,
                    ),
                ],
              ),
            ],
            if (_parts.isNotEmpty || status == 'IN_PROGRESS') ...[
              const Divider(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'อะไหล่ที่ใช้ซ่อม',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.canEdit && status == 'IN_PROGRESS')
                    OutlinedButton.icon(
                      onPressed: _busy || _partsLoading ? null : _addPart,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่มอะไหล่'),
                    ),
                ],
              ),
              if (_partsLoading) const LinearProgressIndicator(),
              if (_parts.isEmpty && !_partsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('ไม่ใช้อะไหล่ในการซ่อม'),
                ),
              for (final part in _parts)
                Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      '${part['itemCode'] ?? '-'} | ${part['itemName'] ?? '-'}',
                    ),
                    subtitle: Text(
                      '${part['warehouseName'] ?? ''}  จำนวน ${_quantity(part['quantity'])} ${part['unitCode'] ?? ''}\nต้นทุน ${_money(part['unitCost'])} บาท / รวม ${_money(part['totalCost'] ?? ((part['quantity'] as num?)?.toDouble() ?? 0) * ((part['unitCost'] as num?)?.toDouble() ?? 0))} บาท${((part['serialNos'] as List?) ?? const []).isEmpty ? '' : '\nSerial: ${(part['serialNos'] as List).join(', ')}'}',
                    ),
                    isThreeLine: true,
                    trailing: widget.canEdit && status == 'IN_PROGRESS'
                        ? IconButton(
                            tooltip: 'ลบรายการ',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _parts.remove(part)),
                            icon: const Icon(Icons.delete_outline),
                          )
                        : null,
                  ),
                ),
              if (_parts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'ต้นทุนอะไหล่รวม ${_money(_partsTotal)} บาท',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
            if (widget.canEdit && status == 'IN_PROGRESS') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _resolution,
                enabled: !_busy,
                minLines: 4,
                maxLines: 8,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'ผลการซ่อม *',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actionsPadding: EdgeInsets.zero,
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
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                  ),
                  child: const Text('ปิด'),
                ),
                if (widget.canEdit && status == 'RECEIVED')
                  FilledButton.icon(
                    onPressed: _busy ? null : _start,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('เริ่มดำเนินการ'),
                  ),
                if (widget.canEdit && status == 'IN_PROGRESS')
                  FilledButton.icon(
                    onPressed: _busy ? null : _complete,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    icon: const Icon(Icons.task_alt),
                    label: const Text('บันทึกปิดงาน'),
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

class _PartPickerDialog extends StatefulWidget {
  const _PartPickerDialog({required this.lookup, required this.caption});
  final Map<String, dynamic> lookup;
  final String caption;

  @override
  State<_PartPickerDialog> createState() => _PartPickerDialogState();
}

class _PartPickerDialogState extends State<_PartPickerDialog> {
  final _quantityController = TextEditingController(text: '1');
  final Set<int> _selectedSerials = {};
  int? _warehouseId;
  int? _itemId;
  String? _error;

  List<Map<String, dynamic>> get _warehouses =>
      ((widget.lookup['warehouses'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
  List<Map<String, dynamic>> get _items =>
      ((widget.lookup['items'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where(
            (item) =>
                _warehouseId == null || item['warehouseId'] == _warehouseId,
          )
          .toList();
  Map<String, dynamic>? get _selectedItem {
    for (final item in _items) {
      if (item['itemId'] == _itemId) return item;
    }
    return null;
  }

  List<Map<String, dynamic>> get _serials =>
      ((widget.lookup['serials'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where(
            (item) =>
                item['warehouseId'] == _warehouseId &&
                item['itemId'] == _itemId,
          )
          .toList();

  @override
  void initState() {
    super.initState();
    if (_warehouses.isNotEmpty) {
      final selected = _warehouses.cast<Map<String, dynamic>>().firstWhere(
        (item) => item['isDefault'] == true,
        orElse: () => _warehouses.first,
      );
      _warehouseId = (selected['warehouseId'] as num).toInt();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _save() {
    final item = _selectedItem;
    if (_warehouseId == null || item == null) {
      setState(() => _error = 'กรุณาเลือกคลังและอะไหล่');
      return;
    }
    final serial = item['stockTrackingCode'] == 'SERIAL';
    final quantity = serial
        ? _selectedSerials.length.toDouble()
        : double.tryParse(_quantityController.text.trim()) ?? 0;
    final available = (item['availableQuantity'] as num?)?.toDouble() ?? 0;
    if (quantity <= 0 || quantity > available) {
      setState(
        () => _error =
            'จำนวนต้องมากกว่า 0 และไม่เกินสต๊อก ${_quantity(available)}',
      );
      return;
    }
    if (serial && _selectedSerials.isEmpty) {
      setState(() => _error = 'กรุณาเลือก Serial อย่างน้อย 1 รายการ');
      return;
    }
    final warehouse = _warehouses.firstWhere(
      (row) => row['warehouseId'] == _warehouseId,
    );
    final selectedSerialRows = _serials
        .where(
          (row) =>
              _selectedSerials.contains((row['itemInstanceId'] as num).toInt()),
        )
        .toList();
    final unitCost = (item['unitCost'] as num?)?.toDouble() ?? 0;
    Navigator.pop(context, <String, dynamic>{
      'warehouseId': _warehouseId,
      'warehouseName': warehouse['warehouseName'],
      'itemId': item['itemId'],
      'itemCode': item['itemCode'],
      'itemName': item['itemName'],
      'unitCode': item['unitCode'],
      'quantity': quantity,
      'unitCost': unitCost,
      'totalCost': quantity * unitCost,
      'serialInstanceIds': _selectedSerials.toList(),
      'serialNos': selectedSerialRows.map((row) => row['serialNo']).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _selectedItem;
    final serial = item?['stockTrackingCode'] == 'SERIAL';
    return AlertDialog(
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
                  Icons.add_box_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: LaooLayout.cardPadding),
                Expanded(
                  child: Text(
                    '${widget.caption} > เพิ่มอะไหล่ที่ใช้ซ่อม',
                    style: LaooTypography.screenCaptionStyle,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ],
      ),
      content: SizedBox(
        width:
            (MediaQuery.sizeOf(context).width -
                    LaooLayout.dialogInsetPadding * 2 -
                    LaooLayout.cardPadding * 2)
                .clamp(0.0, 480.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _warehouseId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'คลัง *'),
                items: _warehouses
                    .map(
                      (row) => DropdownMenuItem<int>(
                        value: (row['warehouseId'] as num).toInt(),
                        child: Text(
                          '${row['warehouseCode']} | ${row['warehouseName']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _warehouseId = value;
                  _itemId = null;
                  _selectedSerials.clear();
                  _error = null;
                }),
              ),
              const SizedBox(height: LaooLayout.popupFieldSpacing),
              DropdownButtonFormField<int>(
                key: ValueKey(_warehouseId),
                initialValue: _itemId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'อะไหล่ *'),
                items: _items
                    .map(
                      (row) => DropdownMenuItem<int>(
                        value: (row['itemId'] as num).toInt(),
                        child: Text(
                          '${row['itemCode']} | ${row['itemName']} (คงเหลือ ${_quantity(row['availableQuantity'])})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _itemId = value;
                  _selectedSerials.clear();
                  _quantityController.text = '1';
                  _error = null;
                }),
              ),
              const SizedBox(height: LaooLayout.popupFieldSpacing),
              if (!serial)
                TextField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'จำนวน *',
                    helperText: item == null
                        ? null
                        : 'คงเหลือ ${_quantity(item['availableQuantity'])} ${item['unitCode'] ?? ''}',
                  ),
                ),
              if (serial) ...[
                const Text(
                  'เลือก Serial *',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_serials.isEmpty)
                  const Text('ไม่มี Serial พร้อมเบิกในคลังนี้'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final row in _serials)
                      FilterChip(
                        label: Text(row['serialNo']?.toString() ?? '-'),
                        selected: _selectedSerials.contains(
                          (row['itemInstanceId'] as num).toInt(),
                        ),
                        onSelected: (selected) => setState(() {
                          final id = (row['itemInstanceId'] as num).toInt();
                          selected
                              ? _selectedSerials.add(id)
                              : _selectedSerials.remove(id);
                          _error = null;
                        }),
                      ),
                  ],
                ),
              ],
              if (item != null) ...[
                const SizedBox(height: LaooLayout.popupFieldSpacing),
                Text('ต้นทุนต่อหน่วย ${_money(item['unitCost'])} บาท'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Padding(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    child: const Text('ยกเลิก'),
                  ),
                  FilledButton.icon(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มรายการ'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _quantity(Object? value) {
  final number = (value as num?)?.toDouble() ?? 0;
  return number == number.truncateToDouble()
      ? number.toStringAsFixed(0)
      : number.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
}

String _money(Object? value) =>
    ((value as num?)?.toDouble() ?? 0).toStringAsFixed(2);

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
      menuCode: '17002',
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

String _date(Object? value) => value?.toString().split('T').first ?? '-';
String _status(Object? value) => value == 'RECEIVED'
    ? 'รับเรื่องแล้ว'
    : value == 'IN_PROGRESS'
    ? 'กำลังดำเนินการ'
    : value == 'COMPLETED'
    ? 'เสร็จสิ้น'
    : value == 'CANCELLED'
    ? 'ยกเลิก'
    : value?.toString() ?? '-';
