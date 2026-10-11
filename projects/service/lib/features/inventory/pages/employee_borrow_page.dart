import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/company_setup/company_setup_controller.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/employee_borrow_api.dart';

class EmployeeBorrowPage extends StatefulWidget {
  const EmployeeBorrowPage({super.key, required this.menuCode});
  final String menuCode;

  @override
  State<EmployeeBorrowPage> createState() => _EmployeeBorrowPageState();
}

class _EmployeeBorrowPageState extends State<EmployeeBorrowPage> {
  final _api = EmployeeBorrowApi();
  final _search = TextEditingController();
  final _remark = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _lookup = {};
  Map<String, bool> _actions = {};
  String _menuName = '';
  String _status = '';
  bool _loading = true, _saving = false, _form = false, _card = false;
  int _page = 0;
  int? _employeeID, _warehouseID;
  DateTime _planned = DateTime.now(),
      _due = DateTime.now().add(const Duration(days: 7));
  final Map<int, num> _selected = {};
  final Map<int, List<int>> _selectedSerials = {};
  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 20;
  String get _routeName => switch (widget.menuCode) {
    '08009' => 'employeeBorrowApprovals',
    '08010' => 'employeeBorrowTransfers',
    '08011' => 'employeeBorrowHistory',
    _ => 'employeeBorrowRequests',
  };

  @override
  void initState() {
    super.initState();
    _menuName = switch (widget.menuCode) {
      '08009' => 'งานอนุมัติ',
      '08010' => 'ส่งมอบและรับคืน',
      '08011' => 'ประวัติและรายงาน',
      _ => 'คำขอยืม',
    };
    _resolveName();
    _loadViewMode();
    _load();
  }

  Future<void> _loadViewMode() async {
    try {
      final profile = await UserProfileRepository().get();
      if (mounted)
        setState(
          () => _card = '${profile['defaultViewMode']}'.toUpperCase() == 'CARD',
        );
    } catch (_) {}
  }

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _resolveName() async {
    try {
      final name = await NavigationMenuRepository().resolveMenuName(
        menuCode: widget.menuCode,
        routeName: _routeName,
        fallback: _menuName,
      );
      if (mounted) setState(() => _menuName = name);
    } catch (_) {}
  }

  String _error(String action, Object error) {
    final detail = error is ApiException
        ? (error.description ?? error.message)
        : 'กรุณาตรวจสอบข้อมูลและการเชื่อมต่อแล้วลองใหม่';
    return 'ไม่สามารถ$actionได้\nรายละเอียดเพิ่มเติม: $detail';
  }

