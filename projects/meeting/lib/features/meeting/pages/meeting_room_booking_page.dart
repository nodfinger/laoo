import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/config/api_config.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../../core/widgets/combo_box_text.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_room_booking_repository.dart';
import '../widgets/meeting_room_calendar_view.dart';

class MeetingRoomBookingPage extends StatefulWidget {
  const MeetingRoomBookingPage({
    super.key,
    this.initialCalendar = false,
    this.menuCode = '21001',
  });

  final bool initialCalendar;
  final String menuCode;

  @override
  State<MeetingRoomBookingPage> createState() => _MeetingRoomBookingPageState();
}

class _MeetingRoomBookingPageState extends State<MeetingRoomBookingPage> {
  final _repository = MeetingRoomBookingRepository();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _attendeeCount = TextEditingController(text: '1');
  final _remark = TextEditingController();

  String _caption = '';
  late String _workspaceMode;
  String _searchMode = 'DATE';
  bool _multipleDays = false;
  bool _awaitingRangeEnd = false;
  bool _loading = true;
  bool _searching = false;
  bool _saving = false;
  bool _roomScheduleLoading = false;
  bool _roomBookingCalendarVisible = false;
  bool _myBookingsOnly = false;
  OverlayEntry? _notificationOverlay;
  String? _subjectError;
  String? _attendeeError;
  String? _timeError;

  Map<String, bool> _actions = {};
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _buildings = [];
  List<Map<String, dynamic>> _floors = [];
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _availableRooms = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _roomScheduleBookings = [];
  final Set<int> _expandedConflictRooms = <int>{};

