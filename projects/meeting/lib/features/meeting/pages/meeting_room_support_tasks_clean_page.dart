import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_equipment_request_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';
import '../widgets/meeting_pagination_card.dart';
import '../widgets/meeting_popup.dart';

class MeetingRoomSupportTasksCleanPage extends StatefulWidget {
  const MeetingRoomSupportTasksCleanPage({super.key});

  @override
  State<MeetingRoomSupportTasksCleanPage> createState() =>
      _MeetingRoomSupportTasksCleanPageState();
}

class _MeetingRoomSupportTasksCleanPageState
    extends State<MeetingRoomSupportTasksCleanPage> {
  final _repository = MeetingEquipmentRequestRepository();
  final _search = TextEditingController();
  String _caption = 'งานเตรียมห้องและอุปกรณ์';
  String? _status;
  String? _message;
  bool _loading = true;
  bool _working = false;
  bool _messageError = false;
  int _page = 1;
  int _total = 0;
  static const _pageSize = 20;
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _summary = const {};

  @override
  void initState() {
    super.initState();
    _loadCaption();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCaption() async {
    final caption = await NavigationMenuRepository().resolveMenuName(
      menuCode: MeetingMenuCodes.roomSupportTasks,
      routeName: MeetingRouteNames.roomSupportTasks,
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = caption);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repository.departmentTasks(
        status: _status,
        search: _search.text,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          data['items'] as List? ?? const [],
        );
        _summary = Map<String, dynamic>.from(
          data['summary'] as Map? ?? const {},
        );
        _total = (data['total'] as num?)?.toInt() ?? _items.length;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _messageError = true;
          _message = _error(error);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> item, String next) async {
    String? remark;
    if (next == 'DEPARTMENT_REJECTED') {
      final controller = TextEditingController();
      remark = await showDialog<String>(
        context: context,
        builder: (context) => MeetingPopup(
          title: const MeetingPopupTitle(
            icon: Icons.info_outline,
            text: 'ระบุเหตุผลที่ไม่สามารถเตรียมได้',
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'เหตุผล *'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (remark == null) return;
    }
    setState(() => _working = true);
    try {
      await _repository.updateStatus(
        item['detailId'] as int,
        next,
        resultRemark: remark,
      );
      if (mounted) {
        setState(() {
          _messageError = false;
          _message = 'บันทึกสถานะงานเรียบร้อย';
        });
        await _load();
      }
    } catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _timeline(Map<String, dynamic> item) async {
    try {
      final data = await _repository.timeline(
        item['requestId'] as int,
        detailId: item['detailId'] as int,
      );
      if (!mounted) return;
      final events = List<Map<String, dynamic>>.from(
        data['items'] as List? ?? const [],
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
                      leading: Icon(
                        Icons.circle,
                        size: 10,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(_eventText('${event['eventCode'] ?? '-'}')),
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
        setState(() {
          _messageError = true;
          _message = _error(error);
        });
      }
    }
  }

  String _eventText(String event) => switch (event) {
    'REQUEST_CREATED' => 'สร้างคำขอ',
    'SUBMITTED_FOR_REVIEW' => 'ส่งตรวจสอบ',
    'SENT_TO_DEPARTMENT' => 'ส่งงานให้แผนก',
    'REVIEW_APPROVED' => 'อนุมัติคำขอ',
    'REVIEW_REJECTED' => 'ไม่อนุมัติ',
    'CANCELLED' => 'ยกเลิก',
    _ => _statusText(event),
  };

  String _error(Object error) => error is ApiException
      ? '${error.message}\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาโหลดข้อมูลล่าสุดแล้วลองอีกครั้ง'}'
      : 'ไม่สามารถดำเนินการงานเตรียมอุปกรณ์ได้\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง';

  String _statusText(String status) => switch (status) {
    'PENDING' => 'รอดำเนินการ',
    'IN_PROGRESS' => 'กำลังเตรียม',
    'COMPLETED' => 'เสร็จสิ้น',
    'DEPARTMENT_REJECTED' => 'ไม่สามารถเตรียมได้',
    _ => status,
  };

  String _date(Object? value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  int _count(String key) => (_summary[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) => buildMeetingWorkspaceShell(
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
                child: WorkspacePageTitle(
                  title: _caption,
                  favoriteKey: MeetingMenuCodes.roomSupportTasks,
                ),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              Wrap(
                spacing: LaooLayout.listSectionSpacing,
                runSpacing: LaooLayout.listSectionSpacing,
                children: [
                  _summaryCard(
                    'รอดำเนินการ',
                    _count('pending'),
                    Icons.pending_actions_outlined,
                  ),
                  _summaryCard(
                    'กำลังเตรียม',
                    _count('inProgress'),
                    Icons.handyman_outlined,
                  ),
                  _summaryCard(
                    'เสร็จวันนี้',
                    _count('completedToday'),
                    Icons.task_alt_outlined,
                  ),
                  _summaryCard(
                    'เตรียมไม่ได้',
                    _count('rejected'),
                    Icons.block_outlined,
                  ),
                ],
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              WorkspaceSectionCard(child: _filters()),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              Expanded(
                child: WorkspaceSectionCard(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                      ? const Center(
                          child: Text('ไม่พบงานเตรียมห้องและอุปกรณ์'),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, index) => _taskCard(_items[index]),
                        ),
                ),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              MeetingPaginationCard(
                total: _total,
                pageIndex: _page - 1,
                pageSize: _pageSize,
                primary: Theme.of(context).colorScheme.primary,
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
                error: _messageError,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _summaryCard(String label, int value, IconData icon) => SizedBox(
    width: 210,
    child: WorkspaceSectionCard(
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$value', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _filters() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      SizedBox(
        width: 280,
        child: TextField(
          controller: _search,
          onSubmitted: (_) {
            setState(() => _page = 1);
            _load();
          },
          decoration: const InputDecoration(
            labelText: 'ค้นหาเลขที่จอง / หัวข้อ / อุปกรณ์',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      SizedBox(
        width: 190,
        child: DropdownButtonFormField<String?>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'สถานะ'),
          items: const [
            DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
            DropdownMenuItem(value: 'PENDING', child: Text('รอดำเนินการ')),
            DropdownMenuItem(value: 'IN_PROGRESS', child: Text('กำลังเตรียม')),
            DropdownMenuItem(value: 'COMPLETED', child: Text('เสร็จสิ้น')),
            DropdownMenuItem(
              value: 'DEPARTMENT_REJECTED',
              child: Text('ไม่สามารถเตรียมได้'),
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
      FilledButton.icon(
        onPressed: () {
          setState(() => _page = 1);
          _load();
        },
        icon: const Icon(Icons.search),
        label: const Text('ค้นหา'),
      ),
      OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _status = null;
            _page = 1;
            _search.clear();
          });
          _load();
        },
        icon: const Icon(Icons.clear),
        label: const Text('ล้าง Filter'),
      ),
    ],
  );

  Widget _taskCard(Map<String, dynamic> item) {
    final status = '${item['statusCode'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['itemName'] ?? '-'}  •  ${item['quantity'] ?? 0} ${item['unitCode'] ?? ''}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Chip(label: Text(_statusText(status))),
            ],
          ),
          Text('${item['bookingNo'] ?? '-'} | ${item['subject'] ?? '-'}'),
          Text(
            '${item['roomCode'] ?? '-'} ${item['roomName'] ?? ''} | ${_date(item['startDateTime'])} - ${_date(item['endDateTime'])}',
          ),
          Text(
            'แผนก: ${item['departmentName'] ?? '-'} | ผู้ร้องขอ: ${item['requesterName'] ?? '-'}',
          ),
          if ('${item['remark'] ?? ''}'.isNotEmpty)
            Text('หมายเหตุ: ${item['remark']}'),
          if ('${item['resultRemark'] ?? ''}'.isNotEmpty)
            Text('ผลการดำเนินการ: ${item['resultRemark']}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _timeline(item),
                icon: const Icon(Icons.history),
                label: const Text('ดูประวัติ'),
              ),
              if (item['canManageStatus'] == true && status == 'PENDING')
                FilledButton(
                  onPressed: _working
                      ? null
                      : () => _changeStatus(item, 'IN_PROGRESS'),
                  child: const Text('เริ่มเตรียม'),
                ),
              if (item['canManageStatus'] == true && status == 'IN_PROGRESS')
                FilledButton(
                  onPressed: _working
                      ? null
                      : () => _changeStatus(item, 'COMPLETED'),
                  child: const Text('เสร็จสิ้น'),
                ),
              if (item['canManageStatus'] == true &&
                  (status == 'PENDING' || status == 'IN_PROGRESS'))
                OutlinedButton(
                  onPressed: _working
                      ? null
                      : () => _changeStatus(item, 'DEPARTMENT_REJECTED'),
                  child: const Text('ไม่สามารถเตรียมได้'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