  void _notice(String text, {bool error = false}) {
    if (mounted) showTimedSnackBar(context, message: text, error: error);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _api.actions(widget.menuCode),
        _api.requests(widget.menuCode, status: _status),
        if (widget.menuCode == '08008') _api.lookup(),
      ]);
      if (!mounted) return;
      setState(() {
        _actions = values[0] as Map<String, bool>;
        _rows = values[1] as List<Map<String, dynamic>>;
        if (widget.menuCode == '08008')
          _lookup = values[2] as Map<String, dynamic>;
        _loading = false;
        _page = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _notice(_error('โหลดรายการยืม–คืน', e), error: true);
    }
  }

  List<Map<String, dynamic>> get _visible {
    final text = _search.text.trim().toLowerCase();
    if (text.isEmpty) return _rows;
    return _rows
        .where(
          (r) =>
              '${r['requestCode']} ${r['employeeName']} ${r['warehouseName']}'
                  .toLowerCase()
                  .contains(text),
        )
        .toList();
  }

  static int _id(dynamic value) => (value as num).toInt();
  static List<Map<String, dynamic>> _list(dynamic value) =>
      List<Map<String, dynamic>>.from(value as List? ?? const []);
  String _date(dynamic value) {
    final date = DateTime.tryParse('$value');
    if (date == null) return '$value';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _statusName(String value) => switch (value) {
    'WAIT_APPROVAL' => 'รออนุมัติ',
    'READY' => 'พร้อมส่งมอบ',
    'REJECTED' => 'ไม่อนุมัติ',
    'CANCELLED' => 'ยกเลิก',
    'ISSUED' => 'ส่งมอบแล้ว',
    'PARTIAL_RETURN' => 'คืนบางส่วน',
    'RETURNED' => 'คืนครบ',
    _ => value,
  };

  Widget _statusPill(BuildContext context, String value) {
    final color = value == 'REJECTED' || value == 'CANCELLED'
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Text(
        _statusName(value),
        style: TextStyle(
          color: color,
          fontSize: LaooTypography.tableBody,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _section(Widget child, {EdgeInsetsGeometry? padding}) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: LaooColors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );

  Widget _header(BuildContext context, bool compact) => _section(
    Row(
      children: [
        Icon(
          Icons.swap_horiz_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            _form ? '$_menuName > เพิ่ม' : _menuName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: LaooColors.pageCaption,
            ),
          ),
        ),
        const LaooPageFavoriteButton(),
        const Spacer(),
        if (!_form && !compact) ...[
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: _card ? 'แสดงรายการ' : 'แสดงการ์ด',
            onPressed: () => setState(() => _card = !_card),
            icon: Icon(
              _card ? Icons.list_alt_outlined : Icons.grid_view_outlined,
            ),
          ),
        ],
        if (!_form &&
            widget.menuCode == '08008' &&
            _actions['create'] == true) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => setState(() {
              _form = true;
              _selected.clear();
              _selectedSerials.clear();
            }),
            icon: const Icon(Icons.add),
            label: const Text('เพิ่ม'),
          ),
        ],
      ],
    ),
  );

  Widget _filter() => _section(
    Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _search,
            onSubmitted: (_) => setState(() => _page = 0),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ค้นหาเลขที่หรือพนักงาน',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'สถานะ',
              border: OutlineInputBorder(),
            ),
            items:
                [
                      '',
                      'WAIT_APPROVAL',
                      'READY',
                      'ISSUED',
                      'PARTIAL_RETURN',
                      'RETURNED',
                      'REJECTED',
                      'CANCELLED',
                    ]
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.isEmpty ? 'ทั้งหมด' : _statusName(s)),
                      ),
                    )
                    .toList(),
            onChanged: (value) => _status = value ?? '',
          ),
        ),
        FilledButton.icon(
          onPressed: () {
            setState(() => _page = 0);
            _load();
          },
          icon: const Icon(Icons.search),
          label: const Text('ค้นหา'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            _search.clear();
            _status = '';
            _load();
          },
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('ล้าง Filter'),
        ),
      ],
    ),
  );

  Widget _rowActions(Map<String, dynamic> row) {
    final id = _id(row['requestID']);
    final status = '${row['statusCode']}';
    final buttons = <Widget>[
      TextButton.icon(
        onPressed: () => _detail(id),
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('ดูรายการ'),
      ),
    ];
    if (widget.menuCode == '08009' && status == 'WAIT_APPROVAL') {
      if (_actions['approve'] == true)
        buttons.add(
          TextButton.icon(
            onPressed: () => _decision(id, true),
            icon: const Icon(Icons.check),
            label: const Text('อนุมัติ'),
          ),
        );
      if (_actions['reject'] == true)
        buttons.add(
          TextButton.icon(
            onPressed: () => _decision(id, false),
            icon: const Icon(Icons.undo),
            label: const Text('ปฏิเสธ'),
          ),
        );
    }
    if (widget.menuCode == '08010' &&
        ['READY', 'ISSUED', 'PARTIAL_RETURN'].contains(status)) {
      if (_actions['issue'] == true && status != 'RETURNED')
        buttons.add(
          TextButton.icon(
            onPressed: () => _transfer(id, false),
            icon: const Icon(Icons.outbox_outlined),
            label: const Text('ส่งมอบ'),
          ),
        );
      if (_actions['return'] == true && status != 'READY')
        buttons.add(
          TextButton.icon(
            onPressed: () => _transfer(id, true),
            icon: const Icon(Icons.move_to_inbox_outlined),
            label: const Text('รับคืน'),
          ),
        );
    }
    if (widget.menuCode == '08008' &&
        _actions['delete'] == true &&
        ['WAIT_APPROVAL', 'READY'].contains(status)) {
      buttons.add(
        TextButton.icon(
          onPressed: () => _cancel(id),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('ยกเลิก'),
        ),
      );
    }
    return Wrap(spacing: 2, children: buttons);
  }

  Widget _results(BuildContext context, bool compact) {
    if (_loading)
      return Expanded(
        child: _section(const Center(child: CircularProgressIndicator())),
      );
    final rows = _visible;
    final start = _page * _pageSize;
    final pageRows = rows.skip(start).take(_pageSize).toList();
    if (rows.isEmpty)
      return Expanded(
        child: _section(
          Center(
            child: Text(
              _search.text.trim().isNotEmpty || _status.isNotEmpty
                  ? 'ไม่พบรายการตามเงื่อนไขที่ค้นหา'
                  : 'ยังไม่มีคำขอยืม',
            ),
          ),
        ),
      );
    return Expanded(
      child: _section(
        compact || _card
            ? ListView.separated(
                itemCount: pageRows.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: LaooLayout.listItemSpacing),
                itemBuilder: (context, i) {
                  final row = pageRows[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: LaooColors.border),
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${row['requestCode']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _statusPill(context, '${row['statusCode']}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${row['employeeName']} · ${row['warehouseName']}',
                        ),
                        Text(
                          'ครบกำหนด ${_date(row['dueDate'])} · ${row['itemCount']} รายการ',
                        ),
                        _rowActions(row),
                      ],
                    ),
                  );
                },
              )
            : LayoutBuilder(
                builder: (context, bounds) => ListView(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: bounds.maxWidth),
                        child: DataTable(
                          headingRowColor: WidgetStatePropertyAll(
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .1),
                          ),
                          columns: const [
                            DataColumn(label: Text('ID')),
                            DataColumn(label: Text('Action')),
                            DataColumn(label: Text('เลขที่')),
                            DataColumn(label: Text('พนักงาน')),
                            DataColumn(label: Text('คลัง')),
                            DataColumn(label: Text('กำหนดคืน')),
                            DataColumn(label: Text('สถานะ')),
                          ],
                          rows: [
                            for (var i = 0; i < pageRows.length; i++)
                              DataRow(
                                cells: [
                                  DataCell(Text('${start + i + 1}')),
                                  DataCell(_rowActions(pageRows[i])),
                                  DataCell(
                                    Text('${pageRows[i]['requestCode']}'),
                                  ),
                                  DataCell(
                                    Text('${pageRows[i]['employeeName']}'),
                                  ),
                                  DataCell(
                                    Text('${pageRows[i]['warehouseName']}'),
                                  ),
                                  DataCell(Text(_date(pageRows[i]['dueDate']))),
                                  DataCell(
                                    _statusPill(
                                      context,
                                      '${pageRows[i]['statusCode']}',
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _pager() {
    final count = _visible.length;
    final from = count == 0 ? 0 : _page * _pageSize + 1;
    final to = (_page * _pageSize + _pageSize).clamp(0, count);
    return SizedBox(
      height: LaooLayout.paginationCardHeight,
      child: _section(
        Row(
          children: [
            IconButton.outlined(
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 6),
            Text('${_page + 1}'),
            const SizedBox(width: 6),
            IconButton.outlined(
              onPressed: to < count ? () => setState(() => _page++) : null,
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text('$from-$to จาก $count')),
          ],
        ),
      ),
    );
  }

  Future<void> _detail(int id) async {
    try {
      final data = await _api.detail(id);
      if (!mounted) return;
      final head = Map<String, dynamic>.from(data['header'] as Map);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          title: Text('$_menuName > ${head['requestCode']}'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ผู้ยืม: ${head['employeeName']}'),
                  Text('คลัง: ${head['warehouseName']}'),
                  Text('ครบกำหนด: ${_date(head['dueDate'])}'),
                  Text('สถานะ: ${_statusName('${head['statusCode']}')}'),
                  if (head['routeName'] != null)
                    Text('สายอนุมัติ: ${head['routeName']}'),
                  const Divider(),
                  for (final line in _list(data['lines']))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${line['itemCode']} ${line['itemName']} · ${line['quantity']} ยืม / ${line['returnedQuantity']} คืน',
                      ),
                    ),
                  for (final serial in _list(data['serials']))
                    Text('SN ${serial['serialNo']} · ${serial['statusCode']}'),
                  if (_list(data['photos']).isNotEmpty) ...[
                    const Divider(),
                    const Text(
                      'รูปส่งมอบและรับคืน',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final photo in _list(data['photos']))
                      TextButton.icon(
                        onPressed: () => _showPhoto(_id(photo['photoID'])),
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          '${photo['transferType'] == 'RETURN' ? 'รับคืน' : 'ส่งมอบ'} · ${photo['fileName']}',
                        ),
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
        ),
      );
    } catch (e) {
      _notice(_error('โหลดรายละเอียด', e), error: true);
    }
  }

  Future<void> _showPhoto(int photoID) async {
    try {
      final bytes = await _api.photo(photoID);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
            child: InteractiveViewer(
              child: Image.memory(Uint8List.fromList(bytes)),
            ),
          ),
        ),
      );
    } catch (e) {
      _notice(_error('เปิดรูปหลักฐาน', e), error: true);
    }
  }

  Future<void> _decision(int id, bool approve) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        title: Text('$_menuName > ${approve ? 'อนุมัติ' : 'ปฏิเสธ'}'),
        content: approve
            ? const Text('ยืนยันอนุมัติคำขอนี้ตามสายอนุมัติที่กำหนด')
            : TextField(
                controller: reason,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'เหตุผล *',
                  border: OutlineInputBorder(),
                ),
              ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'อนุมัติ' : 'ปฏิเสธ'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      reason.dispose();
      return;
    }
    if (!approve && reason.text.trim().isEmpty) {
      reason.dispose();
      _notice('กรุณาระบุเหตุผล', error: true);
      return;
    }
    try {
      if (approve) {
        await _api.approve(id);
      } else {
        await _api.reject(id, reason.text.trim());
      }
      _notice(approve ? 'อนุมัติแล้ว' : 'ปฏิเสธและปล่อยของที่กันไว้แล้ว');
      await _load();
    } catch (e) {
      _notice(_error(approve ? 'อนุมัติ' : 'ปฏิเสธ', e), error: true);
    }
    reason.dispose();
  }

  Future<void> _cancel(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        title: const Text('ยกเลิกคำขอยืม'),
        content: const Text(
          'ระบบจะปล่อยสินค้าที่กันไว้ และเก็บประวัติการยกเลิก',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('กลับ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.cancel(id);
      _notice('ยกเลิกคำขอแล้ว');
      await _load();
    } catch (e) {
      _notice(_error('ยกเลิกคำขอ', e), error: true);
    }
  }

  Future<void> _transfer(int id, bool returning) async {
    try {
      final data = await _api.detail(id);
      if (!mounted) return;
      final lines = _list(data['lines'])
          .where(
            (line) => returning
                ? (line['issuedQuantity'] as num) >
                      (line['returnedQuantity'] as num)
                : (line['quantity'] as num) > (line['issuedQuantity'] as num),
          )
          .toList();
      if (lines.isEmpty) {
        _notice('ไม่มีรายการคงค้างสำหรับขั้นตอนนี้');
        return;
      }
      Map<String, dynamic> selected = lines.first;
      int? instanceID;
      final qty = TextEditingController(text: '1');
      final note = TextEditingController();
      PlatformFile? photo;
      final serials = _list(data['serials']);
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) {
            final availableSerials = serials
                .where(
                  (s) =>
                      _id(s['lineID']) == _id(selected['lineID']) &&
                      s['statusCode'] == (returning ? 'ISSUED' : 'RESERVED'),
                )
                .toList();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
              title: Text('$_menuName > ${returning ? 'รับคืน' : 'ส่งมอบ'}'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('เอกสาร ${data['header']['requestCode']}'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _id(selected['lineID']),
                        decoration: const InputDecoration(
                          labelText: 'สินค้า *',
                          border: OutlineInputBorder(),
                        ),
                        items: lines
                            .map(
                              (line) => DropdownMenuItem(
                                value: _id(line['lineID']),
                                child: Text(
                                  '${line['itemCode']} ${line['itemName']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => update(() {
                          selected = lines.firstWhere(
                            (x) => _id(x['lineID']) == v,
                          );
                          instanceID = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      if (selected['tracking'] == 'SERIAL')
                        DropdownButtonFormField<int>(
                          value: instanceID,
                          decoration: const InputDecoration(
                            labelText: 'SN *',
                            border: OutlineInputBorder(),
                          ),
                          items: availableSerials
                              .map(
                                (s) => DropdownMenuItem(
                                  value: _id(s['instanceID']),
                                  child: Text('${s['serialNo']}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => update(() => instanceID = v),
                        )
                      else
                        TextField(
                          controller: qty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'จำนวน *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: note,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'สภาพ/หมายเหตุ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          if (result != null)
                            update(() => photo = result.files.single);
                        },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          photo?.name ??
                              (returning
                                  ? 'แนบรูปตอนรับคืน *'
                                  : 'แนบรูปก่อนส่งมอบ *'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed:
                      photo?.bytes == null ||
                          (selected['tracking'] == 'SERIAL' &&
                              instanceID == null)
                      ? null
                      : () => Navigator.pop(context, true),
                  child: Text(returning ? 'ยืนยันรับคืน' : 'ยืนยันส่งมอบ'),
                ),
              ],
            );
          },
        ),
      );
      if (saved == true && photo?.bytes != null) {
        final amount = selected['tracking'] == 'SERIAL'
            ? 1
            : num.tryParse(qty.text);
        if (amount == null || amount <= 0) {
          _notice('จำนวนไม่ถูกต้อง', error: true);
        } else {
          await _api.transfer(
            requestID: id,
            lineID: _id(selected['lineID']),
            returning: returning,
            fileName: photo!.name,
            bytes: photo!.bytes!,
            quantity: amount,
            instanceID: instanceID,
            conditionNote: note.text,
          );
          _notice(
            returning ? 'รับคืนและคืนยอดคลังแล้ว' : 'ส่งมอบและตัดยอดคลังแล้ว',
          );
          await _load();
        }
      }
      qty.dispose();
      note.dispose();
    } catch (e) {
      _notice(_error(returning ? 'รับคืน' : 'ส่งมอบ', e), error: true);
    }
  }

  Widget _formBody(BuildContext context, bool compact) {
    final employees = _list(_lookup['employees']);
    final warehouses = _list(_lookup['warehouses']);
    final items = _list(_lookup['items']);
    final serials = _list(_lookup['serials']);
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _section(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Header · ผู้ยืมและกำหนดคืน',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: compact ? double.infinity : 280,
                        child: DropdownButtonFormField<int>(
                          value: _employeeID,
                          decoration: const InputDecoration(
                            labelText: 'พนักงานผู้ยืม *',
                            border: OutlineInputBorder(),
                          ),
                          items: employees
                              .map(
                                (e) => DropdownMenuItem(
                                  value: _id(e['employeeID']),
                                  child: Text('${e['fullName']}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _employeeID = v),
                        ),
                      ),
                      SizedBox(
                        width: compact ? double.infinity : 280,
                        child: DropdownButtonFormField<int>(
                          value: _warehouseID,
                          decoration: const InputDecoration(
                            labelText: 'คลัง *',
                            border: OutlineInputBorder(),
                          ),
                          items: warehouses
                              .map(
                                (e) => DropdownMenuItem(
                                  value: _id(e['warehouseID']),
                                  child: Text('${e['warehouseName']}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _warehouseID = v;
                            _selectedSerials.clear();
                          }),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            initialDate: _planned,
                          );
                          if (picked != null) setState(() => _planned = picked);
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('เริ่มยืม ${_date(_planned)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: _planned,
                            lastDate: _planned.add(const Duration(days: 365)),
                            initialDate: _due.isBefore(_planned)
                                ? _planned
                                : _due,
                          );
                          if (picked != null) setState(() => _due = picked);
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: Text('กำหนดคืน ${_date(_due)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _remark,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'หมายเหตุ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LaooLayout.listSectionSpacing),
            _section(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detail · เลือกสินค้าและ SN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'หากสินค้าใช้คนละสายอนุมัติ ระบบแยกเลขคำขอให้อัตโนมัติ',
                  ),
                  for (final item in items) ...[
                    const Divider(),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item['itemCode']} · ${item['itemName']}'),
                      subtitle: Text(
                        'ยืมได้สูงสุด ${item['maxDays']} วัน · ${item['approvalRequired'] == true ? 'ต้องอนุมัติ' : 'ไม่ต้องอนุมัติ'}',
                      ),
                      value: _selected.containsKey(_id(item['itemID'])),
                      onChanged: (on) => setState(() {
                        final id = _id(item['itemID']);
                        if (on == true) {
                          _selected[id] = 1;
                        } else {
                          _selected.remove(id);
                          _selectedSerials.remove(id);
                        }
                      }),
                    ),
                    if (_selected.containsKey(_id(item['itemID'])))
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 8),
                        child: item['tracking'] == 'SERIAL'
                            ? Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final serial in serials.where(
                                    (s) =>
                                        _id(s['itemID']) ==
                                            _id(item['itemID']) &&
                                        (_warehouseID == null ||
                                            _id(s['warehouseID']) ==
                                                _warehouseID),
                                  ))
                                    FilterChip(
                                      label: Text('${serial['serialNo']}'),
                                      selected:
                                          (_selectedSerials[_id(
                                                    item['itemID'],
                                                  )] ??
                                                  [])
                                              .contains(
                                                _id(serial['instanceID']),
                                              ),
                                      onSelected: (on) => setState(() {
                                        final selected = _selectedSerials
                                            .putIfAbsent(
                                              _id(item['itemID']),
                                              () => [],
                                            );
                                        if (on) {
                                          selected.add(
                                            _id(serial['instanceID']),
                                          );
                                        } else {
                                          selected.remove(
                                            _id(serial['instanceID']),
                                          );
                                        }
                                        _selected[_id(item['itemID'])] =
                                            selected.length;
                                      }),
                                    ),
                                ],
                              )
                            : SizedBox(
                                width: 130,
                                child: TextFormField(
                                  initialValue:
                                      '${_selected[_id(item['itemID'])]}',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'จำนวน *',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) =>
                                      _selected[_id(item['itemID'])] =
                                          num.tryParse(v) ?? 0,
                                ),
                              ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: LaooLayout.listSectionSpacing),
            _section(
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _form = false),
                      child: const Text('ยกเลิก'),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'กำลังบันทึก' : 'บันทึกคำขอ'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_employeeID == null ||
        _warehouseID == null ||
        _selected.isEmpty ||
        _selected.values.any((v) => v <= 0)) {
      _notice('เลือกพนักงาน คลัง สินค้า และจำนวนให้ครบ', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _api.create({
        'employeeID': _employeeID,
        'warehouseID': _warehouseID,
        'plannedIssueDate': _iso(_planned),
        'dueDate': _iso(_due),
        'remark': _remark.text.trim(),
        'lines': [
          for (final e in _selected.entries)
            {
              'itemID': e.key,
              'quantity': e.value,
              'serialIDs': _selectedSerials[e.key] ?? <int>[],
            },
        ],
      });
      if (!mounted) return;
      final count = (result['requests'] as List).length;
      _notice('บันทึก $count ใบ แยกตามสายอนุมัติและกันของแล้ว');
      setState(() {
        _form = false;
        _selected.clear();
        _selectedSerials.clear();
      });
      await _load();
    } catch (e) {
      _notice(_error('บันทึกคำขอ', e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _menuName,
    activeMenu: _routeName,
    menuScope: WorkspaceMenuScope.company,
    child: LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 900;
        return Padding(
          padding: const EdgeInsets.all(LaooLayout.cardMargin),
          child: Column(
            children: [
              _header(context, compact),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              if (_form)
                _formBody(context, compact)
              else ...[
                _filter(),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                _results(context, compact),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                _pager(),
              ],
            ],
          ),
        );
      },
    ),
  );
}
