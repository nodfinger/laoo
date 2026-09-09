import 'package:flutter/material.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_food_order_summary_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';

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
  Map<String, dynamic>? detail;
  bool loading = true, available = true;
  int page = 1, total = 0;

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

  Future<void> open(Map<String, dynamic> item) async {
    setState(() => loading = true);
    try {
      final data = await repo.get((item['bookingId'] as num).toInt());
      if (mounted) setState(() => detail = data);
    } catch (error) {
      if (mounted) {
        setState(() => message = errorText(error, 'โหลดรายละเอียดไม่สำเร็จ'));
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
                to = today.add(const Duration(days: 30));
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
  Widget itemCard(
    Map<String, dynamic> item,
    WorkspaceThemePreset preset,
  ) => InkWell(
    borderRadius: BorderRadius.circular(LaooRadius.xs),
    onTap: () => open(item),
    child: WorkspaceSectionCard(
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
          const Divider(),
          Text('${item['subject'] ?? '-'}'),
          Text(
            '${dateTime(item['startDateTime'])} - ${dateTime(item['endDateTime'])}',
          ),
          Text(
            'ผู้สั่ง ${item['orderedParticipantCount'] ?? 0} คน | จำนวนรวม ${item['orderedQuantity'] ?? 0}',
            style: TextStyle(color: preset.textSecondary),
          ),
        ],
      ),
    ),
  );
  Widget detailView(WorkspaceThemePreset preset) {
    final header = Map<String, dynamic>.from(detail!['header'] as Map);
    final rows = List<Map<String, dynamic>>.from(
      detail!['items'] as List? ?? const [],
    );
    return Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionCard(
            child: WorkspaceActionHeader(
              title: '$caption > รายละเอียด',
              favoriteKey: MeetingMenuCodes.foodOrderSummary,
              actions: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => detail = null),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('กลับ'),
                ),
              ],
            ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          WorkspaceSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${header['roomCode']} | ${header['roomName']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text('${header['bookingNo'] ?? '-'}'),
                    const SizedBox(width: 8),
                    badge(header['status'] as String?, preset),
                  ],
                ),
                const Divider(),
                Text('${header['subject']}'),
                Text(
                  '${dateTime(header['startDateTime'])} - ${dateTime(header['endDateTime'])}',
                ),
              ],
            ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: WorkspaceSectionCard(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      preset.primary.withValues(alpha: .1),
                    ),
                    columns: const [
                      DataColumn(label: Text('ประเภทอาหาร')),
                      DataColumn(label: Text('รายการอาหาร')),
                      DataColumn(label: Text('ผู้สั่ง'), numeric: true),
                      DataColumn(label: Text('จำนวนรวม'), numeric: true),
                    ],
                    rows: [
                      for (final row in rows)
                        DataRow(
                          cells: [
                            DataCell(Text('${row['foodTypeName'] ?? '-'}')),
                            DataCell(Text('${row['code']} | ${row['nameTh']}')),
                            DataCell(
                              Text('${row['orderedParticipantCount'] ?? 0}'),
                            ),
                            DataCell(Text('${row['orderedQuantity'] ?? 0}')),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      activeMenu: MeetingMenuCodes.foodOrderSummary,
      child: Stack(
        children: [
          if (detail != null)
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
                      favoriteKey: MeetingMenuCodes.foodOrderSummary,
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
                              'ระบบสรุปอาหารยังไม่พร้อม กรุณาติดต่อผู้ดูแลระบบ',
                            ),
                          )
                        : items.isEmpty
                        ? const Center(
                            child: Text(
                              'ไม่พบรายการสั่งอาหารในช่วงวันที่เลือก',
                            ),
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
                error: true,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }
}
