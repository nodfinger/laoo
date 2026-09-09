import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_exception.dart';
import '../data/meeting_attendance_repository.dart';

String meetingAttendanceError(Object error, String operation) {
  if (error is ApiException) {
    return '$operation: ${error.message}'
        '${error.message.contains('รายละเอียดเพิ่มเติม:') ? '' : '\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาโหลดข้อมูลล่าสุดแล้วลองอีกครั้ง'}'}';
  }
  return '$operation\nรายละเอียดเพิ่มเติม: ไม่สามารถโหลดหรือบันทึกข้อมูลได้ กรุณาตรวจการเชื่อมต่อแล้วโหลดสถานะล่าสุดก่อนลองอีกครั้ง';
}

String meetingAttendanceDate(Object? value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '-';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

/// Actual receipt is independent of RSVP and food ordering. No quantity is
/// saved merely by opening this panel or by checking an attendee in.
class MeetingFoodReceiptPanel extends StatefulWidget {
  const MeetingFoodReceiptPanel({
    super.key,
    required this.repository,
    required this.bookingId,
    required this.participantId,
    required this.slotId,
    required this.participantName,
    required this.onMessage,
    required this.onClose,
    required this.onSaving,
  });

  final MeetingAttendanceRepository repository;
  final int bookingId;
  final int participantId;
  final int slotId;
  final String participantName;
  final void Function(String message, bool error) onMessage;
  final VoidCallback onClose;
  final ValueChanged<bool> onSaving;

  @override
  State<MeetingFoodReceiptPanel> createState() =>
      _MeetingFoodReceiptPanelState();
}

class _MeetingFoodReceiptPanelState extends State<MeetingFoodReceiptPanel> {
  final _form = GlobalKey<FormState>();
  final _quantities = <int, TextEditingController>{};
  MeetingFoodReceipt? _receipt;
  bool _loading = true;
  bool _saving = false;
  bool _needsRefresh = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MeetingFoodReceiptPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.bookingId, oldWidget.participantId, oldWidget.slotId) !=
        (widget.bookingId, widget.participantId, widget.slotId)) {
      _receipt = null;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _accept(MeetingFoodReceipt value) {
    _receipt = value;
    _needsRefresh = false;
    for (final item in value.items) {
      final controller = _quantities.putIfAbsent(
        item.foodOrderDetailId,
        TextEditingController.new,
      );
      controller.text = '${item.receivedQuantity}';
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      final result = await widget.repository.receipt(
        widget.bookingId,
        widget.participantId,
        widget.slotId,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _accept(result));
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _needsRefresh = true);
      widget.onMessage(
        meetingAttendanceError(error, 'โหลดข้อมูลรับอาหารไม่สำเร็จ'),
        true,
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final receipt = _receipt;
    if (_saving ||
        _loading ||
        _needsRefresh ||
        receipt == null ||
        !receipt.canReceive ||
        receipt.checkInDate == null ||
        !_form.currentState!.validate()) {
      return;
    }
    final quantities = <int, int>{
      for (final item in receipt.items)
        if (int.parse(_quantities[item.foodOrderDetailId]!.text.trim()) !=
            item.receivedQuantity)
          item.foodOrderDetailId: int.parse(
            _quantities[item.foodOrderDetailId]!.text.trim(),
          ),
    };
    if (quantities.isEmpty) {
      widget.onMessage('ยังไม่มีจำนวนรับจริงที่เปลี่ยนแปลง', false);
      return;
    }
    final generation = _generation;
    setState(() => _saving = true);
    widget.onSaving(true);
    try {
      final result = await widget.repository.saveReceipt(receipt, quantities);
      if (!mounted || generation != _generation) return;
      setState(() => _accept(result));
      widget.onMessage('บันทึกจำนวนรับอาหารจริงแล้ว', false);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      // A timeout can occur after the server committed. Reload the cumulative
      // baseline before allowing further edits, rather than adding a delta.
      setState(() => _needsRefresh = true);
      widget.onMessage(
        meetingAttendanceError(error, 'บันทึกรับอาหารไม่สำเร็จ'),
        true,
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _saving = false);
        widget.onSaving(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    final editable =
        !_loading &&
        !_saving &&
        !_needsRefresh &&
        receipt?.canReceive == true &&
        receipt?.checkInDate != null;
    return Container(
      key: const ValueKey('meeting-food-receipt'),
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      decoration: BoxDecoration(
        color: LaooColors.white,
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'รับอาหารจริง',
              style: TextStyle(
                fontSize: LaooTypography.sectionTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : widget.onClose,
                  child: const Text('ปิดรายการรับอาหาร'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading || _saving ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('โหลดข้อมูลรับอาหารล่าสุด'),
                ),
                if (receipt?.canReceive == true)
                  FilledButton.icon(
                    key: const ValueKey('save-food-receipt'),
                    onPressed: editable ? _save : null,
                    icon: const Icon(Icons.restaurant_outlined),
                    label: Text(
                      _saving ? 'กำลังบันทึก...' : 'บันทึกรับอาหารจริง',
                    ),
                  ),
              ],
            ),
            const Divider(color: LaooColors.border),
            Text(
              '${widget.participantName} · การจอง ${widget.bookingId} · รอบ ${widget.slotId}',
            ),
            const Text(
              'กรอกยอดรับสะสมทั้งการจอง รวมทุกรอบประชุม ไม่ใช่จำนวนที่รับเพิ่มครั้งนี้',
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_needsRefresh)
              const Text('กรุณาโหลดข้อมูลรับอาหารล่าสุดก่อนบันทึกอีกครั้ง'),
            if (!_loading && receipt != null) ...[
              if (receipt.checkInDate == null)
                const Text('ต้องเช็กอินรอบนี้ก่อนรับอาหาร')
              else
                Text('เช็กอิน ${meetingAttendanceDate(receipt.checkInDate)}'),
              if (receipt.items.isEmpty)
                const Text('ไม่มีรายการสั่งอาหารสำหรับผู้เข้าร่วมคนนี้'),
              if (!receipt.canReceive && receipt.items.isNotEmpty)
                const Text(
                  'ดูยอดรับอาหารได้ แต่ขณะนี้รับเพิ่มไม่ได้ กรุณาตรวจยอดคงเหลือ ช่วงเวลาประชุม และสิทธิ์',
                ),
              for (final item in receipt.items) ...[
                const SizedBox(height: 12),
                Text(
                  item.foodName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'สั่ง ${item.orderedQuantity} · รับแล้ว ${item.receivedQuantity} · คงเหลือ ${item.remainingQuantity}',
                ),
                if (item.receivedAtUtc != null)
                  Text(
                    'บันทึกล่าสุดโดยผู้ใช้ ${item.receivedByUserId ?? '-'} · ${meetingAttendanceDate(item.receivedAtUtc)} · รอบ ${item.receiptSlotId ?? '-'}',
                  ),
                const SizedBox(height: 12),
                if (receipt.canReceive && item.remainingQuantity > 0)
                  TextFormField(
                    key: ValueKey('receipt-quantity-${item.foodOrderDetailId}'),
                    controller: _quantities[item.foodOrderDetailId],
                    enabled: editable,
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'ยอดรับสะสมจริง *',
                      helperText:
                          'รับเพิ่ม 1 จากยอดเดิม ${item.receivedQuantity} ให้กรอก ${item.receivedQuantity + 1}',
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                    ),
                    validator: (value) => item.validateCumulative(value ?? ''),
                  ),
                const Divider(color: LaooColors.border),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
