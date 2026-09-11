import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/widgets/combo_box_text.dart';
import '../data/meeting_room_booking_repository.dart';
import 'meeting_popup.dart';

Future<bool> showMeetingParticipantDialog(
  BuildContext context, {
  required MeetingRoomBookingRepository repository,
  required int bookingId,
}) async {
  final preset = workspaceThemeController.value;
  final data = await repository.participants(bookingId);
  if (!context.mounted) return false;
  final employees = _maps(data['employees']);
  final selected = employees
      .where((item) => item['selected'] == true)
      .map((item) => _int(item['employeeId']))
      .whereType<int>()
      .toSet();
  final searchController = TextEditingController();
  var keyword = '';
  int? departmentId;
  final departments = <int, String>{};
  for (final employee in employees) {
    final id = _int(employee['departmentOrgUnitId']);
    final name = '${employee['departmentName'] ?? ''}'.trim();
    if (id != null && name.isNotEmpty) {
      departments[id] = name;
    }
  }
  final departmentItems = departments.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  final screen = MediaQuery.sizeOf(context);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) {
        final filtered = employees.where((employee) {
          if (departmentId != null &&
              _int(employee['departmentOrgUnitId']) != departmentId) {
            return false;
          }
          final text =
              '${employee['employeeCode'] ?? ''} ${employee['employeeName'] ?? ''} ${employee['nickName'] ?? ''} ${employee['departmentName'] ?? ''}'
                  .toLowerCase();
          return keyword.isEmpty || text.contains(keyword);
        }).toList();
        return MeetingPopup(
          title: Row(
            children: [
              Icon(Icons.group_add_outlined, color: preset.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'เชิญผู้เข้าร่วมประชุม',
                  style: LaooTypography.popupTitleStyle,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: screen.width < 720 ? screen.width - 64 : 650,
            height: screen.height < 680 ? screen.height - 190 : 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(LaooLayout.cardPadding),
                  color: preset.primary.withValues(alpha: .08),
                  child: Text(
                    '${data['bookingNo'] ?? '-'} | ${data['roomCode'] ?? '-'} ${data['roomName'] ?? '-'}\n${_bookingDateTime(data)}',
                    style: TextStyle(
                      color: preset.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fieldBorder = OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                      borderSide: const BorderSide(color: LaooColors.border),
                    );
                    final focusedFieldBorder = fieldBorder.copyWith(
                      borderSide: BorderSide(color: preset.primary),
                    );
                    final search = TextField(
                      controller: searchController,
                      onChanged: (value) =>
                          refresh(() => keyword = value.trim().toLowerCase()),
                      decoration: InputDecoration(
                        labelText: 'ค้นหารหัสหรือชื่อพนักงาน',
                        prefixIcon: const Icon(Icons.search),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: focusedFieldBorder,
                        floatingLabelStyle: TextStyle(color: preset.primary),
                      ),
                    );
                    final department = DropdownButtonFormField<int?>(
                      initialValue: departmentId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'แผนก',
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: focusedFieldBorder,
                        floatingLabelStyle: TextStyle(color: preset.primary),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: LaooComboBoxText('ทั้งหมด'),
                        ),
                        ...departmentItems.map(
                          (entry) => DropdownMenuItem<int?>(
                            value: entry.key,
                            child: LaooComboBoxText(entry.value),
                          ),
                        ),
                      ],
                      onChanged: (value) => refresh(() => departmentId = value),
                    );
                    return constraints.maxWidth < 520
                        ? Column(
                            children: [
                              search,
                              const SizedBox(height: 8),
                              department,
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(flex: 3, child: search),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: department),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 8),
                Text('เลือกแล้ว ${selected.length} คน'),
                const Divider(color: LaooColors.border),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('ไม่พบพนักงาน'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: LaooColors.border,
                          ),
                          itemBuilder: (_, index) {
                            final employee = filtered[index];
                            final employeeId = _int(employee['employeeId']);
                            final invitationStatus =
                                '${employee['invitationStatus'] ?? ''}';
                            final details = <String>[
                              if (employee['selected'] == true &&
                                  invitationStatus.isNotEmpty)
                                'สถานะ: ${_invitationStatusName(employee)}',
                              if (employee['isLateResponse'] == true &&
                                  '${employee['lateResponseReason'] ?? ''}'
                                      .trim()
                                      .isNotEmpty)
                                'เหตุผล: ${employee['lateResponseReason']}',
                              if ('${employee['nickName'] ?? ''}'.isNotEmpty)
                                'ชื่อเล่น: ${employee['nickName']}',
                              if ('${employee['departmentName'] ?? ''}'
                                  .isNotEmpty)
                                'แผนก: ${employee['departmentName']}',
                            ];
                            return CheckboxListTile(
                              value:
                                  employeeId != null &&
                                  selected.contains(employeeId),
                              activeColor: preset.primary,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                '${employee['employeeCode'] ?? '-'} | ${employee['employeeName'] ?? '-'}',
                              ),
                              subtitle: details.isEmpty
                                  ? null
                                  : Text(details.join(' | ')),
                              onChanged: employeeId == null
                                  ? null
                                  : (value) => refresh(() {
                                      if (value == true) {
                                        selected.add(employeeId);
                                      } else {
                                        selected.remove(employeeId);
                                      }
                                    }),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: preset.primary,
                minimumSize: const Size(0, LaooTypography.buttonHeight),
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: preset.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                minimumSize: const Size(0, LaooTypography.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.send_outlined),
              label: const Text('บันทึกคำเชิญ'),
            ),
          ],
        );
      },
    ),
  );
  searchController.dispose();
  if (saved != true) return false;
  await repository.saveParticipants(bookingId, selected.toList()..sort());
  return true;
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList()
    : const [];

int? _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

String _bookingDateTime(Map<String, dynamic> item) {
  final start = DateTime.tryParse('${item['startDateTime'] ?? ''}');
  final end = DateTime.tryParse('${item['endDateTime'] ?? ''}');
  if (start == null || end == null) return '-';
  final slots = _int(item['slotCount']) ?? 1;
  final startDate = '${_two(start.day)}/${_two(start.month)}/${start.year}';
  final endDate = '${_two(end.day)}/${_two(end.month)}/${end.year}';
  final time =
      '${_two(start.hour)}:${_two(start.minute)}-${_two(end.hour)}:${_two(end.minute)}';
  return slots > 1 ? '$startDate - $endDate | $time' : '$startDate | $time';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _invitationStatusName(Map<String, dynamic> employee) {
  if (employee['isLateResponse'] == true) return 'ตอบรับภายหลัง';
  return switch ('${employee['invitationStatus'] ?? ''}') {
    'ACCEPTED' => 'เข้าร่วม',
    'DECLINED' => 'ไม่เข้าร่วม',
    _ => 'รอตอบรับ',
  };
}
