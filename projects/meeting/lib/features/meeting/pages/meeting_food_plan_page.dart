import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/config/api_config.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_food_plan_repository.dart';

class MeetingFoodPlanPage extends StatefulWidget {
  const MeetingFoodPlanPage({super.key});
  @override
  State<MeetingFoodPlanPage> createState() => _MeetingFoodPlanPageState();
}

class _MeetingFoodPlanPageState extends State<MeetingFoodPlanPage> {
  final _repository = MeetingFoodPlanRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, bool> _actions = {};
  Map<String, dynamic>? _detail;
  Set<int> _selectedFoodIds = {};
  DateTime? _cutoff;
  bool _planActive = true;
  bool _loading = true;
  bool _saving = false;
  int _page = 1;
  int _total = 0;
  String _caption = '';
  String? _message;
  bool _messageError = false;

  @override
  void initState() {
    super.initState();
    _loadCaption();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: '13005',
      routeName: 'meetingFoodPlans',
      fallback: 'เมนูอาหารสำหรับการประชุม',
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _repository.list(search: _search.text, page: _page),
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
      _notify(_error(error, 'โหลดข้อมูลไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    setState(() => _loading = true);
    try {
      final detail = await _repository.get((item['bookingId'] as num).toInt());
      final foods = List<Map<String, dynamic>>.from(
        detail['foods'] as List? ?? const [],
      );
      final start = DateTime.parse('${detail['startDateTime']}').toLocal();
      final savedCutoff = DateTime.tryParse('${detail['orderCutoffDateTime']}');
      var defaultCutoff = start.subtract(const Duration(hours: 2));
      final now = DateTime.now();
      if (!defaultCutoff.isAfter(now) && start.isAfter(now)) {
        defaultCutoff = now.add(
          Duration(minutes: start.difference(now).inMinutes ~/ 2),
        );
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _selectedFoodIds = foods
            .where((food) => food['selected'] == true)
            .map((food) => (food['foodId'] as num).toInt())
            .toSet();
        _cutoff = savedCutoff?.toLocal() ?? defaultCutoff;
        _planActive = detail['isActive'] == true || savedCutoff == null;
      });
    } catch (error) {
      _notify(_error(error, 'เปิดข้อมูลไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCutoff() async {
    final now = DateTime.now();
    final selected = _cutoff ?? now.add(const Duration(hours: 1));
    final current = selected.isBefore(now) ? now : selected;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now,
      lastDate: now.add(const Duration(days: 366)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    setState(
      () => _cutoff = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    final detail = _detail;
    if (detail == null || _cutoff == null) return;
    if (_planActive && _selectedFoodIds.isEmpty) {
      _notify('กรุณาเลือกอาหารอย่างน้อย 1 รายการ', true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.save(
        (detail['bookingId'] as num).toInt(),
        cutoff: _cutoff!,
        foodIds: _selectedFoodIds,
        isActive: _planActive,
      );
      if (!mounted) return;
      setState(() => _detail = null);
      _notify('บันทึกเมนูอาหารสำหรับการประชุมสำเร็จ');
      await _load();
    } catch (error) {
      _notify(_error(error, 'บันทึกข้อมูลไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePlan(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: LaooColors.error),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยืนยันการลบเมนูอาหาร',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
          ],
        ),
        content: Text(
          '${item['bookingNo'] ?? '-'} | ${item['subject']}\n'
          'ผู้เข้าร่วมจะไม่เห็นรายการอาหารของการประชุมนี้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: LaooColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.delete((item['bookingId'] as num).toInt());
      _notify('ลบเมนูอาหารสำหรับการประชุมสำเร็จ');
      await _load();
    } catch (error) {
      _notify(_error(error, 'ลบข้อมูลไม่สำเร็จ'), true);
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

  String _imageUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme
        ? uri.toString()
        : Uri.parse(ApiConfig.baseUrl).resolve(value).toString();
  }

  Widget _foodCard(Map<String, dynamic> food, WorkspaceThemePreset preset) {
    final id = (food['foodId'] as num).toInt();
    final selected = _selectedFoodIds.contains(id);
    final image = food['imageUrl']?.toString() ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      onTap: _saving
          ? null
          : () => setState(() {
              selected ? _selectedFoodIds.remove(id) : _selectedFoodIds.add(id);
            }),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? preset.primary.withValues(alpha: .10)
              : LaooColors.white,
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          border: Border.all(
            color: selected ? preset.primary : LaooColors.border,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
              child: image.isEmpty
                  ? Container(
                      width: 56,
                      height: 56,
                      color: preset.primary.withValues(alpha: .08),
                      child: Icon(
                        Icons.restaurant_menu_outlined,
                        color: preset.primary,
                      ),
                    )
                  : Image.network(
                      _imageUrl(image),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${food['code']} | ${food['nameTh']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('${food['foodTypeName'] ?? '-'}'),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              activeColor: preset.primary,
              onChanged: _saving
                  ? null
                  : (_) => setState(
                      () => selected
                          ? _selectedFoodIds.remove(id)
                          : _selectedFoodIds.add(id),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(WorkspaceThemePreset preset) {
    final detail = _detail!;
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
              title: '$_caption > กำหนดเมนู',
              favoriteKey: '13005',
              actions: [
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _detail = null),
                  child: const Text('ยกเลิก'),
                ),
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
                      '${detail['bookingNo'] ?? '-'} | ${detail['subject']}\n${detail['roomCode']} | ${detail['roomName']}\n${_date(detail['startDateTime'])} - ${_date(detail['endDateTime'])}',
                      style: const TextStyle(fontSize: LaooTypography.body),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('เปิดให้ผู้เข้าร่วมสั่งอาหาร'),
                    value: _planActive,
                    activeTrackColor: preset.primary,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _planActive = value),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickCutoff,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text('ปิดรับคำสั่ง: ${_date(_cutoff)}'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'รายการอาหารที่เปิดให้เลือก',
                    style: TextStyle(
                      fontSize: LaooTypography.sectionTitle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...foods.map(
                    (food) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _foodCard(food, preset),
                    ),
                  ),
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
            WorkspacePageTitle(title: _caption, favoriteKey: '13005'),
            const Divider(height: 17, color: LaooColors.border),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 260,
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
                    _page = 1;
                    _load();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('ล้าง Filter'),
                ),
              ],
            ),
            const Divider(height: 17, color: LaooColors.border),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: !_loading && _items.isEmpty
                  ? const Center(
                      child: Text(
                        'ยังไม่มีรายการประชุมที่อนุมัติแล้วและยังไม่สิ้นสุด',
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: Icon(
                              Icons.room_service_outlined,
                              color: preset.primary,
                            ),
                            title: Text(
                              '${item['bookingNo'] ?? '-'} | ${item['subject']}',
                            ),
                            subtitle: Text(
                              '${item['roomCode']} | ${item['roomName']}\n${_date(item['startDateTime'])}\nอาหาร ${(item['foodCount'] as num?)?.toInt() ?? 0} รายการ',
                            ),
                            trailing: Wrap(
                              children: [
                                if ((item['orderCutoffDateTime'] == null &&
                                        _actions['create'] == true) ||
                                    (item['orderCutoffDateTime'] != null &&
                                        _actions['edit'] == true))
                                  IconButton(
                                    tooltip: 'กำหนดเมนู',
                                    onPressed: () => _open(item),
                                    icon: Icon(
                                      Icons.edit_note_outlined,
                                      color: preset.primary,
                                    ),
                                  ),
                                if (item['orderCutoffDateTime'] != null &&
                                    _actions['delete'] == true)
                                  IconButton(
                                    tooltip: 'ลบเมนูอาหาร',
                                    onPressed: () => _deletePlan(item),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: LaooColors.error,
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
                  '${_items.isEmpty ? 0 : (_page - 1) * 20 + 1}-${((_page - 1) * 20 + _items.length)} จาก $_total',
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
        activeMenu: '13005',
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
