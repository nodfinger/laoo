import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../data/meeting_equipment_request_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';
import '../widgets/meeting_popup.dart';
import '../widgets/meeting_pagination_card.dart';

class MeetingEquipmentRequestPage extends StatefulWidget {
  const MeetingEquipmentRequestPage({super.key});
  @override
  State<MeetingEquipmentRequestPage> createState() =>
      _MeetingEquipmentRequestPageState();
}

class _MeetingEquipmentRequestPageState
    extends State<MeetingEquipmentRequestPage> {
  final _repository = MeetingEquipmentRequestRepository();
  String _caption = 'คำขออุปกรณ์เพิ่มเติม';
  bool _canOpenSupportTasks = false;
  String? _status;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  int _page = 1;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadCaption();
    _load();
  }

  Future<void> _loadCaption() async {
    final caption = await NavigationMenuRepository().resolveMenuName(
      menuCode: MeetingMenuCodes.equipmentRequests,
      routeName: MeetingRouteNames.equipmentRequests,
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = caption);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.list(status: _status);
      if (mounted) {
        _canOpenSupportTasks = data['canOpenSupportTasks'] == true;
        setState(() {
          _items = List<Map<String, dynamic>>.from(
            data['items'] as List? ?? const [],
          );
          final pages = (_items.length / _pageSize).ceil();
          if (_page > pages) _page = pages < 1 ? 1 : pages;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _errorText(
            error,
            'ไม่สามารถโหลดคำขออุปกรณ์เพิ่มเติมได้',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(
    Map<String, dynamic> item,
    String action, {
    bool all = false,
  }) async {
    final remark = await _remarkDialog(
      action == 'REJECT' ? 'เหตุผลไม่อนุมัติ *' : 'หมายเหตุการอนุมัติ',
      required: action == 'REJECT',
    );
    if (remark == null) return;
    try {
      await _repository.review(
        item['requestId'] as int,
        action,
        remark: remark,
        detailIds: all ? null : [item['detailId'] as int],
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _errorText(error, 'บันทึกผลการตรวจสอบไม่สำเร็จ'),
        );
      }
    }
  }

  Future<void> _cancel(Map<String, dynamic> item) async {
    try {
      await _repository.cancel(item['detailId'] as int);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _errorText(error, 'ยกเลิกรายการไม่ได้'));
      }
    }
  }

  Future<String?> _remarkDialog(String label, {required bool required}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => MeetingPopup(
        title: MeetingPopupTitle(icon: Icons.fact_check_outlined, text: label),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(labelText: label),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (required && controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _timeline(Map<String, dynamic> item) async {
    try {
      final data = await _repository.timeline(item['requestId'] as int);
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
                      title: Text(_statusLabel('${event['eventCode'] ?? '-'}')),
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
        setState(
          () => _error = _errorText(error, 'ไม่สามารถอ่านประวัติคำขอได้'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => buildMeetingWorkspaceShell(
    pageTitle: _caption,
    activeMenu: MeetingRouteNames.equipmentRequests,
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
                  favoriteKey: MeetingMenuCodes.equipmentRequests,
                ),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              WorkspaceSectionCard(
                child: LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    width: constraints.maxWidth < 280
                        ? constraints.maxWidth
                        : 280,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'สถานะ'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                        DropdownMenuItem(
                          value: 'WAITING_REVIEW',
                          child: Text('รอตรวจสอบ'),
                        ),
                        DropdownMenuItem(
                          value: 'PENDING',
                          child: Text('รอดำเนินการ'),
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
                          value: 'REVIEW_REJECTED',
                          child: Text('ไม่อนุมัติ'),
                        ),
                        DropdownMenuItem(
                          value: 'DEPARTMENT_REJECTED',
                          child: Text('แผนกปฏิเสธ'),
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
                ),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              Expanded(
                child: _loading
                    ? const WorkspaceSectionCard(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _items.isEmpty
                    ? const WorkspaceSectionCard(
                        child: Center(child: Text('ไม่พบคำขออุปกรณ์เพิ่มเติม')),
                      )
                    : ListView.separated(
                        itemCount: _items
                            .skip((_page - 1) * _pageSize)
                            .take(_pageSize)
                            .length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: LaooLayout.listItemSpacing),
                        itemBuilder: (_, index) =>
                            _card(_items[(_page - 1) * _pageSize + index]),
                      ),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              MeetingPaginationCard(
                total: _items.length,
                pageIndex: _page - 1,
                pageSize: _pageSize,
                primary: Theme.of(context).colorScheme.primary,
                onPrevious: _page > 1 ? () => setState(() => _page--) : null,
                onNext: _page * _pageSize < _items.length
                    ? () => setState(() => _page++)
                    : null,
              ),
            ],
          ),
          if (_error != null)
            Positioned(
              top: 12,
              right: 12,
              child: AutoDismissMessage(
                message: _error!,
                error: true,
                onClose: () => setState(() => _error = null),
              ),
            ),
        ],
      ),
    ),
  );

  String _errorText(Object error, String fallback) => error is ApiException
      ? '${error.message}\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาโหลดข้อมูลล่าสุดแล้วลองอีกครั้ง'}'
      : '$fallback\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง';

  Widget _card(Map<String, dynamic> item) {
    final status = '${item['statusCode'] ?? ''}';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: LaooColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['itemName'] ?? '-'} × ${item['quantity'] ?? 0} ${item['unitName'] ?? ''}',
                    style: const TextStyle(
                      fontSize: LaooTypography.inputLabel,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item['bookingNo'] ?? '-'} | ${item['roomCode'] ?? '-'} ${item['roomName'] ?? ''}',
            ),
            Text(
              '${item['subject'] ?? '-'}',
              style: const TextStyle(color: LaooColors.textSecondary),
            ),
            Text(
              'ผู้ขอ: ${item['requesterName'] ?? '-'} | ${_roleLabel('${item['requesterRoleCode'] ?? ''}')}',
            ),
            Text('แผนกรับผิดชอบ: ${item['departmentName'] ?? '-'}'),
            if (item['remark'] != null && '${item['remark']}'.isNotEmpty)
              Text('หมายเหตุ: ${item['remark']}'),
            if (item['reviewRemark'] != null)
              Text('ผลตรวจสอบ: ${item['reviewRemark']}'),
            if (item['resultRemark'] != null)
              Text('ผลแผนก: ${item['resultRemark']}'),
            const Divider(color: LaooColors.border),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _timeline(item),
                  icon: const Icon(Icons.history_outlined),
                  label: const Text('ประวัติ'),
                ),
                if (status == 'WAITING_REVIEW' &&
                    item['canManageBooking'] == true) ...[
                  FilledButton.icon(
                    onPressed: () => _review(item, 'APPROVE'),
                    icon: const Icon(Icons.check_outlined),
                    label: const Text('อนุมัติรายการ'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _review(item, 'REJECT'),
                    icon: const Icon(Icons.close_outlined),
                    label: const Text('ไม่อนุมัติ'),
                  ),
                  TextButton(
                    onPressed: () => _review(item, 'APPROVE', all: true),
                    child: const Text('อนุมัติทั้งคำขอ'),
                  ),
                ],
                if (item['canCancel'] == true)
                  TextButton(
                    onPressed: () => _cancel(item),
                    child: const Text('ยกเลิกรายการ'),
                  ),
                if (_canOpenSupportTasks &&
                    const [
                      'PENDING',
                      'IN_PROGRESS',
                      'COMPLETED',
                      'DEPARTMENT_REJECTED',
                    ].contains(status))
                  TextButton.icon(
                    onPressed: () =>
                        context.go(MeetingRoutePaths.roomSupportTasks),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('ไปหน้างานเตรียมอุปกรณ์'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) => Chip(label: Text(_statusLabel(status)));
  String _statusLabel(String value) => switch (value) {
    'WAITING_REVIEW' => 'รอตรวจสอบ',
    'REVIEW_REJECTED' => 'ไม่อนุมัติ',
    'PENDING' => 'รอดำเนินการ',
    'IN_PROGRESS' => 'กำลังดำเนินการ',
    'COMPLETED' => 'เสร็จสิ้น',
    'DEPARTMENT_REJECTED' => 'แผนกปฏิเสธ',
    'CANCELLED' => 'ยกเลิก',
    'REQUEST_CREATED' => 'สร้างคำขอ',
    'SUBMITTED_FOR_REVIEW' => 'ส่งตรวจสอบ',
    'SENT_TO_DEPARTMENT' => 'ส่งแผนก',
    'RETURNED_FOR_REVIEW' => 'ส่งกลับเข้าคิวตรวจสอบ',
    'REVIEW_APPROVED' => 'อนุมัติแล้ว',
    _ => value,
  };
  String _roleLabel(String value) => switch (value) {
    'COMPANY_ADMIN' => 'Admin Company',
    'ROOM_ADMIN' => 'Admin ห้อง',
    'MEETING_OWNER' => 'เจ้าของประชุม',
    'INVITEE' => 'ผู้ถูกเชิญ',
    _ => '-',
  };
  String _date(Object? value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
