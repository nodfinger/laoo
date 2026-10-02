import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_complaint_api.dart';

class ServiceComplaintPage extends StatefulWidget {
  const ServiceComplaintPage({super.key});
  @override
  State<ServiceComplaintPage> createState() => _ServiceComplaintPageState();
}

class _ServiceComplaintPageState extends State<ServiceComplaintPage> {
  final _api = ServiceComplaintApi();
  final _search = TextEditingController();
  String _caption = 'แจ้งเรื่องร้องเรียน';
  String _status = '';
  bool _self = true;
  bool _loading = true;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  int _page = 1;
  int _total = 0;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _resolveCaption();
    _loadActions();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _resolveCaption() async {
    try {
      final caption = await NavigationMenuRepository().resolveMenuName(
        menuCode: '20006',
        routeName: 'portalComplaint',
        fallback: _caption,
      );
      if (mounted) setState(() => _caption = caption);
    } catch (_) {}
  }

  Future<void> _loadActions() async {
    try {
      final actions = await _api.actions();
      if (mounted) {
        setState(() {
          final isCrud = actions['screenType'] == 1;
          _canCreate = isCrud && actions['create'] == true;
          _canEdit = isCrud && actions['edit'] == true;
          _canDelete = isCrud && actions['delete'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.list(
        search: _search.text.trim(),
        status: _status,
        self: _self,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items = ((data['items'] as List?) ?? const [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        _total = (data['total'] as num?)?.toInt() ?? 0;
      });
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(Object error, {bool errorState = true}) {
    final text = error is ApiException
        ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง'}'
        : 'ไม่สามารถดำเนินการได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: text, error: errorState);
  }

  Future<void> _refresh() async {
    _page = 1;
    await _load();
  }

  Future<void> _create() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ComplaintCreateDialog(api: _api, caption: _caption),
    );
    if (saved == true && mounted) {
      await _refresh();
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกเรื่องร้องเรียนเรียบร้อยแล้ว',
        );
      }
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final id = (row['complaintId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = await _api.detail(id);
      if (!mounted) return;
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) =>
            _ComplaintDetailDialog(api: _api, data: detail, canEdit: _canEdit),
      );
      if (changed == true) await _load();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    if (!_canEdit || row['statusCode'] != 'NEW') return;
    final id = (row['complaintId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = await _api.detail(id);
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _ComplaintCreateDialog(
          api: _api,
          caption: _caption,
          original: detail,
        ),
      );
      if (saved == true && mounted) await _load();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!_canDelete || row['statusCode'] != 'NEW') return;
    final id = (row['complaintId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = await _api.detail(id);
      if (!mounted) return;
      final errorColor = Theme.of(context).colorScheme.error;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: errorColor),
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: errorColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ยืนยันการลบข้อมูล',
                  style: TextStyle(
                    color: errorColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(),
              Container(
                padding: const EdgeInsets.all(LaooLayout.cardPadding),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
                child: Text('${detail['complaintNo']} — ${detail['subject']}'),
              ),
              const SizedBox(height: 10),
              const Text('รายการที่ลบแล้วไม่สามารถเรียกคืนได้'),
              const Divider(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบ'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _api.delete(id, detail['rowVersion']?.toString() ?? '');
      if (!mounted) return;
      if (_page > 1 && _items.length == 1) _page--;
      await _load();
      if (mounted) showTimedSnackBar(context, message: 'ลบเรื่องร้องเรียนแล้ว');
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'portalComplaint',
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
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _caption,
                        style: const TextStyle(
                          color: LaooColors.pageCaption,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const LaooPageFavoriteButton(),
                    ],
                  ),
                  if (_canCreate)
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LaooLayout.listSectionSpacing),
          _toolbar(),
          const SizedBox(height: LaooLayout.listSectionSpacing),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(child: Text('ไม่พบเรื่องร้องเรียน'))
                  : LayoutBuilder(
                      builder: (context, box) => box.maxWidth < 900
                          ? ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (_, index) => _ComplaintCard(
                                row: _items[index],
                                onTap: () => _open(_items[index]),
                                onEdit:
                                    _canEdit &&
                                        _items[index]['statusCode'] == 'NEW'
                                    ? () => _edit(_items[index])
                                    : null,
                                onDelete:
                                    _canDelete &&
                                        _items[index]['statusCode'] == 'NEW'
                                    ? () => _delete(_items[index])
                                    : null,
                              ),
                            )
                          : _ComplaintTable(
                              items: _items,
                              onOpen: _open,
                              onEdit: _canEdit ? _edit : null,
                              onDelete: _canDelete ? _delete : null,
                            ),
                    ),
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
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 380
                ? MediaQuery.sizeOf(context).width - 4 * LaooLayout.cardMargin
                : 330,
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _refresh(),
              decoration: const InputDecoration(
                labelText: 'ค้นหาเลขที่ หัวข้อ หรือผู้ร้อง',
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
                DropdownMenuItem(value: 'NEW', child: Text('รอรับเรื่อง')),
                DropdownMenuItem(
                  value: 'IN_PROGRESS',
                  child: Text('กำลังดำเนินการ'),
                ),
                DropdownMenuItem(value: 'COMPLETED', child: Text('เสร็จสิ้น')),
                DropdownMenuItem(value: 'CANCELLED', child: Text('ยกเลิก')),
              ],
              onChanged: (value) => setState(() => _status = value ?? ''),
            ),
          ),
          if (_canEdit)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('ของฉัน')),
                ButtonSegment(value: false, label: Text('ทั้งหมด')),
              ],
              selected: {_self},
              onSelectionChanged: (value) {
                setState(() => _self = value.first);
                _refresh();
              },
            ),
          FilledButton.icon(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
        ],
      ),
    ),
  );

  Widget _pagination() => Card(
    margin: EdgeInsets.zero,
    child: SizedBox(
      height: LaooLayout.paginationCardHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: LaooLayout.cardPadding),
        child: Row(
          children: [
            _pageButton(
              Icons.chevron_left,
              _page <= 1
                  ? null
                  : () {
                      setState(() => _page--);
                      _load();
                    },
            ),
            const SizedBox(width: LaooLayout.listSectionSpacing),
            SizedBox(
              width: LaooLayout.paginationButtonSize,
              height: LaooLayout.paginationButtonSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
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
              _page * 20 >= _total
                  ? null
                  : () {
                      setState(() => _page++);
                      _load();
                    },
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '${_total == 0 ? 0 : (_page - 1) * 20 + 1}-'
                '${_total == 0 ? 0 : (_page * 20 < _total ? _page * 20 : _total)} '
                'จาก $_total',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );

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

class _ComplaintTable extends StatelessWidget {
  const _ComplaintTable({
    required this.items,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
  });
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>>? onEdit;
  final ValueChanged<Map<String, dynamic>>? onDelete;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SizedBox(
      width: 1120,
      child: Table(
        border: TableBorder(bottom: BorderSide(color: LaooColors.border)),
        columnWidths: const {
          0: FlexColumnWidth(1.35),
          1: FlexColumnWidth(1.3),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(2.4),
          4: FlexColumnWidth(1.3),
          5: FlexColumnWidth(1.6),
        },
        children: [
          const TableRow(
            children: [
              _Header('เลขที่'),
              _Header('ผู้ร้อง'),
              _Header('สถานที่'),
              _Header('หัวข้อ'),
              _Header('สถานะ'),
              _Header(''),
            ],
          ),
          for (final item in items)
            TableRow(
              children: [
                _Cell(item['complaintNo']?.toString() ?? '-'),
                _Cell(item['complainantName']?.toString() ?? '-'),
                _Cell(item['locationSnapshot']?.toString() ?? '-'),
                _Cell(item['subject']?.toString() ?? '-'),
                _Cell(_statusLabel(item['statusCode']?.toString() ?? '')),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => onOpen(item),
                      icon: const Icon(Icons.visibility_outlined),
                      tooltip: 'ดูรายละเอียด',
                    ),
                    if (onEdit != null && item['statusCode'] == 'NEW')
                      IconButton(
                        onPressed: () => onEdit!(item),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'แก้ไข',
                      ),
                    if (onDelete != null && item['statusCode'] == 'NEW')
                      IconButton(
                        onPressed: () => onDelete!(item),
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        tooltip: 'ลบ',
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({
    required this.row,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      onTap: onTap,
      title: Text(row['subject']?.toString() ?? '-'),
      subtitle: Text(
        '${row['complaintNo'] ?? '-'}\n${row['complainantName'] ?? '-'} • ${row['locationSnapshot'] ?? '-'}\n${_statusLabel(row['statusCode']?.toString() ?? '')}',
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'แก้ไข',
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'ลบ',
            ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _Cell extends StatelessWidget {
  const _Cell(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
  );
}

String _statusLabel(String value) => switch (value) {
  'NEW' => 'รอรับเรื่อง',
  'IN_PROGRESS' => 'กำลังดำเนินการ',
  'COMPLETED' => 'เสร็จสิ้น',
  'CANCELLED' => 'ยกเลิก',
  _ => value,
};

class _ComplaintCreateDialog extends StatefulWidget {
  const _ComplaintCreateDialog({
    required this.api,
    required this.caption,
    this.original,
  });
  final ServiceComplaintApi api;
  final String caption;
  final Map<String, dynamic>? original;
  @override
  State<_ComplaintCreateDialog> createState() => _ComplaintCreateDialogState();
}

class _ComplaintCreateDialogState extends State<_ComplaintCreateDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _subject;
  late final TextEditingController _detail;
  List<PlatformFile> _files = const [];
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(
      text: widget.original?['subject']?.toString() ?? '',
    );
    _detail = TextEditingController(
      text: widget.original?['detail']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _subject.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result != null && mounted) {
      setState(() => _files = [..._files, ...result.files]);
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final original = widget.original;
      final int id;
      if (original == null) {
        final saved = await widget.api.create(
          subject: _subject.text.trim(),
          detail: _detail.text.trim(),
        );
        id = (saved['complaintId'] as num).toInt();
      } else {
        id = (original['complaintId'] as num).toInt();
        await widget.api.edit(
          id,
          subject: _subject.text.trim(),
          detail: _detail.text.trim(),
          rowVersion: original['rowVersion']?.toString() ?? '',
        );
      }
      final failed = <String>[];
      for (final file in _files) {
        if (file.bytes == null) {
          failed.add(file.name);
          continue;
        }
        try {
          await widget.api.uploadAttachment(
            id,
            fileName: file.name,
            bytes: file.bytes!,
          );
        } catch (_) {
          failed.add(file.name);
        }
      }
      if (!mounted) return;
      if (failed.isNotEmpty) {
        _error = 'บันทึกเรื่องแล้ว แต่แนบรูปไม่สำเร็จ: ${failed.join(', ')}';
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? '${error.message}\n${error.description ?? ''}'
              : 'บันทึกเรื่องร้องเรียนไม่สำเร็จ',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.caption} > ${widget.original == null ? 'เพิ่ม' : 'แก้ไข'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Divider(color: LaooColors.border),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _subject,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'หัวข้อ *',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'กรุณาระบุหัวข้อ'
                            : null,
                      ),
                      const SizedBox(height: LaooLayout.popupFieldSpacing),
                      TextFormField(
                        controller: _detail,
                        maxLines: 6,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'รายละเอียด *',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'กรุณาระบุรายละเอียด'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'รูปภาพแนบ (ไม่บังคับ)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pick,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('เลือกไฟล์รูปภาพ'),
                      ),
                      for (var i = 0; i < _files.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.image_outlined),
                          title: Text(_files[i].name),
                          subtitle: Text(
                            '${((_files[i].size) / 1024).toStringAsFixed(0)} KB',
                          ),
                          trailing: IconButton(
                            onPressed: _saving
                                ? null
                                : () => setState(
                                    () => _files = [..._files]..removeAt(i),
                                  ),
                            icon: const Icon(Icons.close),
                            tooltip: 'ลบไฟล์',
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(color: LaooColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('บันทึก'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ComplaintDetailDialog extends StatefulWidget {
  const _ComplaintDetailDialog({
    required this.api,
    required this.data,
    required this.canEdit,
  });
  final ServiceComplaintApi api;
  final Map<String, dynamic> data;
  final bool canEdit;
  @override
  State<_ComplaintDetailDialog> createState() => _ComplaintDetailDialogState();
}

class _ComplaintDetailDialogState extends State<_ComplaintDetailDialog> {
  List<Map<String, dynamic>> _attachments = const [];
  bool _loading = true;
  bool _changed = false;
  String? _error;
  int get _id => (widget.data['complaintId'] as num).toInt();
  String get _status => widget.data['statusCode']?.toString() ?? '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await widget.api.attachments(_id);
      if (mounted) setState(() => _attachments = a);
    } catch (e) {
      if (mounted) setState(() => _error = 'ไม่สามารถโหลดรูปภาพแนบได้');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _noteAction(
    String title,
    Future<void> Function(String) action,
  ) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: title == 'ปิดเรื่อง' ? 'ผลการดำเนินการ *' : 'เหตุผล *',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim().isNotEmpty),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await action(c.text.trim());
        if (mounted) {
          setState(() => _changed = true);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(
            () => _error = e is ApiException
                ? '${e.message}\n${e.description ?? ''}'
                : 'ไม่สามารถบันทึกได้',
          );
        }
      }
    }
    c.dispose();
  }

  Future<void> _start() async {
    try {
      await widget.api.start(_id);
      if (mounted) {
        setState(() => _changed = true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'ไม่สามารถเริ่มดำเนินการได้');
    }
  }

  Future<void> _showImage(Map<String, dynamic> row) async {
    try {
      final bytes = await widget.api.downloadAttachment(
        _id,
        (row['attachmentId'] as num).toInt(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.memory(Uint8List.fromList(bytes)),
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'ไม่สามารถเปิดรูปภาพได้');
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.data['complaintNo']?.toString() ??
                  'รายละเอียดเรื่องร้องเรียน',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Divider(color: LaooColors.border),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line('ผู้ร้อง', widget.data['complainantName']),
                    _line('สถานที่', widget.data['locationSnapshot']),
                    _line('สถานะ', _statusLabel(_status)),
                    _line('หัวข้อ', widget.data['subject']),
                    const SizedBox(height: 6),
                    const Text(
                      'รายละเอียด',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(widget.data['detail']?.toString() ?? '-'),
                    if (widget.data['resolutionDetail'] != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'ผลการดำเนินการ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(widget.data['resolutionDetail'].toString()),
                    ],
                    if (widget.data['cancellationReason'] != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'เหตุผลการยกเลิก',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(widget.data['cancellationReason'].toString()),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'รูปภาพแนบ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      )
                    else if (_attachments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('ไม่มีรูปภาพแนบ'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in _attachments)
                            ActionChip(
                              avatar: const Icon(Icons.image_outlined),
                              label: Text(
                                a['fileName']?.toString() ?? 'รูปภาพ',
                              ),
                              onPressed: () => _showImage(a),
                            ),
                        ],
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, _changed),
                  child: const Text('ปิด'),
                ),
                if (widget.canEdit && _status == 'NEW')
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('เริ่มดำเนินการ'),
                  ),
                if (widget.canEdit && _status == 'IN_PROGRESS') ...[
                  FilledButton.icon(
                    onPressed: () => _noteAction(
                      'ปิดเรื่อง',
                      (v) => widget.api.complete(_id, v),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('บันทึกปิดเรื่อง'),
                  ),
                  OutlinedButton(
                    onPressed: () => _noteAction(
                      'ยกเลิกเรื่อง',
                      (v) => widget.api.cancel(_id, v),
                    ),
                    child: const Text('ยกเลิกเรื่อง'),
                  ),
                ],
                if (widget.canEdit && _status == 'NEW')
                  OutlinedButton(
                    onPressed: () => _noteAction(
                      'ยกเลิกเรื่อง',
                      (v) => widget.api.cancel(_id, v),
                    ),
                    child: const Text('ยกเลิกเรื่อง'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget _line(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      '$label: ${value?.toString().trim().isNotEmpty == true ? value : '-'}',
    ),
  );
}
