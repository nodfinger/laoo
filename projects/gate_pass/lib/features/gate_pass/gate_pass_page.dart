import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'gate_pass_feature_host.dart';

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
  late Future<dynamic> _future;
  late String _title;
  String _appliedQuery = '';
  int _page = 1;
  Map<String, dynamic> _actions = const {};

  bool get _isSettings => widget.endpoint == 'settings';
  bool get _isPurposes => widget.endpoint == 'purposes';
  bool get _isRequests => widget.endpoint == 'requests';
  bool get _isDashboard => widget.endpoint == 'dashboard';
  bool get _canCreate => _actions['create'] == true;
  bool get _canEdit => _actions['edit'] == true;
  bool get _canDelete => _actions['delete'] == true;
  bool get _canSubmit => _actions['submit'] == true;
  bool get _canApprove => _actions['approve'] == true;
  bool get _canConfirmExit => _actions['confirmExit'] == true;
  bool get _canConfirmReturn => _actions['confirmReturn'] == true;

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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: tokens.cardPadding,
        child: Row(
          children: [
            Icon(Icons.star_border, color: tokens.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(_title, style: tokens.captionStyle)),
            if ((_isPurposes || _isRequests) && _canCreate)
              FilledButton.icon(
                onPressed: _isPurposes ? () => _editPurpose() : _createRequest,
                style: FilledButton.styleFrom(
                  minimumSize: Size(100, tokens.buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radius),
                  ),
                  textStyle: tokens.buttonStyle,
                ),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่ม'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterCard(BuildContext context) {
    final tokens = gatePassUiTokens;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
      borderSide: BorderSide(color: tokens.borderColor),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: tokens.cardPadding,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 40).clamp(0.0, 280.0),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _search(),
                style: tokens.inputStyle,
                decoration: InputDecoration(
                  hintText: 'ค้นหารหัส ชื่อ หรือสถานะ',
                  prefixIcon: const Icon(Icons.search),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder.copyWith(
                    borderSide: BorderSide(color: tokens.primaryColor),
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _search,
                  style: _filterFilledStyle(tokens),
                  icon: const Icon(Icons.search),
                  label: const Text('ค้นหา'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearFilter,
                  style: _filterOutlinedStyle(tokens),
                  icon: const Icon(Icons.clear),
                  label: const Text('ล้าง Filter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(BuildContext context, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Center(
          child: Text('ไม่พบข้อมูล', style: gatePassUiTokens.inputStyle),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < gatePassUiTokens.compactBreakpoint) {
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) =>
                SizedBox(height: gatePassUiTokens.itemSpacing),
            itemBuilder: (context, index) =>
                _rowCard(context, rows[index], index),
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  gatePassUiTokens.primaryColor.withValues(alpha: 0.10),
                ),
                dividerThickness: 1,
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('จัดการ')),
                  DataColumn(label: Text('รหัส / เอกสาร')),
                  DataColumn(label: Text('รายละเอียด')),
                  DataColumn(label: Text('สถานะ')),
                ],
                rows: List<DataRow>.generate(
                  rows.length,
                  (index) => DataRow(
                    cells: [
                      DataCell(Text((index + 1).toString())),
                      DataCell(_rowActions(rows[index])),
                      DataCell(Text(_primaryText(rows[index]))),
                      DataCell(Text(_detailText(rows[index]))),
                      DataCell(Text(_statusText(rows[index]))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rowCard(BuildContext context, Map<String, dynamic> row, int index) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: gatePassUiTokens.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID ${index + 1}', style: gatePassUiTokens.inputStyle),
              const SizedBox(height: 4),
              Text(_primaryText(row), style: gatePassUiTokens.sectionStyle),
              const SizedBox(height: 4),
              Text(_detailText(row), style: gatePassUiTokens.inputStyle),
              const SizedBox(height: 4),
              Text(_statusText(row), style: gatePassUiTokens.inputStyle),
              if (_rowActions(row) is! SizedBox) ...[
                SizedBox(height: gatePassUiTokens.itemSpacing),
                _rowActions(row),
              ],
            ],
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
          constraints: const BoxConstraints(maxWidth: 520),
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
          constraints: const BoxConstraints(maxWidth: 520),
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
        _api.get('/api/company/gate-pass/requests/$id'),
        _api.get('/api/company/gate-pass/requests/$id/attachments'),
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
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
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
    final editing = row != null;
    Map<String, dynamic> detail = const {};
    List<Map<String, dynamic>> purposeOptions = const [];
    try {
      purposeOptions = _rows(
        _map(await _api.get('/api/company/gate-pass/purpose-options')),
      );
      if (editing) {
        detail = _map(
          await _api.get('/api/company/gate-pass/requests/${row['id']}'),
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
    final itemName = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final unit = TextEditingController();
    final remark = TextEditingController(
      text: detail['remark']?.toString() ?? '',
    );
    final photos = <PlatformFile>[];
    final items = _rows(detail);
    var purposeId = int.tryParse(detail['purposeID']?.toString() ?? '');
    var returnRequired = detail['isReturnRequired'] == true;
    var photoUploadFailed = 0;
    var saving = false;
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
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: gatePassUiTokens.cardPadding,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          editing
                              ? 'แก้ไขใบขอนำทรัพย์สินออก'
                              : 'เพิ่มใบขอนำทรัพย์สินออก',
                          style: gatePassUiTokens.captionStyle,
                        ),
                      ),
                    ),
                    Divider(color: gatePassUiTokens.borderColor),
                    Text('ข้อมูลเอกสาร', style: gatePassUiTokens.sectionStyle),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: purposeId,
                      decoration: const InputDecoration(
                        labelText: 'วัตถุประสงค์ *',
                      ),
                      items: purposeOptions
                          .map(
                            (option) => DropdownMenuItem<int>(
                              value: int.tryParse(option['id'].toString()),
                              child: Text(
                                '${option['code'] ?? ''} - ${option['name'] ?? ''}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => purposeId = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: carrier,
                      style: gatePassUiTokens.inputStyle,
                      decoration: const InputDecoration(
                        labelText: 'ผู้รับมอบ *',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: destination,
                      style: gatePassUiTokens.inputStyle,
                      decoration: const InputDecoration(labelText: 'ปลายทาง *'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'ต้องรับทรัพย์สินคืน',
                        style: gatePassUiTokens.inputStyle,
                      ),
                      value: returnRequired,
                      onChanged: saving
                          ? null
                          : (value) =>
                                setDialogState(() => returnRequired = value),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'รายการทรัพย์สิน',
                      style: gatePassUiTokens.sectionStyle,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: itemName,
                      style: gatePassUiTokens.inputStyle,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อทรัพย์สิน *',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      style: gatePassUiTokens.inputStyle,
                      decoration: const InputDecoration(labelText: 'จำนวน *'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: unit,
                      style: gatePassUiTokens.inputStyle,
                      decoration: const InputDecoration(labelText: 'หน่วย'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () {
                              final qty = num.tryParse(quantity.text);
                              if (itemName.text.trim().isEmpty ||
                                  qty == null ||
                                  qty <= 0) {
                                showGatePassMessage(
                                  this.context,
                                  message: 'กรุณาระบุชื่อและจำนวนทรัพย์สิน',
                                  error: true,
                                );
                                return;
                              }
                              setDialogState(() {
                                items.add({
                                  'name': itemName.text.trim(),
                                  'quantity': qty,
                                  'unit': unit.text.trim().isEmpty
                                      ? null
                                      : unit.text.trim(),
                                  'serialNo': null,
                                });
                                itemName.clear();
                                quantity.text = '1';
                                unit.clear();
                              });
                            },
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('เพิ่มรายการ'),
                    ),
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...List<Widget>.generate(
                        items.length,
                        (index) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            items[index]['name'].toString(),
                            style: gatePassUiTokens.inputStyle,
                          ),
                          subtitle: Text(
                            '${items[index]['quantity']} ${items[index]['unit'] ?? ''}',
                            style: gatePassUiTokens.inputStyle,
                          ),
                          trailing: IconButton(
                            tooltip: 'ลบรายการ',
                            onPressed: saving
                                ? null
                                : () => setDialogState(
                                    () => items.removeAt(index),
                                  ),
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: remark,
                      maxLines: 2,
                      style: gatePassUiTokens.inputStyle,
                      decoration: const InputDecoration(labelText: 'หมายเหตุ'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final picked = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.image,
                                    allowMultiple: true,
                                    withData: true,
                                  );
                              if (picked != null) {
                                setDialogState(() {
                                  photos
                                    ..clear()
                                    ..addAll(
                                      picked.files.where(
                                        (file) => file.bytes != null,
                                      ),
                                    );
                                });
                              }
                            },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        photos.isEmpty
                            ? 'แนบรูป'
                            : 'แนบรูปแล้ว ${photos.length} รูป',
                      ),
                    ),
                    Divider(color: gatePassUiTokens.borderColor),
                    SizedBox(
                      height: gatePassUiTokens.buttonHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
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
                                    final qty = num.tryParse(quantity.text);
                                    final pendingItems =
                                        List<Map<String, dynamic>>.from(items);
                                    if (itemName.text.trim().isNotEmpty &&
                                        qty != null &&
                                        qty > 0) {
                                      pendingItems.add({
                                        'name': itemName.text.trim(),
                                        'quantity': qty,
                                        'unit': unit.text.trim().isEmpty
                                            ? null
                                            : unit.text.trim(),
                                        'serialNo': null,
                                      });
                                    }
                                    if (purposeId == null ||
                                        carrier.text.trim().isEmpty ||
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
                                        'destination': destination.text.trim(),
                                        'isReturnRequired': returnRequired,
                                        'remark': remark.text.trim().isEmpty
                                            ? null
                                            : remark.text.trim(),
                                        'items': pendingItems,
                                      };
                                      Object? requestId = row?['id'];
                                      if (editing) {
                                        await _api.put(
                                          '/api/company/gate-pass/requests/$requestId',
                                          body: body,
                                        );
                                      } else {
                                        final created = _map(
                                          await _api.post(
                                            '/api/company/gate-pass/requests',
                                            body: body,
                                          ),
                                        );
                                        requestId = created['id'];
                                      }
                                      if (requestId != null) {
                                        for (final photo in photos) {
                                          try {
                                            await uploadGatePassFile(
                                              '/api/company/gate-pass/requests/$requestId/attachments/REQUEST',
                                              fileName: photo.name,
                                              bytes: photo.bytes!,
                                            );
                                          } catch (_) {
                                            photoUploadFailed++;
                                          }
                                        }
                                      }
                                      if (context.mounted) {
                                        Navigator.pop(context, true);
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (final controller in [
      carrier,
      destination,
      itemName,
      quantity,
      unit,
      remark,
    ]) {
      controller.dispose();
    }
    if (saved == true && mounted) {
      showGatePassMessage(
        context,
        message: photoUploadFailed > 0
            ? '${editing ? 'บันทึก' : 'สร้าง'}ใบขอแล้ว แต่มี $photoUploadFailed รูปที่แนบไม่สำเร็จ'
            : editing
            ? 'แก้ไขใบขอฉบับร่างแล้ว'
            : 'สร้างใบขอฉบับร่างแล้ว',
        error: photoUploadFailed > 0,
      );
      _retry();
    }
  }

  Widget _rowActions(Map<String, dynamic> row) {
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
      if ((!draft && !approved) || id == null) return const SizedBox.shrink();
      return Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'ดูรายละเอียด',
            onPressed: () => _viewRequest(id),
            icon: const Icon(Icons.visibility_outlined),
          ),
          if (draft && _canEdit)
            IconButton(
              tooltip: 'แก้ไข',
              onPressed: () => _createRequest(row),
              icon: Icon(
                Icons.edit_outlined,
                color: gatePassUiTokens.primaryColor,
              ),
            ),
          if (_canEdit)
            IconButton(
              tooltip: draft ? 'แนบรูปใบขอ' : 'แนบรูปส่งมอบ',
              onPressed: () =>
                  _uploadStagePhoto(id, draft ? 'REQUEST' : 'HANDOVER'),
              icon: Icon(
                Icons.add_photo_alternate_outlined,
                color: gatePassUiTokens.primaryColor,
              ),
            ),
          if (draft && _canSubmit)
            IconButton(
              tooltip: 'ส่งอนุมัติ',
              onPressed: () => _submitRequest(id),
              icon: Icon(
                Icons.send_outlined,
                color: gatePassUiTokens.primaryColor,
              ),
            ),
          if (draft && _canDelete)
            IconButton(
              tooltip: 'ลบ',
              onPressed: () => _deleteRequest(id),
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          if (approved && _canEdit)
            IconButton(
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
    final code = TextEditingController(text: row?['code']?.toString() ?? '');
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    var isActive = row?['isActive'] != false;
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
            constraints: const BoxConstraints(maxWidth: 520),
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
                        editing ? 'แก้ไขวัตถุประสงค์' : 'เพิ่มวัตถุประสงค์',
                        style: gatePassUiTokens.captionStyle,
                      ),
                    ),
                  ),
                  Divider(color: gatePassUiTokens.borderColor),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('สถานะ', style: gatePassUiTokens.inputStyle),
                    value: isActive,
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(() => isActive = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: code,
                    style: gatePassUiTokens.inputStyle,
                    decoration: const InputDecoration(labelText: 'รหัส *'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    style: gatePassUiTokens.inputStyle,
                    decoration: const InputDecoration(labelText: 'ชื่อ *'),
                  ),
                  Divider(color: gatePassUiTokens.borderColor),
                  SizedBox(
                    height: gatePassUiTokens.buttonHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
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
                                  if (code.text.trim().isEmpty ||
                                      name.text.trim().isEmpty) {
                                    showGatePassMessage(
                                      this.context,
                                      message: 'กรุณาระบุรหัสและชื่อ',
                                      error: true,
                                    );
                                    return;
                                  }
                                  setDialogState(() => saving = true);
                                  try {
                                    final body = {
                                      'code': code.text.trim(),
                                      'name': name.text.trim(),
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
    code.dispose();
    name.dispose();
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
                '${row['code'] ?? '-'} - ${row['name'] ?? '-'}',
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

  Future<void> _editSettings(Map<String, dynamic> value) async {
    List<Map<String, dynamic>> approvers;
    try {
      approvers = _rows(
        _map(await _api.get('/api/company/gate-pass/approver-options')),
      );
    } catch (_) {
      if (mounted) {
        showGatePassMessage(
          context,
          message: 'โหลดรายชื่อผู้อนุมัติไม่สำเร็จ',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;
    final days = TextEditingController(
      text: (value['defaultReturnDays'] ?? 7).toString(),
    );
    final maxMb = TextEditingController(
      text: (value['maxAttachmentSizeMB'] ?? 1).toString(),
    );
    final maxCount = TextEditingController(
      text: (value['maxAttachmentsPerStage'] ?? 5).toString(),
    );
    var isEnabled = value['isEnabled'] == true;
    var approverId = int.tryParse(
      value['defaultApproverUserID']?.toString() ?? '',
    );
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
            constraints: const BoxConstraints(maxWidth: 520),
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
                        'แก้ไขการตั้งค่า',
                        style: gatePassUiTokens.captionStyle,
                      ),
                    ),
                  ),
                  Divider(color: gatePassUiTokens.borderColor),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('สถานะ', style: gatePassUiTokens.inputStyle),
                    value: isEnabled,
                    onChanged: (value) =>
                        setDialogState(() => isEnabled = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    initialValue: approverId,
                    decoration: const InputDecoration(
                      labelText: 'ผู้อนุมัติเริ่มต้น',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ไม่กำหนด'),
                      ),
                      ...approvers.map(
                        (option) => DropdownMenuItem<int?>(
                          value: int.tryParse(option['id'].toString()),
                          child: Text(
                            '${option['code'] ?? ''} - ${option['name'] ?? ''}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => approverId = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: days,
                    keyboardType: TextInputType.number,
                    style: gatePassUiTokens.inputStyle,
                    decoration: const InputDecoration(
                      labelText: 'กำหนดรับคืนเริ่มต้น (วัน)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: maxMb,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: gatePassUiTokens.inputStyle,
                    decoration: const InputDecoration(
                      labelText: 'ขนาดรูปสูงสุดหลังย่อ (MB)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: maxCount,
                    keyboardType: TextInputType.number,
                    style: gatePassUiTokens.inputStyle,
                    decoration: const InputDecoration(
                      labelText: 'จำนวนรูปสูงสุดต่อขั้นตอน',
                    ),
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
                            final returnDays = int.tryParse(days.text);
                            final attachmentMb = double.tryParse(maxMb.text);
                            final attachmentCount = int.tryParse(maxCount.text);
                            if (returnDays == null ||
                                returnDays < 1 ||
                                returnDays > 365 ||
                                attachmentMb == null ||
                                attachmentMb <= 0 ||
                                attachmentMb > 1 ||
                                attachmentCount == null ||
                                attachmentCount < 1 ||
                                attachmentCount > 20) {
                              showGatePassMessage(
                                this.context,
                                message:
                                    'กำหนดวันรับคืน 1-365 วัน ขนาดรูปหลังย่อต้องไม่เกิน 1 MB และจำนวนรูป 1-20 รูป',
                                error: true,
                              );
                              return;
                            }
                            try {
                              await _api.put(
                                '/api/company/gate-pass/settings',
                                body: {
                                  'isEnabled': isEnabled,
                                  'defaultReturnDays': returnDays,
                                  'defaultApproverUserID': approverId,
                                  'maxAttachmentSizeMB': attachmentMb,
                                  'maxAttachmentsPerStage': attachmentCount,
                                },
                              );
                              if (context.mounted) {
                                Navigator.pop(context, true);
                              }
                            } catch (_) {
                              if (mounted) {
                                showGatePassMessage(
                                  this.context,
                                  message: 'บันทึกการตั้งค่าไม่สำเร็จ',
                                  error: true,
                                );
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
    days.dispose();
    maxMb.dispose();
    maxCount.dispose();
    if (saved == true && mounted) {
      showGatePassMessage(context, message: 'บันทึกการตั้งค่าแล้ว');
      _retry();
    }
  }

  Widget _settingsCard(BuildContext context, Map<String, dynamic> value) {
    final tokens = gatePassUiTokens;
    final enabled = value['isEnabled'] == true ? 'ใช้งาน' : 'ปิดใช้งาน';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: tokens.cardPadding,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ค่าการทำงานปัจจุบัน',
                      style: tokens.sectionStyle,
                    ),
                  ),
                  if (_canEdit)
                    IconButton(
                      tooltip: 'แก้ไขการตั้งค่า',
                      onPressed: () => _editSettings(value),
                      icon: Icon(
                        Icons.edit_outlined,
                        color: tokens.primaryColor,
                      ),
                    ),
                ],
              ),
              Divider(color: tokens.borderColor),
              _settingRow('เปิดใช้งานระบบ', enabled),
              SizedBox(height: tokens.itemSpacing),
              _settingRow(
                'กำหนดรับคืนเริ่มต้น',
                '${value['defaultReturnDays'] ?? '-'} วัน',
              ),
              SizedBox(height: tokens.itemSpacing),
              _settingRow(
                'ขนาดรูปสูงสุดหลังย่อ',
                '${value['maxAttachmentSizeMB'] ?? 1} MB',
              ),
              SizedBox(height: tokens.itemSpacing),
              _settingRow(
                'จำนวนรูปสูงสุดต่อขั้นตอน',
                '${value['maxAttachmentsPerStage'] ?? 5} รูป',
              ),
              SizedBox(height: tokens.itemSpacing),
              _settingRow(
                'ผู้อนุมัติเริ่มต้น',
                (value['defaultApproverName'] ?? 'ไม่กำหนด').toString(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingRow(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: gatePassUiTokens.inputStyle),
      const SizedBox(height: 4),
      Text(value, style: gatePassUiTokens.sectionStyle),
    ],
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
    final tokens = gatePassUiTokens;
    final pages = total == 0 ? 1 : (total / pageSize).ceil();
    final start = total == 0 ? 0 : (_page - 1) * pageSize + 1;
    final end = total == 0 ? 0 : (_page * pageSize).clamp(0, total);
    final theme = Theme.of(context);

    Widget arrow(IconData icon, int target, bool enabled) => SizedBox.square(
      dimension: 34,
      child: OutlinedButton(
        onPressed: enabled ? () => setState(() => _page = target) : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        ),
        child: Icon(icon, size: 20),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        height: tokens.paginationCardHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              arrow(Icons.chevron_left, _page - 1, _page > 1),
              const SizedBox(width: 6),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.primaryColor,
                  borderRadius: BorderRadius.circular(tokens.radius),
                ),
                child: Text(
                  _page.toString(),
                  style: tokens.buttonStyle.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              arrow(Icons.chevron_right, _page + 1, _page < pages),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '$start-$end จาก $total',
                  overflow: TextOverflow.ellipsis,
                  style: tokens.inputStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesQuery(Map<String, dynamic> row) {
    if (_appliedQuery.isEmpty) return true;
    return _searchableText(row).contains(_appliedQuery);
  }

  String _searchableText(Map<String, dynamic> row) =>
      '${_primaryText(row)} ${_detailText(row)} ${_statusText(row)}'
          .toLowerCase();

  String _primaryText(Map<String, dynamic> row) =>
      (row['number'] ?? row['code'] ?? row['name'] ?? '-').toString();

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
    if (row['exitCheckedAt'] != null) return 'ผ่านการตรวจที่จุดออกแล้ว';
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
