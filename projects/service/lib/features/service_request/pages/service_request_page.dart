import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'service_attachment_picker.dart';
import 'package:image/image.dart' as img;
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_client.dart';
import '../../../core/company_setup/company_setup_service.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_request_api.dart';
import '../../service_request_qr/data/service_request_qr_api.dart';
import '../../service_request_subject/pages/service_request_subject_page.dart';

Future<Map<String, dynamic>?> _searchPicker(
  BuildContext context, {
  required String label,
  required Future<List<Map<String, dynamic>>> Function(String) load,
  required String Function(Map<String, dynamic>) describe,
}) async {
  var future = load('');
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 480,
          height: 420,
          child: Column(
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'ค้นหา',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final next = load(value);
                  setDialogState(() {
                    future = next;
                  });
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('ไม่สามารถโหลดข้อมูลได้ กรุณาลองใหม่'),
                      );
                    }
                    final rows = snapshot.data ?? const [];
                    if (rows.isEmpty) {
                      return const Center(child: Text('ไม่พบข้อมูล'));
                    }
                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) => ListTile(
                        title: Text(describe(rows[index])),
                        onTap: () => Navigator.pop(dialogContext, rows[index]),
                      ),
                    );
                  },
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
      ),
    ),
  );
}

Future<String?> _pickEquipmentSerial(
  BuildContext context,
  ApiClient api,
  int itemId,
) async {
  final selected = await _searchPicker(
    context,
    label: 'ค้นหา Serial',
    load: (query) async =>
        (await api.get(
                  '/api/company/item-instances',
                  query: {'search': query, 'itemID': '$itemId'},
                )
                as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(),
    describe: (row) => '${row['serialNo']} | ${row['itemName']}',
  );
  return selected?['serialNo']?.toString();
}

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({
    super.key,
    this.selfService = false,
    this.qrToken,
    this.readOnly = false,
    this.menuCode,
    this.routeName,
    this.fixedStatus,
    this.api,
    this.subjectApi,
  });
  final bool selfService;
  final String? qrToken;
  final bool readOnly;
  final String? menuCode;
  final String? routeName;
  final String? fixedStatus;
  final ServiceRequestApi? api;
  final ApiClient? subjectApi;
  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  late final ServiceRequestApi _api = widget.api ?? ServiceRequestApi();
  final _search = TextEditingController();
  String _status = '';
  String _priorityFilter = '';
  List<Map<String, dynamic>> _priorities = const [
    {'code': '0', 'name': 'ปกติ'},
    {'code': '1', 'name': 'ด่วน'},
    {'code': '2', 'name': 'ด่วนมาก'},
  ];
  int _page = 1;
  bool _loading = true;
  bool _cardView = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  String _menuName = 'รายการแจ้งซ่อมทั้งหมด';
  Map<String, dynamic> _data = const {'items': <dynamic>[], 'total': 0};
  String get _menuCode =>
      widget.menuCode ?? (widget.selfService ? '20001' : '15001');

  @override
  void initState() {
    super.initState();
    _status = widget.fixedStatus ?? '';
    if (widget.selfService) _menuName = 'แจ้งซ่อม / ขอใช้บริการ';
    _load();
    _loadActions();
    _loadPriorities();
    _loadMenuName();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final value = _priorityFilter.isEmpty
          ? await _api.list(
              search: _search.text.trim(),
              status: _status,
              selfService: widget.selfService,
              page: _page,
              menuCode: _menuCode,
            )
          : await _api.filteredList(
              search: _search.text.trim(),
              status: _status,
              selfService: widget.selfService,
              page: _page,
              menuCode: _menuCode,
              priority: _priorityFilter,
            );
      if (mounted) setState(() => _data = value);
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPriorities() async {
    try {
      final values = await _api.priorities();
      if (mounted && values.isNotEmpty) setState(() => _priorities = values);
    } catch (_) {
      /* Keep the standard values if the lookup is unavailable. */
    }
  }

  Future<void> _loadActions() async {
    try {
      final actions = await _api.actions();
      if (mounted) {
        setState(() {
          _canCreate = !widget.readOnly && widget.selfService
              ? actions['selfCreate'] == true
              : !widget.readOnly && actions['create'] == true;
          final screenType = widget.selfService
              ? actions['selfScreenType']
              : actions['screenType'];
          _canEdit =
              !widget.readOnly &&
              screenType == 1 &&
              actions[widget.selfService ? 'selfEdit' : 'edit'] == true;
          _canDelete =
              !widget.readOnly &&
              screenType == 1 &&
              actions[widget.selfService ? 'selfDelete' : 'delete'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMenuName() async {
    try {
      final name = await NavigationMenuRepository().resolveMenuName(
        menuCode: _menuCode,
        routeName:
            widget.routeName ??
            (widget.selfService ? 'portalRequest' : 'cmTickets'),
        fallback: _menuName,
      );
      if (mounted) setState(() => _menuName = name);
    } catch (_) {}
  }

  void _message(Object error, {bool errorState = true}) {
    final text = error is ApiException
        ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง'}'
        : 'ไม่สามารถดำเนินการได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: text, error: errorState);
  }

  Future<void> _create(BuildContext context) async {
    if (!_canCreate) return;
    final lookup = await _api.lookup(selfService: widget.selfService);
    if (!mounted || !context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RequestDialog(
        api: _api,
        lookup: lookup,
        selfService: widget.selfService,
        qrToken: widget.qrToken,
        caption: _menuName,
        subjectApi: widget.subjectApi,
      ),
    );
    if (saved == true && mounted) {
      _page = 1;
      await _load();
      if (!mounted || !context.mounted) return;
      showTimedSnackBar(context, message: 'บันทึกใบแจ้งซ่อมเรียบร้อยแล้ว');
    }
  }

  Future<void> _edit(Map<String, dynamic> row, BuildContext context) async {
    if (!_canEdit ||
        (widget.selfService && row['selfCanEdit'] != true) ||
        row['statusCode'] != 'NEW') {
      return;
    }
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = await _api.detail(id, menuCode: _menuCode);
      if (!mounted || !context.mounted) return;
      if (detail['statusCode'] != 'NEW') {
        await _load();
        return;
      }
      final attachments = await _api.attachments(id, menuCode: _menuCode);
      final priorities = await _api.priorities();
      final subjects = await _api.subjectOptions(
        selfService: widget.selfService,
      );
      final equipment = await _api.equipmentOptions(
        selfService: widget.selfService,
      );
      if (!mounted || !context.mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RequestEditDialog(
          api: _api,
          requestId: id,
          data: detail,
          caption: _menuName,
          selfService: widget.selfService,
          menuCode: _menuCode,
          attachments: attachments,
          priorities: priorities,
          subjects: subjects,
          equipment: equipment,
          subjectApi: widget.subjectApi,
        ),
      );
      if (saved == true && mounted) {
        await _load();
        if (context.mounted) {
          showTimedSnackBar(context, message: 'บันทึกการแก้ไขแล้ว');
        }
      }
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  Future<void> _openImages(
    Map<String, dynamic> row,
    BuildContext context,
  ) async {
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final files = await _api.attachments(id, menuCode: _menuCode);
      if (!mounted || !context.mounted) return;
      final images = files
          .where(
            (file) => (file['contentType']?.toString() ?? '')
                .toLowerCase()
                .startsWith('image/'),
          )
          .toList();
      await showDialog<void>(
        context: context,
        builder: (context) => _AttachmentImageDialog(
          child: images.isEmpty
              ? const Text('ไม่พบรูปภาพแนบ')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final image in images)
                      _RemoteAttachmentTile(
                        api: _api,
                        requestId: id,
                        item: image,
                        menuCode: _menuCode,
                        canDelete: false,
                        onDelete: () {},
                      ),
                  ],
                ),
        ),
      );
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  Widget _imageAction(Map<String, dynamic> row, BuildContext context) =>
      row['hasImages'] == true
      ? IconButton(
          tooltip: 'ดูรูปแนบ',
          onPressed: () => _openImages(row, context),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(
            Icons.image_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        )
      : const SizedBox.shrink();

  Future<void> _delete(Map<String, dynamic> row, BuildContext context) async {
    if (!_canDelete || row['statusCode'] != 'NEW') return;
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = await _api.detail(id, menuCode: _menuCode);
      if (!mounted || !context.mounted) return;
      if (detail['statusCode'] != 'NEW') {
        await _load();
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final colors = Theme.of(dialogContext).colorScheme;
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
              side: BorderSide(color: colors.error),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(LaooLayout.cardPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.delete_outline, color: colors.error),
                        const SizedBox(width: 8),
                        Text(
                          'ลบใบแจ้งซ่อม',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: colors.outlineVariant),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: colors.errorContainer,
                      child: Text(
                        '${detail['requestNo']} — ${detail['subject']}',
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('ลบแล้วไม่สามารถเรียกคืนได้'),
                    const SizedBox(height: 12),
                    Divider(color: colors.outlineVariant),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          icon: const Icon(Icons.close),
                          label: const Text('ยกเลิก'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.error,
                            foregroundColor: colors.onError,
                          ),
                          onPressed: () => Navigator.pop(dialogContext, true),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('ลบ'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (confirmed != true || !mounted) return;
      await _api.delete(
        id,
        detail['rowVersion'].toString(),
        selfService: widget.selfService,
      );
      if (_page > 1 && ((_data['items'] as List?)?.length ?? 0) == 1) _page--;
      await _load();
      if (context.mounted) {
        showTimedSnackBar(context, message: 'ลบใบแจ้งซ่อมแล้ว');
      }
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  Widget _rowActions(Map<String, dynamic> row, BuildContext context) {
    final canEdit =
        _canEdit && (!widget.selfService || row['selfCanEdit'] == true);
    final canDelete =
        _canDelete && (!widget.selfService || row['selfCanDelete'] == true);
    if (row['statusCode'] != 'NEW' || (!canEdit && !canDelete)) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit)
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => _edit(row, context),
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              Icons.edit_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (canDelete)
          IconButton(
            tooltip: 'ลบ',
            onPressed: () => _delete(row, context),
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }

  Future<void> _openDetail(
    Map<String, dynamic> row,
    BuildContext context,
  ) async {
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = await _api.detail(id, menuCode: _menuCode);
      if (!mounted || !context.mounted) return;
      final attachments = await _api.attachments(id, menuCode: _menuCode);
      if (!mounted || !context.mounted) return;
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => _RequestDetailDialog(
          api: _api,
          data: detail,
          attachments: attachments,
          canEdit: !widget.selfService && _canEdit,
          menuCode: _menuCode,
        ),
      );
      if (changed == true) await _load();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(
      (_data['items'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final total = (_data['total'] as num?)?.toInt() ?? 0;
    return SupportWorkspaceShell(
      pageTitle: _menuName,
      activeMenu:
          widget.routeName ??
          (widget.selfService ? 'portalRequest' : 'cmTickets'),
      menuScope: WorkspaceMenuScope.company,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _surface(
                  Row(
                    children: [
                      Expanded(
                        child: WorkspacePageTitle(
                          title: _menuName,
                          favoriteKey: _menuCode,
                        ),
                      ),
                      IconButton(
                        tooltip: _cardView ? 'แสดงแบบตาราง' : 'แสดงแบบการ์ด',
                        onPressed: () => setState(() => _cardView = !_cardView),
                        icon: Icon(
                          _cardView ? Icons.view_list : Icons.grid_view,
                          color: colors.primary,
                        ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: colors.primary.withValues(alpha: .1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                      ),
                      if (_canCreate) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _create(context),
                          icon: const Icon(Icons.add),
                          label: Text(
                            widget.selfService ? 'แจ้งซ่อม' : 'เพิ่มใบแจ้งซ่อม',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _surface(
                  FilterHeightSync(
                    builder: (context, searchKey, height) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          child: TextField(
                            key: searchKey,
                            controller: _search,
                            onSubmitted: (_) {
                              _page = 1;
                              _load();
                            },
                            decoration: _input(
                              hint:
                                  'ค้นหาเลขที่ ผู้แจ้ง หัวข้อ หรือสถานที่ / อุปกรณ์แจ้งซ่อม / Serial',
                              icon: Icons.search,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          style: filterActionHeightStyle(height),
                          onPressed: () {
                            _page = 1;
                            _load();
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('ค้นหา'),
                        ),
                        OutlinedButton.icon(
                          style: filterActionHeightStyle(height),
                          onPressed: () {
                            _search.clear();
                            _status = widget.fixedStatus ?? '';
                            _priorityFilter = '';
                            _page = 1;
                            _load();
                          },
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('ล้าง Filter'),
                        ),
                        if (widget.fixedStatus == null)
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _status,
                              decoration: _input(label: 'สถานะ'),
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('ทั้งหมด'),
                                ),
                                DropdownMenuItem(
                                  value: 'NEW',
                                  child: Text('สร้างใหม่'),
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
                                DropdownMenuItem(
                                  value: 'CANCELLED',
                                  child: Text('ยกเลิก'),
                                ),
                              ],
                              onChanged: (value) {
                                _status = value ?? '';
                                _page = 1;
                                _load();
                              },
                            ),
                          )
                        else
                          Chip(label: Text(_statusText(widget.fixedStatus!))),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('priority-filter-$_priorityFilter'),
                            initialValue: _priorityFilter,
                            isExpanded: true,
                            decoration: _input(label: 'ระดับงาน'),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('ทั้งหมด'),
                              ),
                              for (final item in _priorities)
                                DropdownMenuItem(
                                  value: item['code'].toString(),
                                  child: Text(item['name'].toString()),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() => _priorityFilter = value ?? '');
                              _page = 1;
                              _load();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _surface(
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
                        ? const Center(
                            child: Text('ไม่พบใบแจ้งซ่อมตามเงื่อนไขที่เลือก'),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (_cardView || constraints.maxWidth < 850) {
                                return _requestCards(items);
                              }
                              return Padding(
                                padding: const EdgeInsets.all(
                                  LaooLayout.cardPadding,
                                ),
                                child: _requestTable(items, context),
                              );
                            },
                          ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                _surface(
                  _pagination(total, context),
                  padding: const EdgeInsets.symmetric(
                    horizontal: LaooLayout.cardPadding,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _surface(
    Widget child, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(LaooLayout.cardPadding),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );

  Widget _requestCards(List<Map<String, dynamic>> items) => ListView.separated(
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final row = items[index];
      return Container(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _openDetail(row, context),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(row['requestNo']?.toString() ?? '-'),
                  ),
                ),
                _statusBadge(row, context),
                _imageAction(row, context),
                _rowActions(row, context),
              ],
            ),
            Text(row['subject']?.toString() ?? '-'),
            Text('อุปกรณ์แจ้งซ่อม: ${row['equipmentName'] ?? '-'}'),
            Text('Serial: ${row['equipmentSerial'] ?? '-'}'),
            Row(
              children: [
                const Text('ระดับงาน: '),
                _priorityBadge(row, context),
              ],
            ),
            Text(row['requesterName']?.toString() ?? '-'),
            Text(row['locationSnapshot']?.toString() ?? '-'),
            Text(row['requestDate']?.toString() ?? '-'),
          ],
        ),
      );
    },
  );

  Widget _priorityBadge(Map<String, dynamic> row, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = (row['priorityCode']?.toString() ?? '0') == '0'
        ? colors.primary
        : colors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        row['priorityName']?.toString() ?? 'ปกติ',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _statusBadge(Map<String, dynamic> row, BuildContext context) {
    final code = row['statusCode']?.toString() ?? '';
    final colors = Theme.of(context).colorScheme;
    final abnormal = code == 'CANCELLED';
    final color = abnormal ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusText(code),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _requestTable(List<Map<String, dynamic>> items, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget cell(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: child,
    );
    Widget value(Object? text) => Text(
      text?.toString() ?? '-',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(42),
          1: FixedColumnWidth(116),
          2: FixedColumnWidth(60),
          3: FlexColumnWidth(1.1),
          4: FlexColumnWidth(1.2),
          5: FlexColumnWidth(1.2),
          6: FlexColumnWidth(1.8),
          7: FlexColumnWidth(1.1),
          8: FlexColumnWidth(1.0),
          9: FlexColumnWidth(1.0),
          10: FlexColumnWidth(1.0),
          11: FlexColumnWidth(1.0),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .12),
            ),
            children: [
              for (final label in [
                'ID',
                'Action',
                'รูป',
                'เลขที่',
                'ผู้แจ้ง',
                'สถานที่',
                'อุปกรณ์แจ้งซ่อม',
                'Serial',
                'หัวข้อ',
                'ระดับงาน',
                'สถานะ',
                'วันที่',
              ])
                cell(
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          for (final (index, row) in items.indexed)
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.outlineVariant, width: .6),
                ),
              ),
              children: [
                cell(Text('${((_page - 1) * 20) + index + 1}')),
                cell(_rowActions(row, context)),
                cell(_imageAction(row, context)),
                cell(
                  InkWell(
                    onTap: () => _openDetail(row, context),
                    child: Text(
                      row['requestNo']?.toString() ?? '-',
                      style: TextStyle(color: colors.primary),
                    ),
                  ),
                ),
                cell(value(row['requesterName'])),
                cell(value(row['locationSnapshot'])),
                cell(value(row['equipmentName'])),
                cell(value(row['equipmentSerial'])),
                cell(value(row['subject'])),
                cell(_priorityBadge(row, context)),
                cell(_statusBadge(row, context)),
                cell(value(row['requestDate'])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _pagination(int total, BuildContext context) {
    final pages = total == 0 ? 1 : (total / 20).ceil();
    final end = (_page * 20).clamp(0, total);
    final range = total == 0
        ? '0-0 จาก 0'
        : '${((_page - 1) * 20) + 1}-$end จาก $total';
    final colors = Theme.of(context).colorScheme;
    Widget button(
      Widget child,
      VoidCallback? onPressed, {
      bool active = false,
    }) => SizedBox(
      width: LaooLayout.paginationButtonSize,
      height: LaooLayout.paginationButtonSize,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: colors.primary,
          disabledBackgroundColor: active
              ? colors.primary
              : colors.surfaceContainerHighest,
          disabledForegroundColor: active
              ? colors.onPrimary
              : colors.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
        ),
        child: child,
      ),
    );
    return SizedBox(
      height: LaooLayout.paginationCardHeight,
      child: Row(
        children: [
          button(
            const Icon(Icons.chevron_left),
            _page > 1
                ? () {
                    _page--;
                    _load();
                  }
                : null,
          ),
          const SizedBox(width: 6),
          button(Text('$_page'), null, active: true),
          const SizedBox(width: 6),
          button(
            const Icon(Icons.chevron_right),
            _page < pages
                ? () {
                    _page++;
                    _load();
                  }
                : null,
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(range, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  InputDecoration _input({String? label, String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      );

  String _statusText(String code) =>
      const {
        'NEW': 'สร้างใหม่',
        'RECEIVED': 'รับเรื่องแล้ว',
        'IN_PROGRESS': 'กำลังดำเนินการ',
        'COMPLETED': 'เสร็จสิ้น',
        'CANCELLED': 'ยกเลิก',
      }[code] ??
      code;
}

class _RequestEditDialog extends StatefulWidget {
  const _RequestEditDialog({
    required this.api,
    required this.requestId,
    required this.data,
    required this.caption,
    required this.selfService,
    required this.menuCode,
    required this.attachments,
    required this.priorities,
    required this.subjects,
    required this.equipment,
    this.subjectApi,
  });
  final ServiceRequestApi api;
  final int requestId;
  final Map<String, dynamic> data;
  final String caption;
  final bool selfService;
  final String menuCode;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> priorities;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> equipment;
  final ApiClient? subjectApi;

  @override
  State<_RequestEditDialog> createState() => _RequestEditDialogState();
}

class _RequestEditDialogState extends State<_RequestEditDialog> {
  final _form = GlobalKey<FormState>();
  final _attachmentPreviewKey = GlobalKey();
  late final List<Map<String, dynamic>> _files = List.of(widget.attachments);
  bool _attachmentsChanged = false;
  late String _priority = widget.data['priorityCode']?.toString() ?? '0';
  late final List<Map<String, dynamic>> _equipmentOptions = List.of(
    widget.equipment,
  );
  late int? _equipmentId = (widget.data['equipmentItemId'] as num?)?.toInt();
  bool _equipmentChanged = false;
  bool _serialChanged = false;
  late final TextEditingController _serial = TextEditingController(
    text: widget.data['equipmentSerial']?.toString() ?? '',
  );
  int _equipmentVersion = 0;
  late final TextEditingController _subject = TextEditingController(
    text: widget.data['subject']?.toString() ?? '',
  );
  late final TextEditingController _detail = TextEditingController(
    text: widget.data['detail']?.toString() ?? '',
  );
  bool _saving = false;
  late List<Map<String, dynamic>> _subjects = List.of(widget.subjects);
  late final ApiClient _subjectApi = widget.subjectApi ?? ApiClient();
  String? _subjectCode;
  bool _canManageSubjects = false;
  int _subjectVersion = 0;
  static const _legacySubject = '__legacy__';

  @override
  void initState() {
    super.initState();
    final match = _subjects
        .where((item) => item['name']?.toString() == _subject.text)
        .firstOrNull;
    _subjectCode = match?['code']?.toString() ?? _legacySubject;
    _loadSubjectPermission();
  }

  Future<void> _loadSubjectPermission() async {
    try {
      final actions = await _subjectApi.get(
        '/api/service/request-subjects/actions',
      );
      if (mounted && actions is Map) {
        setState(() => _canManageSubjects = actions['view'] == true);
      }
    } catch (_) {
      /* Lookup action is unavailable without the corresponding permission. */
    }
  }

  void _selectSubject(String? code) {
    final selected = _subjects
        .where((item) => item['code']?.toString() == code)
        .firstOrNull;
    setState(() {
      _subjectCode = code;
      if (code != _legacySubject) {
        _subject.text = selected?['shortCode']?.toString() == 'OTHER'
            ? ''
            : selected?['name']?.toString() ?? '';
      }
    });
  }

  Future<void> _manageSubjects() async {
    final selectedCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        child: SizedBox(
          width: 1200,
          height: MediaQuery.sizeOf(dialogContext).height * .85,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'ปิด',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: ServiceRequestSubjectPage(
                  embedded: true,
                  api: _subjectApi,
                  onSelected: (code) => Navigator.pop(dialogContext, code),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    try {
      final subjects = await widget.api.subjectOptions(
        selfService: widget.selfService,
      );
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _subjectVersion++;
      });
      if (selectedCode != null &&
          subjects.any((item) => item['code']?.toString() == selectedCode)) {
        _selectSubject(selectedCode);
      } else if (_subjectCode != _legacySubject &&
          !subjects.any((item) => item['code']?.toString() == _subjectCode)) {
        setState(() => _subjectCode = _legacySubject);
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ไม่สามารถโหลดหัวข้อได้',
          error: true,
        );
      }
    }
  }

  Future<void> _searchEquipment() async {
    final selected = await _searchPicker(
      context,
      label: 'อุปกรณ์ที่แจ้งซ่อม',
      load: (query) => widget.api.equipmentOptions(
        selfService: widget.selfService,
        search: query,
      ),
      describe: (item) => '${item['itemCode']} | ${item['itemName']}',
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (!_equipmentOptions.any(
        (item) => item['itemID'] == selected['itemID'],
      )) {
        _equipmentOptions.add(selected);
      }
      if (_equipmentId != (selected['itemID'] as num).toInt()) {
        _serial.clear();
      }
      _equipmentId = (selected['itemID'] as num).toInt();
      _equipmentChanged = true;
      _equipmentVersion++;
    });
  }

  Future<void> _searchSubject() async {
    final selected = await _searchPicker(
      context,
      label: 'หัวข้อ',
      load: (query) async => _subjects
          .where(
            (item) => (item['name']?.toString() ?? '').toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList(),
      describe: (item) => item['name']?.toString() ?? '-',
    );
    if (mounted && selected != null) {
      _selectSubject(selected['code']?.toString());
      setState(() => _subjectVersion++);
    }
  }

  Future<void> _pickImages() async {
    final selection = await pickServiceAttachmentImages();
    if (!mounted || selection == null) return;
    setState(() => _saving = true);
    try {
      for (final file in selection.files) {
        if (file.bytes == null) {
          throw StateError('ไม่สามารถอ่านไฟล์ ${file.name}');
        }
        final added = await widget.api.uploadAttachment(
          widget.requestId,
          fileName: file.name,
          bytes: file.bytes!,
          editSelf: widget.selfService,
          editNew: true,
        );
        _attachmentsChanged = true;
        if (mounted) setState(() => _files.add(added));
      }
      if (mounted && selection.files.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final preview = _attachmentPreviewKey.currentContext;
          if (mounted && preview != null) {
            Scrollable.ensureVisible(
              preview,
              duration: const Duration(milliseconds: 200),
              alignment: 1,
            );
          }
        });
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? error.message
              : 'เพิ่มรูปไม่สำเร็จ กรุณาตรวจสอบไฟล์แล้วลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeImage(Map<String, dynamic> file) async {
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          side: BorderSide(color: errorColor),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: errorColor),
            const SizedBox(width: 8),
            const Expanded(child: Text('ยืนยันการลบข้อมูล')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: errorColor.withValues(alpha: .1),
              child: Text('${file['fileName'] ?? 'รูปภาพ'}'),
            ),
            const SizedBox(height: 12),
            const Text('รูปที่ลบแล้วไม่สามารถกู้คืนได้'),
            const Divider(),
          ],
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
      ),
    );
    if (confirmed != true || !mounted || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.api.deleteAttachment(
        widget.requestId,
        (file['attachmentId'] as num).toInt(),
        editSelf: widget.selfService,
        editNew: true,
      );
      _attachmentsChanged = true;
      if (mounted) setState(() => _files.remove(file));
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? error.message
              : 'ลบรูปไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _serial.dispose();
    _subject.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_equipmentChanged || _serialChanged) {
        await widget.api.editEquipment(
          widget.requestId,
          selfService: widget.selfService,
          subject: _subject.text.trim(),
          detail: _detail.text.trim(),
          rowVersion: widget.data['rowVersion'].toString(),
          priorityCode: _priority,
          equipmentItemId: _equipmentId,
          equipmentSerial: _serial.text.trim(),
          updateSerial: _serialChanged,
        );
      } else {
        await widget.api.edit(
          widget.requestId,
          selfService: widget.selfService,
          subject: _subject.text.trim(),
          detail: _detail.text.trim(),
          rowVersion: widget.data['rowVersion'].toString(),
          priorityCode: _priority,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : 'บันทึกไม่สำเร็จ';
        showTimedSnackBar(context, message: message, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TextStyle _floatingLabelStyle(ColorScheme colors) =>
      WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          fontSize: LaooTypography.materialFloatingLabelSource,
          color: states.contains(WidgetState.error)
              ? colors.error
              : colors.primary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      title: Row(
        children: [
          Icon(Icons.edit_outlined, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${widget.caption} > แก้ไข',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 12),
                Text('เลขที่ ${widget.data['requestNo']}'),
                const SizedBox(height: LaooLayout.popupFieldSpacing),
                Text('ผู้แจ้ง ${widget.data['requesterName']}'),
                const SizedBox(height: LaooLayout.popupFieldSpacing),
                DropdownButtonFormField<int>(
                  key: ValueKey('edit-equipment-$_equipmentVersion'),
                  initialValue: _equipmentId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'อุปกรณ์ที่แจ้งซ่อม',
                    labelStyle: const TextStyle(
                      fontSize: LaooTypography.inputLabel,
                    ),
                    floatingLabelStyle: _floatingLabelStyle(colors),
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.data['requireEquipment'] == false &&
                            _equipmentId != null)
                          IconButton(
                            tooltip: 'ล้างอุปกรณ์ที่เลือก',
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                    _equipmentId = null;
                                    _serial.clear();
                                    _equipmentChanged = true;
                                    _equipmentVersion++;
                                  }),
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'ค้นหา อุปกรณ์ที่แจ้งซ่อม',
                          onPressed: _saving ? null : _searchEquipment,
                          icon: const Icon(Icons.search),
                        ),
                      ],
                    ),
                  ),
                  items: [
                    for (final item in _equipmentOptions)
                      DropdownMenuItem(
                        value: (item['itemID'] as num).toInt(),
                        child: Text(
                          '${item['itemCode']} | ${item['itemName']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _equipmentId = value;
                          _serial.clear();
                          _equipmentChanged = true;
                        }),
                ),
                const SizedBox(height: LaooLayout.popupFieldSpacing),
                TextFormField(
                  controller: _serial,
                  readOnly: true,
                  style: const TextStyle(fontSize: LaooTypography.inputText),
                  decoration: InputDecoration(
                    labelText: 'Serial อุปกรณ์ (ไม่บังคับ)',
                    labelStyle: const TextStyle(
                      fontSize: LaooTypography.inputLabel,
                    ),
                    floatingLabelStyle: _floatingLabelStyle(colors),
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_serial.text.isNotEmpty)
                          IconButton(
                            tooltip: 'ล้าง Serial',
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                    _serial.clear();
                                    _serialChanged = true;
                                  }),
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'ค้นหา Serial',
                          onPressed: _saving || _equipmentId == null
                              ? null
                              : () async {
                                  final value = await _pickEquipmentSerial(
                                    context,
                                    _subjectApi,
                                    _equipmentId!,
                                  );
                                  if (mounted && value != null)
                                    setState(() {
                                      _serial.text = value;
                                      _serialChanged = true;
                                    });
                                },
                          icon: const Icon(Icons.search),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: LaooLayout.popupFieldSpacing),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: InputDecoration(
                    floatingLabelStyle: _floatingLabelStyle(colors),
                    labelStyle: const TextStyle(
                      fontSize: LaooTypography.inputLabel,
                    ),
                    labelText: 'ระดับงาน',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      (widget.priorities.isEmpty
                              ? [
                                  {'code': '0', 'name': 'ปกติ'},
                                ]
                              : widget.priorities)
                          .map(
                            (item) => DropdownMenuItem(
                              value: item['code'].toString(),
                              child: Text(item['name'].toString()),
                            ),
                          )
                          .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _priority = value ?? '0'),
                ),
                const SizedBox(height: LaooLayout.popupFieldSpacing),
                DropdownButtonFormField<String>(
                  key: ValueKey('edit-subject-$_subjectVersion'),
                  initialValue: _subjectCode,
                  isExpanded: true,
                  decoration: InputDecoration(
                    floatingLabelStyle: _floatingLabelStyle(colors),
                    labelStyle: const TextStyle(
                      fontSize: LaooTypography.inputLabel,
                    ),
                    labelText: 'หัวข้อ *',
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'ค้นหา หัวข้อ',
                          onPressed: _saving ? null : _searchSubject,
                          icon: const Icon(Icons.search),
                        ),
                        if (_canManageSubjects)
                          IconButton(
                            tooltip: 'ค้นหาหัวข้อ',
                            onPressed: _saving ? null : _manageSubjects,
                            icon: const Icon(Icons.edit_note_outlined),
                          ),
                      ],
                    ),
                  ),
                  items: [
                    if (_subjectCode == _legacySubject)
                      DropdownMenuItem(
                        value: _legacySubject,
                        child: Text(
                          _subject.text,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    for (final item in _subjects)
                      DropdownMenuItem(
                        value: item['code'].toString(),
                        child: Text(
                          item['name'].toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving ? null : _selectSubject,
                  validator: (value) =>
                      value == null ? 'กรุณาเลือกหัวข้อ' : null,
                ),
                if (_subjects.any(
                  (item) =>
                      item['code']?.toString() == _subjectCode &&
                      item['shortCode']?.toString() == 'OTHER',
                )) ...[
                  const SizedBox(height: LaooLayout.popupFieldSpacing),
                  TextFormField(
                    controller: _subject,
                    maxLength: 200,
                    decoration: InputDecoration(
                      floatingLabelStyle: _floatingLabelStyle(colors),
                      labelStyle: const TextStyle(
                        fontSize: LaooTypography.inputLabel,
                      ),
                      labelText: 'ระบุหัวข้อ *',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'กรุณาระบุหัวข้อ'
                        : null,
                  ),
                ],
                const SizedBox(height: LaooLayout.popupFieldSpacing),
                TextFormField(
                  controller: _detail,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    floatingLabelStyle: _floatingLabelStyle(colors),
                    labelStyle: const TextStyle(
                      fontSize: LaooTypography.inputLabel,
                    ),
                    labelText: 'รายละเอียด *',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาระบุรายละเอียด'
                      : null,
                ),
                const SizedBox(height: LaooLayout.popupFieldSpacing),
                const Text(
                  'รูปภาพแนบ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickImages,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('เลือกไฟล์'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'รองรับ JPG, PNG, WEBP | ไม่จำกัดจำนวน | ระบบลดขนาดอัตโนมัติ',
                ),
                const Text('การเพิ่มหรือลบรูปจะบันทึกทันที'),
                if (_files.any(
                  (file) => (file['contentType']?.toString() ?? '')
                      .toLowerCase()
                      .startsWith('image/'),
                )) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    key: _attachmentPreviewKey,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final file in _files)
                        if ((file['contentType']?.toString() ?? '')
                            .toLowerCase()
                            .startsWith('image/'))
                          _RemoteAttachmentTile(
                            api: widget.api,
                            requestId: widget.requestId,
                            item: file,
                            menuCode: widget.menuCode,
                            canDelete: !_saving,
                            onDelete: () => _removeImage(file),
                          ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(color: colors.outlineVariant),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context, _attachmentsChanged),
                  icon: const Icon(Icons.close),
                  label: const Text('ยกเลิก'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('บันทึก'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({
    required this.api,
    required this.caption,
    this.lookup,
    this.selfService = false,
    this.qrToken,
    this.subjectApi,
  });
  final ServiceRequestApi api;
  final String caption;
  final Map<String, dynamic>? lookup;
  final bool selfService;
  final String? qrToken;
  final ApiClient? subjectApi;
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _form = GlobalKey<FormState>();
  final _attachmentPreviewKey = GlobalKey();
  final _subject = TextEditingController();
  final _detail = TextEditingController();
  final _serial = TextEditingController();
  Map<String, dynamic>? _requester;
  Map<String, dynamic>? _equipment;
  late final List<Map<String, dynamic>> _requesterOptions = _maps(
    widget.lookup?['requesters'],
  );
  late final List<Map<String, dynamic>> _equipmentOptions = _maps(
    widget.lookup?['equipment'],
  );
  int _lookupVersion = 0;
  Map<String, dynamic>? _qrContext;
  String? _subjectCode;
  String _priority = '0';
  int _subjectOptionsVersion = 0;
  late List<Map<String, dynamic>> _subjects = _maps(widget.lookup?['subjects']);
  late final _subjectApi = widget.subjectApi ?? ApiClient();
  bool _canManageSubjects = false;
  final List<PlatformFile> _attachments = [];
  bool _saving = false;
  String _employeeNameDisplay = 'FULL';

  @override
  void initState() {
    super.initState();
    _loadQrContext();
    _loadSubjectPermission();
    _loadEmployeeNameSetting();
  }

  Future<void> _loadEmployeeNameSetting() async {
    try {
      final settings = await CompanySetupService().loadRuntime();
      if (mounted) {
        setState(() => _employeeNameDisplay = settings.employeeNameDisplay);
      }
    } catch (_) {
      // Keep the existing full-name display when settings are unavailable.
    }
  }

  Future<void> _searchRequester() async {
    final selected = await _searchPicker(
      context,
      label: 'ผู้แจ้ง',
      load: (query) async => _maps(
        (await widget.api.lookup(
          search: query,
          selfService: false,
        ))['requesters'],
      ),
      describe: _requesterLabel,
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (!_requesterOptions.any(
        (item) =>
            item['id'] == selected['id'] &&
            item['requesterType'] == selected['requesterType'],
      )) {
        _requesterOptions.add(selected);
      }
      _requester = selected;
      _lookupVersion++;
    });
  }

  Future<void> _searchEquipment() async {
    final selected = await _searchPicker(
      context,
      label: 'อุปกรณ์ที่แจ้งซ่อม',
      load: (query) => widget.api.equipmentOptions(
        selfService: widget.selfService,
        search: query,
      ),
      describe: (item) => '${item['itemCode']} | ${item['itemName']}',
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (!_equipmentOptions.any(
        (item) => item['itemID'] == selected['itemID'],
      )) {
        _equipmentOptions.add(selected);
      }
      if (_equipment?['itemID'] != selected['itemID']) {
        _serial.clear();
      }
      _equipment = selected;
      _lookupVersion++;
    });
  }

  Future<void> _searchSubject() async {
    final selected = await _searchPicker(
      context,
      label: 'หัวข้อ',
      load: (query) async => _subjects
          .where(
            (item) => (item['name']?.toString() ?? '').toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList(),
      describe: (item) => item['name']?.toString() ?? '-',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _subjectCode = selected['code']?.toString();
      _subject.text = selected['shortCode']?.toString() == 'OTHER'
          ? ''
          : selected['name']?.toString() ?? '';
      _subjectOptionsVersion++;
    });
  }

  Future<void> _loadSubjectPermission() async {
    try {
      final actions = await _subjectApi.get(
        '/api/service/request-subjects/actions',
      );
      if (mounted && actions is Map) {
        setState(() => _canManageSubjects = actions['view'] == true);
      }
    } catch (_) {
      if (mounted) setState(() => _canManageSubjects = false);
    }
  }

  Future<void> _manageSubjects() async {
    final selectedCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        child: SizedBox(
          width: 1200,
          height: MediaQuery.sizeOf(dialogContext).height * .85,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'ปิด',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: ServiceRequestSubjectPage(
                  embedded: true,
                  api: _subjectApi,
                  onSelected: (code) => Navigator.pop(dialogContext, code),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    try {
      final lookup = await widget.api.lookup(selfService: widget.selfService);
      if (!mounted) return;
      final subjects = _maps(lookup['subjects']);
      final selected = subjects
          .where(
            (item) =>
                item['code']?.toString() == (selectedCode ?? _subjectCode),
          )
          .firstOrNull;
      setState(() {
        _subjects = subjects;
        _subjectOptionsVersion++;
        if (selected == null) {
          _subjectCode = null;
          _subject.clear();
        } else if (selected['shortCode']?.toString() != 'OTHER') {
          _subjectCode = selected['code'].toString();
          _subject.text = selected['name']?.toString() ?? '';
        } else if (selectedCode != null) {
          _subjectCode = selectedCode;
          _subject.clear();
        }
      });
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'ไม่สามารถโหลดหัวข้อแจ้งซ่อมได้\nรายละเอียดเพิ่มเติม: กรุณาลองใหม่อีกครั้ง',
          error: true,
        );
      }
    }
  }

  Future<void> _loadQrContext() async {
    final token = widget.qrToken?.trim();
    if (token == null || token.isEmpty) return;
    try {
      final value = await ServiceRequestQrApi().scan(token);
      if (!mounted) return;
      setState(() {
        _qrContext = value;
        _equipment = {
          'itemID': value['itemId'],
          'itemCode': value['itemCode'],
          'itemName': value['itemName'],
        };
      });
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? '${error.message}\n${error.description ?? 'กรุณาลองใหม่'}'
              : 'ไม่สามารถอ่าน QR Code ได้',
          error: true,
        );
      }
    }
  }

  @override
  void dispose() {
    if (widget.subjectApi == null) _subjectApi.dispose();
    _subject.dispose();
    _detail.dispose();
    _serial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final created = await widget.api.create(
        selfService: widget.selfService,
        requesterId: (_requester?['id'] as num?)?.toInt(),
        requesterType: _requester?['requesterType']?.toString(),
        equipmentItemId: (_equipment?['itemID'] as num?)?.toInt(),
        subject: _subject.text.trim(),
        detail: _detail.text.trim(),
        qrToken: widget.qrToken,
        priorityCode: _priority,
        equipmentSerial: _serial.text.trim(),
      );
      final requestId = (created['requestId'] as num?)?.toInt();
      final uploadErrors = <String>[];
      if (requestId != null) {
        for (final file in _attachments) {
          final bytes = file.bytes;
          if (bytes == null) {
            uploadErrors.add(file.name);
            continue;
          }
          try {
            await widget.api.uploadAttachment(
              requestId,
              fileName: file.name,
              bytes: bytes,
            );
          } catch (_) {
            uploadErrors.add(file.name);
          }
        }
      }
      if (uploadErrors.isNotEmpty && mounted) {
        showTimedSnackBar(
          context,
          message:
              'บันทึกใบแจ้งซ่อมแล้ว แต่แนบรูปไม่สำเร็จ: ${uploadErrors.join(', ')}',
          error: true,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final text = error is ApiException
            ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง'}'
            : 'บันทึกไม่สำเร็จ\nกรุณาลองใหม่อีกครั้ง';
        showTimedSnackBar(context, message: text, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAttachments() async {
    final result = await pickServiceAttachmentImages();
    if (!mounted || result == null) return;
    final accepted = <PlatformFile>[];
    final rejected = <String>[];
    for (final file in result.files) {
      try {
        accepted.add(_compressAttachment(file));
      } catch (_) {
        rejected.add(file.name);
      }
    }
    if (!mounted) return;
    setState(() => _attachments.addAll(accepted));
    if (accepted.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final preview = _attachmentPreviewKey.currentContext;
        if (mounted && preview != null) {
          Scrollable.ensureVisible(
            preview,
            duration: const Duration(milliseconds: 200),
            alignment: 1,
          );
        }
      });
    }
    if (rejected.isNotEmpty) {
      showTimedSnackBar(
        context,
        message: 'ไฟล์ไม่ผ่านการประมวลผล: ${rejected.join(', ')}',
        error: true,
      );
    }
  }

  PlatformFile _compressAttachment(PlatformFile source) {
    final bytes = source.bytes;
    if (bytes == null) throw StateError('อ่านไฟล์ไม่ได้');
    if (bytes.length <= 1048576) return source;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('อ่านรูปภาพไม่ได้');
    final widths = [2400, 2000, 1600, 1200, 900, 700, 500];
    const qualities = [88, 78, 68, 58, 48, 38, 30];
    for (var i = 0; i < widths.length; i++) {
      var working = decoded;
      if (working.width > widths[i]) {
        working = img.copyResize(working, width: widths[i]);
      }
      final compressed = Uint8List.fromList(
        img.encodeJpg(working, quality: qualities[i]),
      );
      if (compressed.length <= 1048576) {
        final name = source.name.replaceFirst(RegExp(r'\.[^.]+$'), '.jpg');
        return PlatformFile(
          name: name,
          size: compressed.length,
          bytes: compressed,
        );
      }
    }
    throw StateError('ลดขนาดแล้วยังเกิน 1 MB');
  }

  @override
  Widget build(BuildContext context) {
    final requesters = _requesterOptions;
    final equipment = _equipmentOptions;
    final subjects = _subjects;
    final byKey = {
      for (final item in requesters)
        '${item['requesterType']}:${item['id']}': item,
    };
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      title: Row(
        children: [
          Icon(
            Icons.build_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${widget.caption} > เพิ่ม',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                if (!widget.selfService)
                  DropdownButtonFormField<String>(
                    key: ValueKey('requester-$_lookupVersion'),
                    initialValue: _requester == null
                        ? null
                        : '${_requester!['requesterType']}:${_requester!['id']}',
                    isExpanded: true,
                    decoration: _input(label: 'ผู้แจ้ง *').copyWith(
                      suffixIcon: IconButton(
                        tooltip: 'ค้นหา ผู้แจ้ง',
                        onPressed: _saving ? null : _searchRequester,
                        icon: const Icon(Icons.search),
                      ),
                    ),
                    items: [
                      for (final entry in byKey.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            _requesterLabel(entry.value),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (key) => setState(
                      () => _requester = key == null ? null : byKey[key],
                    ),
                    validator: (_) =>
                        _requester == null ? 'กรุณาเลือกผู้แจ้ง' : null,
                  )
                else
                  _infoBox(
                    'ผู้แจ้ง: ผู้ใช้ปัจจุบัน\nสถานที่: ตามสิทธิ์ของผู้ใช้',
                  ),
                if (_requester != null) ...[
                  const SizedBox(height: 12),
                  _infoBox(
                    'สถานที่: ${_requester!['locationSnapshot']?.toString() ?? '-'}',
                  ),
                ],
                if (_qrContext != null) ...[
                  const SizedBox(height: 12),
                  _infoBox(
                    'สถานที่จาก QR: ${_qrContext!['locationSnapshot'] ?? '-'}',
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('equipment-$_lookupVersion'),
                  isExpanded: true,
                  initialValue: _equipment == null
                      ? null
                      : _equipment!['itemID'].toString(),
                  decoration:
                      _input(
                        label: widget.lookup?['requireEquipment'] == false
                            ? 'อุปกรณ์ที่แจ้งซ่อม'
                            : 'อุปกรณ์ที่แจ้งซ่อม *',
                      ).copyWith(
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.lookup?['requireEquipment'] == false &&
                                _qrContext == null &&
                                _equipment != null)
                              IconButton(
                                tooltip: 'ล้างอุปกรณ์ที่เลือก',
                                onPressed: _saving
                                    ? null
                                    : () => setState(() {
                                        _equipment = null;
                                        _serial.clear();
                                        _lookupVersion++;
                                      }),
                                icon: const Icon(Icons.clear),
                              ),
                            IconButton(
                              tooltip: 'ค้นหา อุปกรณ์ที่แจ้งซ่อม',
                              onPressed: _saving || _qrContext != null
                                  ? null
                                  : _searchEquipment,
                              icon: const Icon(Icons.search),
                            ),
                          ],
                        ),
                      ),
                  items: [
                    for (final item in equipment)
                      DropdownMenuItem(
                        value: item['itemID'].toString(),
                        child: Text(
                          '${item['itemCode']} | ${item['itemName']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _qrContext == null
                      ? (value) => setState(() {
                          if (_equipment?['itemID']?.toString() != value) {
                            _serial.clear();
                          }
                          _equipment = value == null
                              ? null
                              : equipment.firstWhere(
                                  (item) => item['itemID'].toString() == value,
                                );
                        })
                      : null,
                  validator: (_) =>
                      _equipment == null &&
                          widget.lookup?['requireEquipment'] != false
                      ? 'กรุณาเลือกอุปกรณ์ที่แจ้งซ่อม'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _serial,
                  readOnly: true,
                  style: const TextStyle(fontSize: LaooTypography.inputText),
                  decoration: _input(label: 'Serial อุปกรณ์ (ไม่บังคับ)')
                      .copyWith(
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_serial.text.isNotEmpty)
                              IconButton(
                                tooltip: 'ล้าง Serial',
                                onPressed: _saving
                                    ? null
                                    : () => setState(_serial.clear),
                                icon: const Icon(Icons.clear),
                              ),
                            IconButton(
                              tooltip: 'ค้นหา Serial',
                              onPressed: _saving || _equipment == null
                                  ? null
                                  : () async {
                                      final value = await _pickEquipmentSerial(
                                        context,
                                        _subjectApi,
                                        (_equipment!['itemID'] as num).toInt(),
                                      );
                                      if (mounted && value != null)
                                        setState(() => _serial.text = value);
                                    },
                              icon: const Icon(Icons.search),
                            ),
                          ],
                        ),
                      ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: _input(label: 'ระดับงาน'),
                  items:
                      (_maps(widget.lookup?['priorities']).isEmpty
                              ? [
                                  {'code': '0', 'name': 'ปกติ'},
                                ]
                              : _maps(widget.lookup?['priorities']))
                          .map(
                            (item) => DropdownMenuItem(
                              value: item['code'].toString(),
                              child: Text(item['name'].toString()),
                            ),
                          )
                          .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _priority = value ?? '0'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('subject-options-$_subjectOptionsVersion'),
                  initialValue: _subjectCode,
                  decoration: _input(label: 'หัวข้อ *').copyWith(
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'ค้นหา หัวข้อ',
                          onPressed: _saving ? null : _searchSubject,
                          icon: const Icon(Icons.search),
                        ),
                        if (_canManageSubjects)
                          IconButton(
                            tooltip: 'จัดการหัวข้อแจ้งซ่อม',
                            onPressed: _saving ? null : _manageSubjects,
                            icon: const Icon(Icons.edit_note_outlined),
                          ),
                      ],
                    ),
                  ),
                  items: [
                    for (final item in subjects)
                      DropdownMenuItem(
                        value: item['code']?.toString(),
                        child: Text(
                          item['name']?.toString() ?? '-',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (code) {
                    final item = subjects
                        .cast<Map<String, dynamic>>()
                        .firstWhere(
                          (row) => row['code']?.toString() == code,
                          orElse: () => <String, dynamic>{},
                        );
                    setState(() {
                      _subjectCode = code;
                      _subject.text = item['shortCode']?.toString() == 'OTHER'
                          ? ''
                          : item['name']?.toString() ?? '';
                    });
                  },
                  validator: (value) =>
                      value == null ? 'กรุณาเลือกหัวข้อ' : null,
                ),
                if (subjects.any(
                  (item) =>
                      item['code']?.toString() == _subjectCode &&
                      item['shortCode']?.toString() == 'OTHER',
                )) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subject,
                    style: const TextStyle(
                      fontSize: LaooTypography.popupInputText,
                    ),
                    decoration: _input(label: 'ระบุหัวข้อ *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'กรุณาระบุหัวข้อ'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _detail,
                  style: const TextStyle(
                    fontSize: LaooTypography.popupInputText,
                  ),
                  minLines: 4,
                  maxLines: 7,
                  decoration: _input(label: 'รายละเอียด *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาระบุรายละเอียด'
                      : null,
                ),
                const SizedBox(height: 14),
                _AttachmentPicker(
                  files: _attachments,
                  previewKey: _attachmentPreviewKey,
                  enabled: !_saving,
                  onPick: _pickAttachments,
                  onRemove: (file) => setState(() => _attachments.remove(file)),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('ยกเลิก'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'กำลังบันทึก' : 'บันทึก'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _maps(Object? value) =>
      ((value as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Widget _infoBox(String text) => Container(
    padding: const EdgeInsets.all(10),
    color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
    child: Text(text, softWrap: true),
  );

  String _requesterLabel(Map<String, dynamic> value) {
    final prefix = value['requesterType']?.toString() == 'SERVICE_CUSTOMER'
        ? 'ผู้ใช้บริการ Walk-in: '
        : '';
    final nickname = value['nickName']?.toString().trim() ?? '';
    final location = value['locationSnapshot']?.toString().trim() ?? '';
    final employee = value['requesterType']?.toString() == 'EMPLOYEE';
    final name = value['name']?.toString().trim() ?? '';
    final mode = _employeeNameDisplay;
    final display = !employee || nickname.isEmpty
        ? name
        : switch (mode) {
            'NICK' => nickname,
            'BOTH' => name.isEmpty ? nickname : '$name ($nickname)',
            _ => name,
          };
    return '$prefix${display.isEmpty ? '-' : display}${employee && location.isNotEmpty ? ' | $location' : ''}';
  }

  InputDecoration _input({String? label}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: LaooTypography.inputLabel),
    floatingLabelStyle: WidgetStateTextStyle.resolveWith(
      (states) => TextStyle(
        fontSize: LaooTypography.materialFloatingLabelSource,
        color: states.contains(WidgetState.error)
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
  );
}

class _AttachmentPicker extends StatelessWidget {
  const _AttachmentPicker({
    required this.files,
    required this.previewKey,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });
  final List<PlatformFile> files;
  final GlobalKey previewKey;
  final bool enabled;
  final VoidCallback onPick;
  final ValueChanged<PlatformFile> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'รูปภาพแนบ (ไม่บังคับ)',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: enabled ? onPick : null,
          icon: const Icon(Icons.attach_file),
          label: const Text('เลือกไฟล์'),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'รองรับ JPG, PNG, WEBP | ไม่จำกัดจำนวน | ระบบลดขนาดอัตโนมัติ',
        softWrap: true,
      ),
      if (files.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(
          key: previewKey,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final file in files)
              _AttachmentPreview(file: file, onRemove: () => onRemove(file)),
          ],
        ),
      ],
    ],
  );
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.file, required this.onRemove});
  final PlatformFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    child: Stack(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          clipBehavior: Clip.antiAlias,
          child: file.bytes == null
              ? const Icon(Icons.image_not_supported_outlined)
              : InkWell(
                  onTap: () => _showAttachmentImage(context, file.bytes!),
                  child: Image.memory(file.bytes!, fit: BoxFit.cover),
                ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton.filledTonal(
            onPressed: onRemove,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            icon: const Icon(Icons.close),
          ),
        ),
        Positioned(
          left: 4,
          right: 4,
          bottom: 4,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black54),
            child: Text(
              '${file.name}\n${_formatBytes(file.size)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1048576).toStringAsFixed(2)} MB';
}

class _RequestDetailDialog extends StatefulWidget {
  const _RequestDetailDialog({
    required this.api,
    required this.data,
    required this.attachments,
    required this.canEdit,
    required this.menuCode,
  });
  final ServiceRequestApi api;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> attachments;
  final bool canEdit;
  final String menuCode;

  @override
  State<_RequestDetailDialog> createState() => _RequestDetailDialogState();
}

class _RequestDetailDialogState extends State<_RequestDetailDialog> {
  bool _busy = false;
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _attachments = List<Map<String, dynamic>>.from(widget.attachments);
  }

  late List<Map<String, dynamic>> _attachments;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(context, message: error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReasonDialog(
        title: 'ยกเลิกใบแจ้งซ่อม',
        label: 'เหตุผลการยกเลิก *',
        controller: controller,
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty || !mounted) return;
    await _run(() => widget.api.cancel(_id, value.trim()));
  }

  Future<void> _deleteAttachment(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        title: const Text(
          'ลบรูปแนบ',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text('ต้องการลบ ${item['fileName'] ?? 'รูปภาพ'} หรือไม่'),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close),
            label: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.deleteAttachment(
        _id,
        (item['attachmentId'] as num).toInt(),
      );
      if (mounted) setState(() => _attachments.remove(item));
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(context, message: error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _id => (_data['requestId'] as num).toInt();
  String get _status => _data['statusCode']?.toString() ?? '';
  List<Map<String, dynamic>> get _parts =>
      ((_data['parts'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      title: Text(
        _data['requestNo']?.toString() ?? 'รายละเอียดใบแจ้งซ่อม',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _line('สถานะ', status),
              _line('ผู้แจ้ง', _data['requesterName']?.toString()),
              _line('สถานที่', _data['locationSnapshot']?.toString()),
              _line(
                'อุปกรณ์',
                '${_data['equipmentCode'] ?? '-'} | ${_data['equipmentName'] ?? '-'}',
              ),
              _line('หัวข้อ', _data['subject']?.toString()),
              _line('รายละเอียด', _data['detail']?.toString()),
              _line(
                'ช่างผู้รับผิดชอบ',
                _data['assignedEmployeeName']?.toString(),
              ),
              if (_data['resolutionDetail'] != null)
                _line('ผลการซ่อม', _data['resolutionDetail']?.toString()),
              if (_data['cancellationReason'] != null)
                _line('เหตุผลยกเลิก', _data['cancellationReason']?.toString()),
              if (_parts.isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  'อะไหล่ที่ใช้ซ่อม',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final part in _parts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${part['itemCode'] ?? '-'} | ${part['itemName'] ?? '-'}\nจำนวน ${part['quantity'] ?? 0} ${part['unitCode'] ?? ''} · ต้นทุนรวม ${((part['totalCost'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} บาท',
                      softWrap: true,
                    ),
                  ),
                Text(
                  'ต้นทุนอะไหล่รวม ${((_data['partsTotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} บาท',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              if (_attachments.isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  'รูปภาพแนบ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in _attachments)
                      _RemoteAttachmentTile(
                        api: widget.api,
                        requestId: _id,
                        item: item,
                        menuCode: widget.menuCode,
                        canDelete:
                            widget.canEdit &&
                            status != 'COMPLETED' &&
                            status != 'CANCELLED',
                        onDelete: () => _deleteAttachment(item),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.canEdit &&
            (status == 'NEW' ||
                status == 'RECEIVED' ||
                status == 'IN_PROGRESS'))
          TextButton(
            onPressed: _busy ? null : _cancel,
            child: const Text('ยกเลิก'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );
  }

  Widget _line(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      '$label: ${value == null || value.isEmpty ? '-' : value}',
      softWrap: true,
    ),
  );
}

class _RemoteAttachmentTile extends StatelessWidget {
  const _RemoteAttachmentTile({
    required this.api,
    required this.requestId,
    required this.item,
    required this.menuCode,
    required this.canDelete,
    required this.onDelete,
  });
  final ServiceRequestApi api;
  final int requestId;
  final Map<String, dynamic> item;
  final String menuCode;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final attachmentId = (item['attachmentId'] as num).toInt();
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          FutureBuilder<List<int>>(
            future: api.downloadAttachment(
              requestId,
              attachmentId,
              menuCode: menuCode,
            ),
            builder: (context, snapshot) => InkWell(
              onTap: snapshot.hasData
                  ? () => _showAttachmentImage(
                      context,
                      Uint8List.fromList(snapshot.data!),
                    )
                  : null,
              child: Container(
                width: 120,
                height: 96,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
                child: snapshot.hasData
                    ? Image.memory(
                        Uint8List.fromList(snapshot.data!),
                        fit: BoxFit.cover,
                      )
                    : snapshot.hasError
                    ? const Icon(Icons.broken_image_outlined)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  item['fileName']?.toString() ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canDelete)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showAttachmentImage(BuildContext context, Uint8List bytes) =>
    showDialog<void>(
      context: context,
      builder: (context) => _AttachmentImageDialog(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: InteractiveViewer(
            child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
          ),
        ),
      ),
    );

class _AttachmentImageDialog extends StatelessWidget {
  const _AttachmentImageDialog({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final maxHeight = MediaQuery.sizeOf(context).height * .8;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.image_outlined, color: primary, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'รูปภาพแนบ',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 1, color: LaooColors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: child,
                ),
              ),
              const Divider(height: 1, thickness: 1, color: LaooColors.border),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('ปิด'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonDialog extends StatelessWidget {
  const _ReasonDialog({
    required this.title,
    required this.label,
    required this.controller,
  });
  final String title;
  final String label;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    content: SizedBox(
      width: 460,
      child: TextField(
        controller: controller,
        minLines: 4,
        maxLines: 8,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    ),
    actions: [
      OutlinedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
        label: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('บันทึก'),
      ),
    ],
  );
}
