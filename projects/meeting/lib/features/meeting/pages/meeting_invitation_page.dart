import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/config/api_config.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_equipment_request_repository.dart';
import '../data/meeting_invitation_repository.dart';
import '../meeting_feature_host.dart';
import '../widgets/meeting_attendance_panel.dart';
import '../widgets/meeting_pagination_card.dart';
import '../widgets/meeting_popup.dart';

class MeetingInvitationPage extends StatefulWidget {
  const MeetingInvitationPage({super.key});
  @override
  State<MeetingInvitationPage> createState() => _MeetingInvitationPageState();
}

class _MeetingInvitationPageState extends State<MeetingInvitationPage> {
  final _repository = MeetingInvitationRepository();
  final _equipmentRequests = MeetingEquipmentRequestRepository();
  final _search = TextEditingController();
  final _remark = TextEditingController();
  final _changeReason = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<int, int> _foodQuantities = {};
  Map<int, String> _answerValues = {};
  Map<int, Set<int>> _answerOptions = {};
  Map<String, dynamic>? _detail;
  String? _filterStatus;
  String _responseStatus = 'PENDING';
  String _caption = '';
  String? _message;
  bool _messageError = false;
  bool _loading = true;
  bool _saving = false;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadCaption();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _remark.dispose();
    _changeReason.dispose();
    super.dispose();
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: '21003',
      routeName: 'meetingInvitationRsvp',
      fallback: 'การเชิญของฉัน',
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _repository.list(
        search: _search.text,
        status: _filterStatus,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          result['items'] as List? ?? const [],
        );
        _total = (result['total'] as num?)?.toInt() ?? 0;
      });
    } catch (error) {
      _notify(_error(error, 'โหลดคำเชิญไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    setState(() => _loading = true);
    try {
      final detail = await _repository.get(
        (item['participantId'] as num).toInt(),
      );
      final invitation = Map<String, dynamic>.from(detail['invitation'] as Map);
      Map<String, dynamic>? trainingTests;
      if (invitation['activityTypeCode'] == 'TRAINING' &&
          invitation['invitationStatus'] == 'ACCEPTED') {
        try {
          trainingTests = await _repository.trainingTestOverview(
            (invitation['bookingId'] as num).toInt(),
          );
        } catch (_) {
          // The invitation remains available if a training setup is not ready.
        }
      }
      if (!mounted) return;
      setState(() {
        _detail = {...detail, 'trainingTests': trainingTests};
        _responseStatus = '${invitation['invitationStatus'] ?? 'PENDING'}';
        _remark.text = '${invitation['remark'] ?? ''}';
        _changeReason.clear();
        _foodQuantities = {
          for (final food in List<Map<String, dynamic>>.from(
            detail['foods'] as List? ?? const [],
          ))
            (food['foodId'] as num).toInt():
                (food['orderQuantity'] as num?)?.toInt() ?? 0,
        };
        _answerValues = {};
        _answerOptions = {};
        for (final question in List<Map<String, dynamic>>.from(
          detail['questions'] as List? ?? const [],
        )) {
          final id = (question['questionId'] as num).toInt();
          final value = '${question['answerValue'] ?? ''}';
          final type = '${question['answerType']}';
          if ((type == 'SINGLE' || type == 'MULTIPLE') && value.isNotEmpty) {
            try {
              _answerOptions[id] = (jsonDecode(value) as List)
                  .map((item) => (item as num).toInt())
                  .toSet();
            } catch (_) {
              _answerOptions[id] = {};
            }
          } else {
            _answerValues[id] = value;
          }
        }
      });
    } catch (error) {
      _notify(_error(error, 'เปิดคำเชิญไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final detail = _detail;
    if (detail == null) return;
    final invitation = Map<String, dynamic>.from(detail['invitation'] as Map);
    final groups = List<Map<String, dynamic>>.from(
      detail['groups'] as List? ?? const [],
    );
    final questions = List<Map<String, dynamic>>.from(
      detail['questions'] as List? ?? const [],
    );
    final lateResponseMode = invitation['lateResponseMode'] == true;
    final lateAcceptanceOnly = invitation['lateAcceptanceOnly'] == true;
    if (lateAcceptanceOnly && _responseStatus != 'ACCEPTED') {
      _notify('หลังเริ่มประชุมสามารถเลือกได้เฉพาะ เข้าร่วม', true);
      return;
    }
    if (invitation['requiresChangeReason'] == true &&
        _changeReason.text.trim().isEmpty) {
      _notify('กรุณาระบุเหตุผลการตอบรับ', true);
      return;
    }
    if (_responseStatus == 'ACCEPTED' && !lateResponseMode) {
      for (final group in groups) {
        final type = '${group['foodTypeCode']}';
        final foods = List<Map<String, dynamic>>.from(
          detail['foods'] as List? ?? const [],
        ).where((food) => '${food['foodTypeCode']}' == type);
        final total = foods.fold<int>(
          0,
          (sum, food) =>
              sum + (_foodQuantities[(food['foodId'] as num).toInt()] ?? 0),
        );
        final max = (group['maxQuantity'] as num).toInt();
        if (total > max || (group['isRequired'] == true && total == 0)) {
          _notify(
            total > max
                ? 'กลุ่ม ${group['foodTypeName']} เลือกได้รวมไม่เกิน $max'
                : 'กรุณาเลือกอาหารในกลุ่ม ${group['foodTypeName']}',
            true,
          );
          return;
        }
      }
      for (final question in questions.where(
        (question) => question['isRequired'] == true,
      )) {
        final id = (question['questionId'] as num).toInt();
        final type = '${question['answerType']}';
        final answered = type == 'SINGLE' || type == 'MULTIPLE'
            ? (_answerOptions[id]?.isNotEmpty ?? false)
            : (_answerValues[id]?.trim().isNotEmpty ?? false);
        if (!answered) {
          _notify('กรุณาตอบ: ${question['questionText']}', true);
          return;
        }
      }
    }
    setState(() => _saving = true);
    try {
      await _repository.respond(
        (invitation['participantId'] as num).toInt(),
        status: _responseStatus,
        remark: _remark.text.trim(),
        changeReason: _changeReason.text.trim(),
        quantities: _responseStatus == 'ACCEPTED' && !lateResponseMode
            ? _foodQuantities
            : const {},
        answers: _responseStatus == 'ACCEPTED' && !lateResponseMode
            ? questions.map((question) {
                final id = (question['questionId'] as num).toInt();
                final type = '${question['answerType']}';
                return {
                  'questionId': id,
                  'value': type == 'SINGLE' || type == 'MULTIPLE'
                      ? null
                      : _answerValues[id],
                  'optionIds': (_answerOptions[id] ?? {}).toList()..sort(),
                };
              }).toList()
            : const [],
      );
      if (!mounted) return;
      if (lateResponseMode && _responseStatus == 'ACCEPTED') {
        await _open({'participantId': invitation['participantId']});
        _notify('บันทึกการตอบรับภายหลังสำเร็จ สามารถเช็กอินได้แล้ว');
      } else {
        setState(() => _detail = null);
        _notify('บันทึกการตอบรับสำเร็จ');
        await _load();
      }
    } catch (error) {
      _notify(_error(error, 'บันทึกการตอบรับไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showEquipmentRequest(Map<String, dynamic> invitation) async {
    final bookingId = invitation['bookingId'] as num?;
    if (bookingId == null) return;
    try {
      final detail = await _equipmentRequests.booking(bookingId.toInt());
      if (!mounted) return;
      final items = List<Map<String, dynamic>>.from(
        detail['items'] as List? ?? const [],
      );
      final selected = <int, Map<String, TextEditingController>>{};
      final primary = workspaceThemeController.value.primary;
      final screen = MediaQuery.sizeOf(context);
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, refresh) {
            final border = OutlineInputBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
              borderSide: const BorderSide(color: LaooColors.border),
            );
            return MeetingPopup(
              title: const MeetingPopupTitle(
                icon: Icons.handyman_outlined,
                text: 'ขออุปกรณ์เพิ่มเติม',
              ),
              content: SizedBox(
                width: screen.width < 540 ? screen.width - 64 : 460,
                height: screen.height < 720 ? screen.height - 190 : 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      color: primary.withValues(alpha: .08),
                      child: Text(
                        '${detail['bookingNo'] ?? '-'} | ${detail['subject'] ?? '-'}\n'
                        '${detail['roomCode'] ?? '-'} | ${detail['roomName'] ?? '-'}\n'
                        '${_meetingPeriod(invitation)}',
                        style: TextStyle(
                          color: primary,
                          fontSize: LaooTypography.inputText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('ปิดรับ: ${_date(detail['cutoff'])}'),
                    if (detail['canRequest'] != true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _equipmentRequestState(detail['requestState']),
                          style: const TextStyle(color: LaooColors.error),
                        ),
                      ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: LaooColors.border),
                    const SizedBox(height: 8),
                    const Text(
                      'เลือกอุปกรณ์และระบุจำนวน',
                      style: TextStyle(
                        color: LaooColors.pageCaption,
                        fontSize: LaooTypography.sectionTitle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: LaooColors.border),
                        itemBuilder: (_, index) {
                          final equipment = items[index];
                          final id = (equipment['itemId'] as num?)?.toInt();
                          if (id == null) return const SizedBox.shrink();
                          final line = selected[id];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: line != null,
                                      activeColor: primary,
                                      onChanged: detail['canRequest'] != true
                                          ? null
                                          : (checked) => refresh(() {
                                              if (checked == true) {
                                                selected[id] = {
                                                  'quantity':
                                                      TextEditingController(
                                                        text: '1',
                                                      ),
                                                  'remark':
                                                      TextEditingController(),
                                                };
                                              } else {
                                                selected.remove(id);
                                              }
                                            }),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('${equipment['name'] ?? '-'}'),
                                          Text(
                                            'แผนก: ${equipment['departmentName'] ?? '-'}',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontSize:
                                                  LaooTypography.inputHint,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (line != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 48,
                                      top: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 96,
                                          child: TextField(
                                            controller: line['quantity'],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'จำนวน',
                                              isDense: true,
                                              border: border,
                                              enabledBorder: border,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: line['remark'],
                                            decoration: InputDecoration(
                                              labelText: 'หมายเหตุ',
                                              isDense: true,
                                              border: border,
                                              enabledBorder: border,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if ((detail['requests'] as List? ?? const []).isNotEmpty)
                      SizedBox(
                        height: 140,
                        child: ListView(
                          children: [
                            for (final request in detail['requests'] as List)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${request['itemName']} × ${request['quantity']} — ${request['statusCode']}\n"
                                    "ผู้ขอ: ${request['requesterName'] ?? '-'}\n"
                                    "หมายเหตุ: ${request['remark'] ?? '-'}",
                                  ),
                                  if (request['canCancel'] == true)
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          await _equipmentRequests.cancel(
                                            (request['detailId'] as num)
                                                .toInt(),
                                          );
                                          if (dialogContext.mounted) {
                                            refresh(() {
                                              request['statusCode'] =
                                                  'CANCELLED';
                                              request['canCancel'] = false;
                                            });
                                          }
                                          _notify(
                                            'ยกเลิกคำขอแล้ว สามารถเลือกและส่งคำขอใหม่ได้',
                                          );
                                        } catch (error) {
                                          _notify(
                                            _error(
                                              error,
                                              'ยกเลิกคำขอไม่สำเร็จ',
                                            ),
                                            true,
                                          );
                                        }
                                      },
                                      child: const Text('ยกเลิกคำขอนี้'),
                                    ),
                                  const Divider(color: LaooColors.border),
                                ],
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: primary,
                    minimumSize: const Size(80, LaooTypography.buttonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(100, LaooTypography.buttonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                  ),
                  onPressed: detail['canRequest'] != true || selected.isEmpty
                      ? null
                      : () async {
                          try {
                            await _equipmentRequests.save(
                              bookingId.toInt(),
                              selected.entries
                                  .map(
                                    (entry) => {
                                      'itemId': entry.key,
                                      'quantity':
                                          num.tryParse(
                                            entry.value['quantity']!.text,
                                          ) ??
                                          0,
                                      'remark': entry.value['remark']!.text
                                          .trim(),
                                    },
                                  )
                                  .toList(),
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                            _notify('ส่งคำขออุปกรณ์เพิ่มเติมแล้ว');
                          } catch (error) {
                            _notify(
                              _error(error, 'ส่งคำขออุปกรณ์ไม่สำเร็จ'),
                              true,
                            );
                          }
                        },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('ส่งคำขอ'),
                ),
              ],
            );
          },
        ),
      );
      for (final line in selected.values) {
        for (final controller in line.values) {
          controller.dispose();
        }
      }
    } catch (error) {
      _notify(_error(error, 'ไม่สามารถเปิดคำขออุปกรณ์ได้'), true);
    }
  }

  String _error(Object error, String fallback) => error is ApiException
      ? error.description == null
            ? error.message
            : '${error.message}\n${error.description}'
      : '$fallback\n$error';

  void _notify(String value, [bool error = false]) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _messageError = error;
    });
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '-';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  bool _hasPassed(Object? value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    return date != null && !DateTime.now().isBefore(date);
  }

  String _equipmentRequestState(Object? state) => switch ('$state') {
    'CUTOFF_NOT_CONFIGURED' => 'ผู้จัดยังไม่ได้เปิดรับคำขออุปกรณ์',
    'CUTOFF_DISABLED' => 'ผู้จัดปิดรับคำขออุปกรณ์แล้ว',
    'CUTOFF_EXPIRED' => 'เกินเวลาปิดรับคำขออุปกรณ์แล้ว',
    'MEETING_STARTED' => 'เริ่มประชุมแล้ว จึงไม่สามารถขออุปกรณ์ได้',
    _ => 'ยังไม่สามารถส่งคำขออุปกรณ์ได้',
  };

  String _statusName(String value, {bool late = false}) => switch (value) {
    'ACCEPTED' when late => 'ตอบรับภายหลัง',
    'ACCEPTED' => 'เข้าร่วม',
    'DECLINED' => 'ไม่เข้าร่วม',
    _ => 'รอตอบรับ',
  };

  String _meetingPeriod(Map<String, dynamic> invitation) =>
      '${_date(invitation['startDateTime'])} – ${_date(invitation['endDateTime'])}';

  Color _statusColor(String value, WorkspaceThemePreset preset) =>
      value == 'DECLINED' ? LaooColors.error : preset.primary;

  String _imageUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme
        ? uri.toString()
        : Uri.parse(ApiConfig.baseUrl).resolve(value).toString();
  }

  Widget _foodGroup(
    Map<String, dynamic> group,
    List<Map<String, dynamic>> foods,
    bool enabled,
    WorkspaceThemePreset preset,
  ) {
    final type = '${group['foodTypeCode']}';
    final max = (group['maxQuantity'] as num).toInt();
    final groupFoods = foods
        .where((food) => '${food['foodTypeCode']}' == type)
        .toList();
    final total = groupFoods.fold<int>(
      0,
      (sum, food) =>
          sum + (_foodQuantities[(food['foodId'] as num).toInt()] ?? 0),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${group['foodTypeName']}',
                      style: const TextStyle(
                        fontSize: LaooTypography.sectionTitle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (group['isRequired'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: preset.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                        ),
                        child: Text(
                          'บังคับเลือก',
                          style: TextStyle(
                            color: preset.primary,
                            fontSize: LaooTypography.inputHint,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: preset.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
                child: Text(
                  'เลือกแล้ว $total / $max',
                  style: TextStyle(color: preset.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...groupFoods.map((food) {
            final foodId = (food['foodId'] as num).toInt();
            final quantity = _foodQuantities[foodId] ?? 0;
            final image = '${food['imageUrl'] ?? ''}';
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              color: LaooColors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
                side: BorderSide(
                  color: quantity > 0 ? preset.primary : LaooColors.border,
                ),
              ),
              child: ListTile(
                leading: image.isEmpty
                    ? Icon(Icons.restaurant_outlined, color: preset.primary)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                        child: Image.network(
                          _imageUrl(image),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                title: Text('${food['nameTh']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'ลดจำนวน',
                      onPressed: !enabled || quantity == 0
                          ? null
                          : () => setState(
                              () => _foodQuantities[foodId] = quantity - 1,
                            ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'เพิ่มจำนวน',
                      onPressed: !enabled || total >= max
                          ? null
                          : () => setState(
                              () => _foodQuantities[foodId] = quantity + 1,
                            ),
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: enabled && total < max ? preset.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _requirementQuestion(
    Map<String, dynamic> question,
    bool enabled,
    WorkspaceThemePreset preset,
  ) {
    final id = (question['questionId'] as num).toInt();
    final type = '${question['answerType']}';
    final options = List<Map<String, dynamic>>.from(
      question['options'] as List? ?? const [],
    );
    Widget answer;
    if (type == 'BOOLEAN') {
      answer = Wrap(
        spacing: 8,
        children: [
          for (final value in const [('true', 'ใช่'), ('false', 'ไม่ใช่')])
            OutlinedButton.icon(
              onPressed: !enabled
                  ? null
                  : () => setState(() => _answerValues[id] = value.$1),
              icon: Icon(
                _answerValues[id] == value.$1
                    ? Icons.check_circle
                    : Icons.circle_outlined,
              ),
              label: Text(value.$2),
              style: OutlinedButton.styleFrom(
                backgroundColor: _answerValues[id] == value.$1
                    ? preset.primary.withValues(alpha: .10)
                    : LaooColors.white,
              ),
            ),
        ],
      );
    } else if (type == 'SINGLE') {
      answer = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) {
          final optionId = (option['optionId'] as num).toInt();
          final selected = _answerOptions[id]?.contains(optionId) ?? false;
          return OutlinedButton.icon(
            onPressed: !enabled
                ? null
                : () => setState(() => _answerOptions[id] = {optionId}),
            icon: Icon(selected ? Icons.check_circle : Icons.circle_outlined),
            label: Text('${option['optionText']}'),
            style: OutlinedButton.styleFrom(
              backgroundColor: selected
                  ? preset.primary.withValues(alpha: .10)
                  : LaooColors.white,
            ),
          );
        }).toList(),
      );
    } else if (type == 'MULTIPLE') {
      answer = Column(
        children: options.map((option) {
          final optionId = (option['optionId'] as num).toInt();
          final selected = _answerOptions[id]?.contains(optionId) ?? false;
          return CheckboxListTile(
            value: selected,
            title: Text('${option['optionText']}'),
            activeColor: preset.primary,
            onChanged: !enabled
                ? null
                : (value) => setState(() {
                    final selectedOptions = _answerOptions.putIfAbsent(
                      id,
                      () => {},
                    );
                    value == true
                        ? selectedOptions.add(optionId)
                        : selectedOptions.remove(optionId);
                  }),
          );
        }).toList(),
      );
    } else {
      answer = TextFormField(
        key: ValueKey('answer-$id-${_answerValues[id] ?? ''}'),
        initialValue: _answerValues[id] ?? '',
        enabled: enabled,
        keyboardType: type == 'NUMBER'
            ? TextInputType.number
            : TextInputType.text,
        maxLines: type == 'TEXT' ? 3 : 1,
        decoration: InputDecoration(
          labelText: type == 'NUMBER' ? 'จำนวน' : 'คำตอบ',
        ),
        onChanged: (value) => _answerValues[id] = value,
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      decoration: BoxDecoration(
        color: LaooColors.white,
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        border: Border.all(color: LaooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${question['questionText']}'
            '${question['isRequired'] == true ? ' *' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          answer,
        ],
      ),
    );
  }

  Widget _action(WorkspaceThemePreset preset) {
    final detail = _detail!;
    final invitation = Map<String, dynamic>.from(detail['invitation'] as Map);
    final foods = List<Map<String, dynamic>>.from(
      detail['foods'] as List? ?? const [],
    );
    final groups = List<Map<String, dynamic>>.from(
      detail['groups'] as List? ?? const [],
    );
    final questions = List<Map<String, dynamic>>.from(
      detail['questions'] as List? ?? const [],
    );
    final canRequestEquipment = invitation['canRequestEquipment'] == true;
    final canRespond = invitation['canRespond'] == true;
    final canEditPreferences = invitation['canEditPreferences'] == true;
    final hasFoodPlan = groups.isNotEmpty;
    final foodCutoffPassed = _hasPassed(invitation['orderCutoffDateTime']);
    final foodOrderingClosed = hasFoodPlan && foodCutoffPassed;
    final lateAcceptanceOnly = invitation['lateAcceptanceOnly'] == true;
    final participantNickName = '${invitation['participantNickName'] ?? ''}'
        .trim();
    final requiresChangeReason = invitation['requiresChangeReason'] == true;
    final responseChoices = Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          const [
            ('PENDING', 'รอตอบรับ', Icons.schedule_outlined),
            ('ACCEPTED', 'เข้าร่วม', Icons.check_circle_outline),
            ('DECLINED', 'ปฏิเสธ', Icons.cancel_outlined),
          ].map((option) {
            final selected = _responseStatus == option.$1;
            final isDeclined = option.$1 == 'DECLINED';
            final color = isDeclined ? LaooColors.error : preset.primary;
            return SizedBox(
              height: LaooTypography.buttonHeight,
              child: OutlinedButton.icon(
                onPressed:
                    _saving ||
                        !canRespond ||
                        selected ||
                        (lateAcceptanceOnly && option.$1 != 'ACCEPTED')
                    ? null
                    : () => setState(() => _responseStatus = option.$1),
                icon: Icon(option.$3),
                label: Text(option.$2),
                style: OutlinedButton.styleFrom(
                  foregroundColor: selected
                      ? (isDeclined
                            ? Colors.white
                            : Theme.of(context).colorScheme.onPrimary)
                      : color,
                  backgroundColor: selected
                      ? (isDeclined ? LaooColors.error : preset.primary)
                      : Colors.white,
                  disabledForegroundColor: selected
                      ? (isDeclined
                            ? Colors.white
                            : Theme.of(context).colorScheme.onPrimary)
                      : color.withValues(alpha: .45),
                  disabledBackgroundColor: selected
                      ? (isDeclined ? LaooColors.error : preset.primary)
                      : Colors.white,
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(
                    fontSize: LaooTypography.button,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
    );
    return Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionCard(
            child: WorkspaceActionHeader(
              title: '$_caption > ตอบรับ',
              favoriteKey: '21003',
              actions: [
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _detail = null),
                  child: const Text('ยกเลิก'),
                ),
                if (canRespond)
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: WorkspaceSectionCard(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: preset.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                    child: Text(
                      '${invitation['bookingNo'] ?? '-'} | ${invitation['subject']}\n'
                      '${invitation['roomCode']} | ${invitation['roomName']}\n'
                      '${_meetingPeriod(invitation)}\n'
                      'ผู้ถูกเชิญ: ${invitation['participantName'] ?? '-'}${participantNickName.isEmpty ? '' : ' ($participantNickName)'}\n'
                      'ผู้จัด: ${invitation['organizerName'] ?? '-'}',
                    ),
                  ),
                  if (invitation['isLateResponse'] == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      decoration: BoxDecoration(
                        color: preset.primary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                      child: Text(
                        'สถานะ: ตอบรับภายหลัง\n'
                        'เหตุผล: ${invitation['lateResponseReason'] ?? '-'}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 880;
                      final remark = SizedBox(
                        width: double.infinity,
                        height: LaooTypography.buttonHeight,
                        child: TextField(
                          controller: _remark,
                          maxLines: 1,
                          readOnly: !canRespond,
                          style: const TextStyle(
                            fontSize: LaooTypography.inputText,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'หมายเหตุการตอบรับ',
                          ),
                        ),
                      );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'การตอบรับ',
                              style: TextStyle(
                                fontSize: LaooTypography.sectionTitle,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            responseChoices,
                            const SizedBox(height: 8),
                            remark,
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'การตอบรับ',
                            style: TextStyle(
                              fontSize: LaooTypography.sectionTitle,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          responseChoices,
                          const SizedBox(height: 8),
                          remark,
                        ],
                      );
                    },
                  ),
                  if (!canRespond) ...[
                    Text(
                      '${invitation['responseUnavailableReason'] ?? 'คำเชิญนี้ไม่สามารถเปลี่ยนการตอบรับได้ กรุณาโหลดข้อมูลใหม่หรือติดต่อผู้ดูแลระบบ'}',
                    ),
                    const SizedBox(height: LaooLayout.cardSpacing),
                  ],
                  if (lateAcceptanceOnly) ...[
                    Container(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      decoration: BoxDecoration(
                        color: preset.primary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                      child: const Text(
                        'การประชุมเริ่มแล้ว สามารถตอบรับภายหลังได้เฉพาะ เข้าร่วม กรุณาระบุเหตุผลก่อนบันทึก อาหารและความต้องการปิดรับแล้ว',
                      ),
                    ),
                    const SizedBox(height: LaooLayout.cardSpacing),
                  ],
                  if (requiresChangeReason) ...[
                    SizedBox(
                      height: LaooTypography.buttonHeight,
                      child: TextField(
                        controller: _changeReason,
                        maxLines: 1,
                        readOnly: !canRespond,
                        decoration: const InputDecoration(
                          labelText: 'เหตุผลการตอบรับ (กรณีพบปัญหา)',
                        ),
                      ),
                    ),
                    const SizedBox(height: LaooLayout.cardSpacing),
                  ],
                  if (_responseStatus == 'ACCEPTED' &&
                      invitation['activityTypeCode'] == 'TRAINING') ...[
                    const SizedBox(height: LaooLayout.cardSpacing),
                    _trainingTests(invitation, detail, preset),
                  ],
                  if (_responseStatus == 'ACCEPTED' && foodOrderingClosed) ...[
                    const SizedBox(height: LaooLayout.cardSpacing),
                    MeetingAttendancePanel(
                      key: ValueKey((
                        invitation['bookingId'],
                        invitation['participantId'],
                      )),
                      bookingId: (invitation['bookingId'] as num).toInt(),
                      participantId: (invitation['participantId'] as num)
                          .toInt(),
                      onMessage: (message, error) => _notify(message, error),
                    ),
                    const SizedBox(height: LaooLayout.cardSpacing),
                    Container(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      decoration: BoxDecoration(
                        color: LaooColors.error.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: LaooColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'เกินเวลาปิดรับสั่งอาหาร\nปิดรับเมื่อ ${_date(invitation['orderCutoffDateTime'])}',
                              style: const TextStyle(color: LaooColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_responseStatus == 'ACCEPTED' && !foodOrderingClosed) ...[
                    const SizedBox(height: LaooLayout.cardSpacing),
                    MeetingAttendancePanel(
                      key: ValueKey((
                        invitation['bookingId'],
                        invitation['participantId'],
                      )),
                      bookingId: (invitation['bookingId'] as num).toInt(),
                      participantId: (invitation['participantId'] as num)
                          .toInt(),
                      onMessage: (message, error) => _notify(message, error),
                    ),
                    const SizedBox(height: LaooLayout.cardSpacing),
                    Row(
                      children: [
                        Icon(
                          Icons.restaurant_menu_outlined,
                          color: preset.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'อาหารและเครื่องดื่ม',
                            style: TextStyle(
                              fontSize: LaooTypography.sectionTitle,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      groups.isEmpty
                          ? 'ผู้จัดไม่ได้กำหนดอาหารสำหรับการประชุมนี้'
                          : 'เลือกตามจำนวนของแต่ละกลุ่ม · ปิดรับ ${_date(invitation['orderCutoffDateTime'])}',
                      style: TextStyle(color: preset.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ...groups.map(
                      (group) => _foodGroup(
                        group,
                        foods,
                        canEditPreferences && !_saving,
                        preset,
                      ),
                    ),
                    if (questions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.fact_check_outlined,
                            color: preset.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ความต้องการเพิ่มเติม',
                            style: TextStyle(
                              fontSize: LaooTypography.sectionTitle,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...questions.map(
                        (question) => _requirementQuestion(
                          question,
                          canEditPreferences && !_saving,
                          preset,
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      decoration: BoxDecoration(
                        color: preset.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                      child: const Text(
                        'ตรวจสอบสถานะ อาหาร และความต้องการให้ครบ แล้วกดบันทึกด้านบนเพียงครั้งเดียว',
                      ),
                    ),
                  ],
                  if (_responseStatus == 'ACCEPTED') ...[
                    const SizedBox(height: LaooLayout.cardSpacing),
                    const Divider(color: LaooColors.border),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.handyman_outlined, color: preset.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'อุปกรณ์เพิ่มเติม',
                            style: TextStyle(
                              color: LaooColors.pageCaption,
                              fontSize: LaooTypography.sectionTitle,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (canRequestEquipment)
                          OutlinedButton.icon(
                            onPressed: canRequestEquipment
                                ? () => _showEquipmentRequest(invitation)
                                : null,
                            icon: const Icon(Icons.add_outlined),
                            label: const Text('ขออุปกรณ์'),
                          ),
                      ],
                    ),
                    if (!canRequestEquipment) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${invitation['equipmentRequestUnavailableReason'] ?? 'ผู้จัดยังไม่ได้เปิดรับคำขออุปกรณ์'}',
                        style: TextStyle(
                          color: preset.textSecondary,
                          fontSize: LaooTypography.inputHint,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'อุปกรณ์มาตรฐานของห้อง',
                      style: TextStyle(
                        color: LaooColors.pageCaption,
                        fontSize: LaooTypography.inputText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...(List<Map<String, dynamic>>.from(
                          _detail?['roomItems'] as List? ?? const [],
                        ).isEmpty
                        ? const [
                            Text(
                              'ห้องนี้ยังไม่ได้กำหนดอุปกรณ์มาตรฐาน',
                              style: TextStyle(
                                color: LaooColors.textSecondary,
                                fontSize: LaooTypography.inputHint,
                              ),
                            ),
                          ]
                        : List<Map<String, dynamic>>.from(
                            _detail?['roomItems'] as List? ?? const [],
                          ).map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '${item['name'] ?? '-'} × ${item['quantity'] ?? 1}${item['unitName'] == null || '${item['unitName']}'.isEmpty ? '' : ' ${item['unitName']}'}',
                                style: const TextStyle(
                                  fontSize: LaooTypography.inputText,
                                ),
                              ),
                            ),
                          )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainingTests(
    Map<String, dynamic> invitation,
    Map<String, dynamic> detail,
    WorkspaceThemePreset preset,
  ) {
    final overview = detail['trainingTests'] as Map?;
    final sections = List<Map<String, dynamic>>.from(
      overview?['sections'] as List? ?? const [],
    );
    final bookingId = (invitation['bookingId'] as num).toInt();
    return Container(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      decoration: BoxDecoration(
        color: preset.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        border: Border.all(color: preset.primary.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_outlined, color: preset.primary),
              const SizedBox(width: 8),
              const Text(
                'แบบทดสอบอบรม',
                style: TextStyle(
                  fontSize: LaooTypography.sectionTitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (overview == null)
            const Text('ยังไม่สามารถโหลดสถานะแบบทดสอบได้ กรุณาลองใหม่อีกครั้ง')
          else if (sections.where((x) => x['configured'] == true).isEmpty)
            const Text('ผู้จัดยังไม่ได้แนบแบบทดสอบสำหรับการอบรมรอบนี้')
          else
            ...sections.where((x) => x['configured'] == true).map((section) {
              final code = '${section['section']}';
              final label = code == 'PRE' ? 'ก่อนอบรม' : 'หลังอบรม';
              final submitted = section['submitted'] == true;
              final passed = section['passed'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    if (submitted)
                      Text(
                        'คะแนน ${section['score']}/${section['maxScore']} · ${passed ? 'ผ่าน' : 'ไม่ผ่าน'}',
                        style: TextStyle(
                          color: passed ? preset.primary : LaooColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (section['isOpen'] == true)
                      FilledButton.icon(
                        onPressed: () => GoRouter.of(context).go(
                          '/company/training-tests/$bookingId?section=$code',
                        ),
                        icon: const Icon(Icons.play_arrow_outlined),
                        label: Text('ทำแบบทดสอบ$label'),
                      )
                    else
                      Text(
                        code == 'PRE'
                            ? 'เปิดให้ทำก่อนเริ่มอบรม'
                            : 'เปิดให้ทำหลังจบอบรม',
                        style: TextStyle(color: preset.textSecondary),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _list(WorkspaceThemePreset preset) {
    final pageCount = (_total / 20).ceil();
    return Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionCard(
            child: WorkspacePageTitle(title: _caption, favoriteKey: '21003'),
          ),
          const SizedBox(height: LaooLayout.captionFilterSpacing),
          WorkspaceSectionCard(
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 600
                        ? constraints.maxWidth
                        : 260,
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) {
                        _page = 1;
                        _load();
                      },
                      decoration: const InputDecoration(
                        labelText: 'ค้นหาเลขที่จอง/หัวข้อ/ห้อง',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      _page = 1;
                      _load();
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _search.clear();
                      _filterStatus = null;
                      _page = 1;
                      _load();
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('ล้าง Filter'),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 600
                        ? constraints.maxWidth
                        : 280,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _filterStatus,
                      decoration: const InputDecoration(labelText: 'สถานะ'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                        DropdownMenuItem(
                          value: 'PENDING',
                          child: Text('รอตอบรับ'),
                        ),
                        DropdownMenuItem(
                          value: 'ACCEPTED',
                          child: Text('เข้าร่วม'),
                        ),
                        DropdownMenuItem(
                          value: 'LATE_ACCEPTED',
                          child: Text('ตอบรับภายหลัง'),
                        ),
                        DropdownMenuItem(
                          value: 'DECLINED',
                          child: Text('ไม่เข้าร่วม'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterStatus = value;
                          _page = 1;
                        });
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading) const LinearProgressIndicator(),
                Expanded(
                  child: !_loading && _items.isEmpty
                      ? const Center(
                          child: Text(
                            'ยังไม่มีคำเชิญที่รอตอบรับหรือกำลังจะมาถึง',
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final status = '${item['invitationStatus']}';
                            final late = item['isLateResponse'] == true;
                            final participantNickName =
                                '${item['participantNickName'] ?? ''}'.trim();
                            final color = _statusColor(status, preset);
                            return Card(
                              margin: EdgeInsets.zero,
                              color: LaooColors.white,
                              surfaceTintColor: Colors.transparent,
                              elevation: 0,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                                side: BorderSide.none,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.mark_email_read_outlined,
                                  color: color,
                                ),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: .10),
                                        borderRadius: BorderRadius.circular(
                                          LaooRadius.xs,
                                        ),
                                      ),
                                      child: Text(
                                        _statusName(status, late: late),
                                        style: TextStyle(color: color),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${item['bookingNo'] ?? '-'} | ${item['subject']}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${item['roomCode']} | ${item['roomName']}\n'
                                  '${_meetingPeriod(item)}\n'
                                  'ผู้ถูกเชิญ: ${item['participantName'] ?? '-'}${participantNickName.isEmpty ? '' : ' ($participantNickName)'}\n'
                                  'ผู้จัด: ${item['organizerName'] ?? '-'}',
                                ),
                                trailing: SizedBox(
                                  width: 124,
                                  height: 48,
                                  child: FilledButton(
                                    onPressed: () => _open(item),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: preset.primary,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          LaooRadius.xs,
                                        ),
                                      ),
                                    ),
                                    child: const Text('ดำเนินการ'),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          MeetingPaginationCard(
            showDivider: false,
            total: _total,
            pageIndex: _page - 1,
            pageSize: 20,
            primary: preset.primary,
            onPrevious: _page > 1
                ? () {
                    setState(() => _page--);
                    _load();
                  }
                : null,
            onNext: _page < pageCount
                ? () {
                    setState(() => _page++);
                    _load();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, preset, _) => buildMeetingWorkspaceShell(
        pageTitle: _caption,
        activeMenu: '21003',
        child: Stack(
          children: [
            _detail == null ? _list(preset) : _action(preset),
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
  }
}