  int? _branchId;
  int? _buildingId;
  int? _floorId;
  int? _selectedRoomId;
  int? _editingId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  int _page = 1;
  int _total = 0;
  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _workspaceMode = widget.initialCalendar ? 'CALENDAR' : 'BOOKING';
    _setInitialDateTime();
    _load();
    _loadCaption();
  }

  @override
  void dispose() {
    _notificationOverlay?.remove();
    _repository.dispose();
    _subject.dispose();
    _description.dispose();
    _attendeeCount.dispose();
    _remark.dispose();
    super.dispose();
  }

  void _setInitialDateTime() {
    final now = DateTime.now();
    var minuteOfDay = now.hour * 60 + now.minute;
    minuteOfDay = ((minuteOfDay + 19) ~/ 5) * 5;
    if (minuteOfDay + 60 >= 24 * 60) {
      _startDate = DateTime(now.year, now.month, now.day + 1);
      _endDate = _startDate;
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
      return;
    }
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate;
    _startTime = TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60);
    final end = minuteOfDay + 60;
    _endTime = TimeOfDay(hour: end ~/ 60, minute: end % 60);
  }

  Future<void> _loadCaption() async {
    final caption = await NavigationMenuRepository().resolveMenuName(
      menuCode: widget.menuCode,
      routeName: widget.initialCalendar
          ? 'meetingRoomCalendar'
          : 'meetingRoomBookings',
      fallback: widget.initialCalendar ? 'ปฏิทินห้องประชุม' : 'จองห้องประชุม',
    );
    if (mounted) setState(() => _caption = caption);
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repository.actions(),
        _repository.options(),
      ]);
      final options = Map<String, dynamic>.from(results[1] as Map);
      if (!mounted) return;
      setState(() {
        _actions = Map<String, bool>.from(results[0] as Map);
        _branches = _maps(options['branches']);
        _buildings = _maps(options['buildings']);
        _floors = _maps(options['floors']);
        _rooms = _maps(options['rooms']);
      });
      if (!widget.initialCalendar) {
        await Future.wait([_loadBookings(), _searchAvailableRooms()]);
      }
    } catch (error) {
      _showError(error, 'โหลดข้อมูลหน้าจองห้องประชุมไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBookings() async {
    final result = await _repository.list(
      dateFrom: DateTime.now(),
      dateTo: DateTime.now().add(const Duration(days: 90)),
      page: _page,
      pageSize: _pageSize,
      mine: _myBookingsOnly,
    );
    if (!mounted) return;
    setState(() {
      _bookings = _maps(result['items']);
      _total = _int(result['total']) ?? 0;
    });
  }

  Future<void> _toggleMyBookings() async {
    setState(() {
      _myBookingsOnly = !_myBookingsOnly;
      _page = 1;
      _loading = true;
    });
    try {
      await _loadBookings();
    } catch (error) {
      _showError(error, 'โหลดการจองของฉันไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRoomScheduleBookings() async {
    if (_roomScheduleLoading) return;
    setState(() => _roomScheduleLoading = true);
    try {
      final items = <Map<String, dynamic>>[];
      var page = 1;
      var total = 0;
      do {
        final result = await _repository.list(
          dateFrom: DateTime.now(),
          dateTo: DateTime.now().add(const Duration(days: 365)),
          page: page,
          pageSize: 100,
        );
        final pageItems = _maps(result['items']);
        if (pageItems.isEmpty) break;
        items.addAll(pageItems);
        total = _int(result['total']) ?? items.length;
        page++;
      } while (items.length < total);
      if (!mounted) return;
      setState(() => _roomScheduleBookings = items);
    } catch (error) {
      _showError(error, 'โหลดตารางการจองตามห้องประชุมไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _roomScheduleLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRooms => _rooms.where((room) {
    if (_branchId != null && _int(room['branchId']) != _branchId) return false;
    if (_buildingId != null && _int(room['buildingId']) != _buildingId) {
      return false;
    }
    if (_floorId != null && _int(room['floorId']) != _floorId) return false;
    return true;
  }).toList();

  List<Map<String, dynamic>> get _filteredBuildings => _buildings
      .where(
        (building) =>
            _branchId == null || _int(building['branchId']) == _branchId,
      )
      .toList();

  List<Map<String, dynamic>> get _filteredFloors => _floors
      .where(
        (floor) =>
            _buildingId == null || _int(floor['buildingId']) == _buildingId,
      )
      .toList();

  String get _selectedDateLabel => _multipleDays
      ? '${_formatDate(_startDate)} - ${_formatDate(_endDate)}'
      : _formatDate(_startDate);

  List<Map<String, String>> _slotPayload() {
    final result = <Map<String, String>>[];
    final lastDate = _multipleDays ? _endDate : _startDate;
    for (
      var date = _date(_startDate);
      !date.isAfter(_date(lastDate));
      date = date.add(const Duration(days: 1))
    ) {
      result.add({
        'startDateTime': _combine(date, _startTime).toIso8601String(),
        'endDateTime': _combine(date, _endTime).toIso8601String(),
      });
    }
    return result;
  }

  String? _timeValidation() {
    final startError = _startTimeValidation();
    if (startError != null) return startError;
    final start = _startTime.hour * 60 + _startTime.minute;
    final end = _endTime.hour * 60 + _endTime.minute;
    if (end <= start) return 'เวลาสิ้นสุดต้องมากกว่าเวลาเริ่ม';
    if (_multipleDays && _endDate.isBefore(_startDate)) {
      return 'วันที่สิ้นสุดต้องไม่น้อยกว่าวันที่เริ่ม';
    }
    return null;
  }

  String? _startTimeValidation() {
    final now = DateTime.now();
    if (_date(_startDate) == _date(now) &&
        _combine(_startDate, _startTime).isBefore(now)) {
      return 'เวลาเริ่มต้องไม่น้อยกว่าเวลาปัจจุบัน';
    }
    return null;
  }

  Future<void> _searchAvailableRooms({int? roomId}) async {
    final timeError = _timeValidation();
    if (timeError != null) {
      _showMessage(timeError, error: true);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await _repository.availability(
        slots: _slotPayload(),
        roomId: roomId,
        branchId: _branchId,
        buildingId: _buildingId,
        floorId: _floorId,
        attendeeCount: int.tryParse(_attendeeCount.text.trim()),
        excludeBookingId: _editingId,
      );
      if (!mounted) return;
      setState(() => _availableRooms = result);
    } catch (error) {
      _showError(error, 'ตรวจสอบห้องว่างไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectCalendarDate(DateTime value) async {
    final selected = _date(value);
    var rangeComplete = false;
    setState(() {
      if (!_multipleDays) {
        _startDate = selected;
        _endDate = selected;
      } else if (!_awaitingRangeEnd) {
        _startDate = selected;
        _endDate = selected;
        _awaitingRangeEnd = true;
      } else {
        if (selected.isBefore(_startDate)) {
          _startDate = selected;
          _endDate = selected;
        } else {
          _endDate = selected;
        }
        _awaitingRangeEnd = false;
      }
      rangeComplete = !_multipleDays || !_awaitingRangeEnd;
      _availableRooms = [];
    });
    if (!rangeComplete || _timeValidation() != null) return;
    if (_searchMode == 'ROOM' && _selectedRoomId == null) return;
    await _searchAvailableRooms(
      roomId: _searchMode == 'ROOM' ? _selectedRoomId : null,
    );
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _startTime : _endTime;
    final preset = workspaceThemeController.value;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final value = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: start
          ? 'เลือกเวลาเริ่ม\nประเภทเวลาที่จอง: เวลาเริ่ม'
          : 'เริ่ม ${_formatTime(_startTime)}  |  สิ้นสุด\nประเภทเวลาที่จอง: เวลาสิ้นสุด',
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: preset.primary,
            surface: LaooColors.white,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: LaooColors.white,
            helpTextStyle: TextStyle(
              color: preset.primary,
              fontSize: LaooTypography.sectionTitle,
            ),
            hourMinuteShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
              side: const BorderSide(color: LaooColors.border),
            ),
            dayPeriodBorderSide: const BorderSide(color: LaooColors.border),
            dayPeriodShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
              side: const BorderSide(color: LaooColors.border),
            ),
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: preset.primary,
              minimumSize: const Size(64, LaooTypography.buttonHeight),
              side: BorderSide(color: preset.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: onPrimary,
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
          child: Stack(children: [child!]),
        ),
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (start) {
        _startTime = value;
      } else {
        _endTime = value;
      }
      _availableRooms = [];
      _timeError = _timeValidation();
    });
    if (start) {
      final startError = _startTimeValidation();
      if (startError != null) {
        _showMessage(startError, error: true);
        return;
      }
    }
    _showMessage(
      start
          ? 'เลือกเวลาเริ่มแล้ว กรุณาเลือกเวลาสิ้นสุด'
          : 'กำหนดช่วงเวลาเรียบร้อยแล้ว',
    );
    if (start && mounted) {
      await _pickTime(start: false);
    } else if (!start && _timeError == null && mounted) {
      await _searchAvailableRooms(
        roomId: _searchMode == 'ROOM' ? _selectedRoomId : null,
      );
    } else if (!start && _timeError != null) {
      _showMessage(_timeError!, error: true);
    }
  }

  // ignore: unused_element
  Future<void> _pickTimeRange() async {
    var start = _startTime;
    var end = _endTime;
    final result = await showDialog<List<TimeOfDay>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('กำหนดเวลา'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _timeField(
                label: 'เวลาเริ่ม *',
                value: start,
                onTap: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: start,
                    initialEntryMode: TimePickerEntryMode.dial,
                  );
                  if (value != null) refresh(() => start = value);
                },
              ),
              const SizedBox(height: 8),
              _timeField(
                label: 'เวลาสิ้นสุด *',
                value: end,
                onTap: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: end,
                    initialEntryMode: TimePickerEntryMode.dial,
                  );
                  if (value != null) refresh(() => end = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, [start, end]),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _startTime = result[0];
      _endTime = result[1];
      _availableRooms = [];
    });
  }

  void _selectRoom(Map<String, dynamic> room) {
    setState(() {
      _selectedRoomId = _int(room['roomId']);
      _branchId = _int(room['branchId']);
      _buildingId = _int(room['buildingId']);
      _floorId = _int(room['floorId']);
    });
  }

  Future<void> _openBookingDialog(Map<String, dynamic> room) async {
    _selectRoom(room);
    await _showBookingDialog();
  }

  Future<void> _startBookingFromCalendar(DateTime date, int? roomId) async {
    final selectedDate = _date(date);
    Map<String, dynamic>? room;
    if (roomId != null) {
      for (final item in _rooms) {
        if (_int(item['roomId']) == roomId) {
          room = item;
          break;
        }
      }
    }
    setState(() {
      _workspaceMode = 'BOOKING';
      _startDate = selectedDate;
      _endDate = selectedDate;
      _multipleDays = false;
      _awaitingRangeEnd = false;
      _availableRooms = [];
      if (room != null) {
        _selectedRoomId = roomId;
        _branchId = _int(room['branchId']);
        _buildingId = _int(room['buildingId']);
        _floorId = _int(room['floorId']);
      }
    });
    await _searchAvailableRooms(roomId: roomId);
    if (!mounted || room == null) return;
    final availability = _selectedAvailability;
    if (availability?['isAvailable'] == true) {
      await _showBookingDialog();
    } else {
      _showMessage(
        availability?['unavailableReason']?.toString() ??
            'ห้องไม่ว่างในช่วงเวลาที่เลือก',
        error: true,
      );
    }
  }

  Future<void> _showBookingDialog({VoidCallback? onCancelled}) async {
    if (_selectedRoom == null) return;
    final preset = workspaceThemeController.value;
    var saved = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => Dialog(
          backgroundColor: LaooColors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.sm),
            side: BorderSide.none,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 820),
            child: Padding(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        _editingId == null
                            ? Icons.add_task
                            : Icons.edit_calendar_outlined,
                        color: preset.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _editingId == null
                              ? 'จองห้องประชุม'
                              : 'แก้ไขการจองห้องประชุม',
                          style: LaooTypography.popupTitleStyle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: LaooColors.border),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: InputDecorationTheme(
                            filled: true,
                            fillColor: LaooColors.white,
                            labelStyle: TextStyle(color: preset.primary),
                            floatingLabelStyle: TextStyle(
                              color: preset.primary,
                              fontSize: LaooTypography.inputLabel,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                              borderSide: const BorderSide(
                                color: LaooColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                              borderSide: const BorderSide(
                                color: LaooColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                              borderSide: BorderSide(
                                color: preset.primary,
                                width: 1.25,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                                width: 1.25,
                              ),
                            ),
                          ),
                        ),
                        child: _bookingForm(preset, refresh),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: LaooColors.border),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: preset.primary,
                          minimumSize: const Size(96, 48),
                          side: BorderSide(color: preset.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(dialogContext),
                        child: const Text('ยกเลิก'),
                      ),
                      const SizedBox(width: 8),
                      if ((_editingId == null && _actions['create'] == true) ||
                          (_editingId != null && _actions['edit'] == true))
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: preset.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            minimumSize: const Size(110, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          onPressed: _saving
                              ? null
                              : () async {
                                  refresh(() => _saving = true);
                                  final success = await _save();
                                  if (!dialogContext.mounted) return;
                                  refresh(() => _saving = false);
                                  if (success) {
                                    saved = true;
                                    Navigator.pop(dialogContext);
                                  }
                                },
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!saved && mounted) {
      if (onCancelled != null) {
        onCancelled();
      } else {
        _resetForm();
      }
    }
  }

  Map<String, dynamic>? get _selectedRoom {
    for (final room in _rooms) {
      if (_int(room['roomId']) == _selectedRoomId) return room;
    }
    return null;
  }

  Map<String, dynamic>? get _selectedAvailability {
    for (final room in _availableRooms) {
      if (_int(room['roomId']) == _selectedRoomId) return room;
    }
    return null;
  }

  Future<bool> _save() async {
    final subject = _subject.text.trim();
    final attendee = int.tryParse(_attendeeCount.text.trim());
    setState(() {
      _subjectError = subject.isEmpty ? 'กรุณาระบุหัวข้อประชุม' : null;
      _attendeeError = attendee == null || attendee <= 0
          ? 'กรุณาระบุจำนวนผู้เข้าร่วมมากกว่า 0'
          : null;
    });
    if (_subjectError != null || _attendeeError != null) return false;
    if (_selectedRoomId == null) {
      _showMessage('กรุณาเลือกห้องประชุม', error: true);
      return false;
    }
    final timeError = _timeValidation();
    if (timeError != null) {
      _showMessage(timeError, error: true);
      return false;
    }
    await _searchAvailableRooms(roomId: _selectedRoomId);
    final availability = _selectedAvailability;
    if (availability == null || availability['isAvailable'] != true) {
      _showMessage(
        availability?['unavailableReason']?.toString() ??
            'ห้องไม่ว่างในช่วงเวลาที่เลือก',
        error: true,
      );
      return false;
    }
    setState(() => _saving = true);
    try {
      final savedRoomId = _selectedRoomId;
      final result = await _repository.save({
        'roomId': _selectedRoomId,
        'subject': subject,
        'description': _description.text.trim(),
        'attendeeCount': attendee,
        'slots': _slotPayload(),
        'remark': _remark.text.trim(),
      }, id: _editingId);
      final status = result['status'] == 'APPROVED'
          ? 'อนุมัติอัตโนมัติแล้ว'
          : 'ส่งคำขออนุมัติแล้ว';
      _showMessage('บันทึกการจองสำเร็จ ($status)');
      _resetForm(keepSchedule: true);
      if (_searchMode == 'ROOM') {
        setState(() {
          _selectedRoomId = savedRoomId;
          _roomBookingCalendarVisible = false;
        });
        await Future.wait([_loadBookings(), _loadRoomScheduleBookings()]);
      } else {
        await Future.wait([_loadBookings(), _searchAvailableRooms()]);
      }
      return true;
    } catch (error) {
      _showError(error, 'บันทึกการจองไม่สำเร็จ');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editBooking(Map<String, dynamic> item) async {
    final id = _int(item['bookingId']);
    if (id == null) return;
    final previousRoomId = _selectedRoomId;
    final previousStartDate = _startDate;
    final previousEndDate = _endDate;
    final previousMultipleDays = _multipleDays;
    final previousAwaitingRangeEnd = _awaitingRangeEnd;
    final previousStartTime = _startTime;
    final previousEndTime = _endTime;
    final previousAttendeeCount = _attendeeCount.text;
    try {
      final data = await _repository.get(id);
      final booking = Map<String, dynamic>.from(data['booking'] as Map);
      final slots = _maps(data['slots']);
      if (slots.isEmpty || !mounted) return;
      final first = DateTime.parse('${slots.first['startDateTime']}');
      final last = DateTime.parse('${slots.last['endDateTime']}');
      _editingId = id;
      _selectedRoomId = _int(booking['roomId']);
      _subject.text = booking['subject']?.toString() ?? '';
      _description.text = booking['description']?.toString() ?? '';
      _attendeeCount.text = '${booking['attendeeCount'] ?? 1}';
      _remark.text = booking['remark']?.toString() ?? '';
      _startDate = _date(first);
      _endDate = _date(last);
      _multipleDays = slots.length > 1;
      _awaitingRangeEnd = false;
      _startTime = TimeOfDay(hour: first.hour, minute: first.minute);
      _endTime = TimeOfDay(hour: last.hour, minute: last.minute);
      await _showBookingDialog(
        onCancelled: () => setState(() {
          _editingId = null;
          _selectedRoomId = previousRoomId;
          _startDate = previousStartDate;
          _endDate = previousEndDate;
          _multipleDays = previousMultipleDays;
          _awaitingRangeEnd = previousAwaitingRangeEnd;
          _startTime = previousStartTime;
          _endTime = previousEndTime;
          _attendeeCount.text = previousAttendeeCount;
          _subject.clear();
          _description.clear();
          _remark.clear();
          _subjectError = null;
          _attendeeError = null;
        }),
      );
    } catch (error) {
      _showError(error, 'โหลดรายการจองไม่สำเร็จ');
    }
  }

  Future<void> _confirmCancel(Map<String, dynamic> item) async {
    final preset = workspaceThemeController.value;
    final id = _int(item['bookingId']);
    if (id == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'ยืนยันการยกเลิกการจอง',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
          ],
        ),
        content: Text(
          'ต้องการยกเลิก ${item['bookingNo'] ?? ''} - ${item['subject'] ?? ''} หรือไม่?\nข้อมูลที่ยกเลิกแล้วจะไม่ใช้ตรวจเวลาชน',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('ยกเลิก', style: TextStyle(color: preset.primary)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await _repository.cancel(id);
      _showMessage('ยกเลิกรายการจองสำเร็จ');
      await Future.wait([
        _loadBookings(),
        _searchAvailableRooms(),
        if (_searchMode == 'ROOM') _loadRoomScheduleBookings(),
      ]);
    } catch (error) {
      _showError(error, 'ยกเลิกรายการจองไม่สำเร็จ');
    }
  }

  Future<void> _confirmRollback(Map<String, dynamic> item) async {
    final id = _int(item['bookingId']);
    if (id == null) return;
    final remarkController = TextEditingController();
    final preset = workspaceThemeController.value;
    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการถอยสถานะ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ระบบจะเปลี่ยนรายการกลับเป็นรออนุมัติ และให้ผู้อนุมัติพิจารณาใหม่',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarkController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'หมายเหตุ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'ยกเลิก',
              style: TextStyle(color: workspaceThemeController.value.primary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: preset.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, remarkController.text.trim()),
            child: const Text('ถอยสถานะ'),
          ),
        ],
      ),
    );
    remarkController.dispose();
    if (remark == null) return;
    try {
      await _repository.rollback(id, remark: remark);
      _showMessage('ถอยสถานะการจองสำเร็จ');
      await Future.wait([
        _loadBookings(),
        _searchAvailableRooms(),
        if (_searchMode == 'ROOM') _loadRoomScheduleBookings(),
      ]);
    } catch (error) {
      _showError(error, 'ถอยสถานะการจองไม่สำเร็จ');
    }
  }

  Future<void> _showParticipantDialog(Map<String, dynamic> item) async {
    final bookingId = _int(item['bookingId']);
    if (bookingId == null) return;
    final preset = workspaceThemeController.value;
    try {
      final data = await _repository.participants(bookingId);
      if (!mounted) return;
      final employees = _maps(data['employees']);
      final selected = employees
          .where((employee) => employee['selected'] == true)
          .map((employee) => _int(employee['employeeId']))
          .whereType<int>()
          .toSet();
      final searchController = TextEditingController();
      var keyword = '';
      int? departmentId;
      final departmentMap = <int, String>{};
      for (final employee in employees) {
        final id = _int(employee['departmentOrgUnitId']);
        final name = employee['departmentName']?.toString().trim() ?? '';
        if (id != null && name.isNotEmpty) departmentMap[id] = name;
      }
      final departments = departmentMap.entries.toList()
        ..sort((left, right) => left.value.compareTo(right.value));
      final screen = MediaQuery.sizeOf(context);
      final dialogWidth = screen.width < 720 ? screen.width - 64 : 650.0;
      final dialogHeight = screen.height < 680 ? screen.height - 190 : 480.0;
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, refresh) {
            final filtered = employees.where((employee) {
              if (departmentId != null &&
                  _int(employee['departmentOrgUnitId']) != departmentId) {
                return false;
              }
              if (keyword.isEmpty) return true;
              final text =
                  '${employee['employeeCode'] ?? ''} '
                          '${employee['employeeName'] ?? ''} '
                          '${employee['nickName'] ?? ''} '
                          '${employee['departmentName'] ?? ''}'
                      .toLowerCase();
              return text.contains(keyword);
            }).toList();
            return AlertDialog(
              insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
              backgroundColor: LaooColors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
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
                width: dialogWidth,
                height: dialogHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      color: preset.primary.withValues(alpha: .08),
                      child: Text(
                        '${data['bookingNo'] ?? '-'} | ${data['roomCode'] ?? '-'} ${data['roomName'] ?? '-'}\n'
                        '${_bookingDateTime(data)}',
                        style: TextStyle(
                          color: preset.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final search = TextField(
                          controller: searchController,
                          onChanged: (value) => refresh(
                            () => keyword = value.trim().toLowerCase(),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'ค้นหารหัสหรือชื่อพนักงาน',
                            prefixIcon: Icon(Icons.search),
                          ),
                        );
                        final department = DropdownButtonFormField<int?>(
                          initialValue: departmentId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'แผนก'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: LaooComboBoxText('ทั้งหมด'),
                            ),
                            ...departments.map(
                              (entry) => DropdownMenuItem<int?>(
                                value: entry.key,
                                child: LaooComboBoxText(entry.value),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              refresh(() => departmentId = value),
                        );
                        if (constraints.maxWidth < 520) {
                          return Column(
                            children: [
                              search,
                              const SizedBox(height: 8),
                              department,
                            ],
                          );
                        }
                        return Row(
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
                                final checked =
                                    employeeId != null &&
                                    selected.contains(employeeId);
                                final details = <String>[
                                  if ('${employee['nickName'] ?? ''}'
                                      .isNotEmpty)
                                    'ชื่อเล่น: ${employee['nickName']}',
                                  if ('${employee['departmentName'] ?? ''}'
                                      .isNotEmpty)
                                    'แผนก: ${employee['departmentName']}',
                                ];
                                return CheckboxListTile(
                                  value: checked,
                                  activeColor: preset.primary,
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
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
      if (saved != true) return;
      await _repository.saveParticipants(bookingId, selected.toList()..sort());
      _showMessage('บันทึกผู้เข้าร่วมประชุมสำเร็จ');
    } catch (error) {
      _showError(error, 'จัดการผู้เข้าร่วมประชุมไม่สำเร็จ');
    }
  }

  void _resetForm({bool keepSchedule = false}) {
    final roomId = _searchMode == 'ROOM' ? _selectedRoomId : null;
    setState(() {
      _editingId = null;
      _selectedRoomId = roomId;
      _subject.clear();
      _description.clear();
      _remark.clear();
      _attendeeCount.text = '1';
      _subjectError = null;
      _attendeeError = null;
      _timeError = null;
      _multipleDays = false;
      _awaitingRangeEnd = false;
      if (!keepSchedule) _setInitialDateTime();
    });
  }

  void _showMessage(String value, {bool error = false}) {
    if (!mounted) return;
    _notificationOverlay?.remove();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 12,
        right: 12,
        child: AutoDismissMessage(
          message: value,
          error: error,
          onClose: _dismissNotification,
        ),
      ),
    );
    _notificationOverlay = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _dismissNotification() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  void _showError(Object error, String fallback) {
    final text = error is ApiException
        ? error.description == null
              ? error.message
              : '${error.message}\n${error.description}'
        : '$fallback\n$error';
    _showMessage(text, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return SupportWorkspaceShell(
      menuScope: WorkspaceMenuScope.company,
      pageTitle: _caption,
      activeMenu: widget.menuCode,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: LaooColors.background,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(LaooLayout.cardMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _captionCard(preset),
                    const SizedBox(height: 8),
                    if (_loading)
                      const LinearProgressIndicator()
                    else if (_workspaceMode == 'CALENDAR')
                      MeetingRoomCalendarView(
                        repository: _repository,
                        preset: preset,
                        branches: _branches,
                        buildings: _buildings,
                        floors: _floors,
                        rooms: _rooms,
                        canCreate: _actions['create'] == true,
                        canEdit: _actions['edit'] == true,
                        onCreateBooking: _startBookingFromCalendar,
                        onEditBooking: _editBooking,
                      )
                    else if (_myBookingsOnly)
                      _bookingList(preset)
                    else ...[
                      _filterCard(preset),
                      const SizedBox(height: 8),
                      _bookingSelector(preset),
                      const SizedBox(height: 8),
                      _bookingList(preset),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _captionCard(WorkspaceThemePreset preset) => WorkspaceSectionCard(
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: WorkspacePageTitle(
                title: _caption,
                favoriteKey: widget.menuCode,
              ),
            ),
            if (_editingId != null)
              OutlinedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.add),
                label: const Text('จองรายการใหม่'),
              ),
            if (_workspaceMode != 'CALENDAR') ...[
              if (_editingId != null) const SizedBox(width: 4),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: preset.primary,
                  backgroundColor: _myBookingsOnly
                      ? preset.primary.withValues(alpha: .1)
                      : null,
                  side: BorderSide(color: preset.primary),
                  minimumSize: const Size(0, LaooTypography.buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                ),
                onPressed: _toggleMyBookings,
                icon: Icon(
                  _myBookingsOnly
                      ? Icons.arrow_back_outlined
                      : Icons.person_outline,
                ),
                label: Text(_myBookingsOnly ? 'กลับหน้าจอง' : 'การจองของฉัน'),
              ),
            ],
            if (_workspaceMode == 'CALENDAR' && _actions['create'] == true)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: preset.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size(0, LaooTypography.buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                ),
                onPressed: () {
                  setState(() => _workspaceMode = 'BOOKING');
                  if (widget.initialCalendar) {
                    _loadBookings();
                    _searchAvailableRooms();
                  }
                },
                icon: const Icon(Icons.add_task),
                label: const Text('จองห้องประชุม'),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    ),
  );

  Widget _filterCard(WorkspaceThemePreset preset) => WorkspaceSectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Builder(
              builder: (context) {
                final selector = SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'DATE',
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('ตามวันที่'),
                    ),
                    ButtonSegment(
                      value: 'ROOM',
                      icon: const Icon(Icons.meeting_room_outlined),
                      label: const Text('ตามห้องประชุม'),
                    ),
                    if (_actions['calendarView'] == true ||
                        widget.initialCalendar)
                      const ButtonSegment(
                        value: 'CALENDAR',
                        icon: Icon(Icons.calendar_month_outlined),
                        label: Text('ปฏิทินการจอง'),
                      ),
                  ],
                  selected: {
                    _workspaceMode == 'CALENDAR' ? 'CALENDAR' : _searchMode,
                  },
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Theme.of(context).colorScheme.onPrimary
                          : preset.primary,
                    ),
                    iconColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Theme.of(context).colorScheme.onPrimary
                          : preset.primary,
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? preset.primary
                          : LaooColors.white,
                    ),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: preset.primary),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                  ),
                  onSelectionChanged: (value) {
                    final mode = value.first;
                    if (mode == 'CALENDAR') {
                      setState(() => _workspaceMode = 'CALENDAR');
                      return;
                    }
                    setState(() {
                      _workspaceMode = 'BOOKING';
                      _searchMode = mode;
                      _availableRooms = [];
                      _selectedRoomId = null;
                      _roomBookingCalendarVisible = false;
                    });
                    if (mode == 'ROOM') _loadRoomScheduleBookings();
                  },
                );
                if (MediaQuery.sizeOf(context).width < 600) {
                  return SizedBox(
                    width: MediaQuery.sizeOf(context).width - 40,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: selector,
                    ),
                  );
                }
                return selector;
              },
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('หลายวัน'),
                const SizedBox(width: 4),
                Switch(
                  value: _multipleDays,
                  activeTrackColor: preset.primary,
                  onChanged: (value) => setState(() {
                    _multipleDays = value;
                    _awaitingRangeEnd = false;
                    if (!value) _endDate = _startDate;
                    _availableRooms = [];
                  }),
                ),
              ],
            ),
            _dropdown(
              width: 140,
              label: 'สาขา',
              value: _branchId,
              items: _branches,
              idKey: 'branchId',
              nameKey: 'nameTh',
              onChanged: (value) => setState(() {
                _branchId = value;
                _buildingId = null;
                _floorId = null;
                _selectedRoomId = null;
                _availableRooms = [];
                _roomBookingCalendarVisible = false;
              }),
            ),
            _dropdown(
              width: 140,
              label: 'อาคาร',
              value: _buildingId,
              items: _filteredBuildings,
              idKey: 'buildingId',
              nameKey: 'nameTh',
              onChanged: (value) => setState(() {
                _buildingId = value;
                _floorId = null;
                _selectedRoomId = null;
                _availableRooms = [];
                _roomBookingCalendarVisible = false;
              }),
            ),
            _dropdown(
              width: 110,
              label: 'ชั้น',
              value: _floorId,
              items: _filteredFloors,
              idKey: 'floorId',
              nameKey: 'nameTh',
              onChanged: (value) => setState(() {
                _floorId = value;
                _selectedRoomId = null;
                _availableRooms = [];
                _roomBookingCalendarVisible = false;
              }),
            ),
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 600
                  ? MediaQuery.sizeOf(context).width - 40
                  : 100,
              child: TextField(
                controller: _attendeeCount,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: LaooTypography.inputText),
                decoration: InputDecoration(
                  labelText: 'จำนวนผู้ใช้ *',
                  errorText: _attendeeError,
                ),
                onChanged: (_) => setState(() => _availableRooms = []),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _bookingSelector(WorkspaceThemePreset preset) {
    if (_searchMode == 'ROOM') return _roomScheduleSelector(preset);
    return WorkspaceSectionCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final calendarSearch = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(
                Icons.calendar_month_outlined,
                'เลือกวันที่',
                preset,
              ),
              const Divider(color: LaooColors.border),
              _dateTimeSearchPanel(preset),
              const SizedBox(height: 8),
              _styledCalendar(preset),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                calendarSearch,
                const SizedBox(height: 8),
                _roomResultPanel(preset),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 380, child: calendarSearch),
              const SizedBox(width: 8),
              Expanded(child: _roomResultPanel(preset)),
            ],
          );
        },
      ),
    );
  }

  Widget _roomScheduleSelector(WorkspaceThemePreset preset) =>
      WorkspaceSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(
              Icons.meeting_room_outlined,
              'รายการห้องประชุมและการจอง',
              preset,
            ),
            const Divider(color: LaooColors.border),
            if (_roomBookingCalendarVisible) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final calendarSearch = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _sectionTitle(
                              Icons.calendar_month_outlined,
                              'เลือกวันที่และเวลา',
                              preset,
                            ),
                          ),
                          IconButton(
                            tooltip: 'ซ่อนปฏิทิน',
                            color: preset.primary,
                            onPressed: () => setState(
                              () => _roomBookingCalendarVisible = false,
                            ),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Divider(color: LaooColors.border),
                      _dateTimeSearchPanel(preset),
                      const SizedBox(height: 8),
                      _styledCalendar(preset),
                    ],
                  );
                  if (constraints.maxWidth < 900) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        calendarSearch,
                        const SizedBox(height: 8),
                        _roomResultPanel(preset),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 380, child: calendarSearch),
                      const SizedBox(width: 8),
                      Expanded(child: _roomResultPanel(preset)),
                    ],
                  );
                },
              ),
              const Divider(color: LaooColors.border),
            ],
            if (_roomScheduleLoading)
              const LinearProgressIndicator()
            else if (_filteredRooms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('ไม่พบห้องประชุมตามตัวกรอง')),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredRooms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _roomScheduleCard(_filteredRooms[index], preset),
              ),
          ],
        ),
      );

  Widget _roomScheduleCard(
    Map<String, dynamic> room,
    WorkspaceThemePreset preset,
  ) {
    final roomId = _int(room['roomId']);
    final schedules = _roomBookingsForSchedule(roomId);
    return Card(
      margin: EdgeInsets.zero,
      color: LaooColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _roomImage(room['roomImageUrl']?.toString()),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${room['roomCode'] ?? room['code'] ?? ''} | ${room['roomNameTh'] ?? room['nameTh'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${room['branchName'] ?? '-'} | ${room['buildingName'] ?? '-'} | ${room['floorName'] ?? '-'} | ความจุ ${room['capacity'] ?? '-'} คน',
                        style: TextStyle(
                          color: preset.primary,
                          fontSize: LaooTypography.inputText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_actions['create'] == true)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: preset.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    onPressed: () => _openBookingDialog(room),
                    icon: const Icon(Icons.add),
                    label: const Text('จอง'),
                  ),
              ],
            ),
            if (schedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('ยังไม่มีรายการจองที่ยังไม่ผ่าน'),
              )
            else
              ...schedules.map(
                (booking) => _roomScheduleBookingRow(booking, preset),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roomScheduleBookingRow(
    Map<String, dynamic> booking,
    WorkspaceThemePreset preset,
  ) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: LaooColors.border, width: .5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.schedule_outlined, size: 18, color: preset.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_bookingDateTime(booking)} | ${booking['subject'] ?? '-'}',
                style: const TextStyle(fontSize: LaooTypography.inputText),
              ),
              const SizedBox(height: 2),
              Text(
                'ผู้จอง: ${booking['requesterName'] ?? '-'} | เลขที่ ${booking['bookingNo'] ?? '-'}',
                style: const TextStyle(
                  color: LaooColors.textSecondary,
                  fontSize: LaooTypography.inputHint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _status(booking['status']?.toString(), preset),
      ],
    ),
  );

  List<Map<String, dynamic>> _roomBookingsForSchedule(int? roomId) =>
      _roomScheduleBookings
          .where((booking) => _int(booking['roomId']) == roomId)
          .toList();

  Widget _styledCalendar(
    WorkspaceThemePreset preset, {
    ValueChanged<DateTime>? onDateChanged,
  }) {
    final baseTheme = Theme.of(context);
    final onPrimary = baseTheme.colorScheme.onPrimary;
    final today = _date(DateTime.now());
    final firstDate = today.subtract(const Duration(days: 1));
    final lastDate = today.add(const Duration(days: 730));
    final initialDate = _startDate.isBefore(firstDate)
        ? firstDate
        : (_startDate.isAfter(lastDate) ? lastDate : _date(_startDate));
    final roundedDay = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: LaooColors.white,
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Theme(
        data: baseTheme.copyWith(
          colorScheme: baseTheme.colorScheme.copyWith(
            primary: preset.primary,
            surface: LaooColors.white,
            onSurface: LaooColors.textPrimary,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: LaooColors.white,
            surfaceTintColor: Colors.transparent,
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
                return LaooColors.textSecondary.withValues(alpha: .45);
              }
              if (states.contains(WidgetState.selected)) return preset.primary;
              return LaooColors.textPrimary;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? preset.primary.withValues(alpha: .14)
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
            yearForegroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? onPrimary
                  : LaooColors.textPrimary,
            ),
            yearBackgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? preset.primary
                  : Colors.transparent,
            ),
            yearOverlayColor: WidgetStatePropertyAll(
              preset.primary.withValues(alpha: .10),
            ),
            yearShape: WidgetStatePropertyAll(roundedDay),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(foregroundColor: preset.primary),
          ),
        ),
        child: CalendarDatePicker(
          key: ValueKey(
            '${initialDate.toIso8601String()}-${_multipleDays ? 1 : 0}',
          ),
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          onDateChanged: onDateChanged ?? _selectCalendarDate,
        ),
      ),
    );
  }

  Widget _dateTimeSearchPanel(WorkspaceThemePreset preset) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        color: preset.primary.withValues(alpha: .08),
        child: Text(
          _multipleDays
              ? 'ช่วงวันที่ ${_formatDate(_startDate)} - ${_formatDate(_endDate)}\nคลิกวันแรก แล้วคลิกวันสุดท้าย'
              : 'วันที่ ${_formatDate(_startDate)}',
          style: TextStyle(
            color: preset.primary,
            fontSize: LaooTypography.sectionTitle,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _timeField(
              label: 'เวลาเริ่ม *',
              value: _startTime,
              onTap: () => _pickTime(start: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _timeField(
              label: 'เวลาสิ้นสุด *',
              value: _endTime,
              onTap: () => _pickTime(start: false),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _roomResultPanel(WorkspaceThemePreset preset) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: _sectionTitle(
              Icons.event_available_outlined,
              'ผลการค้นหาห้องว่าง',
              preset,
            ),
          ),
          Flexible(
            child: Text(
              'วันที่เลือก: $_selectedDateLabel',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: LaooColors.textPrimary,
                fontSize: LaooTypography.sectionTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      const Divider(color: LaooColors.border),
      if (_searching)
        const LinearProgressIndicator()
      else if (_availableRooms.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('เลือกวันที่และเวลาเพื่อแสดงห้องว่าง')),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _availableRooms.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) =>
              _roomCard(_availableRooms[index], preset, availability: true),
        ),
    ],
  );

  Widget _roomCard(
    Map<String, dynamic> room,
    WorkspaceThemePreset preset, {
    required bool availability,
  }) {
    final id = _int(room['roomId']);
    final selected = id == _selectedRoomId;
    final available = !availability || room['isAvailable'] == true;
    final imageUrl = room['roomImageUrl']?.toString();
    final conflicts = _maps(room['conflictingBookings']);
    final conflictsExpanded = id != null && _expandedConflictRooms.contains(id);
    final visibleConflicts = conflictsExpanded
        ? conflicts
        : conflicts.take(3).toList();
    return Card(
      margin: EdgeInsets.zero,
      color: LaooColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: selected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _roomImage(imageUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${room['roomCode'] ?? room['code'] ?? ''} | ${room['roomNameTh'] ?? room['nameTh'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${room['branchName'] ?? '-'} | ${room['buildingName'] ?? '-'} | ${room['floorName'] ?? '-'} | ความจุ ${room['capacity'] ?? '-'} คน',
                        style: TextStyle(
                          color: preset.primary,
                          fontSize: LaooTypography.inputText,
                        ),
                      ),
                      if ('${room['facilities'] ?? ''}'.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'อุปกรณ์: ${room['facilities']}',
                          style: const TextStyle(
                            fontSize: LaooTypography.inputText,
                          ),
                        ),
                      ],
                      if (!available) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${room['unavailableReason'] ?? 'ไม่ว่าง'}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: LaooTypography.inputHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: available ? () => _openBookingDialog(room) : null,
                  child: const Text('จอง'),
                ),
              ],
            ),
            if (!available && conflicts.isNotEmpty) ...[
              const SizedBox(height: 6),
              _conflictPanel(
                id: id,
                preset: preset,
                conflicts: conflicts,
                visibleConflicts: visibleConflicts,
                expanded: conflictsExpanded,
              ),
            ],
            if (_searchMode == 'ROOM') ...[
              ..._roomBookingsForSchedule(
                id,
              ).map((booking) => _roomScheduleBookingRow(booking, preset)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _conflictPanel({
    required int? id,
    required WorkspaceThemePreset preset,
    required List<Map<String, dynamic>> conflicts,
    required List<Map<String, dynamic>> visibleConflicts,
    required bool expanded,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8),
    color: preset.primary.withValues(alpha: .05),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...visibleConflicts.asMap().entries.map((entry) {
          final conflict = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 16,
                      color: preset.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_conflictDateTime(conflict)} | ${conflict['subject'] ?? '-'}',
                            style: const TextStyle(
                              color: LaooColors.textPrimary,
                              fontSize: LaooTypography.inputText,
                            ),
                          ),
                          Text(
                            'ผู้จอง: ${conflict['requesterName'] ?? '-'}',
                            style: const TextStyle(
                              color: LaooColors.textSecondary,
                              fontSize: LaooTypography.inputHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.key < visibleConflicts.length - 1)
                const Divider(color: LaooColors.border, height: 1),
            ],
          );
        }),
        if (conflicts.length > 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: id == null
                  ? null
                  : () => setState(() {
                      if (expanded) {
                        _expandedConflictRooms.remove(id);
                      } else {
                        _expandedConflictRooms.add(id);
                      }
                    }),
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(
                expanded ? 'ซ่อนรายการ' : 'ดูทั้งหมด (${conflicts.length})',
              ),
            ),
          ),
      ],
    ),
  );

  Widget _bookingForm(WorkspaceThemePreset preset, StateSetter refresh) {
    final room = _selectedRoom!;
    final calendar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(Icons.calendar_month_outlined, 'เลือกวันที่', preset),
        const Divider(color: LaooColors.border),
        _styledCalendar(
          preset,
          onDateChanged: (value) {
            _selectCalendarDate(value);
            refresh(() {});
          },
        ),
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _timeField(
                label: 'เวลาเริ่ม *',
                value: _startTime,
                errorText: _timeError,
                onTap: () async {
                  await _pickTime(start: true);
                  refresh(() {});
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _timeField(
                label: 'เวลาสิ้นสุด *',
                value: _endTime,
                errorText: _timeError,
                onTap: () async {
                  await _pickTime(start: false);
                  refresh(() {});
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subject,
          style: const TextStyle(
            color: LaooColors.textPrimary,
            fontSize: LaooTypography.inputText,
          ),
          decoration: InputDecoration(
            labelText: 'หัวข้อประชุม *',
            errorText: _subjectError,
          ),
          onChanged: (_) {
            if (_subjectError != null) {
              refresh(() => _subjectError = null);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _attendeeCount,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: LaooColors.textPrimary,
            fontSize: LaooTypography.inputText,
          ),
          decoration: InputDecoration(
            labelText: 'จำนวนผู้เข้าร่วม *',
            errorText: _attendeeError,
          ),
          onChanged: (_) {
            if (_attendeeError != null) {
              refresh(() => _attendeeError = null);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          maxLines: 2,
          style: const TextStyle(
            color: LaooColors.textPrimary,
            fontSize: LaooTypography.inputText,
          ),
          decoration: const InputDecoration(labelText: 'รายละเอียด'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _remark,
          maxLines: 2,
          style: const TextStyle(
            color: LaooColors.textPrimary,
            fontSize: LaooTypography.inputText,
          ),
          decoration: const InputDecoration(labelText: 'หมายเหตุ'),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          color: preset.primary.withValues(alpha: .08),
          child: Text(
            '${room['code'] ?? ''} | ${room['nameTh'] ?? ''}\n'
            '${_formatDate(_startDate)}${_multipleDays ? ' - ${_formatDate(_endDate)}' : ''} | ${_formatTime(_startTime)} - ${_formatTime(_endTime)}',
            style: TextStyle(
              color: preset.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [calendar, const SizedBox(height: 12), details],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 320, child: calendar),
                const SizedBox(width: 16),
                Expanded(child: details),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _bookingList(WorkspaceThemePreset preset) => WorkspaceSectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          Icons.list_alt_outlined,
          _myBookingsOnly ? 'รายการจองของฉัน' : 'รายการจอง',
          preset,
        ),
        const Divider(color: LaooColors.border),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bookings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _bookingCard(_bookings[index], preset),
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    preset.primary.withValues(alpha: .10),
                  ),
                  headingTextStyle: TextStyle(
                    color: preset.primary,
                    fontSize: LaooTypography.tableHeader,
                    fontWeight: FontWeight.w700,
                  ),
                  dataTextStyle: const TextStyle(
                    fontSize: LaooTypography.tableBody,
                  ),
                  border: const TableBorder(
                    horizontalInside: BorderSide(
                      color: LaooColors.border,
                      width: .5,
                    ),
                  ),
                  columns: const [
                    DataColumn(
                      columnWidth: LaooDataTable.idColumnWidth,
                      headingRowAlignment: MainAxisAlignment.center,
                      label: Text('ID'),
                    ),
                    DataColumn(label: Text('Action')),
                    DataColumn(label: Text('สถานะ')),
                    DataColumn(label: Text('เลขที่จอง')),
                    DataColumn(label: Text('ห้องประชุม')),
                    DataColumn(label: Text('วันและเวลา')),
                    DataColumn(label: Text('หัวข้อ')),
                    DataColumn(label: Text('ผู้จอง')),
                    DataColumn(label: Text('จำนวน')),
                  ],
                  rows: _bookings.asMap().entries.map((entry) {
                    final item = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(
                          Text('${(_page - 1) * _pageSize + entry.key + 1}'),
                        ),
                        DataCell(_bookingActions(item, preset)),
                        DataCell(_status(item['status']?.toString(), preset)),
                        DataCell(Text('${item['bookingNo'] ?? '-'}')),
                        DataCell(
                          Text('${item['roomCode']} | ${item['roomNameTh']}'),
                        ),
                        DataCell(Text(_bookingDateTime(item))),
                        DataCell(Text('${item['subject'] ?? ''}')),
                        DataCell(
                          Text(
                            '${item['requesterCode'] ?? ''}${item['requesterCode'] == null ? '' : ' | '}${item['requesterName'] ?? '-'}',
                          ),
                        ),
                        DataCell(Text('${item['attendeeCount'] ?? '-'}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: LaooColors.border),
        const SizedBox(height: 8),
        _pagination(preset),
      ],
    ),
  );

  Widget _bookingCard(
    Map<String, dynamic> item,
    WorkspaceThemePreset preset,
  ) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _status(item['status']?.toString(), preset),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item['bookingNo'] ?? '-'} | ${item['roomCode']} ${item['roomNameTh']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _bookingActions(item, preset),
            ],
          ),
          const SizedBox(height: 6),
          Text('${item['subject'] ?? ''}'),
          const SizedBox(height: 4),
          Text(
            'ผู้จอง: ${item['requesterCode'] ?? '-'} | ${item['requesterName'] ?? '-'}',
            style: TextStyle(color: preset.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '${_bookingDateTime(item)} | ${item['attendeeCount'] ?? '-'} คน',
            style: TextStyle(color: preset.primary),
          ),
        ],
      ),
    ),
  );

  Widget _bookingActions(
    Map<String, dynamic> item,
    WorkspaceThemePreset preset,
  ) {
    final status = item['status']?.toString();
    final editable = status != 'CANCELLED' && status != 'REJECTED';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item['canManageParticipants'] == true)
          IconButton(
            tooltip: 'เชิญผู้เข้าร่วมประชุม',
            onPressed: () => _showParticipantDialog(item),
            icon: Icon(Icons.group_add_outlined, color: preset.primary),
          ),
        if (_actions['edit'] == true && editable)
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => _editBooking(item),
            icon: Icon(Icons.edit_outlined, color: preset.primary),
          ),
        if (_actions['delete'] == true && editable)
          IconButton(
            tooltip: 'ยกเลิกการจอง',
            onPressed: () => _confirmCancel(item),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        if ((status == 'APPROVED' || status == 'REJECTED') &&
            _actions['admin'] == true)
          IconButton(
            tooltip: 'ถอยสถานะ',
            onPressed: () => _confirmRollback(item),
            icon: Icon(Icons.undo, color: preset.primary),
          )
        else if (status == 'APPROVED' || status == 'REJECTED')
          IconButton(
            tooltip: 'เฉพาะ Admin เท่านั้น',
            onPressed: null,
            icon: Icon(
              Icons.lock_outline,
              color: Theme.of(context).disabledColor,
            ),
          ),
      ],
    );
  }

  Widget _pagination(WorkspaceThemePreset preset) {
    final pages = (_total / _pageSize).ceil().clamp(1, 999999);
    final start = _total == 0 ? 0 : (_page - 1) * _pageSize + 1;
    final end = (_page * _pageSize).clamp(0, _total);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: _page > 1
              ? () async {
                  setState(() => _page--);
                  await _loadBookings();
                }
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(
            disabledBackgroundColor: preset.primary,
            disabledForegroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: Text('$_page'),
        ),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: _page < pages
              ? () async {
                  setState(() => _page++);
                  await _loadBookings();
                }
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
        Text('$start-$end จาก $_total'),
      ],
    );
  }

  Widget _status(String? value, WorkspaceThemePreset preset) {
    final negative = value == 'CANCELLED' || value == 'REJECTED';
    final label = switch (value) {
      'APPROVED' => 'อนุมัติแล้ว',
      'PENDING' => 'รออนุมัติ',
      'REJECTED' => 'ไม่อนุมัติ',
      'CANCELLED' => 'ยกเลิก',
      _ => value ?? '-',
    };
    final color = negative ? Colors.red : preset.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Text(label, style: TextStyle(color: color)),
    );
  }

  Widget _sectionTitle(
    IconData icon,
    String title,
    WorkspaceThemePreset preset,
  ) => Row(
    children: [
      Icon(icon, color: preset.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: LaooColors.pageCaption,
            fontSize: LaooTypography.inputLabel,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _timeField({
    required String label,
    required TimeOfDay value,
    required VoidCallback onTap,
    String? errorText,
  }) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.schedule),
        errorText: errorText,
      ),
      child: Text(
        _formatTime(value),
        style: const TextStyle(fontSize: LaooTypography.sectionTitle),
      ),
    ),
  );

  Widget _dropdown({
    required double width,
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required String idKey,
    required String nameKey,
    required ValueChanged<int?> onChanged,
  }) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 600
        ? MediaQuery.sizeOf(context).width - 40
        : width,
    child: DropdownButtonFormField<int>(
      initialValue: items.any((item) => _int(item[idKey]) == value)
          ? value
          : null,
      isExpanded: true,
      style: const TextStyle(
        color: LaooColors.pageCaption,
        fontSize: LaooTypography.comboBox,
      ),
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('ทั้งหมด')),
        ...items.map(
          (item) => DropdownMenuItem<int>(
            value: _int(item[idKey]),
            child: Text('${item[nameKey] ?? '-'}'),
          ),
        ),
      ],
      onChanged: onChanged,
    ),
  );

  Widget _roomImage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return Container(
        width: 72,
        height: 56,
        color: LaooColors.background,
        child: const Icon(Icons.meeting_room_outlined),
      );
    }
    final uri = Uri.tryParse(value.trim());
    final url = uri != null && uri.hasScheme
        ? uri.toString()
        : Uri.parse(ApiConfig.baseUrl).resolve(value.trim()).toString();
    return ClipRRect(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      child: Image.network(
        url,
        width: 72,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 72,
          height: 56,
          color: LaooColors.background,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  String _bookingDateTime(Map<String, dynamic> item) {
    final start = DateTime.tryParse('${item['startDateTime'] ?? ''}');
    final end = DateTime.tryParse('${item['endDateTime'] ?? ''}');
    if (start == null || end == null) return '-';
    final count = _int(item['slotCount']) ?? 1;
    if (count > 1) {
      return '${_formatDate(start)} - ${_formatDate(end)} | ${_two(start.hour)}:${_two(start.minute)}-${_two(end.hour)}:${_two(end.minute)}';
    }
    return '${_formatDate(start)} | ${_two(start.hour)}:${_two(start.minute)}-${_two(end.hour)}:${_two(end.minute)}';
  }

  String _conflictDateTime(Map<String, dynamic> item) {
    final start = DateTime.tryParse('${item['startDateTime'] ?? ''}');
    final end = DateTime.tryParse('${item['endDateTime'] ?? ''}');
    if (start == null || end == null) return '-';
    return '${_formatDate(start)} ${_two(start.hour)}:${_two(start.minute)}-${_two(end.hour)}:${_two(end.minute)}';
  }

  static DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static DateTime _combine(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
  static String _formatDate(DateTime value) =>
      '${_two(value.day)}/${_two(value.month)}/${value.year}';
  static String _formatTime(TimeOfDay value) =>
      '${_two(value.hour)}:${_two(value.minute)}';
  static String _two(int value) => value.toString().padLeft(2, '0');
  static int? _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  static List<Map<String, dynamic>> _maps(Object? value) =>
      List<Map<String, dynamic>>.from(value as List? ?? const []);
}
