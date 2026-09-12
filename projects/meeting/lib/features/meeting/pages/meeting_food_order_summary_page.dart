import 'package:flutter/material.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_food_order_summary_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';
import '../utils/meeting_food_summary_export.dart';
import '../widgets/meeting_pagination_card.dart';

class MeetingFoodOrderSummaryPage extends StatefulWidget {
  const MeetingFoodOrderSummaryPage({super.key});
  @override
  State<MeetingFoodOrderSummaryPage> createState() => _State();
}

class _State extends State<MeetingFoodOrderSummaryPage> {
  final repo = MeetingFoodOrderSummaryRepository();
  final search = TextEditingController();
  final today = DateUtils.dateOnly(DateTime.now());
  late DateTime from = today, to = today.add(const Duration(days: 30));
  String caption = 'สรุปการสั่งอาหาร';
  String? message;
  List<Map<String, dynamic>> items = [];
  bool loading = true, available = true;
  int page = 1, total = 0;
  String groupBy = 'room';
  int? foodFilterId;

  @override
  void initState() {
    super.initState();
    NavigationMenuRepository()
        .resolveMenuName(
          menuCode: MeetingMenuCodes.foodOrderSummary,
          routeName: MeetingRouteNames.foodOrderSummary,
          fallback: caption,
        )
        .then((value) {
          if (mounted) setState(() => caption = value);
        });
    load();
  }

