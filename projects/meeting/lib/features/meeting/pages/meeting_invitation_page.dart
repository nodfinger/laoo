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
  Map<String, bool> _actions = {};
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
      final values = await Future.wait([
        _repository.list(
          search: _search.text,
          status: _filterStatus,
          page: _page,
        ),
        _repository.actions(),
      ]);
      if (!mounted) return;
      final result = values[0];
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          result['items'] as List? ?? const [],
        );
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _actions = values[1] as Map<String, bool>;
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
                if (_actions['edit'] == true)
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
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
                      '${_date(invitation['startDateTime'])} - ${_date(invitation['endDateTime'])}\n'
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
                          ('DECLINED', 'ไม่เข้าร่วม', Icons.cancel_outlined),
                        ].map((option) {
                          final selected = _responseStatus == option.$1;
                          return ChoiceChip(
                            selected: selected,
                            selectedColor: preset.primary.withValues(
                              alpha: .15,
                            ),
                            avatar: Icon(
                              option.$3,
                              color: option.$1 == 'DECLINED'
                                  ? LaooColors.error
                                  : preset.primary,
                            ),
                            label: Text(option.$2),
                            onSelected: _saving
                                ? null
                                : (_) => setState(
                                    () => _responseStatus = option.$1,
                                  ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _remark,
                    maxLines: 3,
                    style: const TextStyle(fontSize: LaooTypography.inputText),
                    decoration: const InputDecoration(
                      labelText: 'หมายเหตุการตอบรับ',
                    ),
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
      child: WorkspaceSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkspacePageTitle(title: _caption, favoriteKey: '21003'),
            const Divider(height: 17, color: LaooColors.border),
            LayoutBuilder(
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
                        suffixIcon: Icon(Icons.arrow_forward),
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
            const Divider(height: 17, color: LaooColors.border),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: !_loading && _items.isEmpty
                  ? const Center(
                      child: Text('ยังไม่มีคำเชิญที่รอตอบรับหรือกำลังจะมาถึง'),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final status = '${item['invitationStatus']}';
                        final color = _statusColor(status, preset);
                        return Card(
                          margin: EdgeInsets.zero,
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
                              '${_date(item['startDateTime'])}\n'
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
            const Divider(height: 17, color: LaooColors.border),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _page > 1
                      ? () {
                          setState(() => _page--);
                          _load();
                        }
                      : null,
                  child: const Icon(Icons.chevron_left),
                ),
                FilledButton(
                  onPressed: null,
                  child: Text('${pageCount == 0 ? 0 : _page}'),
                ),
                OutlinedButton(
                  onPressed: _page < pageCount
                      ? () {
                          setState(() => _page++);
                          _load();
                        }
                      : null,
                  child: const Icon(Icons.chevron_right),
                ),
                Text(
                  '${_items.isEmpty ? 0 : (_page - 1) * 20 + 1}-${(_page - 1) * 20 + _items.length} จาก $_total',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, preset, _) => SupportWorkspaceShell(
        menuScope: WorkspaceMenuScope.company,
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
