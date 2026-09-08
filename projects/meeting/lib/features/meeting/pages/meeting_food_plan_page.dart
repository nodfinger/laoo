import 'package:flutter/material.dart';

import '../widgets/meeting_popup.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/config/api_config.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_food_plan_repository.dart';
import '../meeting_feature_host.dart';

class MeetingFoodPlanPage extends StatefulWidget {
  const MeetingFoodPlanPage({
    super.key,
    this.bookingId,
    this.onClose,
    this.parentCaption,
    this.parentMenuCode,
  });
  final int? bookingId;
  final VoidCallback? onClose;
  final String? parentCaption;
  final String? parentMenuCode;
  @override
  State<MeetingFoodPlanPage> createState() => _MeetingFoodPlanPageState();
}

class _MeetingFoodPlanPageState extends State<MeetingFoodPlanPage> {
  final _repository = MeetingFoodPlanRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _detail;
  Set<int> _selectedFoodIds = {};
  final Map<int, TextEditingController> _foodQuantities = {};
  final Set<int> _quantityErrors = {};
  String _foodTypeFilter = '';
  DateTime? _cutoff;
  bool _planActive = true;
  bool _loading = true;
  bool _saving = false;
  int _page = 1;
  int _total = 0;
  String _caption = '';
  String? _message;
  bool _messageError = false;
  String? _foodError;
  String? _cutoffError;
  bool get _canEdit => _detail?['canManageFoodPlan'] == true;

  @override
  void initState() {
    super.initState();
    _loadCaption();
    if (widget.bookingId == null) {
      _load();
    } else {
      _open({'bookingId': widget.bookingId});
    }
  }

