import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_room_booking_repository.dart';

class MeetingRoomApprovalPage extends StatefulWidget {
  const MeetingRoomApprovalPage({super.key});

  @override
  State<MeetingRoomApprovalPage> createState() =>
      _MeetingRoomApprovalPageState();
}

class _MeetingRoomApprovalPageState extends State<MeetingRoomApprovalPage> {
  final _repository = MeetingRoomBookingRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  String _caption = 'รายการรออนุมัติห้องประชุม';
  String? _message;
  bool _loading = true;
  bool _canEdit = false;
  String _status = 'PENDING';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _page = 1;
  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _loadCaption();
    _loadActions();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadActions() async {
    try {
      final actions = await _repository.actions();
      if (mounted) {
        setState(() => _canEdit = actions['approvalEdit'] == true);
      }
    } catch (_) {}
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: '21004',
      routeName: 'meetingRoomApprovals',
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _repository.approvalRequests(
        page: _page,
        pageSize: _pageSize,
        status: _status,
        search: _search.text,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          result['items'] as List? ?? const [],
        );
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = _error(error, 'โหลดรายการรออนุมัติไม่สำเร็จ');
        });
      }
    }
  }

  String _error(Object error, String fallback) => error is ApiException
      ? '${error.message}${error.description == null ? '' : '\n${error.description}'}'
      : '$fallback\n$error';

  Future<String?> _askRemark(Map<String, dynamic> item, String decision) async {
    final controller = TextEditingController();
    final preset = workspaceThemeController.value;
    final actionColor = decision == 'APPROVED'
        ? preset.primary
        : LaooColors.error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LaooColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        title: Row(
          children: [
            Icon(
              decision == 'APPROVED'
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              color: actionColor,
            ),
            const SizedBox(width: 8),
            Text(
              decision == 'APPROVED' ? 'ยืนยันอนุมัติ' : 'ยืนยันไม่อนุมัติ',
              style: LaooTypography.popupTitleStyle,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              color: preset.primary.withValues(alpha: .08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('เลขที่จอง: ${item['bookingNo'] ?? '-'}'),
                  Text(
                    'ห้อง: ${item['roomCode'] ?? '-'} | ${item['roomName'] ?? '-'}',
                  ),
                  Text(
                    'วันที่และเวลา: ${_dateTime(item['startDateTime'])} - ${_dateTime(item['endDateTime'])}',
                  ),
                  Text('ผู้จอง: ${item['requesterName'] ?? '-'}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'หมายเหตุ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('ยกเลิก', style: TextStyle(color: preset.primary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _decide(Map<String, dynamic> item, String decision) async {
    final remark = await _askRemark(item, decision);
    if (remark == null) return;
    try {
      await _repository.decideApproval(
        (item['approvalId'] as num).toInt(),
        decision,
        remark: remark,
      );
      if (!mounted) return;
      setState(
        () => _message = decision == 'APPROVED'
            ? 'อนุมัติการจองสำเร็จ'
            : 'ไม่อนุมัติการจองสำเร็จ',
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _message = _error(error, 'ดำเนินการไม่สำเร็จ'));
      }
    }
  }

  String _dateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _dateOnly(DateTime? value) {
    if (value == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  String _statusText(dynamic value) => switch ('$value') {
    'APPROVED' => 'อนุมัติ',
    'REJECTED' => 'ไม่อนุมัติ',
    _ => 'รออนุมัติ',
  };

  Future<void> _showHistory(Map<String, dynamic> item) async {
    final bookingId = (item['bookingId'] as num).toInt();
    final preset = workspaceThemeController.value;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
        backgroundColor: LaooColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        title: Row(
          children: [
            Icon(Icons.history, color: preset.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'ประวัติการเปลี่ยนสถานะ',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width * .55,
          height: MediaQuery.sizeOf(context).height * .55,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _repository.approvalHistory(bookingId),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(_error(snapshot.error!, 'โหลดประวัติไม่สำเร็จ')),
                );
              }
              final history = snapshot.data ?? const [];
              if (history.isEmpty) {
                return const Center(child: Text('ยังไม่มีประวัติ'));
              }
              return ListView.separated(
                itemCount: history.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (_, index) {
                  final entry = history[index];
                  final from = entry['fromStatus'];
                  final actor = entry['actorName'] ?? entry['actorCode'] ?? '-';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${from == null ? 'เริ่มต้น' : _statusText(from)} → ${_statusText(entry['toStatus'])}',
                        style: TextStyle(
                          color: preset.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_dateTime(entry['changedDate'])} | ผู้ดำเนินการ: $actor',
                      ),
                      if ('${entry['remark'] ?? ''}'.trim().isNotEmpty)
                        Text('หมายเหตุ: ${entry['remark']}'),
                    ],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: preset.primary,
              side: BorderSide(color: preset.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = (from ? _dateFrom : _dateTo) ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (from) {
        _dateFrom = value;
        if (_dateTo != null && _dateTo!.isBefore(value)) _dateTo = value;
      } else {
        _dateTo = value;
        if (_dateFrom != null && _dateFrom!.isAfter(value)) _dateFrom = value;
      }
      _page = 1;
    });
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _status = 'PENDING';
      _dateFrom = null;
      _dateTo = null;
      _page = 1;
    });
    _load();
  }

  Future<void> _rollback(Map<String, dynamic> item) async {
    final preset = workspaceThemeController.value;
    final remarkController = TextEditingController();
    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LaooColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          side: BorderSide.none,
        ),
        title: Row(
          children: [
            Icon(Icons.undo, color: preset.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'ยืนยันการย้อนสถานะ',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ต้องการย้อนเลขที่ ${item['bookingNo'] ?? '-'} กลับเป็นรออนุมัติหรือไม่?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarkController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'หมายเหตุ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: preset.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, remarkController.text.trim()),
            child: const Text('ย้อนเป็นรออนุมัติ'),
          ),
        ],
      ),
    );
    remarkController.dispose();
    if (remark == null) return;
    try {
      await _repository.rollback(
        (item['bookingId'] as num).toInt(),
        remark: remark,
      );
      if (!mounted) return;
      setState(() => _message = 'ย้อนสถานะเป็นรออนุมัติสำเร็จ');
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _message = _error(error, 'ย้อนสถานะไม่สำเร็จ'));
      }
    }
  }

  Widget _filterCard(WorkspaceThemePreset preset) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 260,
                child: TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: LaooTypography.inputText),
                  onSubmitted: (_) {
                    _page = 1;
                    _load();
                  },
                  decoration: const InputDecoration(
                    labelText: 'ค้นหาเลขที่จอง/ห้อง/ผู้จอง',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              SizedBox(
                width: compact ? constraints.maxWidth : 180,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey(_status),
                  initialValue: _status,
                  style: const TextStyle(
                    color: LaooColors.textPrimary,
                    fontSize: LaooTypography.comboBox,
                  ),
                  decoration: const InputDecoration(labelText: 'สถานะ'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                    DropdownMenuItem(
                      value: 'PENDING',
                      child: Text('รออนุมัติ'),
                    ),
                    DropdownMenuItem(value: 'APPROVED', child: Text('อนุมัติ')),
                    DropdownMenuItem(
                      value: 'REJECTED',
                      child: Text('ไม่อนุมัติ'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _status = value ?? ''),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(from: true),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('จาก ${_dateOnly(_dateFrom)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(from: false),
                icon: const Icon(Icons.event_outlined),
                label: Text('ถึง ${_dateOnly(_dateTo)}'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: preset.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                ),
                onPressed: () {
                  _page = 1;
                  _load();
                },
                icon: const Icon(Icons.search),
                label: const Text('ค้นหา'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: preset.primary,
                  side: BorderSide(color: preset.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                ),
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear),
                label: const Text('ล้าง Filter'),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _itemCard(Map<String, dynamic> item, WorkspaceThemePreset preset) {
    final start = _dateTime(item['startDateTime']);
    final end = _dateTime(item['endDateTime']);
    final status = '${item['status'] ?? 'PENDING'}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.meeting_room_outlined, color: preset.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item['roomCode'] ?? '-'} | ${item['roomName'] ?? '-'}',
                    style: TextStyle(
                      color: preset.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: LaooTypography.inputText,
                    ),
                  ),
                ),
                Text(
                  '${item['bookingNo'] ?? '-'}',
                  style: TextStyle(color: preset.primary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'REJECTED'
                        ? LaooColors.error.withValues(alpha: .1)
                        : preset.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                  child: Text(
                    _statusText(status),
                    style: TextStyle(
                      color: status == 'REJECTED'
                          ? LaooColors.error
                          : preset.primary,
                      fontSize: LaooTypography.inputText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              '${item['subject'] ?? '-'}',
              style: const TextStyle(fontSize: LaooTypography.inputText),
            ),
            const SizedBox(height: 4),
            Text(
              '$start - $end',
              style: const TextStyle(fontSize: LaooTypography.inputText),
            ),
            Text(
              'หมายเหตุ: ${item['remark'] ?? '-'}',
              style: TextStyle(
                color: preset.textSecondary,
                fontSize: LaooTypography.inputText,
              ),
            ),
            Text(
              'ผู้จอง: ${item['requesterCode'] ?? '-'} | ${item['requesterName'] ?? '-'} | ผู้เข้าร่วม ${item['attendeeCount'] ?? '-'} คน',
              style: TextStyle(
                color: preset.textSecondary,
                fontSize: LaooTypography.inputText,
              ),
            ),
            Text(
              'สถานที่: ${item['branchName'] ?? '-'} | ${item['buildingName'] ?? '-'} | ${item['floorName'] ?? '-'}',
              style: TextStyle(
                color: preset.textSecondary,
                fontSize: LaooTypography.inputText,
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showHistory(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: preset.primary,
                    side: BorderSide(color: preset.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('ประวัติ'),
                ),
                const SizedBox(width: 8),
                if (status == 'PENDING' && _canEdit) ...[
                  OutlinedButton(
                    onPressed: () => _decide(item, 'REJECTED'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: preset.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    child: const Text('ไม่อนุมัติ'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _decide(item, 'APPROVED'),
                    style: FilledButton.styleFrom(
                      backgroundColor: preset.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    child: const Text('อนุมัติ'),
                  ),
                ] else if (_canEdit)
                  OutlinedButton.icon(
                    onPressed: () => _rollback(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: preset.primary,
                      side: BorderSide(color: preset.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    icon: const Icon(Icons.undo),
                    label: const Text('ย้อนเป็นรออนุมัติ'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return SupportWorkspaceShell(
      menuScope: WorkspaceMenuScope.company,
      pageTitle: _caption,
      activeMenu: '21004',
      child: Stack(
        children: [
          Padding(
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
                          child: WorkspacePageTitle(
                            title: _caption,
                            favoriteKey: '21004',
                          ),
                        ),
                        IconButton(
                          onPressed: _load,
                          icon: Icon(Icons.refresh, color: preset.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                _filterCard(preset),
                const SizedBox(height: LaooLayout.cardSpacing),
                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _items.isEmpty
                        ? const Center(child: Text('ไม่มีรายการรออนุมัติ'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(
                              LaooLayout.cardPadding,
                            ),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: LaooLayout.cardSpacing),
                            itemBuilder: (_, index) =>
                                _itemCard(_items[index], preset),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (_message != null)
            Positioned(
              top: 12,
              right: 12,
              child: AutoDismissMessage(
                message: _message!,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }
}
