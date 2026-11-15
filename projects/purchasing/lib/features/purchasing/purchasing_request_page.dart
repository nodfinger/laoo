import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'purchasing_feature_host.dart';
import 'purchasing_request_repository.dart';
import 'purchasing_route_contract.dart';

ThemeData _purchasingTheme(BuildContext context) {
  final base = Theme.of(context);
  final tokens = purchasingUiTokens;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: tokens.borderColor),
  );
  return base.copyWith(
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: tokens.primaryColor, width: 1.5),
      ),
      labelStyle: tokens.inputStyle.copyWith(color: tokens.primaryColor),
      floatingLabelStyle: tokens.inputStyle.copyWith(
        fontSize: (tokens.tableStyle.fontSize ?? 14) / .75,
        color: tokens.primaryColor,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(0, tokens.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: shape,
        textStyle: tokens.buttonStyle,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, tokens.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: tokens.primaryColor,
        side: BorderSide(color: tokens.primaryColor),
        shape: shape,
        textStyle: tokens.buttonStyle,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  );
}

class PurchasingRequestPage extends StatefulWidget {
  const PurchasingRequestPage({super.key});
  @override
  State<PurchasingRequestPage> createState() => _PurchasingRequestPageState();
}

class _PurchasingRequestPageState extends State<PurchasingRequestPage> {
  late final JsonApiClient _client;
  late final PurchasingRequestRepository _repo;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  List<Map<String, dynamic>> _divisions = const [];
  List<Map<String, dynamic>> _departments = const [];
  List<Map<String, dynamic>> _requesters = const [];
  String? _divisionId, _departmentId, _requesterId;
  bool _loading = true;
  bool _editing = false;
  Map<String, dynamic>? _editingValue;
  String _caption = 'คำขอจัดซื้อ';
  final _searchKey = GlobalKey();
  double _searchHeight = 48;
  int _page = 1;
  int _total = 0;
  bool _cardView = false;
  String _yearFormat = 'AD';
  List<String> _displayOrder = [];
  Set<String> _hidden = {};
  bool _actionOnRight = false;
  static const _labels = <String, String>{
    'requestNo': 'เลขที่ขอ',
    'requestDate': 'วันที่ขอ',
    'divisionName': 'ฝ่าย',
    'departmentName': 'แผนก',
    'requesterName': 'ผู้ขอ',
    'status': 'สถานะ',
    'responsibleName': 'ผู้รับผิดชอบ',
  };
  List<String> get _visibleFields => [
    ..._displayOrder.where(_labels.containsKey),
    ..._labels.keys.where((key) => !_displayOrder.contains(key)),
  ].where((key) => key == 'requestNo' || !_hidden.contains(key)).toList();

  @override
  void initState() {
    super.initState();
    _client = createPurchasingApiClient();
    _repo = PurchasingRequestRepository(_client);
    purchasingListDisplayRevision?.addListener(_loadPreferences);
    _loadPreferences();
    _loadYearFormat();
    resolvePurchasingMenuTitle(PurchasingMenuCodes.requests, _caption).then((
      value,
    ) {
      if (mounted) setState(() => _caption = value);
    });
    _load();
  }

