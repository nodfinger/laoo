import 'package:flutter/material.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_attendance_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';
import '../widgets/meeting_attendance_panel.dart';

class MeetingAttendancePage extends StatefulWidget {
  const MeetingAttendancePage({super.key});
  @override
  State<MeetingAttendancePage> createState() => _State();
}

class _State extends State<MeetingAttendancePage> {
  final repo = MeetingAttendanceRepository();
  final search = TextEditingController();
  final today = DateUtils.dateOnly(DateTime.now());
  late DateTime from = today, to = today;
  String caption = 'รายการเช็คชื่อ';
  String? message;
  bool messageError = false, loading = true, available = true;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic>? selected;
  int page = 1, total = 0;

  @override
  void initState() {
    super.initState();
    NavigationMenuRepository()
        .resolveMenuName(
          menuCode: MeetingMenuCodes.attendance,
          routeName: MeetingRouteNames.attendance,
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

  void notify(String value, bool error) => setState(() {
    message = value;
    messageError = error;
  });
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

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await repo.bookingSlots(
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
        notify(errorText(error, 'โหลดรายการเช็คชื่อไม่สำเร็จ'), true);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pick(bool isFrom) async {
    final value = await showDatePicker(
      context: context,
      initialDate: isFrom ? from : to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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
                to = today;
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
  Widget header(
    Map<String, dynamic> item,
    WorkspaceThemePreset preset,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
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
      const Divider(),
      Text('${item['subject'] ?? '-'}'),
      Text(
        '${dateTime(item['startDateTime'])} - ${dateTime(item['endDateTime'])}',
      ),
    ],
  );
  Widget itemCard(
    Map<String, dynamic> item,
    WorkspaceThemePreset preset,
  ) => InkWell(
    borderRadius: BorderRadius.circular(LaooRadius.xs),
    onTap: () => setState(() => selected = item),
    child: WorkspaceSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.how_to_reg_outlined, color: preset.primary),
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
          const Divider(),
          Text('${item['subject'] ?? '-'}'),
          Text(
            '${dateTime(item['startDateTime'])} - ${dateTime(item['endDateTime'])}',
          ),
          Text(
            'ผู้ได้รับเชิญ ${item['participantCount'] ?? 0} คน | เช็กอินแล้ว ${item['checkedInCount'] ?? 0} คน | ยังไม่เช็กอิน ${item['pendingCheckInCount'] ?? 0} คน',
            style: TextStyle(color: preset.textSecondary),
          ),
        ],
      ),
    ),
  );
  Widget detailView(WorkspaceThemePreset preset) => Padding(
    padding: const EdgeInsets.all(LaooLayout.cardMargin),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkspaceSectionCard(
          child: WorkspaceActionHeader(
            title: '$caption > รายละเอียด',
            favoriteKey: MeetingMenuCodes.attendance,
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => selected = null);
                  load();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('กลับ'),
              ),
            ],
          ),
        ),
        const SizedBox(height: LaooLayout.cardSpacing),
        WorkspaceSectionCard(child: header(selected!, preset)),
        const SizedBox(height: LaooLayout.cardSpacing),
        Expanded(
          child: WorkspaceSectionCard(
            child: SingleChildScrollView(
              child: MeetingAttendancePanel(
                bookingId: (selected!['bookingId'] as num).toInt(),
                slotId: (selected!['slotId'] as num).toInt(),
                repository: repo,
                onMessage: notify,
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget pager() {
    final pages = (total / 20).ceil();
    return SizedBox(
      height: LaooLayout.paginationCardHeight,
      child: Row(
        children: [
          IconButton.filled(
            onPressed: page > 1
                ? () {
                    setState(() => page--);
                    load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          Text('${pages == 0 ? 0 : page} / $pages'),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: page < pages
                ? () {
                    setState(() => page++);
                    load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
          Text('ทั้งหมด $total รายการ'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return buildMeetingWorkspaceShell(
      pageTitle: caption,
      activeMenu: MeetingMenuCodes.attendance,
      child: Stack(
        children: [
          if (selected != null)
            detailView(preset)
          else
            Padding(
              padding: const EdgeInsets.all(LaooLayout.cardMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WorkspaceSectionCard(
                    child: WorkspaceActionHeader(
                      title: caption,
                      favoriteKey: MeetingMenuCodes.attendance,
                      actions: [
                        IconButton(
                          tooltip: 'รีเฟรช',
                          onPressed: load,
                          icon: Icon(Icons.refresh, color: preset.primary),
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
                              'ระบบเช็กชื่อยังไม่พร้อม กรุณาติดต่อผู้ดูแลระบบ',
                            ),
                          )
                        : items.isEmpty
                        ? const Center(
                            child: Text('ไม่พบรายการประชุมในช่วงวันที่เลือก'),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, index) =>
                                itemCard(items[index], preset),
                          ),
                  ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  WorkspaceSectionCard(
                    padding: EdgeInsets.zero,
                    child: pager(),
                  ),
                ],
              ),
            ),
          if (message != null)
            Positioned(
              top: 12,
              right: 12,
              child: AutoDismissMessage(
                message: message!,
                error: messageError,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }
}
