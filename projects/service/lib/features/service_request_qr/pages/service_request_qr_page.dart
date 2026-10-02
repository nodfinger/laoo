import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_request_qr_api.dart';

class ServiceRequestQrPage extends StatefulWidget {
  const ServiceRequestQrPage({super.key, this.api, this.menuName});
  final ServiceRequestQrApi? api;
  final String? menuName;

  @override
  State<ServiceRequestQrPage> createState() => _ServiceRequestQrPageState();
}

class _ServiceRequestQrPageState extends State<ServiceRequestQrPage> {
  late final ServiceRequestQrApi _api = widget.api ?? ServiceRequestQrApi();
  final _search = TextEditingController();
  String _status = '';
  int _page = 1;
  bool _loading = true;
  String? _error;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  String _menuName = 'จัดการ QR Code แจ้งซ่อม';
  Map<String, dynamic> _data = const {'items': <dynamic>[], 'total': 0};

  @override
  void initState() {
    super.initState();
    _load();
    _loadActions();
    if (widget.menuName != null) {
      _menuName = widget.menuName!;
    } else {
      NavigationMenuRepository()
          .resolveMenuName(menuCode: '15002', fallback: _menuName)
          .then((name) {
            if (mounted) setState(() => _menuName = name);
          })
          .catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _api.list(
        search: _search.text.trim(),
        status: _status,
        page: _page,
      );
      if (mounted) setState(() => _data = value);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? '${error.message}\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาตรวจสอบข้อมูลและลองอีกครั้ง'}'
              : 'โหลดรายการ QR Code ไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อและลองอีกครั้ง',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  void _message(Object error, {bool errorState = true}) {
    final text = error is ApiException
        ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่'}'
        : 'ไม่สามารถดำเนินการได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: text, error: errorState);
  }

  Future<void> _create() async {
    try {
      final choices = await _api.lookup();
      if (!mounted) return;
      if (choices.isEmpty) {
        showTimedSnackBar(
          context,
          message:
              'ไม่มีอุปกรณ์ที่สร้าง QR Code ใหม่ได้ กรุณาตรวจสอบรายการ QR เดิมหรือสถานะอุปกรณ์',
        );
        return;
      }
      final created = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) =>
            _CreateQrDialog(api: _api, choices: choices, menuName: _menuName),
      );
      if (created == null || !mounted) return;
      await _load();
      if (!mounted) return;
      await _showQr(created['qrToken']?.toString() ?? '');
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  Future<void> _showQr(String token) async {
    if (token.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _QrDialog(token: token),
    );
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    final id = (row['qrPortalId'] as num?)?.toInt();
    if (id == null || !_canEdit) return;
    final active = await showDialog<bool>(
      context: context,
      builder: (_) => _EditQrDialog(row: row, menuName: _menuName),
    );
    if (active == null || !mounted) return;
    try {
      await _api.setActive(id, active);
      if (!mounted) return;
      showTimedSnackBar(context, message: 'แก้ไขสถานะ QR Code แล้ว');
      await _load();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = (row['qrPortalId'] as num?)?.toInt();
    if (id == null || !_canDelete) return;
    final confirmed = await _confirmQrDelete(
      context,
      '${row['itemCode'] ?? '-'} / ${row['serialNo'] ?? '-'}',
    );
    if (!confirmed || !mounted) return;
    try {
      await _api.delete(id);
      if (!mounted) return;
      showTimedSnackBar(context, message: 'ลบ QR Code แล้ว');
      if (_page > 1 && ((_data['items'] as List?)?.length ?? 0) == 1) _page--;
      await _load();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ((_data['items'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final total = (_data['total'] as num?)?.toInt() ?? 0;
    return SupportWorkspaceShell(
      pageTitle: _menuName,
      activeMenu: 'cmQrPortal',
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
                    Expanded(
                      child: Text(
                        _menuName,
                        style: LaooTypography.screenCaptionStyle,
                      ),
                    ),
                    const LaooPageFavoriteButton(),
                    if (_canCreate)
                      FilledButton.icon(
                        onPressed: _loading ? null : _create,
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: LaooLayout.listSectionSpacing),
            _toolbar(total),
            const SizedBox(height: LaooLayout.listSectionSpacing),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Card(
                      margin: EdgeInsets.zero,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: LaooLayout.cardPadding),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('ลองอีกครั้ง'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : items.isEmpty
                  ? const Card(
                      margin: EdgeInsets.zero,
                      child: Center(child: Text('ยังไม่มี QR Code แจ้งซ่อม')),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth < 900
                          ? ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const SizedBox(
                                height: LaooLayout.listItemSpacing,
                              ),
                              itemBuilder: (_, index) => _QrCard(
                                row: items[index],
                                canEdit: _canEdit,
                                canDelete: _canDelete,
                                onShow: () => _showQr(
                                  items[index]['qrToken']?.toString() ?? '',
                                ),
                                onEdit: () => _edit(items[index]),
                                onDelete: () => _delete(items[index]),
                              ),
                            )
                          : _QrTable(
                              items: items,
                              canEdit: _canEdit,
                              canDelete: _canDelete,
                              onShow: (row) =>
                                  _showQr(row['qrToken']?.toString() ?? ''),
                              onEdit: _edit,
                              onDelete: _delete,
                            ),
                    ),
            ),
            const SizedBox(height: LaooLayout.listSectionSpacing),
            _Pagination(
              page: _page,
              total: total,
              onPrevious: _page > 1
                  ? () {
                      setState(() => _page--);
                      _load();
                    }
                  : null,
              onNext: _page * 20 < total
                  ? () {
                      setState(() => _page++);
                      _load();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(int total) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: TextField(
              controller: _search,
              onSubmitted: (_) {
                _page = 1;
                _load();
              },
              decoration: const InputDecoration(
                labelText: 'ค้นหา QR, Serial หรืออุปกรณ์',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'สถานะ'),
              items: const [
                DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                DropdownMenuItem(value: 'ACTIVE', child: Text('ใช้งาน')),
                DropdownMenuItem(value: 'INACTIVE', child: Text('ปิดใช้งาน')),
              ],
              onChanged: (value) => setState(() => _status = value ?? ''),
            ),
          ),
          FilledButton.icon(
            onPressed: _loading
                ? null
                : () {
                    _page = 1;
                    _load();
                  },
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
          OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _search.clear();
                      _status = '';
                      _page = 1;
                    });
                    _load();
                  },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('ล้าง Filter'),
          ),
          Text('ทั้งหมด $total รายการ'),
        ],
      ),
    ),
  );
}

class _QrTable extends StatelessWidget {
  const _QrTable({
    required this.items,
    required this.canEdit,
    required this.canDelete,
    required this.onShow,
    required this.onEdit,
    required this.onDelete,
  });
  final List<Map<String, dynamic>> items;
  final bool canEdit;
  final bool canDelete;
  final ValueChanged<Map<String, dynamic>> onShow;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('QR Code')),
          DataColumn(label: Text('อุปกรณ์ / Serial')),
          DataColumn(label: Text('สถานที่')),
          DataColumn(label: Text('สถานะ')),
        ],
        rows: [
          for (final row in items)
            DataRow(
              cells: [
                DataCell(Text('${row['qrPortalId']}')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'แสดง QR Code',
                        onPressed: () => onShow(row),
                        icon: const Icon(Icons.qr_code_2),
                      ),
                      if (canEdit)
                        IconButton(
                          tooltip: 'แก้ไข QR Code',
                          onPressed: () => onEdit(row),
                          icon: Icon(
                            Icons.edit_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      if (canDelete)
                        IconButton(
                          tooltip: 'ลบ QR Code',
                          onPressed: () => onDelete(row),
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                DataCell(Text(_tokenLabel(row['qrToken']))),
                DataCell(
                  SizedBox(
                    width: 260,
                    child: Text(
                      '${row['itemCode'] ?? '-'} | ${row['itemName'] ?? '-'}\nSerial: ${row['serialNo'] ?? '-'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(
                      row['locationSnapshot']?.toString() ?? '-',
                      softWrap: true,
                    ),
                  ),
                ),
                DataCell(_StatusChip(active: row['isActive'] == true)),
              ],
            ),
        ],
      ),
    ),
  );
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.row,
    required this.canEdit,
    required this.canDelete,
    required this.onShow,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> row;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onShow;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
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
                  '${row['itemCode'] ?? '-'} | ${row['itemName'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  softWrap: true,
                ),
              ),
              _StatusChip(active: row['isActive'] == true),
            ],
          ),
          const Divider(),
          Text('Serial: ${row['serialNo'] ?? '-'}'),
          Text('สถานที่: ${row['locationSnapshot'] ?? '-'}', softWrap: true),
          Text('QR: ${_tokenLabel(row['qrToken'])}'),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onShow,
                icon: const Icon(Icons.qr_code_2),
                label: const Text('แสดง QR'),
              ),
              if (canEdit)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('แก้ไข'),
                ),
              if (canDelete)
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    'ลบ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(active ? 'ใช้งาน' : 'ปิดใช้งาน'),
    avatar: Icon(
      active ? Icons.check_circle_outline : Icons.block_outlined,
      size: 18,
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });
  final int page;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final first = total == 0 ? 0 : (page - 1) * 20 + 1;
    final last = total == 0 ? 0 : (page * 20).clamp(0, total);
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
                context,
                icon: Icons.chevron_left,
                onPressed: onPrevious,
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
                      '$page',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: LaooLayout.listSectionSpacing),
              _pageButton(
                context,
                icon: Icons.chevron_right,
                onPressed: onNext,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '$first-$last จาก $total',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageButton(
    BuildContext context, {
    required IconData icon,
    VoidCallback? onPressed,
  }) {
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

class _EditQrDialog extends StatefulWidget {
  const _EditQrDialog({required this.row, required this.menuName});
  final Map<String, dynamic> row;
  final String menuName;

  @override
  State<_EditQrDialog> createState() => _EditQrDialogState();
}

class _EditQrDialogState extends State<_EditQrDialog> {
  late bool _active = widget.row['isActive'] == true;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      title: Column(
        children: [
          SizedBox(
            height: LaooLayout.popupHeaderMinHeight,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, color: primary),
                const SizedBox(width: LaooLayout.cardPadding),
                Expanded(
                  child: Text(
                    '${widget.menuName} > แก้ไข',
                    style: const TextStyle(
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
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('สถานะ'),
                Switch(
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
            const SizedBox(height: LaooLayout.popupFieldSpacing),
            Text(
              'อุปกรณ์: ${widget.row['itemCode'] ?? '-'} | ${widget.row['itemName'] ?? '-'}',
            ),
            const SizedBox(height: LaooLayout.popupFieldSpacing),
            Text('Serial: ${widget.row['serialNo'] ?? '-'}'),
            const SizedBox(height: LaooLayout.popupFieldSpacing),
            Text('สถานที่: ${widget.row['locationSnapshot'] ?? '-'}'),
            const SizedBox(height: LaooLayout.popupFieldSpacing),
            const Text(
              'QR Code ผูกกับอุปกรณ์เดิม หากต้องการเปลี่ยนอุปกรณ์ให้ลบรายการนี้แล้วสร้างใหม่',
            ),
          ],
        ),
      ),
      actions: [
        const SizedBox(
          width: double.infinity,
          child: Divider(color: LaooColors.border, height: 1),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _active),
          icon: const Icon(Icons.save_outlined),
          label: const Text('บันทึก'),
        ),
      ],
    );
  }
}

Future<bool> _confirmQrDelete(BuildContext context, String name) async {
  final error = Theme.of(context).colorScheme.error;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
            side: BorderSide(color: error),
          ),
          title: Column(
            children: [
              SizedBox(
                height: LaooLayout.popupHeaderMinHeight,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: error),
                    const SizedBox(width: LaooLayout.cardPadding),
                    Expanded(
                      child: Text(
                        'ยืนยันการลบข้อมูล',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: LaooColors.border, height: 1),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            decoration: BoxDecoration(
              color: error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            child: Text(
              'ลบ QR Code ของ $name ถาวรใช่หรือไม่? QR ที่ลบแล้วจะสแกนใช้งานไม่ได้และไม่สามารถเรียกคืนได้',
            ),
          ),
          actions: [
            const SizedBox(
              width: double.infinity,
              child: Divider(color: LaooColors.border, height: 1),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: error),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบ'),
            ),
          ],
        ),
      ) ??
      false;
}

class _CreateQrDialog extends StatefulWidget {
  const _CreateQrDialog({
    required this.api,
    required this.choices,
    required this.menuName,
  });
  final ServiceRequestQrApi api;
  final List<Map<String, dynamic>> choices;
  final String menuName;
  @override
  State<_CreateQrDialog> createState() => _CreateQrDialogState();
}

class _CreateQrDialogState extends State<_CreateQrDialog> {
  int? _instanceId;
  bool _saving = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
    title: Column(
      children: [
        SizedBox(
          height: LaooLayout.popupHeaderMinHeight,
          child: Row(
            children: [
              Icon(
                Icons.qr_code_2,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: LaooLayout.cardPadding),
              Expanded(
                child: Text(
                  '${widget.menuName} > เพิ่ม',
                  style: LaooTypography.screenCaptionStyle,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: LaooColors.border, height: 1),
      ],
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'อุปกรณ์ / Serial *',
              ),
              items: [
                for (final item in widget.choices)
                  DropdownMenuItem(
                    value: (item['itemInstanceId'] as num).toInt(),
                    child: Text(
                      '${item['itemCode']} | ${item['itemName']} | ${item['serialNo']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _instanceId = value),
            ),
            if (_instanceId != null) ...[
              const SizedBox(height: 12),
              _location(),
            ],
            const SizedBox(height: 8),
            const Text('เลือกได้เฉพาะอุปกรณ์ที่ติดตั้งและมีอาคาร ชั้น ห้องครบ'),
          ],
        ),
      ),
    ),
    actions: [
      const SizedBox(
        width: double.infinity,
        child: Divider(color: LaooColors.border, height: 1),
      ),
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: _instanceId == null || _saving ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
      ),
    ],
  );

  Widget _location() {
    final item = widget.choices.firstWhere(
      (row) => (row['itemInstanceId'] as num).toInt() == _instanceId,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(color: LaooColors.surfaceSoft),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('สถานที่: ${item['locationSnapshot'] ?? '-'}'),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final value = await widget.api.create(_instanceId!);
      if (mounted) Navigator.pop(context, value);
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? '${error.message}\n${error.description ?? 'กรุณาลองใหม่'}'
              : 'บันทึก QR Code ไม่สำเร็จ',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _QrDialog extends StatelessWidget {
  const _QrDialog({required this.token});
  final String token;
  String get _url =>
      '${Uri.base.scheme}://${Uri.base.authority}/#/portal/request?qr=$token';
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
    title: Column(
      children: [
        SizedBox(
          height: LaooLayout.popupHeaderMinHeight,
          child: Row(
            children: [
              Icon(
                Icons.qr_code_2,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: LaooLayout.cardPadding),
              Expanded(
                child: Text(
                  'QR Code แจ้งซ่อม',
                  style: LaooTypography.screenCaptionStyle,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: LaooColors.border, height: 1),
      ],
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: QrImageView(
                  data: _url,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  semanticsLabel: 'QR Code แจ้งซ่อม',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(_url),
            const SizedBox(height: 8),
            const Text('สแกนเพื่อเปิดแบบฟอร์มแจ้งซ่อมพร้อมอุปกรณ์และสถานที่'),
          ],
        ),
      ),
    ),
    actions: [
      const SizedBox(
        width: double.infinity,
        child: Divider(color: LaooColors.border, height: 1),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
      FilledButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: _url));
          if (context.mounted) {
            showTimedSnackBar(context, message: 'คัดลอกลิงก์ QR แล้ว');
          }
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('คัดลอกลิงก์'),
      ),
    ],
  );
}

String _tokenLabel(Object? token) {
  final value = token?.toString() ?? '';
  return value.length <= 12 ? value : '${value.substring(0, 12)}…';
}