  @override
  void dispose() {
    search.dispose();
    repo.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await repo.list(
        dateFrom: from,
        dateTo: to,
        search: search.text,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        available = data['available'] != false;
        items = List<Map<String, dynamic>>.from(
          data['items'] as List? ?? const [],
        );
        total = (data['total'] as num?)?.toInt() ?? 0;
      });
    } catch (error) {
      if (mounted) {
        setState(() => message = errorText(error, 'โหลดสรุปอาหารไม่สำเร็จ'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String errorText(Object error, String fallback) => error is ApiException
      ? '${error.message}${error.description == null ? '' : '\n${error.description}'}'
      : '$fallback\nรายละเอียดเพิ่มเติม: $error';
  String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String dateTime(Object? value) {
    final d = DateTime.tryParse('$value')?.toLocal();
    return d == null
        ? '-'
        : '${date(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> pick(bool isFrom) async {
    final preset = workspaceThemeController.value;
    final baseTheme = Theme.of(context);
    final value = await showDatePicker(
      context: context,
      initialDate: isFrom ? from : to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final scheme = baseTheme.colorScheme.copyWith(
          primary: preset.primary,
          surface: LaooColors.white,
          onSurface: preset.textPrimary,
        );
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: scheme,
            datePickerTheme: DatePickerThemeData(
              backgroundColor: LaooColors.white,
              surfaceTintColor: Colors.transparent,
              headerHelpStyle: LaooTypography.popupTitleStyle,
              dividerColor: LaooColors.border,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
                side: BorderSide.none,
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: preset.primary,
                minimumSize: const Size(64, LaooTypography.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: scheme.onPrimary,
                backgroundColor: preset.primary,
                minimumSize: const Size(64, LaooTypography.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              headerBackgroundColor: LaooColors.white,
              headerForegroundColor: preset.textPrimary,
              weekdayStyle: TextStyle(
                color: preset.primary,
                fontSize: LaooTypography.inputText,
                fontWeight: FontWeight.w700,
              ),
              dayStyle: const TextStyle(
                fontSize: LaooTypography.inputText,
                fontWeight: FontWeight.w500,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return preset.textSecondary.withValues(alpha: .45);
                }
                if (states.contains(WidgetState.selected)) {
                  return scheme.onPrimary;
                }
                return preset.textPrimary;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? preset.primary
                    : Colors.transparent,
              ),
              dayOverlayColor: WidgetStatePropertyAll(
                preset.primary.withValues(alpha: .10),
              ),
              dayShape: WidgetStateProperty.resolveWith(
                (states) => RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                  side: states.contains(WidgetState.selected)
                      ? BorderSide(color: preset.primary, width: 1.25)
                      : BorderSide.none,
                ),
              ),
              todayForegroundColor: WidgetStatePropertyAll(preset.primary),
              todayBackgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? preset.primary.withValues(alpha: .14)
                    : Colors.transparent,
              ),
              todayBorder: BorderSide(color: preset.primary, width: 1.25),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: LaooColors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(foregroundColor: preset.primary),
            ),
          ),
          child: child!,
        );
      },
    );
    if (value == null || !mounted) return;
    setState(() {
      if (isFrom) {
        from = value;
        if (to.isBefore(value)) to = value;
      } else {
        to = value;
        if (from.isAfter(value)) from = value;
      }
      page = 1;
    });
    load();
  }

  Widget badge(String? status, WorkspaceThemePreset preset) {
    final cancelled = status == 'CANCELLED';
    final color = cancelled ? LaooColors.error : preset.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Text(
        cancelled ? 'ยกเลิก' : 'อนุมัติ',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget quantityBadge(String text, WorkspaceThemePreset preset) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: preset.primary.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: Text(
      text,
      style: TextStyle(color: preset.primary, fontWeight: FontWeight.w700),
    ),
  );

  String csvCell(Object? value) {
    final text = '${value ?? ''}'.replaceAll('"', '""');
    return '"$text"';
  }

  void exportSummary() {
    final rows = <List<Object?>>[
      [
        'ห้องประชุม',
        'หัวข้อ',
        'วันและเวลาประชุม',
        'ประเภทอาหาร',
        'รายการอาหาร',
        'ผู้สั่ง',
        'รวมจำนวน',
      ],
    ];
    for (final booking in visibleItems) {
      for (final food in orderedFoods(booking)) {
        rows.add([
          '${booking['roomCode']} | ${booking['roomName']}',
          booking['subject'],
          '${dateTime(booking['startDateTime'])} - ${dateTime(booking['endDateTime'])}',
          food['foodTypeName'],
          food['nameTh'],
          food['orderedParticipantCount'],
          food['orderedQuantity'],
        ]);
      }
    }
    downloadFoodSummary(
      'สรุปการสั่งอาหาร_${date(from).replaceAll('/', '-')}_ ${date(to).replaceAll('/', '-')}.csv'
          .replaceAll('_ ', '_'),
      rows.map((row) => row.map(csvCell).join(',')).join('\r\n'),
    );
  }

  Widget filterCard() => WorkspaceSectionCard(
    child: LayoutBuilder(
      builder: (_, box) => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: box.maxWidth < 650 ? box.maxWidth : 260,
            child: TextField(
              controller: search,
              onSubmitted: (_) {
                page = 1;
                load();
              },
              decoration: const InputDecoration(
                labelText: 'ค้นหาเลขที่จอง/หัวข้อ/ห้อง',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            width: box.maxWidth < 650 ? box.maxWidth : 190,
            child: DropdownButtonFormField<String>(
              initialValue: groupBy,
              decoration: const InputDecoration(labelText: 'จัดกลุ่มข้อมูล'),
              items: const [
                DropdownMenuItem(value: 'room', child: Text('ตามห้องประชุม')),
                DropdownMenuItem(value: 'food', child: Text('ตามอาหาร')),
                DropdownMenuItem(value: 'subject', child: Text('ตามเรื่อง')),
                DropdownMenuItem(
                  value: 'participant',
                  child: Text('ตามผู้เข้าประชุม'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => groupBy = value);
              },
            ),
          ),
          SizedBox(
            width: box.maxWidth < 650 ? box.maxWidth : 220,
            child: DropdownButtonFormField<int?>(
              initialValue:
                  foodFilterOptions.any(
                    (food) => (food['foodId'] as num?)?.toInt() == foodFilterId,
                  )
                  ? foodFilterId
                  : null,
              decoration: const InputDecoration(labelText: 'รายการอาหาร'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('รายการอาหารทั้งหมด'),
                ),
                ...foodFilterOptions.map(
                  (food) => DropdownMenuItem<int?>(
                    value: (food['foodId'] as num).toInt(),
                    child: Text('${food['nameTh']}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => foodFilterId = value),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => pick(true),
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('จาก ${date(from)}'),
          ),
          OutlinedButton.icon(
            onPressed: () => pick(false),
            icon: const Icon(Icons.event_outlined),
            label: Text('ถึง ${date(to)}'),
          ),
          FilledButton.icon(
            onPressed: () {
              page = 1;
              load();
            },
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                search.clear();
                from = today;
                to = today.add(const Duration(days: 30));
                foodFilterId = null;
                page = 1;
              });
              load();
            },
            icon: const Icon(Icons.clear),
            label: const Text('ล้าง Filter'),
          ),
        ],
      ),
    ),
  );

  List<Map<String, dynamic>> orderedFoods(Map<String, dynamic> item) =>
      List<Map<String, dynamic>>.from(
        item['foods'] as List? ?? const [],
      ).where((food) {
        if (foodFilterId != null && food['foodId'] != foodFilterId) {
          return false;
        }
        final people = (food['orderedParticipantCount'] as num?)?.toInt() ?? 0;
        final quantity = (food['orderedQuantity'] as num?)?.toInt() ?? 0;
        return people > 0 && quantity > 0;
      }).toList();

  List<Map<String, dynamic>> get visibleItems => items
      .where((item) => foodFilterId == null || orderedFoods(item).isNotEmpty)
      .toList();

  List<Map<String, dynamic>> get foodFilterOptions {
    final options = <int, Map<String, dynamic>>{};
    for (final item in items) {
      for (final food in List<Map<String, dynamic>>.from(
        item['foods'] as List? ?? const [],
      )) {
        final id = (food['foodId'] as num?)?.toInt();
        final people = (food['orderedParticipantCount'] as num?)?.toInt() ?? 0;
        final quantity = (food['orderedQuantity'] as num?)?.toInt() ?? 0;
        if (id != null && people > 0 && quantity > 0) options[id] = food;
      }
    }
    final result = options.values.toList();
    result.sort(
      (left, right) => '${left['nameTh']}'.compareTo('${right['nameTh']}'),
    );
    return result;
  }

  int quantityOf(Iterable<Map<String, dynamic>> rows) => rows.fold(
    0,
    (total, row) =>
        total + ((row['food']['orderedQuantity'] as num?)?.toInt() ?? 0),
  );

  Widget foodMeetingRow(Map<String, dynamic> row, WorkspaceThemePreset preset) {
    final booking = Map<String, dynamic>.from(row['booking'] as Map);
    final food = Map<String, dynamic>.from(row['food'] as Map);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.meeting_room_outlined, size: 18, color: preset.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${booking['roomCode']} | ${booking['roomName']}\n'
                  '${dateTime(booking['startDateTime'])} - ${dateTime(booking['endDateTime'])}',
                ),
                const SizedBox(height: 4),
                quantityBadge(
                  'รวมจำนวน ${food['orderedQuantity'] ?? 0}',
                  preset,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget foodGroupedList(WorkspaceThemePreset preset) {
    final typeRows = <String, List<Map<String, dynamic>>>{};
    for (final booking in visibleItems) {
      for (final food in orderedFoods(booking)) {
        typeRows.putIfAbsent('${food['foodTypeName'] ?? '-'}', () => []).add({
          'booking': booking,
          'food': food,
        });
      }
    }
    return ListView.separated(
      itemCount: typeRows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, index) {
        final type = typeRows.entries.elementAt(index);
        final foodRows = <String, List<Map<String, dynamic>>>{};
        for (final row in type.value) {
          final food = Map<String, dynamic>.from(row['food'] as Map);
          foodRows.putIfAbsent('${food['foodId']}', () => []).add(row);
        }
        return WorkspaceSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                type.key,
                style: TextStyle(
                  color: preset.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...foodRows.values.map((rows) {
                final food = Map<String, dynamic>.from(
                  rows.first['food'] as Map,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.restaurant_menu_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${food['nameTh']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          quantityBadge('รวมจำนวน ${quantityOf(rows)}', preset),
                        ],
                      ),
                      ...rows.map((row) => foodMeetingRow(row, preset)),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget subjectGroupedList(WorkspaceThemePreset preset) {
    final subjectRows = <String, List<Map<String, dynamic>>>{};
    for (final item in visibleItems) {
      subjectRows.putIfAbsent('${item['subject'] ?? '-'}', () => []).add(item);
    }
    return ListView.separated(
      itemCount: subjectRows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, index) {
        final subject = subjectRows.entries.elementAt(index);
        return WorkspaceSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subject.key,
                style: TextStyle(
                  color: preset.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...subject.value.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 18,
                        color: preset.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['roomCode']} | ${item['roomName']}\n'
                              '${dateTime(item['startDateTime'])} - ${dateTime(item['endDateTime'])}',
                            ),
                            const SizedBox(height: 4),
                            ...orderedFoods(item).map(
                              (food) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.restaurant_menu_outlined,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('${food['nameTh']}'),
                                          const SizedBox(height: 4),
                                          quantityBadge(
                                            'รวมจำนวน ${food['orderedQuantity'] ?? 0}',
                                            preset,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget participantGroupedList(WorkspaceThemePreset preset) {
    final groups = <String, Map<String, dynamic>>{};
    for (final booking in visibleItems) {
      final rows =
          List<Map<String, dynamic>>.from(
                booking['participantFoods'] as List? ?? const [],
              )
              .where(
                (row) => foodFilterId == null || row['foodId'] == foodFilterId,
              )
              .toList();
      for (final row in rows) {
        final key = '${booking['bookingId']}:${row['participantId']}';
        final group = groups.putIfAbsent(
          key,
          () => {
            'booking': booking,
            'participantId': row['participantId'],
            'participantName': row['participantName'],
            'participantNickname': row['participantNickname'],
            'divisionName': row['divisionName'],
            'departmentName': row['departmentName'],
            'foods': <Map<String, dynamic>>[],
          },
        );
        (group['foods'] as List<Map<String, dynamic>>).add(row);
      }
    }
    final orderedGroups = groups.values.toList()
      ..sort((left, right) {
        final nameCompare = '${left['participantName']}'.compareTo(
          '${right['participantName']}',
        );
        if (nameCompare != 0) return nameCompare;
        return '${left['participantNickname'] ?? ''}'.compareTo(
          '${right['participantNickname'] ?? ''}',
        );
      });
    return ListView.separated(
      itemCount: orderedGroups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, index) {
        final group = orderedGroups[index];
        final booking = Map<String, dynamic>.from(group['booking'] as Map);
        final foods = List<Map<String, dynamic>>.from(group['foods'] as List);
        final foodGroups = <String, List<Map<String, dynamic>>>{};
        for (final food in foods) {
          foodGroups
              .putIfAbsent('${food['foodTypeName'] ?? '-'}', () => [])
              .add(food);
        }
        final participantId = group['participantId'];
        final answers = List<Map<String, dynamic>>.from(
          (booking['requirements'] as List? ?? const []).where(
            (answer) => '${answer['participantId']}' == '$participantId',
          ),
        );
        return WorkspaceSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, color: preset.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${group['participantName'] ?? '-'}'
                      '${group['participantNickname'] == null ? '' : ' (${group['participantNickname']})'}'
                      '${group['divisionName'] == null ? '' : ' | ฝ่าย ${group['divisionName']}'}'
                      '${group['departmentName'] == null ? '' : ' | แผนก ${group['departmentName']}'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${booking['subject'] ?? '-'} | ${booking['roomCode']} ${booking['roomName']}',
                style: TextStyle(color: preset.textSecondary),
              ),
              Text(
                '${dateTime(booking['startDateTime'])} - ${dateTime(booking['endDateTime'])}',
                style: TextStyle(color: preset.textSecondary),
              ),
              const SizedBox(height: 10),
              ...foodGroups.entries.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        type.key,
                        style: TextStyle(
                          color: preset.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ...type.value.map(
                        (food) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.restaurant_menu_outlined,
                                size: 17,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('${food['foodName']}'),
                                    quantityBadge(
                                      'จำนวน ${food['quantity'] ?? 0}',
                                      preset,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (answers.isNotEmpty) ...[
                const Divider(),
                Text(
                  'ข้อความ/ตัวเลือก',
                  style: TextStyle(
                    color: preset.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ...answers.map(
                  (answer) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${answer['questionText']}: ${answer['answerValue'] ?? '-'}',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget resultList(WorkspaceThemePreset preset) => switch (groupBy) {
    'food' => foodGroupedList(preset),
    'subject' => subjectGroupedList(preset),
    'participant' => participantGroupedList(preset),
    _ => ListView.separated(
      itemCount: visibleItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, index) => itemCard(visibleItems[index], preset),
    ),
  };

  Widget itemCard(Map<String, dynamic> item, WorkspaceThemePreset preset) {
    final foods = orderedFoods(item);
    final foodGroups = <String, List<Map<String, dynamic>>>{};
    for (final food in foods) {
      foodGroups
          .putIfAbsent('${food['foodTypeName'] ?? '-'}', () => [])
          .add(food);
    }
    final requirements = List<Map<String, dynamic>>.from(
      item['requirements'] as List? ?? const [],
    );
    final requirementGroups = <int, List<Map<String, dynamic>>>{};
    for (final answer in requirements) {
      requirementGroups
          .putIfAbsent((answer['questionId'] as num).toInt(), () => [])
          .add(answer);
    }
    return WorkspaceSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu_outlined, color: preset.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item['roomCode']} | ${item['roomName']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${item['bookingNo'] ?? '-'}'),
              const SizedBox(width: 8),
              badge(item['status'] as String?, preset),
            ],
          ),
          const SizedBox(height: 8),
          Text('${item['subject'] ?? '-'}'),
          Text(
            '${dateTime(item['startDateTime'])} - ${dateTime(item['endDateTime'])}',
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              quantityBadge(
                'ผู้สั่ง ${item['orderedParticipantCount'] ?? 0} คน',
                preset,
              ),
              quantityBadge('รวมจำนวน ${item['orderedQuantity'] ?? 0}', preset),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'สรุปรายการอาหารที่สั่ง',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (foods.isEmpty)
            Text(
              'ยังไม่มีรายการอาหาร',
              style: TextStyle(color: preset.textSecondary),
            )
          else
            ...foodGroups.entries.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WorkspaceSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        group.key,
                        style: TextStyle(
                          color: preset.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...group.value.map(
                        (food) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.restaurant_menu_outlined,
                                color: preset.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${food['nameTh']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        quantityBadge(
                                          'ผู้สั่ง ${food['orderedParticipantCount'] ?? 0} คน',
                                          preset,
                                        ),
                                        quantityBadge(
                                          'รวมจำนวน ${food['orderedQuantity'] ?? 0}',
                                          preset,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (requirementGroups.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'ความต้องการเพิ่มเติม',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...requirementGroups.values.map((answers) {
              final first = answers.first;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WorkspaceSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${first['questionText']}',
                        style: TextStyle(
                          color: preset.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...answers.map(
                        (answer) => Text(
                          '${answer['participantName']} : ${answer['answerValue'] ?? '-'}',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget pager() {
    final pages = (total / 20).ceil();
    return MeetingPaginationCard(
      showDivider: false,
      total: total,
      pageIndex: page - 1,
      pageSize: 20,
      primary: workspaceThemeController.value.primary,
      onPrevious: page > 1
          ? () {
              setState(() => page--);
              load();
            }
          : null,
      onNext: page < pages
          ? () {
              setState(() => page++);
              load();
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return buildMeetingWorkspaceShell(
      pageTitle: caption,
      activeMenu: MeetingMenuCodes.foodOrderSummary,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSectionCard(
                  child: WorkspaceActionHeader(
                    title: caption,
                    favoriteKey: MeetingMenuCodes.foodOrderSummary,
                    actions: [
                      OutlinedButton.icon(
                        onPressed: items.isEmpty ? null : exportSummary,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Export ข้อมูล'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                filterCard(),
                const SizedBox(height: LaooLayout.cardSpacing),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : !available
                      ? const Center(
                          child: Text(
                            'ระบบสรุปอาหารยังไม่พร้อม กรุณาติดต่อผู้ดูแลระบบ',
                          ),
                        )
                      : items.isEmpty
                      ? const Center(
                          child: Text('ไม่พบรายการสั่งอาหารในช่วงวันที่เลือก'),
                        )
                      : resultList(preset),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                pager(),
              ],
            ),
          ),
          if (message != null)
            Positioned(
              top: 12,
              right: 12,
              child: AutoDismissMessage(
                message: message!,
                error: true,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }
}
