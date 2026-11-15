import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'gate_pass_feature_host.dart';
import 'gate_pass_file_open.dart';
import 'gate_pass_print.dart';

class _GatePassFileGroup extends StatefulWidget {
  const _GatePassFileGroup({
    required this.api,
    required this.requestId,
    required this.itemId,
    required this.isItem,
    required this.files,
    required this.revision,
    required this.enabled,
    this.showButtons = true,
    this.showFiles = true,
    this.iconOnly = false,
    this.onFilesChanged,
  });
  final JsonApiClient api;
  final Object? requestId;
  final Object? itemId;
  final bool isItem;
  final List<PlatformFile> files;
  final int revision;
  final bool enabled;
  final bool showButtons;
  final bool showFiles;
  final bool iconOnly;
  final VoidCallback? onFilesChanged;
  @override
  State<_GatePassFileGroup> createState() => _GatePassFileGroupState();
}

class _GatePassFileGroupState extends State<_GatePassFileGroup> {
  late Future<List<dynamic>> _stored;
  @override
  void initState() {
    super.initState();
    _stored = _load();
  }

  @override
  void didUpdateWidget(covariant _GatePassFileGroup old) {
    super.didUpdateWidget(old);
    if (old.requestId != widget.requestId ||
        old.itemId != widget.itemId ||
        old.revision != widget.revision)
      _stored = _load();
  }

  Future<List<dynamic>> _load() async {
    if (!widget.showFiles ||
        widget.requestId == null ||
        (widget.isItem && widget.itemId == null))
      return [];
    final response = await widget.api.get(
      '/api/company/gate-pass/requests/${widget.requestId}/request-files',
    );
    if (response is! Map || response['items'] is! List) return [];
    return (response['items'] as List)
        .where(
          (f) =>
              f is Map &&
              (widget.isItem
                  ? '${f['itemId']}' == '${widget.itemId}'
                  : f['itemId'] == null),
        )
        .toList();
  }

  bool _image(String name) =>
      RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(name);
  bool _pdf(String name) => name.toLowerCase().endsWith('.pdf');

