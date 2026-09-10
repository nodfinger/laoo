import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/config/api_config.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_invitation_repository.dart';
import '../meeting_feature_host.dart';
import '../widgets/meeting_attendance_panel.dart';
import '../widgets/meeting_pagination_card.dart';

class MeetingInvitationPage extends StatefulWidget {
  const MeetingInvitationPage({super.key});
  @override
  State<MeetingInvitationPage> createState() => _MeetingInvitationPageState();
}

class _MeetingInvitationPageState extends State<MeetingInvitationPage> {
  final _repository = MeetingInvitationRepository();
  final _search = TextEditingController();
  final _remark = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<int, int> _foodQuantities = {};
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
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _responseStatus = '${invitation['invitationStatus'] ?? 'PENDING'}';
        _remark.text = '${invitation['remark'] ?? ''}';
        _foodQuantities = {
          for (final food in List<Map<String, dynamic>>.from(
            detail['foods'] as List? ?? const [],
          ))
            (food['foodId'] as num).toInt():
                (food['orderQuantity'] as num?)?.toInt() ?? 0,
        };
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
    setState(() => _saving = true);
    try {
      await _repository.respond(
        (invitation['participantId'] as num).toInt(),
        status: _responseStatus,
        remark: _remark.text.trim(),
      );
      if (!mounted) return;
      setState(() => _detail = null);
      _notify('บันทึกการตอบรับสำเร็จ');
      await _load();
    } catch (error) {
      _notify(_error(error, 'บันทึกการตอบรับไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveFoodOrder() async {
    final detail = _detail;
    if (detail == null) return;
    final invitation = Map<String, dynamic>.from(detail['invitation'] as Map);
    setState(() => _saving = true);
    try {
      await _repository.saveFoodOrder(
        (invitation['participantId'] as num).toInt(),
        quantities: _foodQuantities,
      );
      if (!mounted) return;
      _notify('บันทึกรายการอาหารสำเร็จ');
      await _open({'participantId': invitation['participantId']});
    } catch (error) {
      _notify(_error(error, 'บันทึกรายการอาหารไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _saving = false);
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

  String _statusName(String value) => switch (value) {
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

  Widget _action(WorkspaceThemePreset preset) {
    final detail = _detail!;
    final invitation = Map<String, dynamic>.from(detail['invitation'] as Map);
    final foods = List<Map<String, dynamic>>.from(
      detail['foods'] as List? ?? const [],
    );
    final canRespond = invitation['canRespond'] == true;
    final canOrder = invitation['canOrder'] == true;
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
                if (canOrder)
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveFoodOrder,
                    icon: const Icon(Icons.restaurant_menu_outlined),
                    label: const Text('บันทึกรายการอาหาร'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: LaooColors.border),
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
                      'ผู้จัด: ${invitation['organizerName'] ?? '-'}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'การตอบรับ',
                    style: TextStyle(
                      fontSize: LaooTypography.sectionTitle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
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
                          final color = isDeclined
                              ? LaooColors.error
                              : preset.primary;
                          return SizedBox(
                            height: LaooTypography.buttonHeight,
                            child: OutlinedButton.icon(
                              onPressed: _saving || !canRespond || selected
                                  ? null
                                  : () => setState(
                                      () => _responseStatus = option.$1,
                                    ),
                              icon: Icon(option.$3),
                              label: Text(option.$2),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: selected
                                    ? (isDeclined
                                          ? Colors.white
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onPrimary)
                                    : color,
                                backgroundColor: selected
                                    ? (isDeclined
                                          ? LaooColors.error
                                          : preset.primary)
                                    : Colors.white,
                                disabledForegroundColor: selected
                                    ? (isDeclined
                                          ? Colors.white
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onPrimary)
                                    : color.withValues(alpha: .45),
                                disabledBackgroundColor: selected
                                    ? (isDeclined
                                          ? LaooColors.error
                                          : preset.primary)
                                    : Colors.white,
                                side: BorderSide(color: color),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    LaooRadius.xs,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: LaooTypography.button,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (!canRespond) ...[
                    Text(
                      '${invitation['responseUnavailableReason'] ?? 'คำเชิญนี้ไม่สามารถเปลี่ยนการตอบรับได้ กรุณาโหลดข้อมูลใหม่หรือติดต่อผู้ดูแลระบบ'}',
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _remark,
                    maxLines: 3,
                    readOnly: !canRespond,
                    style: const TextStyle(fontSize: LaooTypography.inputText),
                    decoration: const InputDecoration(
                      labelText: 'หมายเหตุการตอบรับ',
                    ),
                  ),
                  MeetingAttendancePanel(
                    key: ValueKey((
                      invitation['bookingId'],
                      invitation['participantId'],
                    )),
                    bookingId: (invitation['bookingId'] as num).toInt(),
                    participantId: (invitation['participantId'] as num).toInt(),
                    onMessage: (message, error) => _notify(message, error),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu_outlined,
                        color: preset.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'เมนูอาหารของการประชุม',
                          style: TextStyle(
                            fontSize: LaooTypography.sectionTitle,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    foods.isEmpty
                        ? 'ผู้จัดยังไม่ได้เปิดเมนูอาหาร'
                        : 'ปิดรับ ${_date(invitation['orderCutoffDateTime'])}',
                    style: TextStyle(color: preset.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ...foods.map((food) {
                    final foodId = (food['foodId'] as num).toInt();
                    final quantity = _foodQuantities[foodId] ?? 0;
                    final image = '${food['imageUrl'] ?? ''}';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: image.isEmpty
                            ? Icon(
                                Icons.restaurant_outlined,
                                color: preset.primary,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                                child: Image.network(
                                  _imageUrl(image),
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                        title: Text('${food['code']} | ${food['nameTh']}'),
                        subtitle: Text('${food['foodTypeName'] ?? '-'}'),
                        trailing: canOrder
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'ลดจำนวน',
                                    onPressed: _saving || quantity == 0
                                        ? null
                                        : () => setState(
                                            () => _foodQuantities[foodId] =
                                                quantity - 1,
                                          ),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text('$quantity'),
                                  IconButton(
                                    tooltip: 'เพิ่มจำนวน',
                                    onPressed: _saving || quantity >= 99
                                        ? null
                                        : () => setState(
                                            () => _foodQuantities[foodId] =
                                                quantity + 1,
                                          ),
                                    icon: Icon(
                                      Icons.add_circle_outline,
                                      color: preset.primary,
                                    ),
                                  ),
                                ],
                              )
                            : quantity > 0
                            ? Text('จำนวน $quantity')
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
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
                                title: Text(
                                  '${item['bookingNo'] ?? '-'} | ${item['subject']}',
                                ),
                                subtitle: Text(
                                  '${item['roomCode']} | ${item['roomName']}\n'
                                  '${_meetingPeriod(item)}\n'
                                  'ผู้จัด: ${item['organizerName'] ?? '-'}',
                                ),
                                trailing: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
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
                                        _statusName(status),
                                        style: TextStyle(color: color),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'เปิดคำเชิญ',
                                      onPressed: () => _open(item),
                                      icon: Icon(
                                        Icons.chevron_right,
                                        color: preset.primary,
                                      ),
                                    ),
                                  ],
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
