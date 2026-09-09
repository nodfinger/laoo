import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../data/meeting_attendance_repository.dart';
import 'meeting_food_receipt_panel.dart';
import 'meeting_qr_scanner.dart';

class MeetingAttendancePanel extends StatefulWidget {
  const MeetingAttendancePanel({
    super.key,
    required this.bookingId,
    required this.onMessage,
    this.participantId,
    this.slotId,
    this.repository,
  });

  final int bookingId;

  /// Invitation pages restrict the view to the opened invitation. Manager
  /// pages omit this filter; the server still enforces ownership and scope.
  final int? participantId;
  final int? slotId;
  final void Function(String message, bool error) onMessage;
  final MeetingAttendanceRepository? repository;

  @override
  State<MeetingAttendancePanel> createState() => _MeetingAttendancePanelState();
}

class _MeetingAttendancePanelState extends State<MeetingAttendancePanel> {
  late MeetingAttendanceRepository _repository;
  List<MeetingAttendanceRow> _items = [];
  bool _loading = true;
  bool _working = false;
  bool _receiptSaving = false;
  bool _loadFailed = false;
  bool _available = true;
  int _generation = 0;
  MeetingQrCode? _qr;
  String _qrCaption = '';
  MeetingCheckIn? _lastCheckIn;
  ({int booking, int participant, int slot, String name})? _receipt;

  bool get _busy => _loading || _working || _receiptSaving;
  List<MeetingAttendanceRow> get _visible => [
    for (final item in _items)
      if (widget.participantId == null ||
          item.participantId == widget.participantId)
        if (widget.slotId == null || item.slotId == widget.slotId) item,
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MeetingAttendanceRepository();
    _load();
  }

