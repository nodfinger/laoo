import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../data/meeting_equipment_request_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';
import '../widgets/meeting_popup.dart';

class MeetingEquipmentRequestPage extends StatefulWidget {
  const MeetingEquipmentRequestPage({super.key});
  @override
  State<MeetingEquipmentRequestPage> createState() =>
      _MeetingEquipmentRequestPageState();
}

class _MeetingEquipmentRequestPageState
    extends State<MeetingEquipmentRequestPage> {
  final _repository = MeetingEquipmentRequestRepository();
  String? _status;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.list(status: _status);
      if (mounted) {
        setState(
          () => _items = List<Map<String, dynamic>>.from(
            data['items'] as List? ?? const [],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'ไม่สามารถโหลดคำขออุปกรณ์เพิ่มเติมได้');
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
    } catch (_) {
      if (mounted) setState(() => _error = 'บันทึกผลการตรวจสอบไม่สำเร็จ');
    }
  }

  Future<void> _departmentStatus(
    Map<String, dynamic> item,
    String status,
  ) async {
    final reject = status == 'DEPARTMENT_REJECTED';
    final remark = await _remarkDialog(
      reject ? 'เหตุผลปฏิเสธจากแผนก *' : 'ผลการดำเนินการ',
      required: reject,
    );
    if (remark == null) return;
    try {
      await _repository.updateStatus(
        item['detailId'] as int,
        status,
        resultRemark: remark,
      );
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'อัปเดตสถานะงานไม่สำเร็จ');
    }
  }

  Future<void> _cancel(Map<String, dynamic> item) async {
    try {
      await _repository.cancel(item['detailId'] as int);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'ยกเลิกรายการไม่ได้');
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
    } catch (_) {
      if (mounted) setState(() => _error = 'ไม่สามารถอ่านประวัติคำขอได้');
    }
  }

  @override
  Widget build(BuildContext context) => buildMeetingWorkspaceShell(
    pageTitle: 'คำขออุปกรณ์เพิ่มเติม',
    activeMenu: MeetingRouteNames.equipmentRequests,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          child: Row(
            children: [
              SizedBox(
                width: 240,
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
                    setState(() => _status = value);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'รีเฟรช',
                onPressed: _load,
                icon: const Icon(Icons.refresh_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, index) => _card(_items[index]),
                ),
        ),
      ],
    ),
  );

  Widget _card(Map<String, dynamic> item) {
    final status = '${item['statusCode'] ?? ''}';
    return Card(
      elevation: 0,
      color: LaooColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        side: const BorderSide(color: LaooColors.border),
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
                if (status == 'PENDING' && item['canManageStatus'] == true) ...[
                  FilledButton(
                    onPressed: () => _departmentStatus(item, 'IN_PROGRESS'),
                    child: const Text('เริ่มดำเนินการ'),
                  ),
                  FilledButton(
                    onPressed: () => _departmentStatus(item, 'COMPLETED'),
                    child: const Text('เสร็จสิ้น'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        _departmentStatus(item, 'DEPARTMENT_REJECTED'),
                    child: const Text('แผนกปฏิเสธ'),
                  ),
                ],
                if (status == 'IN_PROGRESS' && item['canManageStatus'] == true)
                  FilledButton(
                    onPressed: () => _departmentStatus(item, 'COMPLETED'),
                    child: const Text('เสร็จสิ้น'),
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