  @override
  void dispose() {
    _search.dispose();
    for (final controller in _foodQuantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: '21005',
      routeName: 'meetingFoodPlans',
      fallback: 'เมนูอาหารสำหรับการประชุม',
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _repository.list(search: _search.text, page: _page);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          result['items'] as List? ?? const [],
        );
        _total = (result['total'] as num?)?.toInt() ?? 0;
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
        _foodError = null;
        _cutoffError = null;
        _selectedFoodIds = foods
            .where((food) => food['selected'] == true)
            .map((food) => (food['foodId'] as num).toInt())
            .toSet();
        _foodTypeFilter = '';
        _quantityErrors.clear();
        for (final food in foods) {
          final id = (food['foodId'] as num).toInt();
          _foodQuantities.putIfAbsent(id, () => TextEditingController()).text =
              '${(food['quantity'] as num?)?.toInt() ?? 1}';
        }
        _cutoff = savedCutoff?.toLocal() ?? defaultCutoff;
        _planActive = detail['isActive'] == true || savedCutoff == null;
      });
    } catch (error) {
      _notify(_error(error, 'เปิดข้อมูลไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      setState(() => _detail = null);
      _load();
    }
  }

  Future<void> _pickCutoff() async {
    final now = DateTime.now();
    final selected = _cutoff ?? now.add(const Duration(hours: 1));
    final current = selected.isBefore(now) ? now : selected;
    final preset = workspaceThemeController.value;
    final baseTheme = Theme.of(context);
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now,
      lastDate: now.add(const Duration(days: 366)),
      builder: (context, child) => Theme(
        data: baseTheme.copyWith(
          colorScheme: baseTheme.colorScheme.copyWith(
            primary: preset.primary,
            surface: LaooColors.white,
            onSurface: preset.textPrimary,
            onPrimary: baseTheme.colorScheme.onPrimary,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: LaooColors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
              side: BorderSide.none,
            ),
            headerHelpStyle: LaooTypography.popupTitleStyle,
            dividerColor: LaooColors.border,
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: preset.primary,
              minimumSize: const Size(64, LaooTypography.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: baseTheme.colorScheme.onPrimary,
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
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return preset.textSecondary.withValues(alpha: .45);
              }
              if (states.contains(WidgetState.selected)) {
                return baseTheme.colorScheme.onPrimary;
              }
              return preset.textPrimary;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? preset.primary
                  : Colors.transparent,
            ),
            todayForegroundColor: WidgetStatePropertyAll(preset.primary),
            todayBackgroundColor: WidgetStatePropertyAll(
              preset.primary.withValues(alpha: .10),
            ),
            todayBorder: BorderSide(color: preset.primary),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(foregroundColor: preset.primary),
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) => Theme(
        data: baseTheme.copyWith(
          colorScheme: baseTheme.colorScheme.copyWith(
            primary: preset.primary,
            surface: LaooColors.white,
            onSurface: preset.textPrimary,
            onPrimary: baseTheme.colorScheme.onPrimary,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: LaooColors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: LaooColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
              side: BorderSide.none,
            ),
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            entryModeIconColor: preset.primary,
            helpTextStyle: LaooTypography.popupTitleStyle,
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: preset.primary,
              minimumSize: const Size(64, LaooTypography.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: baseTheme.colorScheme.onPrimary,
              backgroundColor: preset.primary,
              minimumSize: const Size(64, LaooTypography.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: preset.primary,
              minimumSize: const Size(64, LaooTypography.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
          ),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      ),
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
    if (detail == null || !_canEdit) return;
    final start = DateTime.parse('${detail['startDateTime']}').toLocal();
    final quantities = <int, int>{};
    _quantityErrors.clear();
    for (final id in _selectedFoodIds) {
      final value = int.tryParse(_foodQuantities[id]?.text.trim() ?? '');
      if (value == null || value <= 0 || value > 2147483647) {
        _quantityErrors.add(id);
      } else {
        quantities[id] = value;
      }
    }
    setState(() {
      _foodError = _planActive && _selectedFoodIds.isEmpty
          ? 'กรุณาเลือกอาหารอย่างน้อย 1 รายการ'
          : null;
      _cutoffError =
          _cutoff == null ||
              !_cutoff!.isAfter(DateTime.now()) ||
              !_cutoff!.isBefore(start)
          ? 'เวลาปิดรับต้องมากกว่าเวลาปัจจุบันและก่อนเริ่มประชุม'
          : null;
    });
    if (_quantityErrors.isNotEmpty) {
      setState(() {
        _foodTypeFilter = '';
        _foodError =
            'กรุณาระบุจำนวนเต็มมากกว่า 0 และไม่เกิน 2147483647 ในรายการอาหารที่เลือก';
      });
    }
    if (_foodError != null ||
        _cutoffError != null ||
        _quantityErrors.isNotEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.save(
        (detail['bookingId'] as num).toInt(),
        cutoff: _cutoff!,
        foodIds: _selectedFoodIds,
        foodQuantities: quantities,
        isActive: _planActive,
      );
      if (!mounted) return;
      await _open({'bookingId': detail['bookingId']});
      if (!mounted) return;
      _notify('บันทึกเมนูอาหารสำหรับการประชุมสำเร็จ');
    } catch (error) {
      _notify(_error(error, 'บันทึกข้อมูลไม่สำเร็จ'), true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePlan(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => MeetingDeletePopup(
        title: 'ยืนยันการลบเมนูอาหาร',
        record: '${item['bookingNo'] ?? '-'} | ${item['subject']}',
        description: 'ผู้เข้าร่วมจะไม่เห็นรายการอาหารของการประชุมนี้',
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
      onTap: _saving || !_canEdit
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
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _foodQuantities[id],
                enabled: selected && _canEdit && !_saving,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: LaooColors.textPrimary,
                  fontSize: LaooTypography.inputText,
                ),
                decoration: InputDecoration(
                  labelText: 'จำนวน',
                  errorText: selected && _quantityErrors.contains(id)
                      ? 'ระบุจำนวนเต็ม > 0'
                      : null,
                  errorMaxLines: 2,
                ),
                onChanged: (_) => setState(() {
                  _quantityErrors.remove(id);
                }),
              ),
            ),
            Checkbox(
              value: selected,
              activeColor: preset.primary,
              onChanged: _saving || !_canEdit
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
    final foodTypes =
        foods
            .map((food) => '${food['foodTypeName'] ?? ''}'.trim())
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final filteredFoods = _foodTypeFilter.isEmpty
        ? foods
        : foods
              .where(
                (food) =>
                    '${food['foodTypeName'] ?? ''}'.trim() == _foodTypeFilter,
              )
              .toList();
    return Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionCard(
            child: WorkspaceActionHeader(
              title: '${widget.parentCaption ?? _caption} > กำหนดเมนูอาหาร',
              favoriteKey: widget.parentMenuCode ?? '21005',
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: preset.primary,
                    side: BorderSide(color: preset.primary),
                    minimumSize: const Size(0, LaooTypography.buttonHeight),
                    visualDensity: VisualDensity.standard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                  ),
                  onPressed: _saving ? null : _close,
                  child: const Text('ยกเลิก'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: preset.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(0, LaooTypography.buttonHeight),
                    visualDensity: VisualDensity.standard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaooRadius.xs),
                    ),
                  ),
                  onPressed: _saving || !_canEdit ? null : _save,
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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('เปิดให้ผู้เข้าร่วมสั่งอาหาร'),
                      Switch.adaptive(
                        value: _planActive,
                        activeTrackColor: preset.primary,
                        onChanged: _saving || !_canEdit
                            ? null
                            : (value) => setState(() => _planActive = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                  OutlinedButton.icon(
                    onPressed: _saving || !_canEdit ? null : _pickCutoff,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text('ปิดรับคำสั่ง: ${_date(_cutoff)}'),
                  ),
                  if (_cutoffError != null)
                    Text(
                      _cutoffError!,
                      style: const TextStyle(
                        color: LaooColors.error,
                        fontSize: LaooTypography.inputHint,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 280,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_foodTypeFilter),
                      initialValue: _foodTypeFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'ประเภทอาหาร',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('ทั้งหมด'),
                        ),
                        ...foodTypes.map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _foodTypeFilter = value ?? ''),
                    ),
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
                  ...filteredFoods.map(
                    (food) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _foodCard(food, preset),
                    ),
                  ),
                  if (_foodError != null)
                    Text(
                      _foodError!,
                      style: const TextStyle(
                        color: LaooColors.error,
                        fontSize: LaooTypography.inputHint,
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
            WorkspacePageTitle(title: _caption, favoriteKey: '21005'),
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
                                if (item['canManageFoodPlan'] == true)
                                  IconButton(
                                    tooltip: 'กำหนดเมนู',
                                    onPressed: () => _open(item),
                                    icon: Icon(
                                      Icons.edit_note_outlined,
                                      color: preset.primary,
                                    ),
                                  ),
                                if (item['canDeleteFoodPlan'] == true)
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
      builder: (context, preset, _) {
        final content = Stack(
          children: [
            if (_detail != null)
              _action(preset)
            else if (widget.bookingId == null)
              _list(preset)
            else
              Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('ไม่สามารถเปิดชุดอาหารของการจองนี้ได้'),
                          OutlinedButton(
                            onPressed: _close,
                            child: const Text('กลับรายการจอง'),
                          ),
                          TextButton(
                            onPressed: () =>
                                _open({'bookingId': widget.bookingId}),
                            child: const Text('ลองใหม่'),
                          ),
                        ],
                      ),
              ),
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
        );
        return widget.bookingId != null
            ? content
            : buildMeetingWorkspaceShell(
                pageTitle: _caption,
                activeMenu: '21005',
                child: content,
              );
      },
    );
  }
}