  @override
  void didUpdateWidget(covariant MeetingAttendancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final repositoryChanged = oldWidget.repository != widget.repository;
    if (repositoryChanged) {
      if (oldWidget.repository == null) _repository.dispose();
      _repository = widget.repository ?? MeetingAttendanceRepository();
    }
    if (oldWidget.bookingId != widget.bookingId ||
        oldWidget.participantId != widget.participantId ||
        oldWidget.slotId != widget.slotId ||
        repositoryChanged) {
      _items = [];
      _qr = null;
      _lastCheckIn = null;
      _receipt = null;
      _working = false;
      _receiptSaving = false;
      _available = true;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _loadFailed = false;
      _qr = null;
    });
    try {
      final result = await _repository.list(
        widget.bookingId,
        slotId: widget.slotId,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _available = result.available;
        _items = result.items;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = [];
        _loadFailed = true;
      });
      widget.onMessage(
        meetingAttendanceError(error, 'โหลดข้อมูลเช็กอินไม่สำเร็จ'),
        true,
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _issue(
    MeetingAttendanceRow item, {
    required bool personal,
  }) async {
    if (_busy || (personal ? !item.canIssuePersonalQr : !item.canIssueRoomQr)) {
      return;
    }
    final generation = _generation;
    setState(() {
      _working = true;
      _qr = null;
    });
    try {
      final result = await _repository.issueQr(
        widget.bookingId,
        item.slotId,
        participantId: personal ? item.participantId : null,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _qr = result;
        _qrCaption = personal
            ? 'QR คำเชิญ: ${item.participantName}'
            : 'QR ห้อง · รอบ ${item.slotId}';
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        widget.onMessage(
          meetingAttendanceError(error, 'ออก QR ไม่สำเร็จ'),
          true,
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _working = false);
      }
    }
  }

  String _nameFor(int participantId) {
    for (final item in _items) {
      if (item.participantId == participantId) return item.participantName;
    }
    return 'ผู้เข้าร่วม $participantId';
  }

  Future<bool> _checkIn({String? token, MeetingAttendanceRow? item}) async {
    if (_busy) return false;
    if (token == null && item?.canManualCheckIn != true) return false;
    if (token != null &&
        !_visible.any((row) => row.canScanRoomQr || row.canScanPersonalQr)) {
      return false;
    }
    final generation = _generation;
    setState(() => _working = true);
    MeetingCheckIn result;
    try {
      result = token != null
          ? await _repository.consumeQr(token)
          : await _repository.manualCheckIn(
              widget.bookingId,
              item!.participantId,
              item.slotId,
            );
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _working = false);
        widget.onMessage(
          meetingAttendanceError(error, 'เช็กอินไม่สำเร็จ'),
          true,
        );
      }
      return false;
    }
    if (!mounted || generation != _generation) return true;
    setState(() {
      _working = false;
      _lastCheckIn = result;
      _receipt = (
        booking: result.bookingId,
        participant: result.participantId,
        slot: result.slotId,
        name: result.bookingId == widget.bookingId
            ? _nameFor(result.participantId)
            : 'ผู้เข้าร่วม ${result.participantId}',
      );
    });
    // A receipt failure must never be reported as a failed check-in. Receipt
    // loading/saving is handled independently by MeetingFoodReceiptPanel.
    widget.onMessage(
      'เช็กอินแล้ว · การจอง ${result.bookingId} · รอบ ${result.slotId}',
      false,
    );
    await _load();
    return true;
  }

  void _openReceipt(MeetingAttendanceRow item) {
    if (_busy || item.checkInDate == null) return;
    setState(
      () => _receipt = (
        booking: widget.bookingId,
        participant: item.participantId,
        slot: item.slotId,
        name: item.participantName,
      ),
    );
  }

  String _method(String? method) => switch (method) {
    'QR_SELF' => 'สแกน QR ห้อง',
    'QR_STAFF' => 'ผู้ดูแลสแกน QR คำเชิญ',
    'MANUAL' => 'ผู้ดูแลเช็กอินแทน',
    'SELF' => 'เช็กอินด้วยตนเอง',
    _ => method ?? '-',
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkspaceThemePreset>(
      valueListenable: workspaceThemeController,
      builder: (context, preset, _) {
        final theme = Theme.of(context);
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        );
        final buttonText = const TextStyle(fontSize: LaooTypography.button);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(primary: preset.primary),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: preset.primary,
                minimumSize: const Size(0, LaooTypography.buttonHeight),
                shape: shape,
                textStyle: buttonText,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: preset.primary,
                minimumSize: const Size(0, LaooTypography.buttonHeight),
                shape: shape,
                textStyle: buttonText,
              ),
            ),
          ),
          child: _buildPanel(preset),
        );
      },
    );
  }

  Widget _buildPanel(WorkspaceThemePreset preset) {
    if (!_loading && !_available) return const SizedBox.shrink();
    final items = _visible;
    final roomSlots = <int, MeetingAttendanceRow>{
      for (final item in items)
        if (item.canIssueRoomQr) item.slotId: item,
    };
    final receipt = _receipt;
    final checked = _lastCheckIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.how_to_reg_outlined, color: preset.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'เช็กอินผู้เข้าร่วม',
                style: TextStyle(
                  fontSize: LaooTypography.sectionTitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'รีเฟรชเช็กอิน',
              onPressed: _busy ? null : _load,
              icon: Icon(Icons.refresh, color: preset.primary),
            ),
          ],
        ),
        const Text(
          'เช็กอินได้ในช่วงเวลาเริ่มจนถึงก่อนสิ้นสุดการประชุม จากนั้นบันทึกรับอาหารจริงแยกต่างหาก',
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_loadFailed)
          const Text('โหลดข้อมูลไม่สำเร็จ กดรีเฟรชเช็กอินเพื่อลองใหม่'),
        if (!_loading && !_loadFailed && items.isEmpty)
          const Text('ไม่พบผู้เข้าร่วมที่มีสิทธิ์ดูในรายการนี้'),
        if (items.any((row) => row.canScanRoomQr || row.canScanPersonalQr)) ...[
          const SizedBox(height: 12),
          MeetingQrScanner(
            key: ValueKey((widget.bookingId, widget.participantId)),
            enabled: !_busy,
            onToken: (token) => _checkIn(token: token),
            onError: (message) => widget.onMessage(message, true),
          ),
        ],
        if (roomSlots.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in roomSlots.values)
                OutlinedButton.icon(
                  key: ValueKey('room-qr-${item.slotId}'),
                  onPressed: _busy ? null : () => _issue(item, personal: false),
                  icon: const Icon(Icons.qr_code),
                  label: Text(
                    'QR ห้อง · ${meetingAttendanceDate(item.startDateTime)}',
                  ),
                ),
            ],
          ),
        ],
        if (_qr != null) ...[
          const SizedBox(height: 12),
          _MeetingQrDisplay(
            key: ValueKey(_qr),
            qr: _qr!,
            caption: _qrCaption,
            onClose: () => setState(() => _qr = null),
          ),
        ],
        if (checked != null) ...[
          const SizedBox(height: 12),
          Text(
            'เช็กอินการจอง ${checked.bookingId} · ผู้เข้าร่วม ${checked.participantId} · รอบ ${checked.slotId}\n'
            '${_method(checked.method)} · ผู้บันทึก ${checked.checkInByUserId ?? '-'} · ${meetingAttendanceDate(checked.checkInDate)}',
            style: TextStyle(color: preset.primary),
          ),
        ],
        if (receipt != null) ...[
          const SizedBox(height: 12),
          MeetingFoodReceiptPanel(
            key: ValueKey((receipt.booking, receipt.participant, receipt.slot)),
            repository: _repository,
            bookingId: receipt.booking,
            participantId: receipt.participant,
            slotId: receipt.slot,
            participantName: receipt.name,
            onMessage: widget.onMessage,
            onClose: () => setState(() => _receipt = null),
            onSaving: (value) => setState(() => _receiptSaving = value),
          ),
        ],
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              decoration: BoxDecoration(
                color: LaooColors.white,
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.participantName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${meetingAttendanceDate(item.startDateTime)} - ${meetingAttendanceDate(item.endDateTime)}',
                  ),
                  if (item.checkInDate != null)
                    Text(
                      'เช็กอินแล้ว ${meetingAttendanceDate(item.checkInDate)}\n'
                      '${_method(item.method)} · ผู้บันทึก ${item.checkInByUserId ?? '-'}',
                      style: TextStyle(color: preset.primary),
                    )
                  else
                    const Text('ยังไม่เช็กอิน'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (item.canIssuePersonalQr)
                        OutlinedButton.icon(
                          key: ValueKey(
                            'personal-qr-${item.participantId}-${item.slotId}',
                          ),
                          onPressed: _busy
                              ? null
                              : () => _issue(item, personal: true),
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('QR คำเชิญ'),
                        ),
                      if (item.checkInDate == null && item.canManualCheckIn)
                        FilledButton.icon(
                          key: ValueKey(
                            'manual-check-in-${item.participantId}-${item.slotId}',
                          ),
                          onPressed: _busy ? null : () => _checkIn(item: item),
                          icon: const Icon(Icons.how_to_reg_outlined),
                          label: const Text('เช็กอิน'),
                        ),
                      if (item.checkInDate != null)
                        OutlinedButton.icon(
                          key: ValueKey(
                            'food-receipt-${item.participantId}-${item.slotId}',
                          ),
                          onPressed: _busy ? null : () => _openReceipt(item),
                          icon: const Icon(Icons.restaurant_outlined),
                          label: const Text('รับอาหารจริง / ดูยอดรับ'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MeetingQrDisplay extends StatefulWidget {
  const _MeetingQrDisplay({
    super.key,
    required this.qr,
    required this.caption,
    required this.onClose,
  });
  final MeetingQrCode qr;
  final String caption;
  final VoidCallback onClose;
  @override
  State<_MeetingQrDisplay> createState() => _MeetingQrDisplayState();
}

class _MeetingQrDisplayState extends State<_MeetingQrDisplay>
    with WidgetsBindingObserver {
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final duration = widget.qr.expiresAtUtc.difference(DateTime.now().toUtc());
    _expiry = Timer(duration.isNegative ? Duration.zero : duration, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.caption,
                style: const TextStyle(
                  fontSize: LaooTypography.sectionTitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'ปิด QR',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Text('การจอง ${widget.qr.bookingId} · รอบ ${widget.qr.slotId}'),
        Text(
          widget.qr.kind == 'ROOM'
              ? 'ผู้เข้าร่วมเข้าสู่ระบบแล้วสแกน QR นี้'
              : 'ให้ผู้ดูแลสแกน QR นี้เพื่อเช็กอินตามคำเชิญ',
        ),
        if (widget.qr.expired)
          const Text('QR หมดอายุแล้ว กดปุ่ม QR ของรอบนี้เพื่อออกใหม่')
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: AspectRatio(
                aspectRatio: 1,
                child: QrImageView(
                  data: widget.qr.token,
                  backgroundColor: LaooColors.white,
                  padding: const EdgeInsets.all(24),
                  semanticsLabel: 'QR เช็กอินรอบ ${widget.qr.slotId}',
                  errorStateBuilder: (_, _) => const Center(
                    child: Text('แสดง QR ไม่สำเร็จ กรุณาออก QR ใหม่'),
                  ),
                ),
              ),
            ),
          ),
          Text('ใช้ได้ถึง ${meetingAttendanceDate(widget.qr.expiresAtUtc)}'),
        ],
      ],
    );
  }
}
