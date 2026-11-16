import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'comparison.dart';
import 'feature_host.dart';

class SapPmsComparisonPage extends StatefulWidget {
  const SapPmsComparisonPage({super.key});
  @override
  State<SapPmsComparisonPage> createState() => _SapPmsComparisonPageState();
}

class _HistoryDialog extends StatefulWidget {
  const _HistoryDialog({required this.api, required this.buddhistYear});
  final JsonApiClient api;
  final bool buddhistYear;
  @override
  State<_HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<_HistoryDialog> {
  List<dynamic> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.get(
        '/api/sap-pms/history',
        query: {'page': '1', 'pageSize': '10'},
      );
      if (result is! Map || result['items'] is! List)
        throw const FormatException('ข้อมูลประวัติไม่ถูกต้อง');
      if (mounted)
        setState(() {
          items = (result['items'] as List).take(10).toList();
        });
    } catch (e) {
      if (mounted) setState(() => error = 'โหลดประวัติไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String date(dynamic raw, {bool time = false}) {
    final value = DateTime.tryParse('$raw');
    if (value == null) return 'ไม่ระบุ';
    final d = time ? value.toLocal() : value;
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + (widget.buddhistYear ? 543 : 0)}';
    return time
        ? '$date ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
        : date;
  }

  Widget _countBadge(String label, dynamic count, {bool problem = false}) {
    final color = problem && (int.tryParse('$count') ?? 0) > 0
        ? Theme.of(context).colorScheme.error
        : sapPmsTokens.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label $count', style: TextStyle(color: color)),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: SizedBox(
      width: 1000,
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: sapPmsTokens.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ประวัติการเปรียบเทียบ (แสดง 10 ครั้งล่าสุด)',
                    style: sapPmsTokens.sectionStyle,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'ปิด',
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(child: Text(error!))
                  : items.isEmpty
                  ? const Center(child: Text('ไม่พบประวัติการเปรียบเทียบ'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = items[index] as Map;
                        final numbers =
                            '${row['problemDocumentNumbers'] ?? ''}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${date(row['comparedAt'], time: true)}  •  ${row['employeeName'] ?? '-'}',
                                style: sapPmsTokens.sectionStyle,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'PMS: ${row['pmsFileName']} (${row['pmsRecordCount']} รายการ)  •  SAP: ${row['sapFileName']} (${row['sapRecordCount']} รายการ)',
                              ),
                              Text(
                                'ช่วงวันที่: ${date(row['dateFrom'])} - ${date(row['dateTo'])}',
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _countBadge('ทั้งหมด', row['totalCount']),
                                  _countBadge('ปกติ', row['normalCount']),
                                  _countBadge(
                                    'พบปัญหา',
                                    row['problemCount'],
                                    problem: true,
                                  ),
                                  _countBadge('ยังไม่ส่ง', row['waitingCount']),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'เลขที่เอกสารที่พบปัญหา: ${numbers.isEmpty ? '-' : numbers}',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Row(
              children: [
                Text('แสดง ${items.length} ครั้งล่าสุด'),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _SapPmsComparisonPageState extends State<SapPmsComparisonPage> {
  late final JsonApiClient _api;
  String _title = 'ตรวจสอบข้อมูล API SAP-PMS';
  SheetData? _pms, _sap;
  String? _pmsName, _sapName;
  DateTime? _from, _to;
  List<ComparisonRow> _rows = [];
  String _filter = 'all';
  int _page = 1;
  bool _compared = false, _busy = false, _canExport = false;
  bool _cardView = false;
  String _yearFormat = 'AD';
  int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _api = sapPmsClient();
    _loadPermissions();
    _loadDefaultView();
    _loadYearFormat();
    sapPmsTitle().then((value) {
      if (mounted) setState(() => _title = value);
    });
  }

  @override
  void dispose() {
    disposeSapPmsClient(_api);
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    try {
      final data = await _api.get('/api/sap-pms/permissions');
      if (mounted)
        setState(() => _canExport = data is Map && data['canExport'] == true);
    } catch (_) {
      if (mounted)
        sapPmsMessage(context, 'ไม่สามารถตรวจสิทธิ์ส่งออกได้', error: true);
    }
  }

  Future<void> _loadDefaultView() async {
    try {
      final profile = await _api.get('/api/user-profile');
      if (mounted && profile is Map) {
        setState(
          () => _cardView =
              '${profile['defaultViewMode'] ?? ''}'.toUpperCase() == 'CARD',
        );
      }
    } catch (_) {
      if (mounted)
        sapPmsMessage(
          context,
          'ไม่สามารถโหลดรูปแบบแสดงผลของผู้ใช้',
          error: true,
        );
    }
  }

  Future<void> _loadYearFormat() async {
    try {
      final settings = await _api.get('/api/system/company-setup/runtime');
      if (mounted && settings is Map) {
        setState(() {
          _yearFormat = '${settings['yearFormat'] ?? 'AD'}';
          final size = int.tryParse(
            '${settings['rowSTD'] ?? settings['rowStd'] ?? ''}',
          );
          _pageSize = size != null && size > 0 ? size : 50;
          _page = 1;
        });
      }
    } catch (_) {
      if (mounted)
        sapPmsMessage(context, 'ไม่สามารถโหลดรูปแบบปีของบริษัท', error: true);
    }
  }

  bool get _buddhistYear =>
      {'B', 'BE', 'T', 'TH', 'THAI'}.contains(_yearFormat.trim().toUpperCase());

  String _resultDate(String value) {
    if (!_buddhistYear) return value;
    final match = RegExp(r'^(\d{2}/\d{2}/)(\d{4})$').firstMatch(value);
    return match == null ? value : '${match[1]}${int.parse(match[2]!) + 543}';
  }

  Future<void> _choose(bool pms) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (picked == null) return;
      final file = picked.files.single;
      final requiredName = pms ? 'pms' : 'sap';
      if (!file.name.toLowerCase().contains(requiredName)) {
        if (mounted) {
          sapPmsMessage(
            context,
            'ชื่อไฟล์ต้องมีคำว่า ${requiredName.toUpperCase()}',
            error: true,
          );
        }
        return;
      }
      if (file.bytes == null)
        throw const FormatException('ไม่สามารถอ่านไฟล์ได้');
      final data = PmsSapComparison.read(file.bytes!);
      if (!mounted) return;
      setState(() {
        if (pms) {
          _pms = data;
          _pmsName = file.name;
        } else {
          _sap = data;
          _sapName = file.name;
        }
        _rows = [];
        _compared = false;
        _page = 1;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          if (pms) {
            _pms = null;
            _pmsName = null;
          } else {
            _sap = null;
            _sapName = null;
          }
          _rows = [];
          _compared = false;
          _page = 1;
        });
        sapPmsMessage(context, 'เปิดไฟล์ Excel ไม่สำเร็จ: $error', error: true);
      }
    }
  }

  Future<void> _selectDate(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (selected != null && mounted)
      setState(() {
        if (from) {
          _from = selected;
        } else {
          _to = selected;
        }
        _compared = false;
        _rows = [];
        _page = 1;
      });
  }

  String _date(DateTime? value) => value == null
      ? 'ไม่ระบุ'
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year + (_buddhistYear ? 543 : 0)}';
  Future<void> _compare() async {
    if (_pms == null || _sap == null) {
      sapPmsMessage(context, 'กรุณาเลือกไฟล์ PMS และ SAP', error: true);
      return;
    }
    if (_from != null && _to != null && _from!.isAfter(_to!)) {
      sapPmsMessage(
        context,
        'วันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด',
        error: true,
      );
      return;
    }
    if (_from == null && _to == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ยืนยันการเปรียบเทียบ'),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: .6,
                color: sapPmsTokens.borderColor,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ไม่ได้ระบุช่วงวันที่ ต้องการเปรียบเทียบทั้งหมดใช่หรือไม่',
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: .6,
                color: sapPmsTokens.borderColor,
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('เปรียบเทียบทั้งหมด'),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      final rows = PmsSapComparison.compare(_pms!, _sap!, from: _from, to: _to);
      setState(() {
        _rows = rows;
        _compared = true;
        _filter = 'all';
        _page = 1;
      });
      String? iso(DateTime? date) => date == null
          ? null
          : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      try {
        await _api.post(
          '/api/sap-pms/history',
          body: {
            'pmsFileName': _pmsName,
            'pmsRecordCount': _pms!.rows.length,
            'sapFileName': _sapName,
            'sapRecordCount': _sap!.rows.length,
            'dateFrom': iso(_from),
            'dateTo': iso(_to),
            'totalCount': rows.length,
            'normalCount': rows.where((r) => r.status == 'normal').length,
            'problemCount': rows.where((r) => r.status == 'problem').length,
            'waitingCount': rows.where((r) => r.status == 'waiting').length,
            'problemDocumentNumbers': rows
                .where((r) => r.status == 'problem' && r.number != '-')
                .map((r) => r.number)
                .toSet()
                .join(','),
          },
        );
        if (mounted) sapPmsMessage(context, 'เปรียบเทียบและบันทึกประวัติแล้ว');
      } catch (error) {
        if (mounted)
          sapPmsMessage(
            context,
            'เปรียบเทียบแล้ว แต่บันทึกประวัติไม่สำเร็จ: $error',
            error: true,
          );
      }
    } catch (error) {
      if (mounted)
        sapPmsMessage(context, 'เปรียบเทียบไม่สำเร็จ: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<ComparisonRow> get _visible => _filter == 'all'
      ? _rows
      : _rows.where((x) => x.status == _filter).toList();
  Future<void> _export() async {
    if (!_canExport || !_compared || _busy) return;
    setState(() => _busy = true);
    try {
      final permission = await _api.get('/api/sap-pms/permissions');
      if (permission is! Map || permission['canExport'] != true) {
        if (mounted) {
          setState(() => _canExport = false);
          sapPmsMessage(context, 'ไม่มีสิทธิ์ส่งออกข้อมูล', error: true);
        }
        return;
      }
      await FilePicker.platform.saveFile(
        fileName: 'pms_sap_comparison.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: PmsSapComparison.export(
          _visible
              .map(
                (r) => ComparisonRow(
                  status: r.status,
                  number: r.number,
                  date: _resultDate(r.date),
                  pmsStatus: r.pmsStatus,
                  result: r.result,
                  details: r.details,
                ),
              )
              .toList(),
        ),
      );
    } catch (error) {
      if (mounted)
        sapPmsMessage(context, 'ส่งออก Excel ไม่สำเร็จ: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, Widget child, {Widget? action}) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (action != null && constraints.maxWidth <= 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: sapPmsTokens.sectionStyle),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(title, style: sapPmsTokens.sectionStyle),
                  ),
                  if (action != null) action,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
  Widget _file(bool pms) => SizedBox(
    width: 220,
    child: OutlinedButton.icon(
      onPressed: _busy ? null : () => _choose(pms),
      icon: const Icon(Icons.upload_file),
      label: Text(
        '${pms ? 'PMS' : 'SAP'}: ${(pms ? _pmsName : _sapName) ?? 'เลือกไฟล์ Excel'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
  Widget _stat(String value, String label, int count) => OutlinedButton(
    onPressed: () => setState(() {
      _filter = value;
      _page = 1;
    }),
    style: OutlinedButton.styleFrom(
      backgroundColor: _filter == value
          ? sapPmsTokens.primaryColor.withValues(alpha: .12)
          : null,
    ),
    child: Text(
      '$label  $count',
      style: TextStyle(
        color: value == 'problem' ? Theme.of(context).colorScheme.error : null,
      ),
    ),
  );
  Widget _resultCard(ComparisonRow row) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.number, style: sapPmsTokens.sectionStyle),
          Text('วันที่เอกสาร PMS: ${_resultDate(row.date)}'),
          Text('PmsStatus: ${row.pmsStatus}'),
          Text(
            row.result,
            style: TextStyle(
              color: row.status == 'problem'
                  ? Theme.of(context).colorScheme.error
                  : row.status == 'waiting'
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : sapPmsTokens.primaryColor,
            ),
          ),
          if (row.details != '-') Text(row.details),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => sapPmsShell(
    pageTitle: _title,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth <= 600,
            filtered = _visible,
            first = filtered.isEmpty ? 0 : (_page - 1) * _pageSize,
            start = first > filtered.length ? filtered.length : first,
            end = (start + _pageSize).clamp(0, filtered.length),
            pageRows = filtered.sublist(start, end);
        return ListView(
          padding: EdgeInsets.all(narrow ? 10 : 24),
          children: [
            _section(
              _title,
              Text(
                'เปรียบเทียบข้อมูลจากไฟล์ PMS และ SAP โดยบันทึกเฉพาะสรุปประวัติ',
                style: sapPmsTokens.inputStyle,
              ),
              action: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) => _HistoryDialog(
                              api: _api,
                              buddhistYear: _buddhistYear,
                            ),
                          ),
                    icon: const Icon(Icons.history),
                    label: const Text('ตรวจสอบประวัติ'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _compare,
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('เปรียบเทียบ'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _section(
              'เลือกไฟล์และกำหนดช่วงวันที่',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _file(true),
                      _file(false),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _selectDate(true),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('ตั้งแต่ ${_date(_from)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _selectDate(false),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('ถึง ${_date(_to)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _from = null;
                                _to = null;
                                _filter = 'all';
                                _rows = [];
                                _compared = false;
                                _page = 1;
                              }),
                        icon: const Icon(Icons.clear),
                        label: const Text('ล้าง Filter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'กรองวันที่จาก PMS · รายการ SAP ที่ไม่มีคู่ PMS แสดงทั้งหมด',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ชื่อไฟล์ PMS ต้องมีคำว่า PMS และชื่อไฟล์ SAP ต้องมีคำว่า SAP (ไม่แยกตัวพิมพ์เล็ก–ใหญ่)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _section(
              'ผลการตรวจสอบ',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _stat('all', 'ทั้งหมด', _rows.length),
                      _stat(
                        'problem',
                        'พบปัญหา',
                        _rows.where((x) => x.status == 'problem').length,
                      ),
                      _stat(
                        'normal',
                        'ปกติ',
                        _rows.where((x) => x.status == 'normal').length,
                      ),
                      Text(
                        'ยังไม่ส่ง ${_rows.where((x) => x.status == 'waiting').length}',
                      ),
                      if (_canExport)
                        OutlinedButton.icon(
                          onPressed: _compared && !_busy ? _export : null,
                          icon: const Icon(Icons.download),
                          label: const Text('ส่งออก Excel'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_compared)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text('เลือกไฟล์ทั้งสองและกดเปรียบเทียบ'),
                      ),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('ไม่พบข้อมูล')),
                    )
                  else if (narrow || _cardView)
                    ...pageRows.map(_resultCard)
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 56,
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 56,
                        horizontalMargin: 8,
                        dividerThickness: .6,
                        border: TableBorder(
                          horizontalInside: BorderSide(
                            color: sapPmsTokens.borderColor,
                            width: .6,
                          ),
                          bottom: BorderSide(
                            color: sapPmsTokens.borderColor,
                            width: .6,
                          ),
                        ),
                        dataTextStyle: sapPmsTokens.tableStyle,
                        headingRowColor: WidgetStatePropertyAll(
                          sapPmsTokens.primaryColor.withValues(alpha: .12),
                        ),
                        headingTextStyle: TextStyle(
                          color: sapPmsTokens.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('สถานะ')),
                          DataColumn(label: Text('เลขที่เอกสาร')),
                          DataColumn(label: Text('วันที่เอกสาร PMS')),
                          DataColumn(label: Text('PmsStatus')),
                          DataColumn(label: Text('ผลตรวจสอบ')),
                          DataColumn(label: Text('รายละเอียด')),
                        ],
                        rows: pageRows
                            .map(
                              (r) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      r.status == 'problem'
                                          ? 'พบปัญหา'
                                          : r.status == 'waiting'
                                          ? 'ยังไม่ส่ง'
                                          : 'ปกติ',
                                      style: TextStyle(
                                        color: r.status == 'problem'
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.error
                                            : r.status == 'waiting'
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant
                                            : sapPmsTokens.primaryColor,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(r.number)),
                                  DataCell(Text(_resultDate(r.date))),
                                  DataCell(Text(r.pmsStatus)),
                                  DataCell(Text(r.result)),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 450,
                                      ),
                                      child: Text(r.details),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            LaooPaginationCard(
              tokens: sapPmsTokens,
              page: _page,
              pageCount: filtered.isEmpty
                  ? 1
                  : (filtered.length / _pageSize).ceil(),
              pageSize: _pageSize,
              total: filtered.length,
              onPrevious: _page > 1 ? () => setState(() => _page--) : null,
              onNext: end < filtered.length
                  ? () => setState(() => _page++)
                  : null,
              borderless: true,
            ),
          ],
        );
      },
    ),
  );
}