  @override
  void dispose() {
    purchasingListDisplayRevision?.removeListener(_loadPreferences);
    _search.dispose();
    disposePurchasingApiClient(_client);
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final value = await _client.get('/api/user-list-display/69002');
      if (!mounted || value is! Map) return;
      setState(() {
        _displayOrder =
            (value['order'] is List ? value['order'] as List : const [])
                .whereType<String>()
                .where(_labels.containsKey)
                .toSet()
                .toList();
        _hidden = (value['hidden'] is List ? value['hidden'] as List : const [])
            .whereType<String>()
            .toSet();
        _actionOnRight = value['actionOnRight'] == true;
      });
    } catch (_) {
      /* Use standard display when settings are unavailable. */
    }
  }

  Future<void> _loadYearFormat() async {
    try {
      final data = await _client.get('/api/system/company-setup/runtime');
      if (mounted && data is Map)
        setState(() => _yearFormat = '${data['yearFormat'] ?? 'AD'}');
    } catch (_) {
      /* Use the default year format. */
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _repo.list(
        search: _search.text,
        divisionId: _divisionId,
        departmentId: _departmentId,
        requesterId: _requesterId,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _rows = List<Map<String, dynamic>>.from(
          result['items'] as List? ?? const [],
        );
        _divisions = List<Map<String, dynamic>>.from(
          result['divisions'] as List? ?? const [],
        );
        _departments = List<Map<String, dynamic>>.from(
          result['departments'] as List? ?? const [],
        );
        _requesters = List<Map<String, dynamic>>.from(
          result['requesters'] as List? ?? const [],
        );
      });
    } catch (error) {
      if (mounted)
        showPurchasingMessage(
          context,
          message: 'โหลดคำขอจัดซื้อไม่สำเร็จ: $error',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEditor([Map<String, dynamic>? value]) => setState(() {
    _editingValue = value;
    _editing = true;
  });

  Future<void> _openExisting(Map<String, dynamic> row) async {
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = await _repo.get(id);
      if (mounted) _openEditor(detail);
    } catch (_) {
      if (mounted)
        showPurchasingMessage(
          context,
          message: 'โหลดรายละเอียดคำขอไม่สำเร็จ',
          error: true,
        );
    }
  }

  void _closeEditor(bool changed) {
    setState(() {
      _editing = false;
      _editingValue = null;
    });
    if (changed) {
      showPurchasingMessage(
        context,
        message: 'บันทึกคำขอจัดซื้อสำเร็จ',
        error: false,
      );
      _load();
    }
  }

  Future<void> _deleteRequest(Map<String, dynamic> row) async {
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null || row['canDelete'] != true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Theme.of(dialogContext).colorScheme.error),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  dialogContext,
                ).colorScheme.error.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.delete_outline,
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: purchasingUiTokens.captionStyle.copyWith(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.error.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${row['requestNo'] ?? '-'}'),
              ),
              const SizedBox(height: 12),
              const Text(
                'เมื่อลบข้อมูลแล้วจะไม่สามารถเรียกคืนได้ รวมถึงไฟล์แนบทั้งหมด',
              ),
              const SizedBox(height: 12),
              const Divider(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await _repo.delete(id);
      if (!mounted) return;
      showPurchasingMessage(
        context,
        message: result is Map && result['attachmentCleanupFailed'] == true
            ? 'ลบคำขอแล้ว แต่ลบไฟล์แนบบางไฟล์ไม่สำเร็จ กรุณาติดต่อผู้ดูแลระบบ'
            : 'ลบคำขอจัดซื้อสำเร็จ',
        error: result is Map && result['attachmentCleanupFailed'] == true,
      );
      if (_rows.length == 1 && _page > 1) _page--;
      await _load();
    } catch (error) {
      if (mounted)
        showPurchasingMessage(
          context,
          message: 'ลบคำขอจัดซื้อไม่สำเร็จ: $error',
          error: true,
        );
    }
  }

  Widget _actions(Map<String, dynamic> row, {bool card = false}) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _edit(row, card: card),
      if (row['canDelete'] == true)
        if (card)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () => _deleteRequest(row),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          )
        else
          IconButton(
            tooltip: 'ลบ',
            color: Theme.of(context).colorScheme.error,
            onPressed: () => _deleteRequest(row),
            icon: const Icon(Icons.delete_outline),
          ),
    ],
  );

  @override
  Widget build(BuildContext context) => buildPurchasingWorkspaceShell(
    pageTitle: _caption,
    activeMenu: PurchasingMenuCodes.requests,
    child: Theme(
      data: _purchasingTheme(context),
      child: _editing
          ? _PurchasingRequestDialog(
              repository: _repo,
              initial: _editingValue,
              caption: _caption,
              onClose: _closeEditor,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth <= 600;
                final showCards = narrow || _cardView;
                return ListView(
                  padding: EdgeInsets.all(narrow ? 10 : 24),
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              color: purchasingUiTokens.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _caption,
                                style: purchasingUiTokens.captionStyle,
                              ),
                            ),
                            if (!narrow) ...[
                              IconButton.filledTonal(
                                style: IconButton.styleFrom(
                                  fixedSize: const Size(48, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                tooltip: showCards
                                    ? 'แสดงแบบตาราง'
                                    : 'แสดงแบบการ์ด',
                                onPressed: () =>
                                    setState(() => _cardView = !_cardView),
                                icon: Icon(
                                  showCards
                                      ? Icons.view_list_outlined
                                      : Icons.grid_view,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                fixedSize: const Size.fromHeight(48),
                              ),
                              onPressed: () => _openEditor(),
                              icon: const Icon(Icons.add),
                              label: const Text('สร้างคำขอ'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final height =
                                  _searchKey.currentContext?.size?.height;
                              if (mounted &&
                                  height != null &&
                                  height != _searchHeight)
                                setState(() => _searchHeight = height);
                            });
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: constraints.maxWidth < 260
                                      ? constraints.maxWidth
                                      : 260,
                                  child: TextField(
                                    key: _searchKey,
                                    controller: _search,
                                    onSubmitted: (_) {
                                      _page = 1;
                                      _load();
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'ค้นหาเลขที่ขอ/รายการ',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                  ),
                                ),
                                _filter('ฝ่าย', _divisionId, _divisions, (v) {
                                  setState(() {
                                    _divisionId = v;
                                    _departmentId = null;
                                    _requesterId = null;
                                    _page = 1;
                                  });
                                  _load();
                                }),
                                _filter('แผนก', _departmentId, _departments, (
                                  v,
                                ) {
                                  setState(() {
                                    _departmentId = v;
                                    _requesterId = null;
                                    _page = 1;
                                  });
                                  _load();
                                }),
                                _filter('ผู้ขอ', _requesterId, _requesters, (
                                  v,
                                ) {
                                  setState(() {
                                    _requesterId = v;
                                    _page = 1;
                                  });
                                  _load();
                                }),
                                SizedBox(
                                  height: _searchHeight,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      _page = 1;
                                      _load();
                                    },
                                    icon: const Icon(Icons.search),
                                    label: const Text('ค้นหา'),
                                  ),
                                ),
                                SizedBox(
                                  height: _searchHeight,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _search.clear();
                                      setState(() {
                                        _divisionId = null;
                                        _departmentId = null;
                                        _requesterId = null;
                                        _page = 1;
                                      });
                                      _load();
                                    },
                                    icon: const Icon(Icons.clear),
                                    label: const Text('ล้าง Filter'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _results(showCards, constraints.maxWidth),
                    const SizedBox(height: 8),
                    _pagination(),
                  ],
                );
              },
            ),
    ),
  );

  String _date(dynamic value) {
    final text = value?.toString() ?? '';
    final date = DateTime.tryParse(text);
    return date == null
        ? (text.isEmpty ? '-' : text)
        : formatPurchasingDate(date, _yearFormat);
  }

  String _fieldValue(String key, Map<String, dynamic> row) => switch (key) {
    'requestDate' => _date(row[key]),
    'status' => _status(row),
    _ => '${row[key] ?? '-'}',
  };

  String _status(Map<String, dynamic> row) =>
      row['statusCode'] == 'DRAFT' ? 'แบบร่าง' : '${row['statusCode'] ?? '-'}';

  Widget _edit(Map<String, dynamic> row, {bool card = false}) => card
      ? OutlinedButton.icon(
          onPressed: () => _openExisting(row),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('แก้ไข'),
        )
      : IconButton(
          tooltip: 'แก้ไข',
          color: purchasingUiTokens.primaryColor,
          onPressed: () => _openExisting(row),
          icon: const Icon(Icons.edit_outlined),
        );

  Widget _results(bool cards, double width) {
    final Widget content;
    if (_loading) {
      content = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_rows.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('ไม่พบข้อมูล')),
      );
    } else if (cards) {
      content = Column(
        children: [
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_actionOnRight) _actions(_rows[i], card: true),
                  const SizedBox(height: 8),
                  for (final key in _visibleFields)
                    Text('${_labels[key]}: ${_fieldValue(key, _rows[i])}'),
                  if (_actionOnRight)
                    Align(
                      alignment: Alignment.centerRight,
                      child: _actions(_rows[i], card: true),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    } else {
      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: width > 68 ? width - 68 : 0),
          child: DataTable(
            border: TableBorder(
              horizontalInside: BorderSide(
                color: purchasingUiTokens.borderColor,
                width: .6,
              ),
              bottom: BorderSide(
                color: purchasingUiTokens.borderColor,
                width: .6,
              ),
            ),
            horizontalMargin: 8,
            columnSpacing: 20,
            headingRowHeight: 56,
            headingRowColor: WidgetStatePropertyAll(
              purchasingUiTokens.primaryColor.withValues(alpha: .12),
            ),
            headingTextStyle: TextStyle(
              color: purchasingUiTokens.primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            columns: [
              const DataColumn(label: Text('ID')),
              if (!_actionOnRight) const DataColumn(label: Text('Action')),
              for (final key in _visibleFields)
                DataColumn(label: Text(_labels[key]!)),
              if (_actionOnRight) const DataColumn(label: Text('Action')),
            ],
            rows: [
              for (var i = 0; i < _rows.length; i++)
                DataRow(
                  cells: [
                    DataCell(Text('${(_page - 1) * 20 + i + 1}')),
                    if (!_actionOnRight) DataCell(_actions(_rows[i])),
                    for (final key in _visibleFields)
                      DataCell(Text(_fieldValue(key, _rows[i]))),
                    if (_actionOnRight) DataCell(_actions(_rows[i])),
                  ],
                ),
            ],
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: Padding(padding: const EdgeInsets.all(10), child: content),
    );
  }

  Widget _pagination() {
    final first = _total == 0 ? 0 : (_page - 1) * 20 + 1;
    final last = _total == 0 ? 0 : first + _rows.length - 1;
    Widget button(Widget child, VoidCallback? action) => SizedBox(
      width: 36,
      height: 36,
      child: FilledButton(
        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: action,
        child: child,
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              button(
                const Icon(Icons.chevron_left),
                _page > 1 && !_loading
                    ? () {
                        setState(() => _page--);
                        _load();
                      }
                    : null,
              ),
              const SizedBox(width: 6),
              button(Text('$_page'), () {}),
              const SizedBox(width: 6),
              button(
                const Icon(Icons.chevron_right),
                last < _total && !_loading
                    ? () {
                        setState(() => _page++);
                        _load();
                      }
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
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

  Widget _filter(
    String label,
    String? value,
    List<Map<String, dynamic>> items,
    ValueChanged<String?> onChanged,
  ) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
        ...items.map(
          (item) => DropdownMenuItem(
            value: '${item['id']}',
            child: Text('${item['name']}'),
          ),
        ),
      ],
      onChanged: onChanged,
    ),
  );
}

class _PurchasingRequestDialog extends StatefulWidget {
  const _PurchasingRequestDialog({
    required this.repository,
    required this.caption,
    required this.onClose,
    this.initial,
  });
  final PurchasingRequestRepository repository;
  final Map<String, dynamic>? initial;
  final String caption;
  final void Function(bool changed) onClose;
  @override
  State<_PurchasingRequestDialog> createState() =>
      _PurchasingRequestDialogState();
}

class _PurchasingRequestDialogState extends State<_PurchasingRequestDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _remark,
      _requestDate,
      _previousPoNo,
      _previousPrNo;
  List<Map<String, dynamic>> _details = [];
  final Set<Map<String, dynamic>> _expandedDetails = HashSet.identity();
  final Set<Map<String, dynamic>> _newDetails = HashSet.identity();
  final Map<Map<String, dynamic>, Map<int, int>> _referenceRevisions =
      HashMap.identity();
  final Map<int, Future<Uint8List>> _savedImagePreviews = {};
  bool _saving = false;
  int? _savedRequestId;
  String? _yearFormat;

  String? _normalizeReference(dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || RegExp(r'\s').hasMatch(text)) return null;
    if (RegExp(
      r'^(javascript|data|file|mailto):',
      caseSensitive: false,
    ).hasMatch(text))
      return null;
    final withScheme =
        RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(text)
        ? text
        : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        withScheme.length > 2048)
      return null;
    return withScheme;
  }

  void _finishReferenceEdit(Map<String, dynamic> detail, int link) {
    final key = 'referenceUrl$link';
    final value = _normalizeReference(detail[key]);
    if (value == null || value == detail[key]) return;
    setState(() {
      detail[key] = value;
      final revisions = _referenceRevisions.putIfAbsent(detail, () => {});
      revisions[link] = (revisions[link] ?? 0) + 1;
    });
  }

  Future<void> _openReferenceLink(dynamic value) async {
    final normalized = _normalizeReference(value);
    if (normalized == null) {
      showPurchasingMessage(
        context,
        message: 'กรุณาระบุลิงก์เว็บไซต์ที่ถูกต้อง',
        error: true,
      );
      return;
    }
    try {
      if (await launchUrl(Uri.parse(normalized), webOnlyWindowName: '_blank'))
        return;
    } catch (_) {
      // Show the same message when the browser cannot open the link.
    }
    if (mounted) {
      showPurchasingMessage(
        context,
        message: 'ไม่สามารถเปิดลิงก์ได้',
        error: true,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final x = widget.initial ?? {};
    _savedRequestId = (x['requestId'] as num?)?.toInt();
    _remark = TextEditingController(text: '${x['remark'] ?? ''}');
    _previousPoNo = TextEditingController(text: '${x['previousPoNo'] ?? ''}');
    _previousPrNo = TextEditingController(text: '${x['previousPrNo'] ?? ''}');
    _requestDate = TextEditingController(
      text:
          '${x['requestDate'] ?? (widget.initial == null ? _isoDate(DateTime.now()) : '')}',
    );
    _details = [
      for (final d in (x['details'] as List? ?? const []))
        Map<String, dynamic>.from(d),
    ];
    if (_details.isEmpty) _addDetail(markNew: false);
    _loadYearFormat();
  }

  Future<void> _loadYearFormat() async {
    try {
      final setup = await widget.repository.api.get(
        '/api/system/company-setup/runtime',
      );
      if (mounted && setup is Map)
        setState(() => _yearFormat = setup['yearFormat']?.toString() ?? 'AD');
    } catch (_) {
      if (mounted)
        showPurchasingMessage(
          context,
          message: 'ไม่สามารถโหลดรูปแบบวันที่ของบริษัท',
          error: true,
        );
    }
  }

  String _displayDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return formatPurchasingDate(date, _yearFormat ?? 'AD');
  }

  Future<DateTime?> _pickDate(String value) => showDatePicker(
    context: context,
    initialDate: _pickerInitialDate(value),
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      child: child!,
    ),
  );

  DateTime _pickerInitialDate(String value) {
    final date = DateTime.tryParse(value);
    return date != null && date.year >= 1900 && date.year <= 2100
        ? date
        : DateTime.now();
  }

  bool _validDate(String value) {
    final date = DateTime.tryParse(value);
    return date != null && date.year >= 1900 && date.year <= 2100;
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _remark.dispose();
    _previousPoNo.dispose();
    _previousPrNo.dispose();
    _requestDate.dispose();
    super.dispose();
  }

  void _addDetail({bool markNew = true}) => setState(() {
    final detail = <String, dynamic>{
      'itemText': '',
      'quantity': 1,
      'estimatedMin': null,
      'estimatedMax': null,
      'remark': '',
      'neededDate': '',
      'urgencyLevel': 0,
      'attachments': <dynamic>[],
    };
    _details.insert(0, detail);
    if (markNew) _newDetails.add(detail);
    _expandedDetails.add(detail);
  });

  Future<void> _removeDetail(Map<String, dynamic> detail, int index) async {
    final name = '${detail['itemText'] ?? ''}'.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final errorColor = Theme.of(dialogContext).colorScheme.error;
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: errorColor),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.delete_outline, color: errorColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ยืนยันการลบข้อมูล',
                  style: purchasingUiTokens.captionStyle.copyWith(
                    color: errorColor,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: errorColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_newDetails.contains(detail) ? 'เพิ่มใหม่' : 'รายการที่ ${_details.take(index + 1).where((item) => !_newDetails.contains(item)).length}'}${name.isEmpty ? '' : ' - $name'}',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'เมื่อลบข้อมูลแล้วจะไม่สามารถเรียกคืนได้ รวมถึงไฟล์แนบของรายการนี้',
                ),
                const SizedBox(height: 12),
                const Divider(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: errorColor),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบ'),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _expandedDetails.remove(detail);
      _newDetails.remove(detail);
      _referenceRevisions.remove(detail);
      _details.removeWhere((item) => identical(item, detail));
    });
  }

  Future<void> _save() async {
    if (_details.isEmpty) {
      showPurchasingMessage(
        context,
        message: 'กรุณาเพิ่มรายการอย่างน้อย 1 รายการก่อนบันทึก',
        error: true,
      );
      return;
    }
    if (!_form.currentState!.validate()) {
      setState(() => _expandedDetails.addAll(_details));
      return;
    }
    setState(() => _saving = true);
    var documentSaved = false;
    try {
      final orderedDetails = [
        ..._details.where((detail) => !_newDetails.contains(detail)),
        ..._details.reversed.where((detail) => _newDetails.contains(detail)),
      ];
      final details = [
        for (final d in orderedDetails)
          Map<String, dynamic>.from(d)
            ..remove('_pending')
            ..addAll({
              for (var link = 1; link <= 3; link++)
                'referenceUrl$link': _normalizeReference(
                  d['referenceUrl$link'],
                ),
            }),
      ];
      final body = <String, dynamic>{
        'requestId': widget.initial?['requestId'],
        'requestDate': _requestDate.text.trim(),
        'remark': _remark.text.trim(),
        'previousPoNo': _previousPoNo.text.trim(),
        'previousPrNo': _previousPrNo.text.trim(),
        'statusCode': 'DRAFT',
        'details': details,
      };
      final existingId = _savedRequestId;
      final result = existingId == null
          ? await widget.repository.save(body)
          : await widget.repository.update(existingId, body);
      documentSaved = true;
      final upload = purchasingUpload;
      final requestId = (result['requestId'] as num?)?.toInt();
      final ids = List<dynamic>.from(result['detailIds'] as List? ?? const []);
      if (requestId == null || ids.length != orderedDetails.length) {
        throw StateError('ผลบันทึกไม่ครบ กรุณาตรวจสอบรายการก่อนลองอีกครั้ง');
      }
      _savedRequestId = requestId;
      for (var i = 0; i < ids.length; i++) {
        orderedDetails[i]['detailId'] = (ids[i] as num).toInt();
      }
      if (upload == null &&
          orderedDetails.any(
            (d) => (d['_pending'] as List? ?? const []).isNotEmpty,
          )) {
        throw StateError('ระบบยังไม่พร้อมแนบไฟล์');
      }
      if (upload != null) {
        for (var i = 0; i < orderedDetails.length && i < ids.length; i++) {
          for (final file in List<Map<String, dynamic>>.from(
            orderedDetails[i]['_pending'] as List? ?? const [],
          )) {
            final uploaded = await upload(
              '/api/purchasing/requests/$requestId/details/${(ids[i] as num).toInt()}/attachments',
              List<int>.from(file['bytes'] as Uint8List),
              '${file['name']}',
              {},
            );
            final remaining = List<Map<String, dynamic>>.from(
              orderedDetails[i]['_pending'] as List? ?? const [],
            );
            remaining.removeWhere((item) => identical(item, file));
            orderedDetails[i]['_pending'] = remaining;
            if (uploaded is Map && uploaded['attachmentId'] is num) {
              final savedFiles = List<Map<String, dynamic>>.from(
                orderedDetails[i]['attachments'] as List? ?? const [],
              );
              savedFiles.add({
                'attachmentId': uploaded['attachmentId'],
                'name': file['name'],
              });
              orderedDetails[i]['attachments'] = savedFiles;
            }
          }
        }
      }
      if (mounted) {
        widget.onClose(true);
        if (result['attachmentCleanupFailed'] == true) {
          showPurchasingMessage(
            context,
            message:
                'บันทึกแล้ว แต่ลบไฟล์แนบบางไฟล์จากเครื่องจัดเก็บไม่สำเร็จ กรุณาติดต่อผู้ดูแลระบบ',
            error: true,
          );
        }
      }
    } catch (error) {
      if (mounted)
        showPurchasingMessage(
          context,
          message: !documentSaved
              ? 'บันทึกคำขอจัดซื้อไม่สำเร็จ: $error'
              : 'บันทึกใบขอแล้ว แต่ขั้นตอนถัดไปไม่สำเร็จ กรุณาตรวจไฟล์แนบและสิทธิ์ก่อนลองอีกครั้ง: $error',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAttachment(Map<String, dynamic> detail) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) return;
    final pending = List<Map<String, dynamic>>.from(
      detail['_pending'] as List? ?? const [],
    );
    for (final file in result.files) {
      if (file.bytes != null)
        pending.add({'name': file.name, 'bytes': file.bytes});
    }
    setState(() => detail['_pending'] = pending);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      color: purchasingUiTokens.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${widget.caption} > ${widget.initial == null ? 'เพิ่ม' : 'แก้ไข'}',
                        style: purchasingUiTokens.captionStyle,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => widget.onClose(false),
                      child: const Text('ยกเลิก'),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save),
                      label: const Text('บันทึกแบบร่าง'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionHeading(
                  Icons.description_outlined,
                  'ข้อมูลเอกสาร',
                  'ข้อมูลหลักของใบแจ้งความต้องการสินค้า',
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth < 600
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2,
                        child: TextFormField(
                          key: ValueKey(
                            'request-date-${_requestDate.text}-$_yearFormat',
                          ),
                          initialValue: _displayDate(_requestDate.text),
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'วันที่ขอ',
                            suffixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          onTap: () async {
                            final date = await _pickDate(_requestDate.text);
                            if (date != null && mounted)
                              setState(
                                () => _requestDate.text = _isoDate(date),
                              );
                          },
                          validator: (_) => _validDate(_requestDate.text)
                              ? null
                              : 'กรุณาเลือกวันที่ขอให้ถูกต้อง',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: purchasingUiTokens.primaryColor.withValues(
                            alpha: .10,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'สถานะ: แบบร่าง',
                          style: TextStyle(
                            color: purchasingUiTokens.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 700
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 16) / 3;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            controller: _previousPoNo,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'อ้างอิงเลขที่ PO เดิม',
                              counterText: '',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            controller: _previousPrNo,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'อ้างอิงเลขที่ PR เดิม',
                              counterText: '',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            controller: _remark,
                            decoration: const InputDecoration(
                              labelText: 'หมายเหตุ',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionHeading(
                  Icons.inventory_2_outlined,
                  'รายการจัดซื้อ',
                  'ระบุรายละเอียดและไฟล์แนบแต่ละรายการ',
                  isItems: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_details.length} รายการ',
                        style: purchasingUiTokens.sectionStyle,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _addDetail,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่มรายการ'),
                    ),
                  ],
                ),
                ..._details.asMap().entries.map(
                  (entry) => _detailCard(entry.key, entry.value),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Widget _sectionHeading(
    IconData icon,
    String title,
    String subtitle, {
    bool isItems = false,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isItems
          ? Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: .45)
          : purchasingUiTokens.primaryColor.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: purchasingUiTokens.primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: purchasingUiTokens.sectionStyle),
              const SizedBox(height: 4),
              Text(subtitle, style: purchasingUiTokens.inputStyle),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _detailCard(int index, Map<String, dynamic> d) => Card(
    key: ObjectKey(d),
    margin: const EdgeInsets.only(top: 8),
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: BorderSide(color: purchasingUiTokens.borderColor),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(
              () => _expandedDetails.contains(d)
                  ? _expandedDetails.remove(d)
                  : _expandedDetails.add(d),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _newDetails.contains(d)
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: purchasingUiTokens.primaryColor.withValues(
                                alpha: .12,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'เพิ่มใหม่',
                              style: purchasingUiTokens.buttonStyle.copyWith(
                                color: purchasingUiTokens.primaryColor,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          'รายการที่ ${_details.take(index + 1).where((item) => !_newDetails.contains(item)).length}${'${d['itemText'] ?? ''}'.trim().isEmpty ? '' : ' - ${d['itemText']}'}',
                          style: purchasingUiTokens.sectionStyle,
                        ),
                ),
                IconButton(
                  tooltip: _expandedDetails.contains(d)
                      ? 'ย่อรายการ'
                      : 'ขยายรายการ',
                  onPressed: () => setState(
                    () => _expandedDetails.contains(d)
                        ? _expandedDetails.remove(d)
                        : _expandedDetails.add(d),
                  ),
                  icon: Icon(
                    _expandedDetails.contains(d)
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                ),
                IconButton(
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'ลบรายการ',
                  onPressed: () => _removeDetail(d, index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          Visibility(
            visible: _expandedDetails.contains(d),
            maintainState: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: '${d['itemText'] ?? ''}',
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'รายการ *',
                    counterText: '',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'กรุณาระบุรายการ' : null,
                  onChanged: (v) => setState(() => d['itemText'] = v),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 900;
                    final width = narrow
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 32) / 5;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: width,
                          child: _number(d, 'quantity', 'จำนวน'),
                        ),
                        SizedBox(
                          width: width,
                          child: _number(d, 'estimatedMin', 'ราคาต่ำสุด'),
                        ),
                        SizedBox(
                          width: width,
                          child: _number(d, 'estimatedMax', 'ราคาสูงสุด'),
                        ),
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            key: ValueKey(
                              'needed-date-${identityHashCode(d)}-${d['neededDate']}-$_yearFormat',
                            ),
                            initialValue: _displayDate(
                              '${d['neededDate'] ?? ''}',
                            ),
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'วันที่ต้องการ',
                              suffixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            onTap: () async {
                              final date = await _pickDate(
                                '${d['neededDate'] ?? ''}',
                              );
                              if (date != null && mounted)
                                setState(
                                  () => d['neededDate'] = _isoDate(date),
                                );
                            },
                            validator: (_) {
                              final value = '${d['neededDate'] ?? ''}';
                              return value.isEmpty || _validDate(value)
                                  ? null
                                  : 'กรุณาเลือกวันที่ต้องการให้ถูกต้อง';
                            },
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<int>(
                            value: (d['urgencyLevel'] as num?)?.toInt() ?? 0,
                            decoration: const InputDecoration(
                              labelText: 'ระดับความต้องการ',
                            ),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('ปกติ')),
                              DropdownMenuItem(value: 1, child: Text('ด่วน')),
                              DropdownMenuItem(
                                value: 2,
                                child: Text('ด่วนมาก'),
                              ),
                            ],
                            onChanged: (v) => d['urgencyLevel'] = v ?? 0,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 700
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 16) / 3;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            initialValue: '${d['previousPoNo'] ?? ''}',
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'อ้างอิงเลขที่ PO เดิม',
                              counterText: '',
                            ),
                            onChanged: (v) => d['previousPoNo'] = v,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            initialValue: '${d['previousPrNo'] ?? ''}',
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'อ้างอิงเลขที่ PR เดิม',
                              counterText: '',
                            ),
                            onChanged: (v) => d['previousPrNo'] = v,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            initialValue: '${d['remark'] ?? ''}',
                            decoration: const InputDecoration(
                              labelText: 'หมายเหตุรายการ',
                            ),
                            onChanged: (v) => d['remark'] = v,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text('ลิงก์อ้างอิง', style: purchasingUiTokens.sectionStyle),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 750
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 16) / 3;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var link = 1; link <= 3; link++)
                          SizedBox(
                            width: width,
                            child: TextFormField(
                              key: ValueKey(
                                'reference-${identityHashCode(d)}-$link-${_referenceRevisions[d]?[link] ?? 0}',
                              ),
                              initialValue: '${d['referenceUrl$link'] ?? ''}',
                              keyboardType: TextInputType.url,
                              maxLength: 2048,
                              decoration: InputDecoration(
                                labelText: 'ลิงก์อ้างอิง $link',
                                prefixIcon: const Icon(Icons.link),
                                suffixIcon: IconButton(
                                  tooltip: 'เปิดลิงก์อ้างอิง $link',
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () => _openReferenceLink(
                                    d['referenceUrl$link'],
                                  ),
                                ),
                                counterText: '',
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) return null;
                                return _normalizeReference(text) != null
                                    ? null
                                    : 'กรุณาระบุลิงก์เว็บไซต์ที่ถูกต้อง';
                              },
                              onChanged: (value) =>
                                  d['referenceUrl$link'] = value.trim(),
                              onTapOutside: (_) {
                                _finishReferenceEdit(d, link);
                                FocusManager.instance.primaryFocus?.unfocus();
                              },
                              onEditingComplete: () {
                                _finishReferenceEdit(d, link);
                                FocusScope.of(context).nextFocus();
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickAttachment(d),
                        icon: const Icon(Icons.attach_file),
                        label: const Text('แนบรูป/เอกสาร'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addDetail,
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่มรายการ'),
                      ),
                    ],
                  ),
                ),
                if ((d['attachments'] as List? ?? const []).isNotEmpty ||
                    (d['_pending'] as List? ?? const []).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final file in List<Map<String, dynamic>>.from(
                        d['attachments'] as List? ?? const [],
                      ))
                        _attachmentCard(d, file, saved: true),
                      for (final file in List<Map<String, dynamic>>.from(
                        d['_pending'] as List? ?? const [],
                      ))
                        _attachmentCard(d, file, saved: false),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Future<Uint8List> _attachmentBytes(
    Map<String, dynamic> file,
    bool saved,
  ) async {
    if (!saved) return file['bytes'] as Uint8List;
    final requestId = _savedRequestId!;
    final attachmentId = (file['attachmentId'] as num).toInt();
    final response = await widget.repository.api.get(
      '/api/purchasing/requests/$requestId/attachments/$attachmentId',
    );
    return base64Decode((response as Map)['base64'] as String);
  }

  Future<Uint8List> _savedImageBytes(Map<String, dynamic> file) {
    final id = (file['attachmentId'] as num).toInt();
    return _savedImagePreviews.putIfAbsent(
      id,
      () => _attachmentBytes(file, true),
    );
  }

  Future<void> _openAttachment(Map<String, dynamic> file, bool saved) async {
    final name = '${file['name'] ?? ''}';
    final isImage = RegExp(
      r'\.(jpg|jpeg|png|webp|gif|bmp)$',
      caseSensitive: false,
    ).hasMatch(name);
    final isPdf = name.toLowerCase().endsWith('.pdf');
    if (!isImage && !isPdf) return;
    try {
      final bytes = await (saved && isImage
          ? _savedImageBytes(file)
          : _attachmentBytes(file, saved));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: SizedBox(
            width: 1000,
            height: 800,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        isImage
                            ? Icons.image_outlined
                            : Icons.picture_as_pdf_outlined,
                        color: purchasingUiTokens.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        tooltip: 'ปิด',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: isImage
                      ? InteractiveViewer(
                          minScale: .5,
                          maxScale: 5,
                          child: Center(
                            child: Image.memory(bytes, fit: BoxFit.contain),
                          ),
                        )
                      : PdfPreview(
                          build: (_) async => bytes,
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          canDebug: false,
                          allowPrinting: false,
                          allowSharing: false,
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        showPurchasingMessage(
          context,
          message: 'ไม่สามารถเปิดไฟล์แนบได้',
          error: true,
        );
    }
  }

  Future<void> _removeAttachment(
    Map<String, dynamic> detail,
    Map<String, dynamic> file,
    bool saved,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Theme.of(dialogContext).colorScheme.error),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  dialogContext,
                ).colorScheme.error.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.delete_outline,
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: purchasingUiTokens.captionStyle.copyWith(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.error.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${file['name'] ?? ''}'),
              ),
              const SizedBox(height: 12),
              Text(
                saved
                    ? 'ไฟล์ที่บันทึกแล้วจะถูกลบทันทีและเรียกคืนไม่ได้'
                    : 'เมื่อลบข้อมูลแล้วจะไม่สามารถเรียกคืนได้',
              ),
              const SizedBox(height: 12),
              const Divider(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      if (saved) {
        final requestId = _savedRequestId!;
        final attachmentId = (file['attachmentId'] as num).toInt();
        final response = await widget.repository.api.delete(
          '/api/purchasing/requests/$requestId/attachments/$attachmentId',
        );
        if (!mounted) return;
        if (response is Map && response['attachmentCleanupFailed'] == true)
          showPurchasingMessage(
            context,
            message:
                'ลบข้อมูลแนบแล้ว แต่ลบไฟล์จากเครื่องจัดเก็บไม่สำเร็จ กรุณาติดต่อผู้ดูแลระบบ',
            error: true,
          );
      }
      if (!mounted) return;
      setState(() {
        if (saved)
          _savedImagePreviews.remove((file['attachmentId'] as num).toInt());
        final key = saved ? 'attachments' : '_pending';
        final files = List<Map<String, dynamic>>.from(
          detail[key] as List? ?? const [],
        );
        files.removeWhere(
          (item) => saved
              ? item['attachmentId'] == file['attachmentId']
              : identical(item, file),
        );
        detail[key] = files;
      });
    } catch (_) {
      if (mounted)
        showPurchasingMessage(
          context,
          message: 'ลบไฟล์แนบไม่สำเร็จ',
          error: true,
        );
    }
  }

  Widget _attachmentCard(
    Map<String, dynamic> detail,
    Map<String, dynamic> file, {
    required bool saved,
  }) {
    final name = '${file['name'] ?? ''}';
    final bytes = file['bytes'];
    final isImage = RegExp(
      r'\.(jpg|jpeg|png|gif|webp|bmp)$',
      caseSensitive: false,
    ).hasMatch(name);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: purchasingUiTokens.borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: isImage || name.toLowerCase().endsWith('.pdf')
                ? () => _openAttachment(file, saved)
                : null,
            child: SizedBox(
              height: 80,
              width: double.infinity,
              child: isImage
                  ? saved
                        ? FutureBuilder<Uint8List>(
                            future: _savedImageBytes(file),
                            builder: (context, snapshot) {
                              if (snapshot.hasError)
                                return Icon(
                                  Icons.broken_image_outlined,
                                  color: Theme.of(context).colorScheme.error,
                                );
                              if (!snapshot.hasData)
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.broken_image_outlined,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              );
                            },
                          )
                        : bytes is Uint8List
                        ? Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.broken_image_outlined,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          )
                        : Icon(
                            Icons.broken_image_outlined,
                            color: Theme.of(context).colorScheme.error,
                          )
                  : Icon(
                      Icons.insert_drive_file_outlined,
                      color: purchasingUiTokens.primaryColor,
                      size: 36,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: isImage || name.toLowerCase().endsWith('.pdf')
                      ? () => _openAttachment(file, saved)
                      : null,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'ลบไฟล์แนบ',
                color: Theme.of(context).colorScheme.error,
                onPressed: () => _removeAttachment(detail, file, saved),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Text(
            saved ? 'ไฟล์แนบที่บันทึกแล้ว' : 'ไฟล์แนบของรายการนี้',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _number(Map<String, dynamic> d, String key, String label) =>
      TextFormField(
        initialValue: d[key]?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: (v) => d[key] = double.tryParse(v),
      );
}
