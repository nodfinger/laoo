import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_room_booking_repository.dart';

enum MeetingCalendarMode { month, week, day, room }

class MeetingRoomCalendarView extends StatefulWidget {
  const MeetingRoomCalendarView({
    super.key,
    required this.repository,
    required this.preset,
    required this.branches,
    required this.buildings,
    required this.floors,
    required this.rooms,
    required this.canCreate,
    required this.canEdit,
    required this.onCreateBooking,
    required this.onEditBooking,
    this.initialMode = MeetingCalendarMode.month,
  });

  final MeetingRoomBookingRepository repository;
  final WorkspaceThemePreset preset;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> buildings;
  final List<Map<String, dynamic>> floors;
  final List<Map<String, dynamic>> rooms;
  final bool canCreate;
  final bool canEdit;
  final void Function(DateTime date, int? roomId) onCreateBooking;
  final void Function(Map<String, dynamic> booking) onEditBooking;
  final MeetingCalendarMode initialMode;

  @override
  State<MeetingRoomCalendarView> createState() =>
      _MeetingRoomCalendarViewState();
}

class _MeetingRoomCalendarViewState extends State<MeetingRoomCalendarView> {
  late MeetingCalendarMode _mode;
  DateTime _anchor = _date(DateTime.now());
  DateTime _selectedDate = _date(DateTime.now());
  int? _branchId;
  int? _buildingId;
  int? _floorId;
  int? _roomId;
  String? _status;
  bool _loading = false;
  String? _error;
  int _requestSerial = 0;
  List<Map<String, dynamic>> _events = [];

  static const _months = <String>[
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  static const _weekdays = <String>[
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<Map<String, dynamic>> get _filteredBuildings => widget.buildings
      .where((item) => _branchId == null || _id(item['branchId']) == _branchId)
      .toList();

  List<Map<String, dynamic>> get _filteredFloors => widget.floors
      .where(
        (item) => _buildingId == null || _id(item['buildingId']) == _buildingId,
      )
      .toList();

  List<Map<String, dynamic>> get _filteredRooms => widget.rooms.where((item) {
    if (_branchId != null && _id(item['branchId']) != _branchId) return false;
    if (_buildingId != null && _id(item['buildingId']) != _buildingId) {
      return false;
    }
    if (_floorId != null && _id(item['floorId']) != _floorId) return false;
    return true;
  }).toList();

  (DateTime, DateTime) get _range {
    switch (_mode) {
      case MeetingCalendarMode.month:
        final first = DateTime(_anchor.year, _anchor.month, 1);
        final start = first.subtract(Duration(days: first.weekday - 1));
        return (start, start.add(const Duration(days: 41)));
      case MeetingCalendarMode.week:
        final start = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        return (start, start.add(const Duration(days: 6)));
      case MeetingCalendarMode.day:
        return (_anchor, _anchor);
      case MeetingCalendarMode.room:
        return (_anchor, _anchor.add(const Duration(days: 6)));
    }
  }

  Future<void> _load() async {
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final range = _range;
      final result = await widget.repository.calendar(
        from: range.$1,
        to: range.$2,
        branchId: _branchId,
        buildingId: _buildingId,
        floorId: _floorId,
        roomId: _roomId,
        status: _status,
      );
      if (!mounted || serial != _requestSerial) return;
      setState(() => _events = result);
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() => _error = 'โหลดปฏิทินไม่สำเร็จ\n$error');
    } finally {
      if (mounted && serial == _requestSerial) {
        setState(() => _loading = false);
      }
    }
  }

  void _changeMode(MeetingCalendarMode mode) {
    setState(() {
      _mode = mode;
      if (mode == MeetingCalendarMode.day) _anchor = _selectedDate;
    });
    _load();
  }

  void _move(int direction) {
    setState(() {
      _anchor = switch (_mode) {
        MeetingCalendarMode.month => DateTime(
          _anchor.year,
          _anchor.month + direction,
          1,
        ),
        MeetingCalendarMode.week => _anchor.add(Duration(days: 7 * direction)),
        MeetingCalendarMode.day => _anchor.add(Duration(days: direction)),
        MeetingCalendarMode.room => _anchor.add(Duration(days: 7 * direction)),
      };
      _selectedDate = _anchor;
    });
    _load();
  }

