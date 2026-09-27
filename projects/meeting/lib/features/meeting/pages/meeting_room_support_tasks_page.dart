import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_equipment_request_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';
import '../widgets/meeting_pagination_card.dart';
import '../widgets/meeting_popup.dart';

class MeetingRoomSupportTasksPage extends StatefulWidget {
  const MeetingRoomSupportTasksPage({super.key});

  @override
  State<MeetingRoomSupportTasksPage> createState() =>
      _MeetingRoomSupportTasksPageState();
}

class _MeetingRoomSupportTasksPageState
    extends State<MeetingRoomSupportTasksPage> {
  final _repository = MeetingEquipmentRequestRepository();
  final _search = TextEditingController();
  String _caption = 'งานเตรียมห้องและอุปกรณ์';
  String? _message;
  bool _loading = true;
  bool _working = false;
  String? _status;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int? _roomId;
  List<Map<String, dynamic>> _rooms = const [];
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _summary = const {};
  int _total = 0;
  int _page = 1;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadCaption();
    _loadRooms();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: MeetingMenuCodes.roomSupportTasks,
      routeName: MeetingRouteNames.roomSupportTasks,
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _repository.departmentTasks(
        status: _status,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        search: _search.text,
        roomId: _roomId,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          result['items'] as List? ?? const [],
        );
        _summary = Map<String, dynamic>.from(
          result['summary'] as Map? ?? const {},
        );
        _total = (result['total'] as num?)?.toInt() ?? _items.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = _error(error, 'โหลดงานเตรียมอุปกรณ์ไม่สำเร็จ');
      });
    }
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _repository.departmentTaskRooms();
      if (mounted) setState(() => _rooms = rooms);
    } catch (_) {
      // The task list remains usable if the optional room filter cannot load.
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: (from ? _dateFrom : _dateTo) ?? DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (from) {
        _dateFrom = selected;
      } else {
        _dateTo = selected;
      }
      _page = 1;
    });
    _load();
  }

  void _clearFilters() {
    setState(() {
      _status = null;
      _dateFrom = null;
      _dateTo = null;
      _roomId = null;
      _search.clear();
      _page = 1;
    });
    _load();
  }

  Future<void> _updateStatus(Map<String, dynamic> item, String status) async {
    final isReject = status == 'DEPARTMENT_REJECTED';
    final controller = TextEditingController();
    final remark = await showDialog<String>(
      context: context,
      builder: (context) => MeetingPopup(
        title: MeetingPopupTitle(
          icon: isReject ? Icons.block_outlined : Icons.handyman_outlined,
          text: isReject ? 'เหตุผลที่เตรียมไม่ได้' : 'หมายเหตุการดำเนินการ',
        ),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: isReject ? 'เหตุผล *' : 'หมายเหตุ',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (isReject && controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (remark == null) return;
    setState(() => _working = true);
    try {
      await _repository.updateStatus(
        item['detailId'] as int,
        status,
        resultRemark: remark,
      );
      if (mounted) {
        setState(() => _message = 'บันทึกสถานะงานอุปกรณ์แล้ว');
        await _load();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = _error(error, 'บันทึกสถานะไม่สำเร็จ'));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _timeline(Map<String, dynamic> item) async {
    try {
      final result = await _repository.timeline(item['requestId'] as int);
      if (!mounted) return;
      final events = List<Map<String, dynamic>>.from(
        result['items'] as List? ?? const [],
      );
      await showDialog<void>(
        context: context,
        builder: (context) => MeetingPopup(
          scrollable: true,
          title: const MeetingPopupTitle(
            icon: Icons.history_outlined,
            text: 'ประวัติคำขออุปกรณ์',
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: events
                  .map(
                    (event) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.circle, size: 10),
                      title: Text(_eventLabel('${event['eventCode'] ?? '-'}')),
                      subtitle: Text(
                        '${event['actorName'] ?? '-'}${event['remark'] == null ? '' : '\n${event['remark']}'}',
                      ),
                      trailing: Text(_date(event['createDate'])),
                    ),
                  )
                  .toList(),
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
    } catch (error) {
      if (mounted) {
        setState(() => _message = _error(error, 'อ่านประวัติไม่สำเร็จ'));
      }
    }
  }

  String _error(Object error, String fallback) => error is ApiException
      ? '${error.message}${error.description == null ? '' : '\n${error.description}'}'
      : '$fallback\n$error';

  String _date(Object? value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _eventLabel(String code) => switch (code) {
    'SENT_TO_DEPARTMENT' => 'ส่งให้แผนก',
    'SUBMITTED_FOR_REVIEW' => 'ส่งตรวจสอบ',
    'REVIEW_APPROVED' => 'อนุมัติคำขอ',
    'IN_PROGRESS' => 'เริ่มเตรียมอุปกรณ์',
    'COMPLETED' => 'เตรียมเสร็จสิ้น',
    'DEPARTMENT_REJECTED' => 'แผนกปฏิเสธ',
    _ => code,
  };

  String _statusLabel(String value) => switch (value) {
    'PENDING' => 'รอดำเนินการ',
    'IN_PROGRESS' => 'กำลังเตรียม',
    'COMPLETED' => 'เสร็จสิ้น',
    'DEPARTMENT_REJECTED' => 'เตรียมไม่ได้',
    _ => value,
  };

  Widget _summaryCard(
    WorkspaceThemePreset preset,
    String label,
    String key,
    IconData icon,
  ) => Container(
    width: 210,
    constraints: const BoxConstraints(minWidth: 150),
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: LaooColors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      border: Border.all(color: LaooColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: preset.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Text(
              '${(_summary[key] as num?)?.toInt() ?? 0}',
              style: const TextStyle(
                fontSize: LaooTypography.sectionTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return buildMeetingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: MeetingRouteNames.roomSupportTasks,
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WorkspacePageTitle(
                        title: _caption,
                        favoriteKey: MeetingMenuCodes.roomSupportTasks,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'งานจะแสดงตามแผนกที่รับผิดชอบอุปกรณ์ของผู้ใช้งาน',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                Wrap(
                  spacing: LaooLayout.cardSpacing,
                  runSpacing: LaooLayout.cardSpacing,
                  children: [
                    _summaryCard(
                      preset,
                      'รอดำเนินการ',
                      'pending',
                      Icons.inbox_outlined,
                    ),
                    _summaryCard(
                      preset,
                      'กำลังเตรียม',
                      'inProgress',
                      Icons.handyman_outlined,
                    ),
                    _summaryCard(
                      preset,
                      'เสร็จวันนี้',
                      'completedToday',
                      Icons.task_alt_outlined,
                    ),
                    _summaryCard(
                      preset,
                      'เตรียมไม่ได้',
                      'rejected',
                      Icons.block_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                WorkspaceSectionCard(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            labelText: 'ค้นหาเลขที่จอง/อุปกรณ์',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) {
                            setState(() => _page = 1);
                            _load();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _status,
                          decoration: const InputDecoration(labelText: 'สถานะ'),
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('ทั้งหมด'),
                            ),
                            DropdownMenuItem(
                              value: 'PENDING',
                              child: Text('รอดำเนินการ'),
                            ),
                            DropdownMenuItem(
                              value: 'IN_PROGRESS',
                              child: Text('กำลังเตรียม'),
                            ),
                            DropdownMenuItem(
                              value: 'COMPLETED',
                              child: Text('เสร็จสิ้น'),
                            ),
                            DropdownMenuItem(
                              value: 'DEPARTMENT_REJECTED',
                              child: Text('เตรียมไม่ได้'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _status = value;
                              _page = 1;
                            });
                            _load();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<int?>(
                          initialValue: _roomId,
                          decoration: const InputDecoration(labelText: 'ห้อง'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('ทุกห้อง'),
                            ),
                            for (final room in _rooms)
                              DropdownMenuItem<int?>(
                                value: (room['roomId'] as num).toInt(),
                                child: Text(
                                  '${room['code'] ?? '-'} ${room['name'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _roomId = value;
                              _page = 1;
                            });
                            _load();
                          },
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(from: true),
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          _dateFrom == null ? 'จากวันที่' : _date(_dateFrom),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(from: false),
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          _dateTo == null ? 'ถึงวันที่' : _date(_dateTo),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() => _page = 1);
                          _load();
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('ค้นหา'),
                      ),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear),
                        label: const Text('ล้าง Filter'),
                      ),
                      IconButton(
                        tooltip: 'รีเฟรช',
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.refresh_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                Expanded(
                  child: WorkspaceSectionCard(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _items.isEmpty
                        ? const Center(child: Text('ไม่พบงานเตรียมอุปกรณ์'))
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: LaooLayout.cardSpacing),
                            itemBuilder: (_, index) =>
                                _taskCard(preset, _items[index]),
                          ),
                  ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                MeetingPaginationCard(
                  total: _total,
                  pageIndex: _page - 1,
                  pageSize: _pageSize,
                  primary: preset.primary,
                  onPrevious: _page > 1 && !_loading
                      ? () {
                          setState(() => _page--);
                          _load();
                        }
                      : null,
                  onNext: _page * _pageSize < _total && !_loading
                      ? () {
                          setState(() => _page++);
                          _load();
                        }
                      : null,
                ),
              ],
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
      ),
    );
  }

  Widget _taskCard(WorkspaceThemePreset preset, Map<String, dynamic> item) {
    final status = '${item['statusCode'] ?? ''}';
    final canStart = status == 'PENDING';
    final canComplete = status == 'IN_PROGRESS';
    final color = status == 'DEPARTMENT_REJECTED'
        ? Theme.of(context).colorScheme.error
        : preset.primary;
    return Container(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      decoration: BoxDecoration(
        color: LaooColors.white,
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        border: Border.all(color: LaooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['itemName'] ?? '-'} × ${item['quantity'] ?? 0} ${item['unitCode'] ?? ''}',
                  style: const TextStyle(
                    fontSize: LaooTypography.inputLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(
                label: Text(_statusLabel(status)),
                side: BorderSide(color: color),
                labelStyle: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            '${item['bookingNo'] ?? '-'} | ${item['roomCode'] ?? '-'} ${item['roomName'] ?? ''}',
          ),
          Text('${item['subject'] ?? '-'}'),
          Text(
            'วันเวลา: ${_date(item['startDateTime'])} - ${_date(item['endDateTime'])}',
          ),
          Text(
            'แผนก: ${item['departmentName'] ?? '-'} | ผู้ร้องขอ: ${item['requesterName'] ?? '-'}',
          ),
          if ('${item['remark'] ?? ''}'.isNotEmpty)
            Text('หมายเหตุ: ${item['remark']}'),
          if ('${item['resultRemark'] ?? ''}'.isNotEmpty)
            Text('ผลการดำเนินการ: ${item['resultRemark']}'),
          if ('${item['latestEventCode'] ?? ''}'.isNotEmpty)
            Text(
              'ความคืบหน้าล่าสุด: ${_eventLabel('${item['latestEventCode']}')} ${item['latestEventRemark'] == null ? '' : '· ${item['latestEventRemark']}'}',
            ),
          const Divider(color: LaooColors.border),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canStart)
                FilledButton.icon(
                  onPressed: _working
                      ? null
                      : () => _updateStatus(item, 'IN_PROGRESS'),
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('เริ่มเตรียม'),
                ),
              if (canComplete)
                FilledButton.icon(
                  onPressed: _working
                      ? null
                      : () => _updateStatus(item, 'COMPLETED'),
                  icon: const Icon(Icons.check_outlined),
                  label: const Text('เสร็จสิ้น'),
                ),
              if (canStart || canComplete)
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () => _updateStatus(item, 'DEPARTMENT_REJECTED'),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('เตรียมไม่ได้'),
                ),
              TextButton.icon(
                onPressed: _working ? null : () => _timeline(item),
                icon: const Icon(Icons.history_outlined),
                label: const Text('ดูประวัติ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