  void _previewPdf(String name, Future<Uint8List> Function() load) {
    final content = load();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 900,
          height: 720,
          child: Column(
            children: [
              Padding(
                padding: gatePassUiTokens.cardPadding,
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      color: gatePassUiTokens.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: gatePassUiTokens.captionStyle,
                      ),
                    ),
                    IconButton(
                      tooltip: 'ปิด',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: gatePassUiTokens.borderColor),
              Expanded(
                child: FutureBuilder<Uint8List>(
                  future: content,
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Center(
                        child: Text('เปิดไฟล์ PDF ไม่สำเร็จ'),
                      );
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    return PdfPreview(
                      build: (_) async => snapshot.data!,
                      allowPrinting: false,
                      allowSharing: false,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick({required bool images}) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: images
          ? ['jpg', 'jpeg', 'png', 'webp']
          : ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || !mounted) return;
    final accepted = picked.files
        .where(
          (f) => f.bytes != null && f.size > 0 && f.size <= 10 * 1024 * 1024,
        )
        .toList();
    if (accepted.length != picked.files.length)
      showGatePassMessage(
        context,
        message: 'เลือกได้เฉพาะไฟล์ที่มีขนาดไม่เกิน 10 MB',
        error: true,
      );
    setState(() => widget.files.addAll(accepted));
    widget.onFilesChanged?.call();
  }

  void _zoom(List<int> bytes) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 900,
          height: 650,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Center(
                    child: Image.memory(
                      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.showButtons)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.iconOnly)
              IconButton(
                tooltip: 'เพิ่มรูป',
                onPressed: widget.enabled ? () => _pick(images: true) : null,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                color: gatePassUiTokens.primaryColor,
              )
            else
              OutlinedButton.icon(
                onPressed: widget.enabled ? () => _pick(images: true) : null,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('เพิ่มรูป'),
              ),
            if (widget.iconOnly)
              IconButton(
                tooltip: 'เพิ่มเอกสาร',
                onPressed: widget.enabled ? () => _pick(images: false) : null,
                icon: const Icon(Icons.attach_file),
                color: gatePassUiTokens.primaryColor,
              )
            else
              OutlinedButton.icon(
                onPressed: widget.enabled ? () => _pick(images: false) : null,
                icon: const Icon(Icons.attach_file),
                label: const Text('เพิ่มเอกสาร'),
              ),
          ],
        ),
      if (widget.showFiles)
        FutureBuilder<List<dynamic>>(
          future: _stored,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('โหลดไฟล์แนบไม่สำเร็จ');
            final stored = snapshot.data ?? [];
            return Padding(
              padding: EdgeInsets.only(
                top: widget.files.isNotEmpty || stored.isNotEmpty
                    ? gatePassUiTokens.itemSpacing
                    : 0,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...widget.files.map(
                    (file) => _fileCard(
                      file.name,
                      file.bytes,
                      () {
                        setState(() => widget.files.remove(file));
                        widget.onFilesChanged?.call();
                      },
                      onOpen: file.bytes != null && !_image(file.name)
                          ? () => _pdf(file.name)
                                ? _previewPdf(
                                    file.name,
                                    () async => file.bytes!,
                                  )
                                : openGatePassFile(
                                    file.name,
                                    () async => file.bytes!,
                                  )
                          : null,
                    ),
                  ),
                  ...stored.map(
                    (file) => FutureBuilder<dynamic>(
                      future: _image(file['fileName']?.toString() ?? '')
                          ? widget.api.get(
                              '/api/company/gate-pass/requests/${widget.requestId}/request-files/${file['id']}',
                            )
                          : null,
                      builder: (context, imageSnapshot) => _fileCard(
                        file['fileName']?.toString() ?? '',
                        imageSnapshot.data is Map &&
                                imageSnapshot.data['base64'] is String
                            ? base64Decode(
                                imageSnapshot.data['base64'] as String,
                              )
                            : null,
                        widget.enabled
                            ? () async {
                                try {
                                  await widget.api.delete(
                                    '/api/company/gate-pass/requests/${widget.requestId}/request-files/${file['id']}',
                                  );
                                  if (mounted)
                                    setState(() => _stored = _load());
                                } catch (_) {
                                  if (mounted)
                                    showGatePassMessage(
                                      context,
                                      message: 'ลบไฟล์ไม่สำเร็จ',
                                      error: true,
                                    );
                                }
                              }
                            : null,
                        onOpen: () async {
                          try {
                            Future<Uint8List> load() async {
                              final data = await widget.api.get(
                                '/api/company/gate-pass/requests/${widget.requestId}/request-files/${file['id']}',
                              );
                              if (data is! Map || data['base64'] is! String)
                                throw StateError('File unavailable');
                              return base64Decode(data['base64'] as String);
                            }

                            if (_image(file['fileName'].toString())) {
                              final bytes = await load();
                              if (mounted) _zoom(bytes);
                            } else if (_pdf(file['fileName'].toString())) {
                              _previewPdf(file['fileName'].toString(), load);
                            } else {
                              await openGatePassFile(
                                file['fileName'].toString(),
                                load,
                              );
                            }
                          } catch (_) {
                            if (mounted)
                              showGatePassMessage(
                                context,
                                message: 'เปิดไฟล์ไม่สำเร็จ',
                                error: true,
                              );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
    ],
  );
  Widget _fileCard(
    String name,
    Uint8List? bytes,
    VoidCallback? remove, {
    VoidCallback? onOpen,
  }) => SizedBox(
    width: 150,
    child: Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(gatePassUiTokens.radius),
        side: BorderSide(color: gatePassUiTokens.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap:
                onOpen ??
                (bytes != null && _image(name) ? () => _zoom(bytes) : null),
            child: SizedBox(
              height: 75,
              width: 140,
              child: bytes != null && _image(name)
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : Icon(
                      _image(name)
                          ? Icons.image_outlined
                          : Icons.description_outlined,
                    ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              if (remove != null && widget.enabled)
                IconButton(
                  tooltip: 'ลบไฟล์',
                  onPressed: remove,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class GatePassPage extends StatefulWidget {
  const GatePassPage({
    required this.menuCode,
    required this.title,
    required this.endpoint,
    super.key,
  });

  final String menuCode;
  final String title;
  final String endpoint;

  @override
  State<GatePassPage> createState() => _GatePassPageState();
}

class _GatePassPageState extends State<GatePassPage> {
  late final JsonApiClient _api = createGatePassApiClient();
  final _searchController = TextEditingController();
  final _searchFieldKey = GlobalKey();
  double _searchHeight = 48;
  late Future<dynamic> _future;
  late String _title;
  String _appliedQuery = '';
  List<Map<String, dynamic>> _requestDepartments = const [];
  List<Map<String, dynamic>> _requestPurposes = const [];
  String _requestYearFormat = 'C';
  int? _departmentId;
  int? _filterPurposeId;
  String? _filterCarrier;
  List<String> _returnCarriers = const [];
  DateTimeRange? _documentDateRange;
  DateTimeRange? _exitDateRange;
  int _page = 1;
  bool _cards = false;
  Map<String, dynamic> _actions = const {};

  bool get _isSettings => widget.endpoint == 'settings';
  bool get _isPurposes => widget.endpoint == 'purposes';
  bool get _isRequests => widget.endpoint == 'requests';
  bool get _isReturns => widget.endpoint == 'returns';
  bool get _hasDocumentFilters => _isRequests || _isReturns;
  bool get _isDashboard => widget.endpoint == 'dashboard';
  bool get _canCreate => _actions['create'] == true;
  bool get _canEdit => _actions['edit'] == true;
  bool get _canDelete => _actions['delete'] == true;
  bool get _canPrint => _actions['print'] == true;
  bool get _canSubmit => _actions['submit'] == true;
  bool get _canApprove => _actions['approve'] == true;
  bool get _canConfirmExit => _actions['confirmExit'] == true;
  bool get _canConfirmReturn => _actions['confirmReturn'] == true;
  IconData get _menuIcon => switch (widget.endpoint) {
    'settings' => Icons.settings_outlined,
    'purposes' => Icons.category_outlined,
    'requests' => Icons.assignment_outlined,
    'approvals' => Icons.approval_outlined,
    'exit-checks' => Icons.verified_user_outlined,
    'return-checks' => Icons.assignment_return_outlined,
    'history' => Icons.history_outlined,
    'dashboard' => Icons.dashboard_outlined,
    _ => Icons.local_shipping_outlined,
  };

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _future = _load();
    _resolveTitle();
  }

  Future<dynamic> _load() async {
    final responses = await Future.wait<dynamic>([
      _api.get('/api/company/gate-pass/${widget.endpoint}'),
      _api.get('/api/company/gate-pass/actions/${widget.menuCode}'),
    ]);
    final value = _map(responses.first);
    value['actions'] = _map(responses.last);
    if (_isRequests) {
      final lookups = await Future.wait<dynamic>([
        _api.get('/api/company/gate-pass/request-departments'),
        _api.get('/api/company/gate-pass/purpose-options'),
        _api.get('/api/system/company-setup/runtime'),
      ]);
      value['requestDepartments'] = _rows(_map(lookups[0]));
      value['requestPurposes'] = _rows(_map(lookups[1]));
      value['requestYearFormat'] =
          _map(lookups[2])['yearFormat']?.toString() ?? 'C';
    } else if (_isReturns) {
      final rows = _rows(value);
      final departments = <int, String>{};
      final purposes = <int, String>{};
      final carriers = <String>{};
      for (final row in rows) {
        final department = int.tryParse('${row['departmentId'] ?? ''}');
        final purpose = int.tryParse('${row['purposeId'] ?? ''}');
        final departmentName = '${row['departmentName'] ?? ''}'.trim();
        final purposeName = '${row['purpose'] ?? ''}'.trim();
        final carrier = '${row['carrier'] ?? ''}'.trim();
        if (department != null && departmentName.isNotEmpty)
          departments[department] = departmentName;
        if (purpose != null && purposeName.isNotEmpty)
          purposes[purpose] = purposeName;
        if (carrier.isNotEmpty) carriers.add(carrier);
      }
      value['requestDepartments'] =
          departments.entries
              .map((e) => {'id': e.key, 'name': e.value})
              .toList()
            ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      value['requestPurposes'] =
          purposes.entries.map((e) => {'id': e.key, 'name': e.value}).toList()
            ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      value['returnCarriers'] = carriers.toList()..sort();
      final setup = _map(await _api.get('/api/system/company-setup/runtime'));
      value['requestYearFormat'] = setup['yearFormat']?.toString() ?? 'C';
    }
    return value;
  }

  Future<void> _resolveTitle() async {
    final value = await resolveGatePassMenuTitle(widget.menuCode, widget.title);
    if (mounted) setState(() => _title = value);
  }

  @override
  void dispose() {
    _searchController.dispose();
    disposeGatePassApiClient(_api);
    super.dispose();
  }

  void _search() => setState(() {
    _appliedQuery = _searchController.text.trim().toLowerCase();
    _page = 1;
  });

  void _clearFilter() => setState(() {
    _searchController.clear();
    _appliedQuery = '';
    _departmentId = null;
    _filterPurposeId = null;
    _filterCarrier = null;
    _documentDateRange = null;
    _exitDateRange = null;
    _page = 1;
  });

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final tokens = gatePassUiTokens;
    return buildGatePassWorkspaceShell(
      pageTitle: _title,
      activeMenu: widget.menuCode,
      child: Padding(
        padding: tokens.contentMargin,
        child: FutureBuilder<dynamic>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _pageFrame(
                context,
                content: _loadingCard(),
                showFilter: !_isSettings,
              );
            }
            if (snapshot.hasError) {
              return _pageFrame(
                context,
                content: _errorCard(context),
                showFilter: !_isSettings,
              );
            }
            final value = _map(snapshot.data);
            _actions = _map(value['actions']);
            if (_hasDocumentFilters) {
              _requestDepartments =
                  (value['requestDepartments'] as List?)?.map(_map).toList() ??
                  [];
              _requestPurposes =
                  (value['requestPurposes'] as List?)?.map(_map).toList() ?? [];
              _requestYearFormat =
                  value['requestYearFormat']?.toString() ?? 'C';
              if (_isReturns) {
                _returnCarriers =
                    (value['returnCarriers'] as List?)?.cast<String>() ?? [];
                if (_departmentId != null &&
                    !_requestDepartments.any(
                      (d) => '${d['id']}' == '$_departmentId',
                    ))
                  _departmentId = null;
                if (_filterPurposeId != null &&
                    !_requestPurposes.any(
                      (p) => '${p['id']}' == '$_filterPurposeId',
                    ))
                  _filterPurposeId = null;
                if (_filterCarrier != null &&
                    !_returnCarriers.contains(_filterCarrier))
                  _filterCarrier = null;
              }
            }
            if (_isSettings) {
              final rows = _rows(value);
              final settings = rows.isEmpty
                  ? <String, dynamic>{
                      'isEnabled': true,
                      'defaultReturnDays': 7,
                      'maxAttachmentSizeMB': 1,
                      'maxAttachmentsPerStage': 5,
                    }
                  : rows.first;
              return _pageFrame(
                context,
                content: _settingsCard(context, settings),
                showFilter: false,
              );
            }
            if (_isDashboard) {
              final rows = _rows(value);
              return _pageFrame(
                context,
                content: _dashboardCard(
                  context,
                  rows.isEmpty ? const {} : rows.first,
                ),
                showFilter: false,
              );
            }
            return _listFrame(context, _rows(value));
          },
        ),
      ),
    );
  }

  Widget _pageFrame(
    BuildContext context, {
    required Widget content,
    required bool showFilter,
  }) {
    final tokens = gatePassUiTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _captionCard(context),
        if (showFilter) ...[
          SizedBox(height: tokens.sectionSpacing),
          _filterCard(context),
        ],
        SizedBox(height: tokens.sectionSpacing),
        Expanded(child: content),
        if (showFilter) ...[
          SizedBox(height: tokens.sectionSpacing),
          _paginationCard(context, total: 0),
        ],
      ],
    );
  }

  Widget _listFrame(BuildContext context, List<Map<String, dynamic>> items) {
    const pageSize = 10;
    final filtered = items.where(_matchesQuery).toList();
    final pages = (filtered.length / pageSize).ceil().clamp(1, 9999);
    if (_page > pages) _page = pages;
    final start = (_page - 1) * pageSize;
    final rows = filtered.skip(start).take(pageSize).toList();
    final tokens = gatePassUiTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _captionCard(context),
        SizedBox(height: tokens.sectionSpacing),
        _filterCard(context),
        SizedBox(height: tokens.sectionSpacing),
        Expanded(child: _resultCard(context, rows)),
        SizedBox(height: tokens.sectionSpacing),
        _paginationCard(context, total: filtered.length),
      ],
    );
  }

  Widget _captionCard(BuildContext context) {
    final tokens = gatePassUiTokens;
    final shared = _sharedTokens(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showToggle = constraints.maxWidth >= tokens.compactBreakpoint;
        final showAdd = (_isPurposes || _isRequests) && _canCreate;
        return LaooCaptionCard(
          tokens: shared,
          caption: _title,
          leading: Icon(_menuIcon, color: tokens.primaryColor),
          trailing: !showToggle && !showAdd
              ? null
              : SizedBox(
                  width:
                      (showToggle ? tokens.buttonHeight : 0) +
                      (showToggle && showAdd ? 8 : 0) +
                      (showAdd ? 100 : 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showToggle)
                        LaooListCardToggle(
                          tokens: shared,
                          cards: _cards,
                          onChanged: (value) => setState(() => _cards = value),
                        ),
                      if (showAdd) ...[
                        if (showToggle) const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          height: tokens.buttonHeight,
                          child: FilledButton.icon(
                            onPressed: _isPurposes
                                ? () => _editPurpose()
                                : _createRequest,
                            style: FilledButton.styleFrom(
                              minimumSize: Size(100, tokens.buttonHeight),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  tokens.radius,
                                ),
                              ),
                              textStyle: tokens.buttonStyle,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่ม'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  String _formatRequestDate(Object? value, {bool time = false}) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '-';
    if (time)
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final year =
        {
          'B',
          'BE',
          'T',
          'TH',
          'THAI',
        }.contains(_requestYearFormat.toUpperCase())
        ? date.year + 543
        : date.year;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/$year';
  }

  Future<void> _chooseRequestDepartment() async {
    final search = TextEditingController();
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final options = _requestDepartments
              .where(
                (d) => (d['name']?.toString() ?? '').toLowerCase().contains(
                  search.text.trim().toLowerCase(),
                ),
              )
              .toList();
          return AlertDialog(
            title: const Text('เลือกแผนกผู้ขอ'),
            content: SizedBox(
              width: 480,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'ค้นหาแผนก',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          title: const Text('ทุกแผนก'),
                          onTap: () => Navigator.pop(dialogContext, 0),
                        ),
                        ...options.map(
                          (d) => ListTile(
                            title: Text(d['name']?.toString() ?? ''),
                            onTap: () => Navigator.pop(
                              dialogContext,
                              int.tryParse(d['id'].toString()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ปิด'),
              ),
            ],
          );
        },
      ),
    );
    search.dispose();
    if (selected != null && mounted)
      setState(() {
        _departmentId = selected == 0 ? null : selected;
        _page = 1;
      });
  }

  Future<void> _chooseRequestDateRange({required bool exit}) async {
    final existing = exit ? _exitDateRange : _documentDateRange;
    final today = DateUtils.dateOnly(DateTime.now());
    var start = existing?.start ?? today;
    var end = existing?.end ?? today;
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.date_range_outlined,
                    color: gatePassUiTokens.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(exit ? 'ช่วงวันที่นำออก' : 'ช่วงวันที่ขอ'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: gatePassUiTokens.borderColor),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final isStart in [true, false])
                    SizedBox(
                      width: 300,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(isStart ? 'ตั้งแต่วันที่' : 'ถึงวันที่'),
                          Theme(
                            data: Theme.of(dialogContext).copyWith(
                              datePickerTheme: const DatePickerThemeData(
                                backgroundColor: Colors.white,
                                surfaceTintColor: Colors.transparent,
                                headerBackgroundColor: Colors.white,
                              ),
                            ),
                            child: CalendarDatePicker(
                              initialDate: isStart ? start : end,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              onDateChanged: (date) => update(() {
                                if (isStart) {
                                  start = date;
                                } else {
                                  end = date;
                                }
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: _filterOutlinedStyle(gatePassUiTokens).copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(84, 48)),
                maximumSize: const WidgetStatePropertyAll(
                  Size(double.infinity, 48),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: _filterFilledStyle(gatePassUiTokens).copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(100, 48)),
                maximumSize: const WidgetStatePropertyAll(
                  Size(double.infinity, 48),
                ),
              ),
              onPressed: end.isBefore(start)
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      DateTimeRange(start: start, end: end),
                    ),
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted)
      setState(() {
        if (exit) {
          _exitDateRange = picked;
        } else {
          _documentDateRange = picked;
        }
        _page = 1;
      });
  }

  Widget _filterCard(BuildContext context) {
    final tokens = gatePassUiTokens;
    if (_isPurposes) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final height = _searchFieldKey.currentContext?.size?.height;
        if (mounted && height != null && height != _searchHeight)
          setState(() => _searchHeight = height);
      });
    }
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
      borderSide: BorderSide(color: tokens.borderColor),
    );
    return LaooFilterCard(
      tokens: _sharedTokens(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 40).clamp(
                  0.0,
                  280.0,
                ),
                child: TextField(
                  key: _isPurposes ? _searchFieldKey : null,
                  controller: _searchController,
                  onSubmitted: (_) => _search(),
                  style: tokens.inputStyle,
                  decoration: InputDecoration(
                    hintText: _isPurposes
                        ? 'ค้นหาชื่อ หรือสถานะ'
                        : _isReturns
                        ? 'ค้นหาเอกสาร ปลายทาง หรือเบอร์โทร'
                        : _isRequests
                        ? 'ค้นหาเอกสาร ชื่อ หรือหมายเหตุ'
                        : 'ค้นหารหัส ชื่อ หรือสถานะ',
                    prefixIcon: const Icon(Icons.search),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: inputBorder.copyWith(
                      borderSide: BorderSide(color: tokens.primaryColor),
                    ),
                  ),
                ),
              ),
              if (_hasDocumentFilters) ...[
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('request-filter-department-$_departmentId'),
                    initialValue: _departmentId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'แผนกผู้ขอ',
                      border: inputBorder,
                      suffixIcon: IconButton(
                        tooltip: 'ค้นหาแผนก',
                        onPressed: _chooseRequestDepartment,
                        icon: const Icon(Icons.search),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('ทุกแผนก'),
                      ),
                      ..._requestDepartments.map(
                        (d) => DropdownMenuItem<int>(
                          value: int.tryParse(d['id'].toString()),
                          child: Text(
                            d['name']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _departmentId = value;
                      _page = 1;
                    }),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('request-filter-purpose-$_filterPurposeId'),
                    initialValue: _filterPurposeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'วัตถุประสงค์',
                      border: inputBorder,
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      ..._requestPurposes.map(
                        (p) => DropdownMenuItem<int>(
                          value: int.tryParse(p['id'].toString()),
                          child: Text(
                            p['name']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _filterPurposeId = value;
                      _page = 1;
                    }),
                  ),
                ),
              ],
              if (_isReturns)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('return-filter-carrier-$_filterCarrier'),
                    initialValue: _filterCarrier,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'ผู้รับมอบ',
                      border: inputBorder,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      ..._returnCarriers.map(
                        (name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _filterCarrier = value;
                      _page = 1;
                    }),
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  SizedBox(
                    height: _isPurposes ? _searchHeight : null,
                    child: FilledButton.icon(
                      onPressed: _search,
                      style: _isPurposes
                          ? FilledButton.styleFrom(
                              minimumSize: Size(0, _searchHeight),
                              maximumSize: Size(double.infinity, _searchHeight),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  tokens.radius,
                                ),
                              ),
                              textStyle: tokens.buttonStyle,
                            )
                          : _filterFilledStyle(tokens),
                      icon: const Icon(Icons.search),
                      label: const Text('ค้นหา'),
                    ),
                  ),
                  SizedBox(
                    height: _isPurposes ? _searchHeight : null,
                    child: OutlinedButton.icon(
                      onPressed: _clearFilter,
                      style: _isPurposes
                          ? OutlinedButton.styleFrom(
                              minimumSize: Size(0, _searchHeight),
                              maximumSize: Size(double.infinity, _searchHeight),
                              foregroundColor: tokens.primaryColor,
                              side: BorderSide(color: tokens.primaryColor),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  tokens.radius,
                                ),
                              ),
                              textStyle: tokens.buttonStyle,
                            )
                          : _filterOutlinedStyle(tokens),
                      icon: const Icon(Icons.clear),
                      label: const Text('ล้าง Filter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_hasDocumentFilters) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: _filterOutlinedStyle(tokens),
                  onPressed: () => _chooseRequestDateRange(exit: false),
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _documentDateRange == null
                        ? 'ช่วงวันที่ขอ'
                        : '${_formatRequestDate(_documentDateRange!.start)} - ${_formatRequestDate(_documentDateRange!.end)}',
                  ),
                ),
                OutlinedButton.icon(
                  style: _filterOutlinedStyle(tokens),
                  onPressed: () => _chooseRequestDateRange(exit: true),
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _exitDateRange == null
                        ? 'ช่วงวันที่นำออก'
                        : '${_formatRequestDate(_exitDateRange!.start)} - ${_formatRequestDate(_exitDateRange!.end)}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return LaooTableCard(
        tokens: _sharedTokens(context),
        child: Center(
          child: Text('ไม่พบข้อมูล', style: gatePassUiTokens.inputStyle),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_cards ||
            constraints.maxWidth < gatePassUiTokens.compactBreakpoint) {
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) =>
                SizedBox(height: gatePassUiTokens.itemSpacing),
            itemBuilder: (context, index) =>
                _rowCard(context, rows[index], index),
          );
        }
        return LaooTableCard(
          tokens: _sharedTokens(context),
          child: LaooWorkspaceDataTable(
            tokens: _sharedTokens(context),
            headingRowColor: WidgetStatePropertyAll(
              gatePassUiTokens.primaryColor.withValues(alpha: 0.10),
            ),
            columns: [
              if (!_isRequests) LaooWorkspaceTableColumns.id,
              DataColumn(
                label: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Action'),
                ),
                columnWidth: FixedColumnWidth(_isRequests ? 200 : 100),
              ),
              DataColumn(
                label: Text(
                  _isPurposes
                      ? 'ชื่อ'
                      : _isRequests
                      ? 'เอกสาร'
                      : 'รหัส / เอกสาร',
                ),
              ),
              if (_isPurposes) const DataColumn(label: Text('จำนวนวันรับคืน')),
              if (_isRequests) ...[
                const DataColumn(label: Text('วันที่เอกสาร')),
                const DataColumn(label: Text('เวลา')),
                const DataColumn(label: Text('วันที่นำออก')),
                const DataColumn(label: Text('วัตถุประสงค์')),
                const DataColumn(label: Text('ผู้รับมอบ')),
                const DataColumn(label: Text('แผนกผู้ขอ')),
                const DataColumn(label: Text('ชื่อผู้ขอ')),
              ] else if (!_isPurposes)
                const DataColumn(label: Text('รายละเอียด')),
              const DataColumn(label: Text('สถานะ')),
            ],
            rows: List<DataRow>.generate(
              rows.length,
              (index) => DataRow(
                cells: [
                  if (!_isRequests) DataCell(Text((index + 1).toString())),
                  DataCell(
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _rowActions(rows[index], card: false),
                    ),
                  ),
                  DataCell(Text(_primaryText(rows[index]))),
                  if (_isPurposes)
                    DataCell(Text('${rows[index]['returnDays'] ?? '-'}')),
                  if (_isRequests) ...[
                    DataCell(
                      Text(_formatRequestDate(rows[index]['documentDateTime'])),
                    ),
                    DataCell(
                      Text(
                        _formatRequestDate(
                          rows[index]['documentDateTime'],
                          time: true,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(_formatRequestDate(rows[index]['plannedExitDate'])),
                    ),
                    DataCell(Text(rows[index]['purpose']?.toString() ?? '-')),
                    DataCell(_requestCarrierLink(context, rows[index])),
                    DataCell(
                      Text(rows[index]['departmentName']?.toString() ?? '-'),
                    ),
                    DataCell(
                      Text(rows[index]['requesterName']?.toString() ?? '-'),
                    ),
                  ] else if (!_isPurposes)
                    DataCell(Text(_detailText(rows[index]))),
                  DataCell(Text(_statusText(rows[index]))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rowCard(
    BuildContext context,
    Map<String, dynamic> row,
    int index,
  ) => LaooSurfaceCard(
    tokens: _sharedTokens(context),
    padding: gatePassUiTokens.cardPadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isRequests) ...[
          _rowActions(row, card: true),
          SizedBox(height: gatePassUiTokens.itemSpacing),
        ],
        if (!_isRequests) ...[
          Text('ID ${index + 1}', style: gatePassUiTokens.inputStyle),
          const SizedBox(height: 4),
        ],
        Text(_primaryText(row), style: gatePassUiTokens.sectionStyle),
        if (_isPurposes) ...[
          const SizedBox(height: 4),
          Text(
            'จำนวนวันรับคืน: ${row['returnDays'] ?? '-'} วัน',
            style: gatePassUiTokens.inputStyle,
          ),
        ],
        if (_isRequests) ...[
          const SizedBox(height: 4),
          Text(
            'วันที่เอกสาร: ${_formatRequestDate(row['documentDateTime'])} ${_formatRequestDate(row['documentDateTime'], time: true)}',
            style: gatePassUiTokens.inputStyle,
          ),
          Text(
            'วันที่นำออก: ${_formatRequestDate(row['plannedExitDate'])}',
            style: gatePassUiTokens.inputStyle,
          ),
          Text(
            'วัตถุประสงค์: ${row['purpose'] ?? '-'}',
            style: gatePassUiTokens.inputStyle,
          ),
          Row(
            children: [
              Text('ผู้รับมอบ: ', style: gatePassUiTokens.inputStyle),
              Flexible(child: _requestCarrierLink(context, row)),
            ],
          ),
          Text(
            'แผนกผู้ขอ: ${row['departmentName'] ?? '-'}',
            style: gatePassUiTokens.inputStyle,
          ),
          Text(
            'ชื่อผู้ขอ: ${row['requesterName'] ?? '-'}',
            style: gatePassUiTokens.inputStyle,
          ),
        ] else if (!_isPurposes) ...[
          const SizedBox(height: 4),
          Text(_detailText(row), style: gatePassUiTokens.inputStyle),
        ],
        const SizedBox(height: 4),
        Text(_statusText(row), style: gatePassUiTokens.inputStyle),
        if (!_isRequests && _rowActions(row) is! SizedBox) ...[
          SizedBox(height: gatePassUiTokens.itemSpacing),
          _rowActions(row, card: true),
        ],
      ],
    ),
  );

  Widget _requestCarrierLink(BuildContext context, Map<String, dynamic> row) =>
      InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(gatePassUiTokens.radius),
            ),
            titlePadding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: gatePassUiTokens.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ข้อมูลผู้รับมอบ',
                        style: gatePassUiTokens.captionStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: gatePassUiTokens.borderColor),
              ],
            ),
            contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  decoration: BoxDecoration(
                    color: gatePassUiTokens.primaryColor.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(
                      gatePassUiTokens.radius,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('ผู้รับมอบ', row['carrier']),
                      _detailRow('ปลายทาง', row['destination']),
                      _detailRow('เบอร์โทร', row['carrierPhone']),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            actions: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(height: 1, color: gatePassUiTokens.borderColor),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 60),
                        foregroundColor: gatePassUiTokens.primaryColor,
                        side: BorderSide(color: gatePassUiTokens.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            gatePassUiTokens.radius,
                          ),
                        ),
                        textStyle: gatePassUiTokens.buttonStyle,
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('ปิด'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        child: Text(
          row['carrier']?.toString() ?? '-',
          style: gatePassUiTokens.inputStyle.copyWith(
            color: gatePassUiTokens.primaryColor,
            decoration: TextDecoration.underline,
          ),
        ),
      );

  Future<void> _runRequestAction(
    Object id,
    String action,
    String success,
  ) async {
    try {
      await _api.post('/api/company/gate-pass/requests/$id/$action');
      if (!mounted) return;
      showGatePassMessage(context, message: success);
      _retry();
    } catch (_) {
      if (mounted) {
        showGatePassMessage(
          context,
          message: 'ส่งอนุมัติไม่ได้ สถานะเอกสารอาจเปลี่ยนแล้ว',
          error: true,
        );
      }
    }
  }

  Future<void> _submitRequest(Object id) =>
      _runRequestAction(id, 'submit', 'ส่งใบขออนุมัติแล้ว');

  Future<void> _uploadStagePhoto(Object id, String stage) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || !mounted) return;
    try {
      var uploaded = 0;
      for (final file in picked.files.where((file) => file.bytes != null)) {
        await uploadGatePassFile(
          '/api/company/gate-pass/requests/$id/attachments/$stage',
          fileName: file.name,
          bytes: file.bytes!,
        );
        uploaded++;
      }
      if (mounted) {
        showGatePassMessage(context, message: 'แนบรูปสำเร็จ $uploaded รูป');
      }
    } catch (_) {
      if (mounted) {
        showGatePassMessage(
          context,
          message: 'แนบรูปไม่สำเร็จ กรุณาตรวจขนาด จำนวน และสถานะเอกสาร',
          error: true,
        );
      }
    }
  }

  Future<void> _deleteRequest(Object id) async {
    final theme = Theme.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(gatePassUiTokens.radius),
          side: BorderSide(color: theme.colorScheme.error),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text(
              'ลบใบขอฉบับร่าง',
              style: gatePassUiTokens.captionStyle.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: gatePassUiTokens.cardPadding,
              color: theme.colorScheme.errorContainer,
              child: Text(
                'รหัสรายการ: $id',
                style: gatePassUiTokens.inputStyle,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ลบแล้วไม่สามารถเรียกคืนได้ รวมถึงรูปประกอบทั้งหมด',
              style: gatePassUiTokens.inputStyle,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              minimumSize: Size(0, gatePassUiTokens.buttonHeight),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await _api.delete('/api/company/gate-pass/requests/$id');
      if (!mounted) return;
      showGatePassMessage(context, message: 'ลบใบขอฉบับร่างแล้ว');
      _retry();
    } catch (_) {
      if (mounted) {
        showGatePassMessage(
          context,
          message: 'ลบไม่ได้ เนื่องจากเอกสารไม่ใช่ Draft ของผู้ขอ',
          error: true,
        );
      }
    }
  }

  Future<void> _rejectRequest(Object id) async {
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(gatePassUiTokens.radius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: gatePassUiTokens.cardPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ส่งกลับแก้ไข',
                      style: gatePassUiTokens.captionStyle,
                    ),
                  ),
                ),
                Divider(color: gatePassUiTokens.borderColor),
                TextField(
                  controller: reason,
                  maxLines: 3,
                  style: gatePassUiTokens.inputStyle,
                  decoration: const InputDecoration(labelText: 'เหตุผล *'),
                ),
                Divider(color: gatePassUiTokens.borderColor),
                SizedBox(
                  height: gatePassUiTokens.buttonHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ยกเลิก'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          if (reason.text.trim().isEmpty) {
                            showGatePassMessage(
                              this.context,
                              message: 'กรุณาระบุเหตุผลส่งกลับ',
                              error: true,
                            );
                            return;
                          }
                          try {
                            await _api.post(
                              '/api/company/gate-pass/requests/$id/reject',
                              body: {'remark': reason.text.trim()},
                            );
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (_) {
                            if (mounted) {
                              showGatePassMessage(
                                this.context,
                                message: 'ส่งกลับแก้ไขไม่สำเร็จ',
                                error: true,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.undo_outlined),
                        label: const Text('ส่งกลับ'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    reason.dispose();
    if (accepted == true && mounted) {
      showGatePassMessage(context, message: 'ส่งกลับแก้ไขแล้ว');
      _retry();
    }
  }

  Future<void> _handoverRequest(Object id) async {
    final recipient = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(gatePassUiTokens.radius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: gatePassUiTokens.cardPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ส่งมอบทรัพย์สิน',
                      style: gatePassUiTokens.captionStyle,
                    ),
                  ),
                ),
                Divider(color: gatePassUiTokens.borderColor),
                TextField(
                  controller: recipient,
                  style: gatePassUiTokens.inputStyle,
                  decoration: const InputDecoration(labelText: 'ผู้รับมอบ *'),
                ),
                Divider(color: gatePassUiTokens.borderColor),
                SizedBox(
                  height: gatePassUiTokens.buttonHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ยกเลิก'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          if (recipient.text.trim().isEmpty) return;
                          try {
                            await _api.post(
                              '/api/company/gate-pass/requests/$id/handover',
                              body: {'recipient': recipient.text.trim()},
                            );
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                          } catch (_) {
                            if (mounted) {
                              showGatePassMessage(
                                this.context,
                                message: 'ส่งมอบทรัพย์สินไม่สำเร็จ',
                                error: true,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.handshake_outlined),
                        label: const Text('ยืนยันส่งมอบ'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    recipient.dispose();
    if (accepted == true && mounted) {
      showGatePassMessage(context, message: 'ส่งมอบทรัพย์สินแล้ว');
      _retry();
    }
  }

  Future<void> _viewRequest(Object id) async {
    try {
      final responses = await Future.wait<dynamic>([
        _api.get('/api/company/gate-pass/requests/$id?menu=${widget.menuCode}'),
        _api.get(
          '/api/company/gate-pass/requests/$id/attachments?menu=${widget.menuCode}',
        ),
      ]);
      if (!mounted) return;
      final detail = _map(responses.first);
      final attachments = _rows(_map(responses.last));
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(gatePassUiTokens.radius),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
            child: Padding(
              padding: gatePassUiTokens.cardPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'รายละเอียดใบขอ ${detail['number'] ?? ''}',
                        style: gatePassUiTokens.captionStyle,
                      ),
                    ),
                  ),
                  Divider(color: gatePassUiTokens.borderColor),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _detailRow('สถานะ', detail['status']),
                          _detailRow('ผู้รับมอบ', detail['carrier']),
                          _detailRow('ปลายทาง', detail['destination']),
                          _detailRow(
                            'การรับคืน',
                            detail['isReturnRequired'] == true
                                ? 'ต้องรับคืน'
                                : 'ไม่รับคืน',
                          ),
                          _detailRow('หมายเหตุ', detail['remark']),
                          const SizedBox(height: 16),
                          Text(
                            'รายการทรัพย์สิน',
                            style: gatePassUiTokens.sectionStyle,
                          ),
                          const SizedBox(height: 8),
                          ..._rows(detail).map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item['name']?.toString() ?? '-',
                                style: gatePassUiTokens.inputStyle,
                              ),
                              subtitle: Text(
                                '${item['quantity'] ?? '-'} ${item['unit'] ?? ''}',
                                style: gatePassUiTokens.inputStyle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'รูปประกอบ (${attachments.length})',
                            style: gatePassUiTokens.sectionStyle,
                          ),
                          const SizedBox(height: 8),
                          if (attachments.isEmpty)
                            Text(
                              'ไม่มีรูปประกอบ',
                              style: gatePassUiTokens.inputStyle,
                            )
                          else
                            ...attachments.map(
                              (file) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.image_outlined),
                                title: Text(
                                  file['fileName']?.toString() ?? '-',
                                  style: gatePassUiTokens.inputStyle,
                                ),
                                subtitle: Text(
                                  '${file['stage'] ?? '-'} • ${_fileSize(file['fileSizeBytes'])}',
                                  style: gatePassUiTokens.inputStyle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: gatePassUiTokens.borderColor),
                  SizedBox(
                    height: gatePassUiTokens.buttonHeight,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('ปิด'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        showGatePassMessage(
          context,
          message: 'โหลดรายละเอียดใบขอไม่สำเร็จ',
          error: true,
        );
      }
    }
  }

  Widget _detailRow(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: gatePassUiTokens.inputStyle),
        ),
        Expanded(
          child: Text(
            value?.toString().trim().isNotEmpty == true
                ? value.toString()
                : '-',
            style: gatePassUiTokens.sectionStyle,
          ),
        ),
      ],
    ),
  );

  String _fileSize(Object? value) {
    final bytes = num.tryParse(value?.toString() ?? '') ?? 0;
    return bytes >= 1024 * 1024
        ? '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB'
        : '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  Future<void> _createRequest([Map<String, dynamic>? row]) async {
    var editing = row != null;
    Map<String, dynamic> detail = const {};
    var yearFormat = 'C';
    List<Map<String, dynamic>> purposeOptions = const [];
    try {
      final setup = _map(await _api.get('/api/system/company-setup/runtime'));
      yearFormat = setup['yearFormat']?.toString().toUpperCase() ?? 'C';
      purposeOptions = _rows(
        _map(await _api.get('/api/company/gate-pass/purpose-options')),
      );
      if (editing) {
        detail = _map(
          await _api.get(
            '/api/company/gate-pass/requests/${row['id']}?menu=${widget.menuCode}',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        showGatePassMessage(
          context,
          message: 'โหลดวัตถุประสงค์หรือรายละเอียดใบขอไม่สำเร็จ',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;
    if (purposeOptions.isEmpty) {
      showGatePassMessage(
        context,
        message: 'กรุณาเพิ่มวัตถุประสงค์การนำออกก่อนสร้างใบขอ',
        error: true,
      );
      return;
    }
    final carrier = TextEditingController(
      text: detail['carrier']?.toString() ?? '',
    );
    final destination = TextEditingController(
      text: detail['destination']?.toString() ?? '',
    );
    final carrierPhone = TextEditingController(
      text: detail['carrierPhone']?.toString() ?? '',
    );
    var documentDate =
        DateTime.tryParse(detail['documentDateTime']?.toString() ?? '') ??
        DateTime.now();
    final savedExitDate = DateTime.tryParse(
      detail['plannedExitDate']?.toString() ?? '',
    );
    var exitDate =
        savedExitDate ??
        DateTime(documentDate.year, documentDate.month, documentDate.day);
    var exitDateFollowsDocument = savedExitDate == null;
    String formatDocumentDate(DateTime value) {
      final year = {'B', 'BE', 'T', 'TH', 'THAI'}.contains(yearFormat)
          ? value.year + 543
          : value.year;
      return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/$year';
    }

    var documentNumber = detail['number']?.toString() ?? '';
    final itemName = TextEditingController();
    final itemRemark = TextEditingController();
    final draftItemFiles = <PlatformFile>[];
    int? itemPurposeId;
    final quantity = TextEditingController(text: '1');
    final unit = TextEditingController();
    final remark = TextEditingController(
      text: detail['remark']?.toString() ?? '',
    );
    final photos = <PlatformFile>[];
    var fileRevision = 0;
    final items = List<Map<String, dynamic>>.of(_rows(detail));
    var purposeId = int.tryParse(detail['purposeID']?.toString() ?? '');
    var returnRequired = false;
    DateTime? itemReturnDate;
    bool mustReturn(int? selectedPurpose) {
      final effective = selectedPurpose ?? purposeId;
      return purposeOptions.any(
        (option) =>
            int.tryParse(option['id'].toString()) == effective &&
            option['alwaysReturnRequired'] == true,
      );
    }

    DateTime? calculateReturnDate(int? selectedPurpose) {
      final effectivePurpose = selectedPurpose ?? purposeId;
      if (effectivePurpose == null) return null;
      for (final option in purposeOptions) {
        if (int.tryParse(option['id'].toString()) == effectivePurpose) {
          final days = int.tryParse(option['returnDays']?.toString() ?? '');
          if (days != null && days > 0)
            return DateTime(
              exitDate.year,
              exitDate.month,
              exitDate.day,
            ).add(Duration(days: days));
        }
      }
      return null;
    }

    void recalculateReturnDates() {
      if (mustReturn(itemPurposeId)) returnRequired = true;
      if (returnRequired) itemReturnDate = calculateReturnDate(itemPurposeId);
      for (final item in items) {
        final selected = int.tryParse(item['purposeId']?.toString() ?? '');
        final newlyRequired =
            mustReturn(selected) && item['isReturnRequired'] != true;
        if (newlyRequired) item['isReturnRequired'] = true;
        if (item['isReturnRequired'] == true && (!editing || newlyRequired)) {
          item['expectedReturnDate'] = calculateReturnDate(
            selected,
          )?.toIso8601String();
        }
      }
    }

    if (mustReturn(itemPurposeId)) {
      returnRequired = true;
      itemReturnDate = calculateReturnDate(itemPurposeId);
    }

    var photoUploadFailed = 0;
    var saving = false;
    int? editingItemIndex;
    Object? currentRequestId = row?['id'];
    var savedAny = false;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => buildGatePassWorkspaceShell(
            pageTitle: _title,
            activeMenu: widget.menuCode,
            child: Padding(
              padding: gatePassUiTokens.contentMargin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LaooCaptionCard(
                    tokens: _sharedTokens(context),
                    caption: '$_title > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
                    trailing: SizedBox(
                      height: gatePassUiTokens.buttonHeight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_canPrint && currentRequestId != null) ...[
                            Tooltip(
                              message: 'พิมพ์ข้อมูลที่บันทึกล่าสุด',
                              child: OutlinedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () => _printRequest({
                                        'id': currentRequestId,
                                      }),
                                icon: const Icon(Icons.print_outlined),
                                label: const Text('พิมพ์'),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(context, savedAny),
                            child: const Text('ยกเลิก'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: saving || (editing && !_canEdit)
                                ? null
                                : () async {
                                    final qty = num.tryParse(quantity.text);
                                    if (itemName.text.trim().isNotEmpty &&
                                        returnRequired &&
                                        itemReturnDate == null) {
                                      showGatePassMessage(
                                        this.context,
                                        message:
                                            'กรุณาเลือกวัตถุประสงค์เพื่อกำหนดวันนำกลับ',
                                        error: true,
                                      );
                                      return;
                                    }
                                    final pendingItems =
                                        List<Map<String, dynamic>>.from(items);
                                    if (draftItemFiles.isNotEmpty &&
                                        itemName.text.trim().isEmpty) {
                                      showGatePassMessage(
                                        this.context,
                                        message:
                                            'กรุณาระบุชื่อทรัพย์สินสำหรับไฟล์แนบ',
                                        error: true,
                                      );
                                      return;
                                    }
                                    if (editingItemIndex != null &&
                                        (itemName.text.trim().isEmpty ||
                                            qty == null ||
                                            qty <= 0)) {
                                      showGatePassMessage(
                                        this.context,
                                        message:
                                            'กรุณาระบุชื่อและจำนวนทรัพย์สิน',
                                        error: true,
                                      );
                                      return;
                                    }
                                    if (itemName.text.trim().isNotEmpty &&
                                        qty != null &&
                                        qty > 0) {
                                      final updatedItem = <String, dynamic>{
                                        if (editingItemIndex != null)
                                          ...pendingItems[editingItemIndex!],
                                        'name': itemName.text.trim(),
                                        'quantity': qty,
                                        'isReturnRequired': returnRequired,
                                        'expectedReturnDate': returnRequired
                                            ? itemReturnDate?.toIso8601String()
                                            : null,
                                        'purposeId': itemPurposeId,
                                        'remark': itemRemark.text.trim().isEmpty
                                            ? null
                                            : itemRemark.text.trim(),
                                        '_files': List<PlatformFile>.from(
                                          draftItemFiles,
                                        ),
                                        'unit': unit.text.trim().isEmpty
                                            ? null
                                            : unit.text.trim(),
                                        if (editingItemIndex == null)
                                          'serialNo': null,
                                      };
                                      if (editingItemIndex == null) {
                                        pendingItems.add(updatedItem);
                                      } else {
                                        pendingItems[editingItemIndex!] =
                                            updatedItem;
                                      }
                                    }
                                    if (carrierPhone.text.trim().isEmpty) {
                                      showGatePassMessage(
                                        this.context,
                                        message: 'กรุณาระบุเบอร์โทรผู้รับมอบ',
                                        error: true,
                                      );
                                      return;
                                    }
                                    if (carrierPhone.text.trim().length > 40) {
                                      showGatePassMessage(
                                        this.context,
                                        message:
                                            'เบอร์โทรผู้รับมอบต้องไม่เกิน 40 ตัวอักษร',
                                        error: true,
                                      );
                                      return;
                                    }
                                    if (purposeId == null ||
                                        carrier.text.trim().isEmpty ||
                                        carrierPhone.text.trim().isEmpty ||
                                        destination.text.trim().isEmpty ||
                                        pendingItems.isEmpty) {
                                      showGatePassMessage(
                                        this.context,
                                        message:
                                            'กรุณากรอกข้อมูลเอกสารและรายการทรัพย์สินให้ครบ',
                                        error: true,
                                      );
                                      return;
                                    }
                                    setDialogState(() => saving = true);
                                    try {
                                      final body = {
                                        'purposeId': purposeId,
                                        'carrier': carrier.text.trim(),
                                        'carrierPhone': carrierPhone.text
                                            .trim(),
                                        'documentDateTime': documentDate
                                            .toIso8601String(),
                                        'plannedExitDate': exitDate
                                            .toIso8601String(),
                                        'destination': destination.text.trim(),
                                        'isReturnRequired': returnRequired,
                                        'remark': remark.text.trim().isEmpty
                                            ? null
                                            : remark.text.trim(),
                                        'items': pendingItems
                                            .map(
                                              (item) =>
                                                  Map<String, dynamic>.from(
                                                    item,
                                                  )..remove('_files'),
                                            )
                                            .toList(),
                                      };
                                      Object? requestId = currentRequestId;
                                      Map<String, dynamic> response;
                                      if (editing) {
                                        response = _map(
                                          await _api.put(
                                            '/api/company/gate-pass/requests/$requestId',
                                            body: body,
                                          ),
                                        );
                                      } else {
                                        response = _map(
                                          await _api.post(
                                            '/api/company/gate-pass/requests',
                                            body: body,
                                          ),
                                        );
                                        requestId = response['id'];
                                      }
                                      final itemIds = response['itemIds'];
                                      if (itemIds is List &&
                                          itemIds.length ==
                                              pendingItems.length) {
                                        for (
                                          var i = 0;
                                          i < itemIds.length;
                                          i++
                                        ) {
                                          pendingItems[i]['id'] = itemIds[i];
                                        }
                                      }
                                      if (requestId != null) {
                                        currentRequestId = requestId;
                                        editing = true;
                                        savedAny = true;
                                        try {
                                          final refreshed = _map(
                                            await _api.get(
                                              '/api/company/gate-pass/requests/$requestId',
                                            ),
                                          );
                                          documentNumber =
                                              refreshed['number']?.toString() ??
                                              documentNumber;
                                        } catch (_) {
                                          /* The document was saved; do not create it again. */
                                        }
                                      }
                                      if (requestId != null) {
                                        for (final photo
                                            in List<PlatformFile>.from(
                                              photos,
                                            )) {
                                          try {
                                            await _api.post(
                                              '/api/company/gate-pass/requests/$requestId/request-files',
                                              body: {
                                                'fileName': photo.name,
                                                'base64': base64Encode(
                                                  photo.bytes!,
                                                ),
                                                'itemId': null,
                                              },
                                            );
                                            photos.remove(photo);
                                          } catch (_) {
                                            photoUploadFailed++;
                                          }
                                        }
                                        for (final item in pendingItems) {
                                          final files =
                                              item['_files']
                                                  as List<PlatformFile>?;
                                          if (files == null) continue;
                                          if (item['id'] == null) {
                                            photoUploadFailed += files.length;
                                            continue;
                                          }
                                          for (final file
                                              in List<PlatformFile>.from(
                                                files,
                                              )) {
                                            try {
                                              await _api.post(
                                                '/api/company/gate-pass/requests/$requestId/request-files',
                                                body: {
                                                  'fileName': file.name,
                                                  'base64': base64Encode(
                                                    file.bytes!,
                                                  ),
                                                  'itemId': item['id'],
                                                },
                                              );
                                              files.remove(file);
                                            } catch (_) {
                                              photoUploadFailed++;
                                            }
                                          }
                                        }
                                      }
                                      if (context.mounted) {
                                        setDialogState(() {
                                          currentRequestId = requestId;
                                          editing = true;
                                          editingItemIndex = null;
                                          savedAny = true;
                                          items
                                            ..clear()
                                            ..addAll(pendingItems);
                                          itemName.clear();
                                          itemRemark.clear();
                                          itemPurposeId = null;
                                          returnRequired = mustReturn(null);
                                          itemReturnDate = returnRequired
                                              ? calculateReturnDate(null)
                                              : null;
                                          draftItemFiles.clear();
                                          quantity.text = '1';
                                          unit.clear();
                                          fileRevision++;
                                        });
                                        showGatePassMessage(
                                          context,
                                          message: photoUploadFailed > 0
                                              ? 'บันทึกใบขอแล้ว แต่มี $photoUploadFailed รูปที่แนบไม่สำเร็จ'
                                              : 'บันทึกใบขอฉบับร่างแล้ว',
                                          error: photoUploadFailed > 0,
                                        );
                                        photoUploadFailed = 0;
                                      }
                                    } catch (_) {
                                      if (mounted) {
                                        showGatePassMessage(
                                          this.context,
                                          message: editing
                                              ? 'แก้ไขใบขอไม่สำเร็จ'
                                              : 'สร้างใบขอไม่สำเร็จ',
                                          error: true,
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setDialogState(() => saving = false);
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.save_outlined),
                            label: Text(editing ? 'บันทึก' : 'บันทึกร่าง'),
                          ),
                        ],
                      ),
                    ),
                    leading: Icon(
                      _menuIcon,
                      color: gatePassUiTokens.primaryColor,
                    ),
                  ),
                  SizedBox(height: gatePassUiTokens.sectionSpacing),
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: Theme.of(context)
                            .inputDecorationTheme
                            .copyWith(
                              labelStyle: gatePassUiTokens.inputStyle,
                              hintStyle: gatePassUiTokens.inputStyle,
                              floatingLabelStyle: gatePassUiTokens.inputStyle
                                  .copyWith(
                                    fontSize:
                                        (gatePassUiTokens.inputStyle.fontSize ??
                                            16) /
                                        .75,
                                    color: gatePassUiTokens.primaryColor,
                                  ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  gatePassUiTokens.radius,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  gatePassUiTokens.radius,
                                ),
                                borderSide: BorderSide(
                                  color: gatePassUiTokens.borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  gatePassUiTokens.radius,
                                ),
                                borderSide: BorderSide(
                                  color: gatePassUiTokens.primaryColor,
                                ),
                              ),
                            ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LaooSurfaceCard(
                              tokens: _sharedTokens(context),
                              padding: gatePassUiTokens.cardPadding,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: gatePassUiTokens.primaryColor
                                          .withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(
                                        gatePassUiTokens.radius,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.description_outlined,
                                          color: gatePassUiTokens.primaryColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'ข้อมูลเอกสาร',
                                          style: gatePassUiTokens.sectionStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 14,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 230,
                                        child: TextFormField(
                                          key: ValueKey(documentNumber),
                                          style: gatePassUiTokens.inputStyle,
                                          initialValue: documentNumber.isEmpty
                                              ? 'ออกเลขเมื่อบันทึก'
                                              : documentNumber,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                            labelText: 'เลขที่เอกสาร',
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 250,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            textStyle:
                                                gatePassUiTokens.inputStyle,
                                          ),
                                          onPressed: saving
                                              ? null
                                              : () async {
                                                  final value =
                                                      await showDatePicker(
                                                        context: context,
                                                        initialDate:
                                                            documentDate,
                                                        firstDate: DateTime(
                                                          2000,
                                                        ),
                                                        lastDate: DateTime(
                                                          2100,
                                                        ),
                                                      );
                                                  if (value != null) {
                                                    setDialogState(() {
                                                      documentDate = DateTime(
                                                        value.year,
                                                        value.month,
                                                        value.day,
                                                        documentDate.hour,
                                                        documentDate.minute,
                                                      );
                                                      if (exitDateFollowsDocument)
                                                        exitDate = DateTime(
                                                          value.year,
                                                          value.month,
                                                          value.day,
                                                        );
                                                      if (exitDateFollowsDocument)
                                                        recalculateReturnDates();
                                                    });
                                                  }
                                                },
                                          icon: const Icon(
                                            Icons.calendar_today_outlined,
                                          ),
                                          label: Text(
                                            'วันที่เอกสาร ${formatDocumentDate(documentDate)}',
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 180,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            textStyle:
                                                gatePassUiTokens.inputStyle,
                                          ),
                                          onPressed: saving
                                              ? null
                                              : () async {
                                                  final value =
                                                      await showTimePicker(
                                                        context: context,
                                                        initialTime:
                                                            TimeOfDay.fromDateTime(
                                                              documentDate,
                                                            ),
                                                      );
                                                  if (value != null)
                                                    setDialogState(
                                                      () => documentDate =
                                                          DateTime(
                                                            documentDate.year,
                                                            documentDate.month,
                                                            documentDate.day,
                                                            value.hour,
                                                            value.minute,
                                                          ),
                                                    );
                                                },
                                          icon: const Icon(Icons.access_time),
                                          label: Text(
                                            'เวลา ${documentDate.hour.toString().padLeft(2, '0')}:${documentDate.minute.toString().padLeft(2, '0')}',
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 270,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            textStyle:
                                                gatePassUiTokens.inputStyle,
                                          ),
                                          onPressed: saving
                                              ? null
                                              : () async {
                                                  final value =
                                                      await showDatePicker(
                                                        context: context,
                                                        initialDate: exitDate,
                                                        firstDate: DateTime(
                                                          2000,
                                                        ),
                                                        lastDate: DateTime(
                                                          2100,
                                                        ),
                                                      );
                                                  if (value != null) {
                                                    setDialogState(() {
                                                      exitDate = value;
                                                      exitDateFollowsDocument =
                                                          false;
                                                      recalculateReturnDates();
                                                    });
                                                  }
                                                },
                                          icon: const Icon(
                                            Icons.calendar_today_outlined,
                                          ),
                                          label: Text(
                                            'วันที่นำออก * ${formatDocumentDate(exitDate)}',
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 300,
                                        child: _GatePassFileGroup(
                                          api: _api,
                                          requestId: currentRequestId,
                                          itemId: null,
                                          isItem: false,
                                          files: photos,
                                          revision: fileRevision,
                                          iconOnly:
                                              !_cards &&
                                              MediaQuery.sizeOf(
                                                    context,
                                                  ).width >=
                                                  gatePassUiTokens
                                                      .compactBreakpoint,
                                          showFiles: false,
                                          onFilesChanged: () =>
                                              setDialogState(() {}),
                                          enabled:
                                              !saving && (!editing || _canEdit),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _GatePassFileGroup(
                                    api: _api,
                                    requestId: currentRequestId,
                                    itemId: null,
                                    isItem: false,
                                    files: photos,
                                    revision: fileRevision,
                                    enabled: !saving && (!editing || _canEdit),
                                    showButtons: false,
                                  ),
                                  const SizedBox(height: 16),
                                  LayoutBuilder(
                                    builder: (context, constraints) => Wrap(
                                      spacing: 8,
                                      runSpacing: 14,
                                      children: [
                                        SizedBox(
                                          width: constraints.maxWidth >= 720
                                              ? (constraints.maxWidth - 24) *
                                                    .25
                                              : constraints.maxWidth,
                                          child: DropdownButtonFormField<int>(
                                            initialValue: purposeId,
                                            isExpanded: true,
                                            style: gatePassUiTokens.inputStyle,
                                            decoration: const InputDecoration(
                                              labelText: 'วัตถุประสงค์ *',
                                            ),
                                            items: purposeOptions
                                                .map(
                                                  (
                                                    option,
                                                  ) => DropdownMenuItem<int>(
                                                    value: int.tryParse(
                                                      option['id'].toString(),
                                                    ),
                                                    child: Text(
                                                      '${option['name'] ?? ''}',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: saving
                                                ? null
                                                : (value) => setDialogState(() {
                                                    purposeId = value;
                                                    recalculateReturnDates();
                                                  }),
                                          ),
                                        ),
                                        SizedBox(
                                          width: constraints.maxWidth >= 720
                                              ? (constraints.maxWidth - 24) *
                                                    .27
                                              : constraints.maxWidth,
                                          child: TextField(
                                            controller: carrier,
                                            style: gatePassUiTokens.inputStyle,
                                            decoration: const InputDecoration(
                                              labelText: 'ผู้รับมอบ *',
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: constraints.maxWidth >= 720
                                              ? (constraints.maxWidth - 24) *
                                                    .27
                                              : constraints.maxWidth,
                                          child: TextField(
                                            controller: destination,
                                            style: gatePassUiTokens.inputStyle,
                                            decoration: const InputDecoration(
                                              labelText: 'ปลายทาง *',
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: constraints.maxWidth >= 720
                                              ? (constraints.maxWidth - 24) *
                                                    .21
                                              : constraints.maxWidth,
                                          child: TextField(
                                            controller: carrierPhone,
                                            keyboardType: TextInputType.phone,
                                            maxLength: 40,
                                            style: gatePassUiTokens.inputStyle,
                                            decoration: const InputDecoration(
                                              labelText: 'เบอร์โทรผู้รับมอบ *',
                                              counterText: '',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: remark,
                                    maxLines: 2,
                                    style: gatePassUiTokens.inputStyle,
                                    decoration: const InputDecoration(
                                      labelText: 'หมายเหตุ',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: gatePassUiTokens.sectionSpacing),
                            LaooSurfaceCard(
                              tokens: _sharedTokens(context),
                              padding: gatePassUiTokens.cardPadding,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffe7efff),
                                      borderRadius: BorderRadius.circular(
                                        gatePassUiTokens.radius,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          color: gatePassUiTokens.primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'รายการทรัพย์สิน',
                                          style: gatePassUiTokens.sectionStyle,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${items.length} รายการ',
                                          style: gatePassUiTokens.inputStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff3f7ff),
                                      border: Border.all(
                                        color: const Color(0xffd5e1f5),
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        gatePassUiTokens.radius,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          editingItemIndex == null
                                              ? 'เพิ่มรายการทรัพย์สิน'
                                              : 'แก้ไขรายการทรัพย์สิน',
                                          style: gatePassUiTokens.sectionStyle,
                                        ),
                                        const SizedBox(height: 16),
                                        LayoutBuilder(
                                          builder: (context, constraints) => Wrap(
                                            spacing: 8,
                                            runSpacing: 14,
                                            children: [
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth >= 720
                                                    ? (constraints.maxWidth -
                                                              16) *
                                                          .30
                                                    : constraints.maxWidth,
                                                child: DropdownButtonFormField<int>(
                                                  key: ValueKey(
                                                    'item-purpose-$itemPurposeId',
                                                  ),
                                                  initialValue: itemPurposeId,
                                                  isExpanded: true,
                                                  style: gatePassUiTokens
                                                      .inputStyle,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'วัตถุประสงค์',
                                                      ),
                                                  items: [
                                                    const DropdownMenuItem<int>(
                                                      value: null,
                                                      child: Text('ไม่ระบุ'),
                                                    ),
                                                    ...purposeOptions.map(
                                                      (
                                                        option,
                                                      ) => DropdownMenuItem<int>(
                                                        value: int.tryParse(
                                                          option['id']
                                                              .toString(),
                                                        ),
                                                        child: Text(
                                                          option['name']
                                                                  ?.toString() ??
                                                              '',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: saving
                                                      ? null
                                                      : (
                                                          value,
                                                        ) => setDialogState(() {
                                                          itemPurposeId = value;
                                                          if (mustReturn(value))
                                                            returnRequired =
                                                                true;
                                                          if (returnRequired)
                                                            itemReturnDate =
                                                                calculateReturnDate(
                                                                  value,
                                                                );
                                                        }),
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth >= 720
                                                    ? (constraints.maxWidth -
                                                              16) *
                                                          .35
                                                    : constraints.maxWidth,
                                                child: TextField(
                                                  controller: itemName,
                                                  style: gatePassUiTokens
                                                      .inputStyle,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'ชื่อทรัพย์สิน *',
                                                      ),
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth >= 720
                                                    ? (constraints.maxWidth -
                                                              16) *
                                                          .35
                                                    : constraints.maxWidth,
                                                child: TextField(
                                                  controller: itemRemark,
                                                  maxLength: 1000,
                                                  style: gatePassUiTokens
                                                      .inputStyle,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'หมายเหตุ',
                                                        counterText: '',
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 140,
                                              child: TextField(
                                                controller: quantity,
                                                keyboardType:
                                                    TextInputType.number,
                                                style:
                                                    gatePassUiTokens.inputStyle,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'จำนวน *',
                                                    ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 160,
                                              child: TextField(
                                                controller: unit,
                                                style:
                                                    gatePassUiTokens.inputStyle,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'หน่วย',
                                                    ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 240,
                                              child: SwitchListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(
                                                  'ต้องรับทรัพย์สินคืน',
                                                  style: gatePassUiTokens
                                                      .inputStyle,
                                                ),
                                                value: returnRequired,
                                                onChanged:
                                                    saving ||
                                                        mustReturn(
                                                          itemPurposeId,
                                                        )
                                                    ? null
                                                    : (
                                                        value,
                                                      ) => setDialogState(() {
                                                        returnRequired = value;
                                                        itemReturnDate = value
                                                            ? calculateReturnDate(
                                                                itemPurposeId,
                                                              )
                                                            : null;
                                                      }),
                                              ),
                                            ),
                                            if (returnRequired)
                                              OutlinedButton.icon(
                                                onPressed:
                                                    saving ||
                                                        itemReturnDate == null
                                                    ? null
                                                    : () async {
                                                        final selected =
                                                            await showDatePicker(
                                                              context: context,
                                                              initialDate:
                                                                  itemReturnDate!,
                                                              firstDate:
                                                                  DateTime(
                                                                    2000,
                                                                  ),
                                                              lastDate:
                                                                  DateTime(
                                                                    2100,
                                                                  ),
                                                            );
                                                        if (selected != null)
                                                          setDialogState(
                                                            () =>
                                                                itemReturnDate =
                                                                    selected,
                                                          );
                                                      },
                                                icon: const Icon(
                                                  Icons.event_outlined,
                                                ),
                                                label: Text(
                                                  itemReturnDate == null
                                                      ? 'นำกลับภายในวันที่: เลือกวัตถุประสงค์'
                                                      : 'นำกลับภายในวันที่ ${formatDocumentDate(itemReturnDate!)}',
                                                ),
                                              ),
                                            _GatePassFileGroup(
                                              api: _api,
                                              requestId: null,
                                              itemId: null,
                                              isItem: true,
                                              files: draftItemFiles,
                                              revision: fileRevision,
                                              iconOnly:
                                                  !_cards &&
                                                  MediaQuery.sizeOf(
                                                        context,
                                                      ).width >=
                                                      gatePassUiTokens
                                                          .compactBreakpoint,
                                              showFiles: false,
                                              onFilesChanged: () =>
                                                  setDialogState(() {}),
                                              enabled:
                                                  !saving &&
                                                  (!editing || _canEdit),
                                            ),
                                            FilledButton.icon(
                                              onPressed: saving
                                                  ? null
                                                  : () {
                                                      final qty = num.tryParse(
                                                        quantity.text,
                                                      );
                                                      if (returnRequired &&
                                                          itemReturnDate ==
                                                              null) {
                                                        showGatePassMessage(
                                                          this.context,
                                                          message:
                                                              'กรุณาเลือกวัตถุประสงค์เพื่อกำหนดวันนำกลับ',
                                                          error: true,
                                                        );
                                                        return;
                                                      }
                                                      if (itemName.text
                                                              .trim()
                                                              .isEmpty ||
                                                          qty == null ||
                                                          qty <= 0) {
                                                        showGatePassMessage(
                                                          this.context,
                                                          message:
                                                              'กรุณาระบุชื่อและจำนวนทรัพย์สิน',
                                                          error: true,
                                                        );
                                                        return;
                                                      }
                                                      setDialogState(() {
                                                        final updatedItem = <String, dynamic>{
                                                          if (editingItemIndex !=
                                                              null)
                                                            ...items[editingItemIndex!],
                                                          'name': itemName.text
                                                              .trim(),
                                                          'quantity': qty,
                                                          'isReturnRequired':
                                                              returnRequired,
                                                          'expectedReturnDate':
                                                              returnRequired
                                                              ? itemReturnDate
                                                                    ?.toIso8601String()
                                                              : null,
                                                          'purposeId':
                                                              itemPurposeId,
                                                          'remark':
                                                              itemRemark.text
                                                                  .trim()
                                                                  .isEmpty
                                                              ? null
                                                              : itemRemark.text
                                                                    .trim(),
                                                          '_files':
                                                              List<
                                                                PlatformFile
                                                              >.from(
                                                                draftItemFiles,
                                                              ),
                                                          'unit':
                                                              unit.text
                                                                  .trim()
                                                                  .isEmpty
                                                              ? null
                                                              : unit.text
                                                                    .trim(),
                                                          if (editingItemIndex ==
                                                              null)
                                                            'serialNo': null,
                                                        };
                                                        if (editingItemIndex ==
                                                            null) {
                                                          items.add(
                                                            updatedItem,
                                                          );
                                                        } else {
                                                          items[editingItemIndex!] =
                                                              updatedItem;
                                                          editingItemIndex =
                                                              null;
                                                        }
                                                        itemName.clear();
                                                        itemRemark.clear();
                                                        itemPurposeId = null;
                                                        returnRequired =
                                                            mustReturn(null);
                                                        itemReturnDate =
                                                            returnRequired
                                                            ? calculateReturnDate(
                                                                null,
                                                              )
                                                            : null;
                                                        draftItemFiles.clear();
                                                        quantity.text = '1';
                                                        unit.clear();
                                                      });
                                                    },
                                              icon: const Icon(
                                                Icons.playlist_add,
                                              ),
                                              label: Text(
                                                editingItemIndex == null
                                                    ? 'เพิ่มรายการ'
                                                    : 'บันทึกรายการ',
                                              ),
                                            ),
                                            if (editingItemIndex != null)
                                              OutlinedButton.icon(
                                                style:
                                                    _filterOutlinedStyle(
                                                      gatePassUiTokens,
                                                    ).copyWith(
                                                      foregroundColor:
                                                          WidgetStatePropertyAll(
                                                            Theme.of(
                                                              context,
                                                            ).colorScheme.error,
                                                          ),
                                                      side: WidgetStatePropertyAll(
                                                        BorderSide(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.error,
                                                        ),
                                                      ),
                                                    ),
                                                onPressed: saving
                                                    ? null
                                                    : () => setDialogState(() {
                                                        items.removeAt(
                                                          editingItemIndex!,
                                                        );
                                                        editingItemIndex = null;
                                                        itemName.clear();
                                                        itemPurposeId = null;
                                                        quantity.text = '1';
                                                        unit.clear();
                                                        returnRequired =
                                                            mustReturn(null);
                                                        itemReturnDate =
                                                            returnRequired
                                                            ? calculateReturnDate(
                                                                null,
                                                              )
                                                            : null;
                                                      }),
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                ),
                                                label: const Text('ลบ'),
                                              ),
                                            if (editingItemIndex != null)
                                              OutlinedButton(
                                                style: _filterOutlinedStyle(
                                                  gatePassUiTokens,
                                                ),
                                                onPressed: saving
                                                    ? null
                                                    : () => setDialogState(() {
                                                        editingItemIndex = null;
                                                        itemName.clear();
                                                        quantity.text = '1';
                                                        unit.clear();
                                                      }),
                                                child: const Text(
                                                  'ยกเลิกแก้ไขรายการ',
                                                ),
                                              ),
                                          ],
                                        ),
                                        _GatePassFileGroup(
                                          api: _api,
                                          requestId: null,
                                          itemId: null,
                                          isItem: true,
                                          files: draftItemFiles,
                                          revision: fileRevision,
                                          enabled:
                                              !saving && (!editing || _canEdit),
                                          showButtons: false,
                                          onFilesChanged: () =>
                                              setDialogState(() {}),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (items.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    Text(
                                      'รายการที่เพิ่มแล้ว',
                                      style: gatePassUiTokens.sectionStyle,
                                    ),
                                    ...List<Widget>.generate(
                                      items.length,
                                      (index) => Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                            color: gatePassUiTokens.borderColor,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            gatePassUiTokens.radius,
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final wide =
                                                constraints.maxWidth >= 700;
                                            final available =
                                                constraints.maxWidth -
                                                (wide ? 16 : 0);
                                            return Wrap(
                                              spacing: 16,
                                              runSpacing: 16,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.start,
                                              children: [
                                                SizedBox(
                                                  width: wide
                                                      ? available * .6
                                                      : constraints.maxWidth,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Wrap(
                                                        spacing: 4,
                                                        children: [
                                                          _responsiveItemAction(
                                                            iconOnly:
                                                                constraints
                                                                    .maxWidth >=
                                                                gatePassUiTokens
                                                                    .compactBreakpoint,
                                                            style: _filterOutlinedStyle(
                                                              gatePassUiTokens,
                                                            ),
                                                            onPressed:
                                                                saving ||
                                                                    editingItemIndex !=
                                                                        null ||
                                                                    (editing &&
                                                                        !_canEdit)
                                                                ? null
                                                                : () => setDialogState(() {
                                                                    editingItemIndex =
                                                                        index;
                                                                    itemPurposeId =
                                                                        int.tryParse(
                                                                          items[index]['purposeId']?.toString() ??
                                                                              '',
                                                                        );
                                                                    itemRemark
                                                                            .text =
                                                                        items[index]['remark']
                                                                            ?.toString() ??
                                                                        '';
                                                                    draftItemFiles
                                                                      ..clear()
                                                                      ..addAll(
                                                                        (items[index]['_files']
                                                                                as List<
                                                                                  PlatformFile
                                                                                >?) ??
                                                                            const [],
                                                                      );
                                                                    itemName.text =
                                                                        items[index]['name']
                                                                            ?.toString() ??
                                                                        '';
                                                                    quantity.text =
                                                                        items[index]['quantity']
                                                                            ?.toString() ??
                                                                        '1';
                                                                    unit.text =
                                                                        items[index]['unit']
                                                                            ?.toString() ??
                                                                        '';
                                                                    returnRequired =
                                                                        items[index]['isReturnRequired'] ==
                                                                            true ||
                                                                        mustReturn(
                                                                          itemPurposeId,
                                                                        );
                                                                    itemReturnDate =
                                                                        DateTime.tryParse(
                                                                          items[index]['expectedReturnDate']?.toString() ??
                                                                              '',
                                                                        ) ??
                                                                        (returnRequired
                                                                            ? calculateReturnDate(
                                                                                itemPurposeId,
                                                                              )
                                                                            : null);
                                                                  }),
                                                            icon: Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                              color: gatePassUiTokens
                                                                  .primaryColor,
                                                            ),
                                                            label: const Text(
                                                              'แก้ไข',
                                                            ),
                                                          ),
                                                          _responsiveItemAction(
                                                            iconOnly:
                                                                constraints
                                                                    .maxWidth >=
                                                                gatePassUiTokens
                                                                    .compactBreakpoint,
                                                            style: _filterOutlinedStyle(gatePassUiTokens).copyWith(
                                                              foregroundColor:
                                                                  WidgetStatePropertyAll(
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .error,
                                                                  ),
                                                              side: WidgetStatePropertyAll(
                                                                BorderSide(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.error,
                                                                ),
                                                              ),
                                                            ),
                                                            onPressed:
                                                                saving ||
                                                                    editingItemIndex !=
                                                                        null ||
                                                                    (editing &&
                                                                        !_canEdit)
                                                                ? null
                                                                : () => setDialogState(
                                                                    () => items
                                                                        .removeAt(
                                                                          index,
                                                                        ),
                                                                  ),
                                                            icon: Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              color: Theme.of(
                                                                context,
                                                              ).colorScheme.error,
                                                            ),
                                                            label: const Text(
                                                              'ลบ',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        '${items[index]['name']}  •  ${items[index]['quantity']} ${items[index]['unit'] ?? ''}',
                                                        style: gatePassUiTokens
                                                            .inputStyle,
                                                      ),
                                                      Text(
                                                        [
                                                              [
                                                                if (items[index]['purposeId'] !=
                                                                    null)
                                                                  'วัตถุประสงค์: ${purposeOptions.where((p) => '${p['id']}' == '${items[index]['purposeId']}').map((p) => p['name']).join()}',
                                                                if (items[index]['isReturnRequired'] ==
                                                                        true &&
                                                                    DateTime.tryParse(
                                                                          items[index]['expectedReturnDate']?.toString() ??
                                                                              '',
                                                                        ) !=
                                                                        null)
                                                                  'นำกลับภายในวันที่ ${formatDocumentDate(DateTime.parse(items[index]['expectedReturnDate'].toString()))}',
                                                              ].join(' • '),
                                                              if (items[index]['remark']
                                                                      ?.toString()
                                                                      .trim()
                                                                      .isNotEmpty ==
                                                                  true)
                                                                'หมายเหตุ: ${items[index]['remark']}',
                                                            ]
                                                            .where(
                                                              (line) => line
                                                                  .isNotEmpty,
                                                            )
                                                            .join('\n'),
                                                        style: gatePassUiTokens
                                                            .inputStyle,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: wide
                                                      ? available * .4
                                                      : constraints.maxWidth,
                                                  child: _GatePassFileGroup(
                                                    api: _api,
                                                    requestId: currentRequestId,
                                                    itemId: items[index]['id'],
                                                    isItem: true,
                                                    files:
                                                        items[index].putIfAbsent(
                                                              '_files',
                                                              () =>
                                                                  <
                                                                    PlatformFile
                                                                  >[],
                                                            )
                                                            as List<
                                                              PlatformFile
                                                            >,
                                                    revision: fileRevision,
                                                    iconOnly:
                                                        !_cards &&
                                                        MediaQuery.sizeOf(
                                                              context,
                                                            ).width >=
                                                            gatePassUiTokens
                                                                .compactBreakpoint,
                                                    onFilesChanged: () =>
                                                        setDialogState(() {}),
                                                    enabled:
                                                        !saving &&
                                                        (!editing || _canEdit),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (final controller in [
      carrier,
      destination,
      carrierPhone,
      itemName,
      itemRemark,
      quantity,
      unit,
      remark,
    ]) {
      controller.dispose();
    }
    if (savedAny && mounted) _retry();
  }

  Widget _responsiveItemAction({
    required bool iconOnly,
    required ButtonStyle style,
    required VoidCallback? onPressed,
    required Widget icon,
    required Text label,
  }) => iconOnly
      ? IconButton(tooltip: label.data, onPressed: onPressed, icon: icon)
      : OutlinedButton.icon(
          style: style,
          onPressed: onPressed,
          icon: icon,
          label: label,
        );

  Future<void> _printRequest(Map<String, dynamic> row) async {
    try {
      if (!row.containsKey('requesterName')) {
        final rows = _rows(
          _map(await _api.get('/api/company/gate-pass/requests')),
        );
        row = rows.firstWhere(
          (item) => '${item['id']}' == '${row['id']}',
          orElse: () => row,
        );
      }
      final data = _map(
        await _api.get('/api/company/gate-pass/requests/${row['id']}/print'),
      );
      await printGatePass(data, row, _requestPurposes, _requestYearFormat);
    } catch (_) {
      if (mounted)
        showGatePassMessage(
          context,
          message: 'พิมพ์ใบขอไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองอีกครั้ง',
          error: true,
        );
    }
  }

  Widget _rowActions(Map<String, dynamic> row, {bool card = false}) {
    final id = row['id'];
    if (widget.endpoint == 'approvals' && _canApprove && id != null) {
      return Wrap(
        children: [
          IconButton(
            tooltip: 'ดูรายละเอียด',
            onPressed: () => _viewRequest(id),
            icon: const Icon(Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: 'อนุมัติ',
            onPressed: () =>
                _runRequestAction(id, 'approve', 'อนุมัติใบขอแล้ว'),
            icon: Icon(
              Icons.check_circle_outline,
              color: gatePassUiTokens.primaryColor,
            ),
          ),
          if (_canEdit)
            IconButton(
              tooltip: 'ส่งกลับแก้ไข',
              onPressed: () => _rejectRequest(id),
              icon: Icon(
                Icons.undo_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      );
    }
    if (widget.endpoint == 'exit-check' && _canConfirmExit && id != null) {
      return Wrap(
        children: [
          IconButton(
            tooltip: 'ดูรายละเอียด',
            onPressed: () => _viewRequest(id),
            icon: const Icon(Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: 'แนบรูปตรวจออก',
            onPressed: () => _uploadStagePhoto(id, 'EXIT'),
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              color: gatePassUiTokens.primaryColor,
            ),
          ),
          IconButton(
            tooltip: 'ยืนยันตรวจออก',
            onPressed: () =>
                _runRequestAction(id, 'confirm-exit', 'ยืนยันการตรวจออกแล้ว'),
            icon: Icon(
              Icons.verified_outlined,
              color: gatePassUiTokens.primaryColor,
            ),
          ),
        ],
      );
    }
    if (widget.endpoint == 'returns' && _canConfirmReturn && id != null) {
      return Wrap(
        children: [
          IconButton(
            tooltip: 'ดูรายละเอียด',
            onPressed: () => _viewRequest(id),
            icon: const Icon(Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: 'แนบรูปรับคืน',
            onPressed: () => _uploadStagePhoto(id, 'RETURN'),
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              color: gatePassUiTokens.primaryColor,
            ),
          ),
          IconButton(
            tooltip: 'ยืนยันรับคืน',
            onPressed: () => _runRequestAction(
              id,
              'confirm-return',
              'ยืนยันรับทรัพย์สินคืนแล้ว',
            ),
            icon: Icon(
              Icons.assignment_return_outlined,
              color: gatePassUiTokens.primaryColor,
            ),
          ),
        ],
      );
    }
    if (_isRequests) {
      final draft = row['status'] == 'DRAFT';
      final approved = row['status'] == 'APPROVED';
      final isOwner = row['isOwner'] == true;
      if (id == null) return const SizedBox.shrink();
      return Wrap(
        spacing: 2,
        children: [
          if (_canPrint)
            card
                ? OutlinedButton.icon(
                    onPressed: () => _printRequest(row),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('พิมพ์'),
                  )
                : IconButton(
                    tooltip: 'พิมพ์',
                    onPressed: () => _printRequest(row),
                    icon: Icon(
                      Icons.print_outlined,
                      color: gatePassUiTokens.primaryColor,
                    ),
                  ),
          if (draft && _canEdit && isOwner)
            card
                ? OutlinedButton.icon(
                    style: _filterOutlinedStyle(gatePassUiTokens),
                    onPressed: () => _createRequest(row),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('แก้ไข'),
                  )
                : IconButton(
                    tooltip: 'แก้ไข',
                    onPressed: () => _createRequest(row),
                    icon: Icon(
                      Icons.edit_outlined,
                      color: gatePassUiTokens.primaryColor,
                    ),
                  ),
          if (draft && _canDelete && isOwner)
            card
                ? OutlinedButton.icon(
                    style: _filterOutlinedStyle(gatePassUiTokens).copyWith(
                      foregroundColor: WidgetStatePropertyAll(
                        Theme.of(context).colorScheme.error,
                      ),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                    onPressed: () => _deleteRequest(id),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('ลบ'),
                  )
                : IconButton(
                    tooltip: 'ลบ',
                    onPressed: () => _deleteRequest(id),
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
          if (draft && _canSubmit && isOwner)
            card
                ? OutlinedButton.icon(
                    onPressed: () => _submitRequest(id),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('ส่งอนุมัติ'),
                  )
                : IconButton(
                    tooltip: 'ส่งอนุมัติ',
                    onPressed: () => _submitRequest(id),
                    icon: Icon(
                      Icons.send_outlined,
                      color: gatePassUiTokens.primaryColor,
                    ),
                  ),
          if (approved && _canEdit && isOwner)
            card
                ? OutlinedButton.icon(
                    onPressed: () => _handoverRequest(id),
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('ยืนยันส่งมอบ'),
                  )
                : IconButton(
                    tooltip: 'ยืนยันส่งมอบ',
                    onPressed: () => _handoverRequest(id),
                    icon: Icon(
                      Icons.handshake_outlined,
                      color: gatePassUiTokens.primaryColor,
                    ),
                  ),
        ],
      );
    }
    if (!_isPurposes && id != null) {
      return IconButton(
        tooltip: 'ดูรายละเอียด',
        onPressed: () => _viewRequest(id),
        icon: const Icon(Icons.visibility_outlined),
      );
    }
    if (!_isPurposes || (!_canEdit && !_canDelete)) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 2,
      children: [
        if (_canEdit)
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => _editPurpose(row),
            icon: Icon(
              Icons.edit_outlined,
              color: gatePassUiTokens.primaryColor,
            ),
          ),
        if (_canDelete)
          IconButton(
            tooltip: 'ลบ',
            onPressed: () => _deletePurpose(row),
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }

  Future<void> _editPurpose([Map<String, dynamic>? row]) async {
    int? defaultDays;
    if (row == null) {
      try {
        final settings = _map(
          await _api.get('/api/company/gate-pass/purposes/default-return-days'),
        );
        defaultDays = (settings['defaultReturnDays'] as num?)?.toInt();
        if (defaultDays == null)
          throw StateError('Missing default return days');
      } catch (_) {
        if (mounted) {
          showGatePassMessage(
            context,
            message: 'โหลดจำนวนวันรับคืนเริ่มต้นไม่สำเร็จ',
            error: true,
          );
        }
        return;
      }
      if (!mounted) return;
    }
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final days = TextEditingController(
      text: (row?['returnDays'] ?? defaultDays ?? '').toString(),
    );
    var isActive = row?['isActive'] != false;
    var alwaysReturnRequired = row?['alwaysReturnRequired'] == true;
    var saving = false;
    final editing = row != null;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(gatePassUiTokens.radius),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: gatePassUiTokens.cardPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(
                            editing ? Icons.edit_outlined : Icons.add,
                            color: gatePassUiTokens.primaryColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_title > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
                              style: gatePassUiTokens.captionStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: gatePassUiTokens.borderColor),
                  Wrap(
                    spacing: 20,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('สถานะ', style: gatePassUiTokens.inputStyle),
                          const SizedBox(width: 8),
                          Switch(
                            value: isActive,
                            onChanged: saving
                                ? null
                                : (value) =>
                                      setDialogState(() => isActive = value),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ต้องนำกลับเสมอ',
                            style: gatePassUiTokens.inputStyle,
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: alwaysReturnRequired,
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(
                                    () => alwaysReturnRequired = value,
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: name,
                    style: gatePassUiTokens.inputStyle,
                    decoration: InputDecoration(
                      labelText: 'ชื่อ *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          gatePassUiTokens.radius,
                        ),
                        borderSide: BorderSide(
                          color: gatePassUiTokens.borderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          gatePassUiTokens.radius,
                        ),
                        borderSide: BorderSide(
                          color: gatePassUiTokens.borderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          gatePassUiTokens.radius,
                        ),
                        borderSide: BorderSide(
                          color: gatePassUiTokens.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: days,
                    keyboardType: TextInputType.number,
                    style: gatePassUiTokens.inputStyle,
                    decoration: InputDecoration(
                      labelText: alwaysReturnRequired
                          ? 'จำนวนวันรับคืน *'
                          : 'จำนวนวันรับคืน',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  Divider(color: gatePassUiTokens.borderColor),
                  SizedBox(
                    height: gatePassUiTokens.buttonHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('ยกเลิก'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (name.text.trim().isEmpty) {
                                    showGatePassMessage(
                                      this.context,
                                      message: 'กรุณาระบุชื่อ',
                                      error: true,
                                    );
                                    return;
                                  }
                                  final returnDays = int.tryParse(
                                    days.text.trim(),
                                  );
                                  if ((days.text.trim().isEmpty &&
                                          alwaysReturnRequired) ||
                                      (days.text.trim().isNotEmpty &&
                                          (returnDays == null ||
                                              returnDays < 1 ||
                                              returnDays > 365))) {
                                    showGatePassMessage(
                                      this.context,
                                      message:
                                          'กรุณาระบุจำนวนวันรับคืน 1 ถึง 365 วัน',
                                      error: true,
                                    );
                                    return;
                                  }
                                  setDialogState(() => saving = true);
                                  try {
                                    final body = {
                                      'name': name.text.trim(),
                                      'returnDays': returnDays,
                                      'clearReturnDays': days.text
                                          .trim()
                                          .isEmpty,
                                      'alwaysReturnRequired':
                                          alwaysReturnRequired,
                                      'isActive': isActive,
                                    };
                                    if (editing) {
                                      await _api.put(
                                        '/api/company/gate-pass/purposes/${row['id']}',
                                        body: body,
                                      );
                                    } else {
                                      await _api.post(
                                        '/api/company/gate-pass/purposes',
                                        body: body,
                                      );
                                    }
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      showGatePassMessage(
                                        this.context,
                                        message: 'บันทึกวัตถุประสงค์ไม่สำเร็จ',
                                        error: true,
                                      );
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setDialogState(() => saving = false);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('บันทึก'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    name.dispose();
    days.dispose();
    if (saved == true && mounted) {
      showGatePassMessage(
        context,
        message: editing ? 'แก้ไขวัตถุประสงค์แล้ว' : 'เพิ่มวัตถุประสงค์แล้ว',
      );
      _retry();
    }
  }

  Future<void> _deletePurpose(Map<String, dynamic> row) async {
    final theme = Theme.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(gatePassUiTokens.radius),
          side: BorderSide(color: theme.colorScheme.error),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text(
              'ลบวัตถุประสงค์',
              style: gatePassUiTokens.captionStyle.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: gatePassUiTokens.cardPadding,
              color: theme.colorScheme.errorContainer,
              child: Text(
                '${row['name'] ?? '-'}',
                style: gatePassUiTokens.inputStyle,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ลบแล้วไม่สามารถเรียกคืนได้',
              style: gatePassUiTokens.inputStyle,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              minimumSize: Size(0, gatePassUiTokens.buttonHeight),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await _api.delete('/api/company/gate-pass/purposes/${row['id']}');
      if (!mounted) return;
      showGatePassMessage(context, message: 'ลบวัตถุประสงค์แล้ว');
      _retry();
    } catch (_) {
      if (mounted) {
        showGatePassMessage(
          context,
          message: 'ลบไม่ได้ เนื่องจากรายการอาจถูกใช้อ้างอิงแล้ว',
          error: true,
        );
      }
    }
  }

  Widget _settingsCard(BuildContext context, Map<String, dynamic> value) =>
      _GatePassSettingsForm(
        key: ValueKey<String>(
          <Object?>[
            value['isEnabled'],
            value['defaultReturnDays'],
            value['defaultApproverUserID'],
            value['maxAttachmentSizeMB'],
            value['maxAttachmentsPerStage'],
          ].join('|'),
        ),
        value: value,
        canEdit: _canEdit,
        api: _api,
        onSaved: _retry,
      );

  Widget _dashboardCard(BuildContext context, Map<String, dynamic> value) {
    final tokens = gatePassUiTokens;
    final metrics = <(String, Object?, IconData)>[
      ('ใบขอทั้งหมด', value['total'] ?? 0, Icons.description_outlined),
      ('ส่งมอบแล้ว', value['handedOver'] ?? 0, Icons.handshake_outlined),
      ('ผ่านจุดตรวจ', value['exitChecked'] ?? 0, Icons.verified_outlined),
      ('รับคืนแล้ว', value['returned'] ?? 0, Icons.assignment_return_outlined),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: tokens.cardPadding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - (columns - 1) * tokens.sectionSpacing) /
                columns;
            return SingleChildScrollView(
              child: Wrap(
                spacing: tokens.sectionSpacing,
                runSpacing: tokens.sectionSpacing,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: width,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(tokens.radius),
                          ),
                          child: Padding(
                            padding: tokens.cardPadding,
                            child: Row(
                              children: [
                                Icon(metric.$3, color: tokens.primaryColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(metric.$1, style: tokens.inputStyle),
                                      const SizedBox(height: 4),
                                      Text(
                                        metric.$2.toString(),
                                        style: tokens.captionStyle,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _loadingCard() => const Card(
    margin: EdgeInsets.zero,
    child: Center(child: CircularProgressIndicator()),
  );

  Widget _errorCard(BuildContext context) {
    final tokens = gatePassUiTokens;
    return Card(
      margin: EdgeInsets.zero,
      child: Center(
        child: Padding(
          padding: tokens.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('โหลดข้อมูลไม่สำเร็จ', style: tokens.sectionStyle),
              SizedBox(height: tokens.itemSpacing),
              Text(
                'รายละเอียดเพิ่มเติม: กรุณาตรวจสอบสิทธิ์หรือการเชื่อมต่อ แล้วลองอีกครั้ง',
                textAlign: TextAlign.center,
                style: tokens.inputStyle,
              ),
              SizedBox(height: tokens.itemSpacing),
              OutlinedButton.icon(
                onPressed: _retry,
                style: _filterOutlinedStyle(tokens),
                icon: const Icon(Icons.replay_outlined),
                label: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paginationCard(BuildContext context, {required int total}) {
    const pageSize = 10;
    final pages = total == 0 ? 1 : (total / pageSize).ceil();
    return LaooPaginationCard(
      tokens: _sharedTokens(context),
      page: _page,
      pageCount: pages,
      pageSize: pageSize,
      total: total,
      onPrevious: _page > 1 ? () => setState(() => _page--) : null,
      onNext: _page < pages ? () => setState(() => _page++) : null,
      borderless: true,
    );
  }

  LaooWorkspaceUiTokens _sharedTokens(BuildContext context) {
    final tokens = gatePassUiTokens;
    return LaooWorkspaceUiTokens(
      contentMargin: tokens.contentMargin,
      cardPadding: tokens.cardPadding,
      sectionSpacing: tokens.sectionSpacing,
      captionFilterSpacing: tokens.sectionSpacing,
      itemSpacing: tokens.itemSpacing,
      radius: tokens.radius,
      compactBreakpoint: tokens.compactBreakpoint,
      paginationHeight: tokens.paginationCardHeight,
      captionStyle: tokens.captionStyle,
      sectionStyle: tokens.sectionStyle,
      inputStyle: tokens.inputStyle,
      tableStyle: tokens.tableStyle,
      buttonStyle: tokens.buttonStyle,
      buttonHeight: tokens.buttonHeight,
      primaryColor: tokens.primaryColor,
      borderColor: tokens.borderColor,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }

  bool _matchesQuery(Map<String, dynamic> row) {
    if (_hasDocumentFilters) {
      if (_departmentId != null &&
          int.tryParse(row['departmentId']?.toString() ?? '') != _departmentId)
        return false;
      if (_filterPurposeId != null &&
          int.tryParse(row['purposeId']?.toString() ?? '') != _filterPurposeId)
        return false;
      if (_isReturns &&
          _filterCarrier != null &&
          '${row['carrier'] ?? ''}'.trim() != _filterCarrier)
        return false;
      bool inRange(Object? raw, DateTimeRange? range) {
        if (range == null) return true;
        final parsed = DateTime.tryParse(raw?.toString() ?? '');
        if (parsed == null) return false;
        final day = DateTime(parsed.year, parsed.month, parsed.day);
        return !day.isBefore(
              DateTime(range.start.year, range.start.month, range.start.day),
            ) &&
            !day.isAfter(
              DateTime(range.end.year, range.end.month, range.end.day),
            );
      }

      if (!inRange(row['documentDateTime'], _documentDateRange) ||
          !inRange(row['plannedExitDate'], _exitDateRange))
        return false;
    }
    return _appliedQuery.isEmpty ||
        _searchableText(row).contains(_appliedQuery);
  }

  String _searchableText(Map<String, dynamic> row) =>
      '${_primaryText(row)} ${_detailText(row)} ${_statusText(row)} ${row['remark'] ?? ''} ${row['requesterName'] ?? ''} ${row['departmentName'] ?? ''} ${row['carrierPhone'] ?? ''}'
          .toLowerCase();

  String _primaryText(Map<String, dynamic> row) =>
      (_isPurposes
              ? row['name']
              : (row['number'] ?? row['code'] ?? row['name']))
          ?.toString() ??
      '-';

  String _detailText(Map<String, dynamic> row) {
    final values = <String>[
      if (row['name'] != null && row['number'] != null) row['name'].toString(),
      if (row['carrier'] != null) 'ผู้รับมอบ: ${row['carrier']}',
      if (row['destination'] != null) 'ปลายทาง: ${row['destination']}',
      if (row['purpose'] != null) 'วัตถุประสงค์: ${row['purpose']}',
    ];
    return values.isEmpty ? '-' : values.join(' • ');
  }

  String _statusText(Map<String, dynamic> row) {
    if (_isPurposes) return row['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน';
    if (row['exitCheckedAt'] != null) return 'ผ่านการตรวจที่จุดออกแล้ว';
    if (row['status'] == 'DRAFT') return 'แบบร่าง';
    return (row['status'] ?? row['isActive'] ?? '-').toString();
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> value) {
    final source = value['items'];
    if (source is! List) return const [];
    return source.map((row) => _map(row)).toList();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  ButtonStyle _filterFilledStyle(GatePassUiTokens tokens) =>
      FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        maximumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
        textStyle: tokens.buttonStyle,
      );

  ButtonStyle _filterOutlinedStyle(GatePassUiTokens tokens) =>
      OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        maximumSize: const Size(double.infinity, 40),
        foregroundColor: tokens.primaryColor,
        side: BorderSide(color: tokens.primaryColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
        textStyle: tokens.buttonStyle,
      );
}

class _GatePassSettingsForm extends StatefulWidget {
  const _GatePassSettingsForm({
    required this.value,
    required this.canEdit,
    required this.api,
    required this.onSaved,
    super.key,
  });

  final Map<String, dynamic> value;
  final bool canEdit;
  final JsonApiClient api;
  final VoidCallback onSaved;

  @override
  State<_GatePassSettingsForm> createState() => _GatePassSettingsFormState();
}

class _GatePassSettingsFormState extends State<_GatePassSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _returnDays;
  late final TextEditingController _qrExpiryDays;
  late final TextEditingController _maxAttachmentSize;
  late final TextEditingController _maxAttachments;
  late final Future<List<Map<String, dynamic>>> _approvers;
  late bool _isEnabled;
  int? _approverId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.value['isEnabled'] == true;
    _approverId = int.tryParse(
      widget.value['defaultApproverUserID']?.toString() ?? '',
    );
    _returnDays = TextEditingController(
      text: (widget.value['defaultReturnDays'] ?? 7).toString(),
    );
    _qrExpiryDays = TextEditingController(
      text: (widget.value['defaultQrExpiryDays'] ?? 1).toString(),
    );
    _maxAttachmentSize = TextEditingController(
      text: (widget.value['maxAttachmentSizeMB'] ?? 1).toString(),
    );
    _maxAttachments = TextEditingController(
      text: (widget.value['maxAttachmentsPerStage'] ?? 5).toString(),
    );
    _approvers = _loadApprovers();
  }

  @override
  void dispose() {
    _returnDays.dispose();
    _qrExpiryDays.dispose();
    _maxAttachmentSize.dispose();
    _maxAttachments.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadApprovers() async {
    final response = await widget.api.get(
      '/api/company/gate-pass/approver-options',
    );
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final source = map['items'] ?? map['data'];
      if (source is List) {
        return source
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
    }
    return const [];
  }

  String? _validateReturnDays(String? value) {
    final days = int.tryParse(value?.trim() ?? '');
    if (days == null || days < 1 || days > 365) {
      return 'ระบุจำนวนวันตั้งแต่ 1-365 วัน';
    }
    return null;
  }

  String? _validateAttachmentSize(String? value) {
    final size = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (size == null || size <= 0 || size > 1) {
      return 'ระบุขนาดมากกว่า 0 และไม่เกิน 1 MB';
    }
    return null;
  }

  String? _validateAttachmentCount(String? value) {
    final count = int.tryParse(value?.trim() ?? '');
    if (count == null || count < 1 || count > 20) {
      return 'ระบุจำนวนตั้งแต่ 1-20 รูป';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !widget.canEdit) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.api.put(
        '/api/company/gate-pass/settings',
        body: {
          'isEnabled': _isEnabled,
          'defaultReturnDays': int.parse(_returnDays.text.trim()),
          'defaultQrExpiryDays': int.parse(_qrExpiryDays.text.trim()),
          'defaultApproverUserID': _approverId,
          'maxAttachmentSizeMB': double.parse(
            _maxAttachmentSize.text.trim().replaceAll(',', '.'),
          ),
          'maxAttachmentsPerStage': int.parse(_maxAttachments.text.trim()),
        },
      );
      if (!mounted) return;
      setState(() => _saving = false);
      showGatePassMessage(context, message: 'บันทึกการตั้งค่าแล้ว');
      widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showGatePassMessage(
        context,
        message: 'บันทึกการตั้งค่าไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = gatePassUiTokens;
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: tokens.cardPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ค่าการทำงานปัจจุบัน', style: tokens.sectionStyle),
              Divider(color: tokens.borderColor),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('สถานะ', style: tokens.inputStyle),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isEnabled,
                    onChanged: widget.canEdit && !_saving
                        ? (value) => setState(() => _isEnabled = value)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _isEnabled ? 'เปิดใช้งานระบบ' : 'ปิดใช้งานระบบ',
                      style: tokens.inputStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 16.0;
                  final compact = constraints.maxWidth < 720;
                  final fieldWidth = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _approvers,
                          builder: (context, snapshot) {
                            final options = snapshot.data ?? const [];
                            final selected =
                                options.any(
                                  (option) =>
                                      int.tryParse(option['id'].toString()) ==
                                      _approverId,
                                )
                                ? _approverId
                                : null;
                            return DropdownButtonFormField<int?>(
                              initialValue: selected,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'ผู้อนุมัติเริ่มต้น',
                                helperText: snapshot.hasError
                                    ? 'โหลดรายชื่อไม่สำเร็จ'
                                    : null,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('ไม่กำหนด'),
                                ),
                                ...options.map(
                                  (option) => DropdownMenuItem<int?>(
                                    value: int.tryParse(
                                      option['id'].toString(),
                                    ),
                                    child: Text(
                                      '${option['code'] ?? ''} - ${option['name'] ?? ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged:
                                  widget.canEdit && !_saving && snapshot.hasData
                                  ? (value) => _approverId = value
                                  : null,
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _returnDays,
                          enabled: widget.canEdit && !_saving,
                          keyboardType: TextInputType.number,
                          style: tokens.inputStyle,
                          decoration: const InputDecoration(
                            labelText: 'กำหนดรับคืนเริ่มต้น (วัน)',
                          ),
                          validator: _validateReturnDays,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _maxAttachmentSize,
                          enabled: widget.canEdit && !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: tokens.inputStyle,
                          decoration: const InputDecoration(
                            labelText: 'ขนาดรูปสูงสุดหลังย่อ (MB)',
                          ),
                          validator: _validateAttachmentSize,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _qrExpiryDays,
                          enabled: widget.canEdit && !_saving,
                          keyboardType: TextInputType.number,
                          style: tokens.inputStyle,
                          decoration: const InputDecoration(
                            labelText: 'อายุ QR เริ่มต้น (วัน)',
                            helperText: 'กำหนดวันหมดอายุเริ่มต้นหลังสร้าง QR',
                          ),
                          validator: _validateReturnDays,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _maxAttachments,
                          enabled: widget.canEdit && !_saving,
                          keyboardType: TextInputType.number,
                          style: tokens.inputStyle,
                          decoration: const InputDecoration(
                            labelText: 'จำนวนรูปสูงสุดต่อขั้นตอน',
                          ),
                          validator: _validateAttachmentCount,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (widget.canEdit) ...[
                const SizedBox(height: 16),
                Divider(color: tokens.borderColor),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: Size(120, tokens.buttonHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radius),
                      ),
                      textStyle: tokens.buttonStyle,
                    ),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'กำลังบันทึก' : 'บันทึก'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