  void _today() {
    setState(() {
      _anchor = _date(DateTime.now());
      _selectedDate = _anchor;
    });
    _load();
  }

  List<Map<String, dynamic>> _eventsOn(DateTime date) => _events.where((item) {
    final start = DateTime.tryParse('${item['startDateTime']}');
    return start != null && _sameDate(start, date);
  }).toList();

  List<Map<String, dynamic>> _eventsForRoom(int roomId, DateTime date) =>
      _eventsOn(date).where((item) => _id(item['roomId']) == roomId).toList();

  Future<void> _selectDate(DateTime date) async {
    setState(() => _selectedDate = _date(date));
    if (MediaQuery.sizeOf(context).width < 900) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: LaooColors.white,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: SingleChildScrollView(child: _dayDetails(_selectedDate)),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _filterCard(),
      const SizedBox(height: 8),
      WorkspaceSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(),
            const SizedBox(height: 8),
            const Divider(height: 1, color: LaooColors.border),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: LaooColors.error),
                ),
              ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (_, _) {
                final calendar = switch (_mode) {
                  MeetingCalendarMode.month => _monthView(),
                  MeetingCalendarMode.week => _weekView(),
                  MeetingCalendarMode.day => _dayView(),
                  MeetingCalendarMode.room => _roomView(),
                };
                return calendar;
              },
            ),
          ],
        ),
      ),
    ],
  );

  Widget _filterCard() => WorkspaceSectionCard(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        double width(double preferred) =>
            compact ? constraints.maxWidth : preferred;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _dropdown(
              width: width(210),
              label: 'สาขา',
              value: _branchId,
              items: widget.branches,
              idKey: 'branchId',
              onChanged: (value) {
                setState(() {
                  _branchId = value;
                  _buildingId = null;
                  _floorId = null;
                  _roomId = null;
                });
                _load();
              },
            ),
            _dropdown(
              width: width(210),
              label: 'อาคาร',
              value: _buildingId,
              items: _filteredBuildings,
              idKey: 'buildingId',
              onChanged: (value) {
                setState(() {
                  _buildingId = value;
                  _floorId = null;
                  _roomId = null;
                });
                _load();
              },
            ),
            _dropdown(
              width: width(160),
              label: 'ชั้น',
              value: _floorId,
              items: _filteredFloors,
              idKey: 'floorId',
              onChanged: (value) {
                setState(() {
                  _floorId = value;
                  _roomId = null;
                });
                _load();
              },
            ),
            _dropdown(
              width: width(240),
              label: 'ห้องประชุม',
              value: _roomId,
              items: _filteredRooms,
              idKey: 'roomId',
              onChanged: (value) {
                setState(() => _roomId = value);
                _load();
              },
            ),
            SizedBox(
              width: width(180),
              child: DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'สถานะ'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                  DropdownMenuItem(value: 'PENDING', child: Text('รออนุมัติ')),
                  DropdownMenuItem(
                    value: 'APPROVED',
                    child: Text('อนุมัติแล้ว'),
                  ),
                  DropdownMenuItem(value: 'REJECTED', child: Text('ปฏิเสธ')),
                  DropdownMenuItem(value: 'CANCELLED', child: Text('ยกเลิก')),
                ],
                onChanged: (value) {
                  setState(() => _status = value);
                  _load();
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _toolbar() => LayoutBuilder(
    builder: (context, constraints) {
      final modeSelector = SegmentedButton<MeetingCalendarMode>(
        segments: const [
          ButtonSegment(value: MeetingCalendarMode.month, label: Text('เดือน')),
          ButtonSegment(
            value: MeetingCalendarMode.week,
            label: Text('สัปดาห์'),
          ),
          ButtonSegment(value: MeetingCalendarMode.day, label: Text('วัน')),
          ButtonSegment(
            value: MeetingCalendarMode.room,
            label: Text('ห้องประชุม'),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (value) => _changeMode(value.first),
      );
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (constraints.maxWidth < 520)
            SizedBox(
              width: constraints.maxWidth,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: modeSelector,
              ),
            )
          else
            modeSelector,
          IconButton.outlined(
            tooltip: 'ก่อนหน้า',
            onPressed: () => _move(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          if (_mode != MeetingCalendarMode.week)
            FilledButton(onPressed: _today, child: const Text('วันนี้')),
          IconButton.outlined(
            tooltip: 'ถัดไป',
            onPressed: () => _move(1),
            icon: const Icon(Icons.chevron_right),
          ),
          Text(
            _rangeTitle(),
            style: const TextStyle(
              color: LaooColors.pageCaption,
              fontSize: LaooTypography.sectionTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    },
  );

  Widget _monthView() {
    final range = _range;
    final dates = List.generate(
      42,
      (index) => range.$1.add(Duration(days: index)),
    );
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 910.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width < 910 ? 910 : width,
            child: Column(
              children: [
                Row(
                  children: _weekdays
                      .map(
                        (day) => Expanded(
                          child: Container(
                            height: 38,
                            alignment: Alignment.center,
                            color: widget.preset.primary.withValues(alpha: .08),
                            child: Text(
                              day,
                              style: TextStyle(
                                color: widget.preset.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                for (var week = 0; week < 6; week++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var day = 0; day < 7; day++)
                        Expanded(child: _monthCell(dates[week * 7 + day])),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _monthCell(DateTime date) {
    final events = _eventsOn(date);
    final outside = date.month != _anchor.month;
    final selected = _sameDate(date, _selectedDate);
    final today = _sameDate(date, DateTime.now());
    return InkWell(
      onTap: events.isEmpty && widget.canCreate
          ? () => widget.onCreateBooking(date, _roomId)
          : () => _selectDate(date),
      child: Container(
        height: 126,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected
              ? widget.preset.primary.withValues(alpha: .07)
              : LaooColors.white,
          border: Border.all(color: LaooColors.border, width: .5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: today
                      ? widget.preset.primary.withValues(alpha: .14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                  border: Border.all(
                    color: today || selected
                        ? widget.preset.primary
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: today
                        ? widget.preset.primary
                        : outside
                        ? LaooColors.textSecondary.withValues(alpha: .5)
                        : LaooColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            for (final event in events.take(2))
              _eventChip(event, compact: true),
            if (events.length > 2)
              Text(
                '+ อีก ${events.length - 2} รายการ',
                style: TextStyle(
                  color: widget.preset.primary,
                  fontSize: LaooTypography.inputHint,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _weekView() {
    final start = _range.$1;
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 980.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width < 980 ? 980 : width,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < 7; index++)
                  Expanded(child: _agendaDay(start.add(Duration(days: index)))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dayView() => _agendaDay(_anchor, expanded: true, plain: true);

  Widget _agendaDay(
    DateTime date, {
    bool expanded = false,
    bool plain = false,
  }) {
    final events = _eventsOn(date);
    return InkWell(
      onTap: () => _selectDate(date),
      child: Container(
        constraints: BoxConstraints(minHeight: expanded ? 420 : 360),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: plain
              ? LaooColors.white
              : _sameDate(date, _selectedDate)
              ? widget.preset.primary.withValues(alpha: .05)
              : LaooColors.white,
          border: plain
              ? Border.all(color: LaooColors.white)
              : Border.all(color: LaooColors.border, width: .5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_weekdays[date.weekday - 1]} ${_formatDate(date)}',
              style: TextStyle(
                color: widget.preset.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (events.isEmpty)
              const Text(
                'ไม่มีรายการจอง',
                style: TextStyle(color: LaooColors.textSecondary),
              )
            else
              for (final event in events) ...[
                plain ? _plainAgendaEvent(event) : _agendaEvent(event),
                const SizedBox(height: 6),
              ],
          ],
        ),
      ),
    );
  }

  Widget _roomView() => LayoutBuilder(
    builder: (context, constraints) {
      final rooms = _roomId == null
          ? _filteredRooms
          : _filteredRooms
                .where((item) => _id(item['roomId']) == _roomId)
                .toList();
      if (constraints.maxWidth < 900) {
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, index) => _roomAgendaCard(rooms[index]),
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1120,
          child: Column(
            children: [_roomHeader(), for (final room in rooms) _roomRow(room)],
          ),
        ),
      );
    },
  );

  Widget _roomHeader() => Row(
    children: [
      const SizedBox(width: 220),
      for (var index = 0; index < 7; index++)
        Expanded(
          child: Container(
            height: 44,
            alignment: Alignment.center,
            color: widget.preset.primary.withValues(alpha: .08),
            child: Text(
              _formatDate(_anchor.add(Duration(days: index))),
              style: TextStyle(
                color: widget.preset.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _roomRow(Map<String, dynamic> room) {
    final roomId = _id(room['roomId'])!;
    return SizedBox(
      height: 118,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 220,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: LaooColors.white,
              border: Border.all(color: LaooColors.border, width: .5),
            ),
            child: Text(
              '${room['code']} | ${room['nameTh']}\nความจุ ${room['capacity'] ?? '-'} คน',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (var index = 0; index < 7; index++)
            Expanded(
              child: _roomDayCell(roomId, _anchor.add(Duration(days: index))),
            ),
        ],
      ),
    );
  }

  Widget _roomDayCell(int roomId, DateTime date) {
    final events = _eventsForRoom(roomId, date);
    return InkWell(
      onTap: widget.canCreate
          ? () => widget.onCreateBooking(date, roomId)
          : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: LaooColors.white,
          border: Border.all(color: LaooColors.border, width: .5),
        ),
        child: events.isEmpty
            ? const Center(
                child: Text(
                  'ว่าง',
                  style: TextStyle(color: LaooColors.textSecondary),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final event in events.take(3)) _eventChip(event),
                  if (events.length > 3)
                    Text(
                      '+ อีก ${events.length - 3}',
                      style: TextStyle(color: widget.preset.primary),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _roomAgendaCard(Map<String, dynamic> room) {
    final roomId = _id(room['roomId'])!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${room['code']} | ${room['nameTh']} · ความจุ ${room['capacity'] ?? '-'} คน',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Divider(color: LaooColors.border),
            for (var index = 0; index < 7; index++) ...[
              Builder(
                builder: (_) {
                  final date = _anchor.add(Duration(days: index));
                  final events = _eventsForRoom(roomId, date);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_formatDate(date)),
                    subtitle: Text(
                      events.isEmpty
                          ? 'ไม่มีรายการจอง'
                          : events
                                .map(
                                  (event) =>
                                      '${_eventTime(event)} | ${event['subject']}',
                                )
                                .join('\n'),
                    ),
                  );
                },
              ),
              if (index < 6) const Divider(height: 1, color: LaooColors.border),
            ],
          ],
        ),
      ),
    );
  }

  Widget _eventChip(Map<String, dynamic> event, {bool compact = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: InkWell(
          onTap: () => _showEvent(event),
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 5,
              vertical: compact ? 2 : 3,
            ),
            decoration: BoxDecoration(
              color: _eventBackground(event),
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            child: Text(
              '${_eventTime(event)} ${event['roomCode']} | ${event['subject']}',
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _eventForeground(event),
                fontSize: LaooTypography.inputHint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

  Widget _agendaEvent(Map<String, dynamic> event) => InkWell(
    onTap: () => _showEvent(event),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _eventBackground(event),
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Text(
        '${_eventTime(event)}\n${event['roomCode']} | ${event['subject']}',
        style: TextStyle(color: _eventForeground(event)),
      ),
    ),
  );

  Widget _plainAgendaEvent(Map<String, dynamic> event) => InkWell(
    onTap: () => _showEvent(event),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: LaooColors.white,
        border: Border(bottom: BorderSide(color: LaooColors.border, width: .5)),
      ),
      child: Text(
        '${_eventTime(event)}\n${event['roomCode']} | ${event['subject']}',
        style: const TextStyle(color: LaooColors.textPrimary),
      ),
    ),
  );

  Widget _dayDetails(DateTime date) {
    final events = _eventsOn(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_weekdays[date.weekday - 1]} ${_formatDate(date)}',
          style: const TextStyle(
            color: LaooColors.pageCaption,
            fontSize: LaooTypography.sectionTitle,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Divider(color: LaooColors.border),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('ไม่มีรายการจอง')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, index) => _agendaEvent(events[index]),
          ),
      ],
    );
  }

  Future<void> _showEvent(Map<String, dynamic> event) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: LaooColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.sm),
        side: BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note_outlined, color: widget.preset.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'รายละเอียดการจอง',
                      style: LaooTypography.popupTitleStyle,
                    ),
                  ),
                ],
              ),
              const Divider(color: LaooColors.border),
              Text(
                '${event['roomCode']} | ${event['roomNameTh']}',
                style: TextStyle(
                  color: widget.preset.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('${event['subject']}'),
              const SizedBox(height: 6),
              Text('${_formatEventDate(event)} · ${_eventTime(event)}'),
              const SizedBox(height: 6),
              Text('จำนวน ${event['attendeeCount'] ?? '-'} คน'),
              if ('${event['description'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('${event['description']}'),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: _statusBadge('${event['status']}'),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: LaooColors.border),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('ปิด'),
                    ),
                    if (widget.canEdit &&
                        event['status'] != 'CANCELLED' &&
                        event['status'] != 'REJECTED')
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          widget.onEditBooking(event);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('แก้ไข'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _statusBadge(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: status == 'REJECTED' || status == 'CANCELLED'
          ? LaooColors.error.withValues(alpha: .10)
          : widget.preset.primary.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: Text(
      _statusText(status),
      style: TextStyle(
        color: status == 'REJECTED' || status == 'CANCELLED'
            ? LaooColors.error
            : widget.preset.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _dropdown({
    required double width,
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required String idKey,
    required ValueChanged<int?> onChanged,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<int?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
        ...items.map(
          (item) => DropdownMenuItem(
            value: _id(item[idKey]),
            child: Text(
              '${item['nameTh'] ?? item['name'] ?? item['code'] ?? ''}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    ),
  );

  Color _eventBackground(Map<String, dynamic> event) {
    final status = '${event['status']}';
    if (status == 'REJECTED' || status == 'CANCELLED') {
      return LaooColors.error.withValues(alpha: .10);
    }
    if (status == 'APPROVED') return widget.preset.primary;
    return widget.preset.primary.withValues(alpha: .12);
  }

  Color _eventForeground(Map<String, dynamic> event) {
    final status = '${event['status']}';
    if (status == 'REJECTED' || status == 'CANCELLED') {
      return LaooColors.error;
    }
    if (status == 'APPROVED') return Theme.of(context).colorScheme.onPrimary;
    return widget.preset.primary;
  }

  String _rangeTitle() {
    final range = _range;
    if (_mode == MeetingCalendarMode.month) {
      return '${_months[_anchor.month - 1]} ${_anchor.year}';
    }
    if (_mode == MeetingCalendarMode.day) return _formatDate(_anchor);
    return '${_formatDate(range.$1)} - ${_formatDate(range.$2)}';
  }

  static String _eventTime(Map<String, dynamic> event) {
    final start = DateTime.tryParse('${event['startDateTime']}');
    final end = DateTime.tryParse('${event['endDateTime']}');
    if (start == null || end == null) return '-';
    return '${_time(start)}-${_time(end)}';
  }

  static String _formatEventDate(Map<String, dynamic> event) {
    final start = DateTime.tryParse('${event['startDateTime']}');
    return start == null ? '-' : _formatDate(start);
  }

  static String _statusText(String status) => switch (status) {
    'PENDING' => 'รออนุมัติ',
    'APPROVED' => 'อนุมัติแล้ว',
    'REJECTED' => 'ปฏิเสธ',
    'CANCELLED' => 'ยกเลิก',
    _ => status,
  };

  static DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
  static int? _id(dynamic value) => value is int
      ? value
      : value == null
      ? null
      : int.tryParse('$value');
  static String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
