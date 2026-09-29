import 'package:flutter/material.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_food_distribution_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';
import '../widgets/meeting_pagination_card.dart';
import '../widgets/meeting_popup.dart';

class MeetingFoodDistributionPage extends StatefulWidget {
  const MeetingFoodDistributionPage({super.key});
  @override
  State<MeetingFoodDistributionPage> createState() => _State();
}

class _State extends State<MeetingFoodDistributionPage> {
  final repo = MeetingFoodDistributionRepository();
  final search = TextEditingController();
  final today = DateUtils.dateOnly(DateTime.now());
  late DateTime from = today, to = today.add(const Duration(days: 30));
  String caption = 'แจกอาหาร';
  String? message, status;
  List<Map<String, dynamic>> items = [];
  bool loading = true, available = true;
  int page = 1, total = 0;

  @override
  void initState() {
    super.initState();
    NavigationMenuRepository()
        .resolveMenuName(
          menuCode: MeetingMenuCodes.foodDistribution,
          routeName: MeetingRouteNames.foodDistribution,
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
        status: status,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        available = data['available'] != false;
        items = List<Map<String, dynamic>>.from(
          data['items'] as List? ?? const [],
        );
        total = (data['total'] as num?)?.toInt() ?? 0;
        message = null;
      });
    } catch (error) {
      if (mounted)
        setState(
          () => message = errorText(error, 'โหลดรายการแจกอาหารไม่สำเร็จ'),
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String errorText(Object error, String fallback) => error is ApiException
      ? '${error.message}\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาตรวจสิทธิ์และโหลดข้อมูลล่าสุดอีกครั้ง'}'
      : '${fallback}\nรายละเอียดเพิ่มเติม: ไม่สามารถเชื่อมต่อระบบได้ กรุณาลองใหม่อีกครั้ง';
  String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String dateTime(Object? value) {
    final d = DateTime.tryParse('$value')?.toLocal();
    return d == null
        ? '-'
        : '${date(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> pick(bool start) async {
    final value = await showDatePicker(
      context: context,
      initialDate: start ? from : to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (start) {
        from = DateUtils.dateOnly(value);
        if (to.isBefore(from)) to = from;
      } else {
        to = DateUtils.dateOnly(value);
        if (to.isBefore(from)) from = to;
      }
      page = 1;
    });
    load();
  }

  Future<void> detail(Map<String, dynamic> row) async {
    try {
      final data = await repo.detail(
        (row['participantId'] as num).toInt(),
        (row['slotId'] as num).toInt(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _DistributionDialog(
          data: data,
          dateTime: dateTime,
          errorText: errorText,
          onSave: (values) async {
            await repo.save(
              (row['participantId'] as num).toInt(),
              (row['slotId'] as num).toInt(),
              values,
            );
            if (mounted) {
              Navigator.pop(context);
              setState(() => message = 'บันทึกการแจกอาหารแล้ว');
              load();
            }
          },
        ),
      );
    } catch (error) {
      if (mounted)
        setState(
          () =>
              message = errorText(error, 'โหลดรายละเอียดการแจกอาหารไม่สำเร็จ'),
        );
    }
  }

  Widget filters(WorkspaceThemePreset preset) => WorkspaceSectionCard(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => pick(true),
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text('ตั้งแต่ ${date(from)}'),
        ),
        OutlinedButton.icon(
          onPressed: () => pick(false),
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text('ถึง ${date(to)}'),
        ),
        SizedBox(
          width: 210,
          child: TextField(
            controller: search,
            onSubmitted: (_) {
              setState(() => page = 1);
              load();
            },
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'เลขที่จอง/ชื่อ/รหัสพนักงาน',
            ),
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String?>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'สถานะการแจก'),
            items: const [
              DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
              DropdownMenuItem(value: 'PENDING', child: Text('รอแจก')),
              DropdownMenuItem(value: 'PARTIAL', child: Text('แจกบางส่วน')),
              DropdownMenuItem(value: 'COMPLETED', child: Text('แจกครบแล้ว')),
            ],
            onChanged: (v) => setState(() => status = v),
          ),
        ),
        FilledButton.icon(
          onPressed: () {
            setState(() => page = 1);
            load();
          },
          icon: const Icon(Icons.search),
          label: const Text('ค้นหา'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            search.clear();
            setState(() {
              status = null;
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
  );

  Widget card(Map<String, dynamic> row, WorkspaceThemePreset preset) {
    final ordered = (row['orderedQuantity'] as num?)?.toInt() ?? 0;
    final received = (row['receivedQuantity'] as num?)?.toInt() ?? 0;
    final complete = ordered > 0 && received >= ordered;
    final partial = received > 0 && !complete;
    return WorkspaceSectionCard(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row['participantName'] ?? '-'} (${row['employeeCode'] ?? '-'})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('${row['subject']} · ${row['bookingNo']}'),
                Text(
                  '${row['roomCode']} ${row['roomName']} · ${dateTime(row['startDateTime'])} - ${dateTime(row['endDateTime'])}',
                ),
                Text(
                  'เช็กอิน: ${row['checkedIn'] == true ? 'แล้ว' : 'ยังไม่เช็กอิน'} · สั่ง $ordered · รับแล้ว $received · คงเหลือ ${ordered - received}',
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text(
                  complete
                      ? 'แจกครบแล้ว'
                      : partial
                      ? 'แจกบางส่วน'
                      : 'รอแจก',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => detail(row),
                icon: const Icon(Icons.restaurant_outlined),
                label: Text(complete ? 'ดูรายการ' : 'บันทึกรับอาหาร'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget pager(WorkspaceThemePreset preset) {
    final pages = (total / 20).ceil();
    return MeetingPaginationCard(
      showDivider: false,
      total: total,
      pageIndex: page - 1,
      pageSize: 20,
      primary: preset.primary,
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
      activeMenu: MeetingMenuCodes.foodDistribution,
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
                    favoriteKey: MeetingMenuCodes.foodDistribution,
                    actions: const [],
                  ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                filters(preset),
                const SizedBox(height: LaooLayout.cardSpacing),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : !available
                      ? const Center(
                          child: Text(
                            'ระบบรับอาหารยังไม่พร้อม กรุณาติดต่อผู้ดูแลระบบ',
                          ),
                        )
                      : items.isEmpty
                      ? const Center(child: Text('ไม่พบรายการแจกอาหาร'))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: LaooLayout.cardSpacing),
                          itemBuilder: (_, i) => card(items[i], preset),
                        ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                pager(preset),
              ],
            ),
          ),
          if (message != null)
            Positioned(
              top: 12,
              right: 12,
              child: AutoDismissMessage(
                message: message!,
                error:
                    message!.contains('ไม่สำเร็จ') ||
                    message!.contains('ไม่มีสิทธิ์'),
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }
}

class _DistributionDialog extends StatefulWidget {
  const _DistributionDialog({
    required this.data,
    required this.dateTime,
    required this.errorText,
    required this.onSave,
  });
  final Map<String, dynamic> data;
  final String Function(Object?) dateTime;
  final String Function(Object, String) errorText;
  final Future<void> Function(List<Map<String, dynamic>>) onSave;
  @override
  State<_DistributionDialog> createState() => _DistributionDialogState();
}

class _DistributionDialogState extends State<_DistributionDialog> {
  final controllers = <int, TextEditingController>{};
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = Map<String, dynamic>.from(widget.data['header'] as Map);
    final rows = List<Map<String, dynamic>>.from(
      widget.data['items'] as List? ?? const [],
    );
    final canReceive = widget.data['canReceive'] == true;
    return MeetingPopup(
      title: MeetingPopupTitle(
        icon: Icons.restaurant_outlined,
        text: 'แจกอาหาร · ${header['participantName'] ?? '-'}',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${header['subject']} · ${header['bookingNo']}'),
              Text('${header['roomCode']} ${header['roomName']}'),
              Text(
                '${widget.dateTime(header['startDateTime'])} - ${widget.dateTime(header['endDateTime'])}',
              ),
              Text(
                header['checkInDate'] == null
                    ? 'ยังไม่เช็กอิน'
                    : 'เช็กอินแล้ว ${widget.dateTime(header['checkInDate'])}',
              ),
              const Divider(),
              if (!canReceive)
                const Text(
                  'ยังบันทึกรับอาหารไม่ได้: ต้องเช็กอินและอยู่ในช่วงเวลาประชุม',
                ),
              for (final row in rows) ...[
                const SizedBox(height: 10),
                Text(
                  '${row['foodName']} · สั่ง ${row['orderedQuantity']} · รับแล้ว ${row['receivedQuantity']} · คงเหลือ ${row['remainingQuantity']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if ((row['remainingQuantity'] as num? ?? 0) > 0)
                  TextField(
                    controller: controllers.putIfAbsent(
                      (row['foodOrderDetailId'] as num).toInt(),
                      () => TextEditingController(
                        text: '${row['receivedQuantity']}',
                      ),
                    ),
                    enabled: canReceive && !saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ยอดรับสะสมจริง',
                      helperText: 'กรอกยอดรวมที่รับแล้วทั้งหมด',
                    ),
                  ),
              ],
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
        FilledButton.icon(
          onPressed: !canReceive || saving
              ? null
              : () async {
                  setState(() => saving = true);
                  try {
                    await widget.onSave([
                      for (final row in rows)
                        if ((row['remainingQuantity'] as num? ?? 0) > 0)
                          {
                            'foodOrderDetailId': row['foodOrderDetailId'],
                            'receivedQuantity':
                                int.tryParse(
                                  controllers[(row['foodOrderDetailId'] as num)
                                              .toInt()]
                                          ?.text
                                          .trim() ??
                                      '',
                                ) ??
                                -1,
                          },
                    ]);
                  } catch (e) {
                    if (mounted)
                      setState(() {
                        saving = false;
                        error = widget.errorText(e, 'บันทึกรับอาหารไม่สำเร็จ');
                      });
                  }
                },
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'กำลังบันทึก...' : 'บันทึกรับอาหาร'),
        ),
      ],
    );
  }
}
