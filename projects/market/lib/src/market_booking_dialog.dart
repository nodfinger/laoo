import 'dart:math';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'host.dart';

String _iso(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _requestKey() {
  final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final text = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${text.substring(0, 8)}-${text.substring(8, 12)}-${text.substring(12, 16)}-${text.substring(16, 20)}-${text.substring(20)}';
}

InputDecoration _input(LaooWorkspaceUiTokens t, String label) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(t.radius),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    border: border(t.borderColor),
    enabledBorder: border(t.borderColor),
    focusedBorder: border(t.primaryColor),
  );
}

class MarketBookingDialog extends StatefulWidget {
  const MarketBookingDialog({
    super.key,
    required this.title,
    required this.iconName,
    required this.stall,
    required this.traders,
    required this.selectedDay,
    required this.api,
    required this.tokens,
    required this.onSaved,
  });
  final String title;
  final String? iconName;
  final Map<String, dynamic> stall;
  final List<Map<String, dynamic>> traders;
  final DateTime selectedDay;
  final JsonApiClient api;
  final LaooWorkspaceUiTokens tokens;
  final VoidCallback onSaved;
  @override
  State<MarketBookingDialog> createState() => _MarketBookingDialogState();
}

class _MarketBookingDialogState extends State<MarketBookingDialog> {
  static const base = '/api/company/market';
  int? traderId;
  late DateTime from = widget.selectedDay;
  late DateTime to = widget.selectedDay;
  String idempotencyKey = _requestKey();
  bool saving = false, savedAny = false;
  String? error;

  Future<void> selectDate(bool first) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: first ? from : to,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (first) {
        from = picked;
        if (to.isBefore(from)) to = from;
      } else {
        to = picked;
      }
      idempotencyKey = _requestKey();
      error = null;
    });
  }

  Future<void> save() async {
    if (saving) return;
    if (traderId == null || to.isBefore(from)) {
      setState(() => error = 'เลือกผู้ค้าและช่วงวันที่ที่ถูกต้อง');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.post(
        '$base/bookings',
        body: {
          'stallID': widget.stall['id'],
          'traderID': traderId,
          'startsOn': _iso(from),
          'endsOn': _iso(to),
          'idempotencyKey': idempotencyKey,
        },
      );
      if (!mounted) return;
      widget.onSaved();
      marketMessage(context, message: 'จองล็อกแล้ว', error: false);
      setState(() {
        savedAny = true;
        traderId = null;
        idempotencyKey = _requestKey();
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = marketErrorText(e, 'จองล็อก'));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return Dialog(
      insetPadding: EdgeInsets.all(t.dialogInsetPadding),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: t.popupMaxWidth,
          maxHeight:
              MediaQuery.sizeOf(context).height - t.dialogInsetPadding * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: t.cardPadding,
              child: Row(
                children: [
                  Icon(
                    marketMenuIcon(widget.iconName),
                    color: t.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.title} > จองล็อก',
                      style: t.captionStyle,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: t.borderColor),
            Flexible(
              child: SingleChildScrollView(
                padding: t.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ล็อก ${widget.stall['code']} · ${widget.stall['zone']}',
                      style: t.sectionStyle,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      key: ValueKey('trader-$traderId'),
                      initialValue: traderId,
                      isExpanded: true,
                      decoration: _input(t, 'ผู้ค้า *'),
                      items: widget.traders
                          .map(
                            (trader) => DropdownMenuItem<int>(
                              value: (trader['id'] as num).toInt(),
                              child: Text(
                                '${trader['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) => setState(() {
                              traderId = value;
                              idempotencyKey = _requestKey();
                              error = null;
                            }),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => selectDate(true),
                      child: InputDecorator(
                        decoration: _input(t, 'วันที่เริ่ม *').copyWith(
                          suffixIcon: const Icon(Icons.calendar_month_outlined),
                        ),
                        child: Text(marketDateText(from), style: t.inputStyle),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => selectDate(false),
                      child: InputDecorator(
                        decoration: _input(t, 'วันที่สิ้นสุด *').copyWith(
                          suffixIcon: const Icon(Icons.calendar_month_outlined),
                        ),
                        child: Text(marketDateText(to), style: t.inputStyle),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ผู้ค้าที่มีประวัติเช่าจองล่วงหน้าได้; ล็อกจองค้างไว้ 24 ชั่วโมง',
                      style: t.tableStyle,
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: t.borderColor),
            Padding(
              padding: t.cardPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(context, savedAny),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(84, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radius),
                      ),
                    ),
                    child: Text(savedAny ? 'ปิด' : 'ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(100, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radius),
                      ),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('จอง'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketCancelDialog extends StatefulWidget {
  const MarketCancelDialog({super.key, required this.tokens});
  final LaooWorkspaceUiTokens tokens;
  @override
  State<MarketCancelDialog> createState() => _MarketCancelDialogState();
}

class _MarketCancelDialogState extends State<MarketCancelDialog> {
  final reason = TextEditingController();
  String? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return Dialog(
      insetPadding: EdgeInsets.all(t.dialogInsetPadding),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.popupMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: t.cardPadding,
              child: Row(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    color: t.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ผังและล็อกขายของ > ยกเลิกการจอง',
                      style: t.captionStyle,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: t.borderColor),
            Padding(
              padding: t.cardPadding,
              child: Column(
                children: [
                  TextField(
                    controller: reason,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: _input(t, 'เหตุผลยกเลิก *'),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: t.borderColor),
            Padding(
              padding: t.cardPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(84, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radius),
                      ),
                    ),
                    child: const Text('กลับ'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (reason.text.trim().isEmpty) {
                        setState(() => error = 'ระบุเหตุผลยกเลิก');
                        return;
                      }
                      Navigator.pop(context, reason.text.trim());
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(100, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radius),
                      ),
                    ),
                    child: const Text('ยืนยันยกเลิก'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
