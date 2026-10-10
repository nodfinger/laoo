import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'booking_host.dart';

class BookingCapabilitiesDialog extends StatefulWidget {
  const BookingCapabilitiesDialog({
    super.key,
    required this.provider,
    required this.id,
    required this.title,
    required this.api,
    required this.tokens,
  });
  final bool provider;
  final int id;
  final String title;
  final JsonApiClient api;
  final LaooWorkspaceUiTokens tokens;
  @override
  State<BookingCapabilitiesDialog> createState() =>
      _BookingCapabilitiesDialogState();
}

class _Slot {
  _Slot(this.day, this.start, this.end);
  int day;
  String start, end;
  String apiTime(String value) => value.length == 5 ? '$value:00' : value;
  Map<String, dynamic> toJson() => {
    'weekdayNumber': day,
    'startsAt': apiTime(start),
    'endsAt': apiTime(end),
  };
}

class _BookingCapabilitiesDialogState extends State<BookingCapabilitiesDialog> {
  static const base = '/api/company/booking';
  final serviceIds = <int>{};
  final slots = <_Slot>[];
  List<Map<String, dynamic>> services = [];
  bool loading = true, saving = false;
  String? error;

  String get endpoint => widget.provider
      ? 'providers/${widget.id}/schedule'
      : 'resources/${widget.id}/services';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final menu = widget.provider ? '61003' : '61004';
      final options = await widget.api.get('$base/options/$menu');
      final master = await widget.api.get('$base/$endpoint');
      services = ((options as Map)['services'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (widget.provider) {
        final value = master as Map;
        serviceIds.addAll(
          (value['serviceIds'] as List? ?? []).whereType<num>().map(
            (e) => e.toInt(),
          ),
        );
        for (final raw in (value['slots'] as List? ?? []).whereType<Map>()) {
          final s = Map<String, dynamic>.from(raw);
          slots.add(
            _Slot(
              (s['weekdayNumber'] as num).toInt(),
              s['startsAt'].toString().substring(0, 5),
              s['endsAt'].toString().substring(0, 5),
            ),
          );
        }
      } else {
        serviceIds.addAll(
          (master as List).whereType<Map>().map(
            (e) => (e['serviceId'] as num).toInt(),
          ),
        );
      }
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = bookingErrorText(e, 'โหลดข้อมูล');
        });
      }
    }
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.api.put(
        '$base/$endpoint',
        body: widget.provider
            ? {
                'serviceIds': serviceIds.toList(),
                'slots': slots.map((e) => e.toJson()).toList(),
              }
            : {'serviceIds': serviceIds.toList()},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        bookingMessage(
          context,
          message: bookingErrorText(e, 'บันทึกความสามารถ'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LaooActionDialog(
    tokens: widget.tokens,
    icon: widget.provider
        ? Icons.schedule_outlined
        : Icons.room_preferences_outlined,
    title: '${widget.title} > บริการและเวลา',
    content: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Text(error!)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('บริการที่รองรับ', style: widget.tokens.sectionStyle),
              if (services.isEmpty)
                const Text('ยังไม่มีบริการ กรุณาเพิ่มประเภทบริการก่อน'),
              ...services.map((service) {
                final id = (service['id'] as num).toInt();
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(service['name'].toString()),
                  value: serviceIds.contains(id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      serviceIds.add(id);
                    } else {
                      serviceIds.remove(id);
                    }
                  }),
                );
              }),
              if (widget.provider) ...[
                const Divider(),
                Text(
                  'ช่วงเวลาให้บริการ (ว่าง = ไม่จำกัด)',
                  style: widget.tokens.sectionStyle,
                ),
                ...slots.asMap().entries.map((entry) {
                  final slot = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            initialValue: slot.day,
                            decoration: const InputDecoration(
                              labelText: 'วัน',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('จันทร์')),
                              DropdownMenuItem(value: 2, child: Text('อังคาร')),
                              DropdownMenuItem(value: 3, child: Text('พุธ')),
                              DropdownMenuItem(
                                value: 4,
                                child: Text('พฤหัสบดี'),
                              ),
                              DropdownMenuItem(value: 5, child: Text('ศุกร์')),
                              DropdownMenuItem(value: 6, child: Text('เสาร์')),
                              DropdownMenuItem(
                                value: 7,
                                child: Text('อาทิตย์'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) slot.day = v;
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextFormField(
                            initialValue: slot.start,
                            decoration: const InputDecoration(
                              labelText: 'เริ่ม',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => slot.start = v,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextFormField(
                            initialValue: slot.end,
                            decoration: const InputDecoration(
                              labelText: 'สิ้นสุด',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => slot.end = v,
                          ),
                        ),
                        IconButton(
                          tooltip: 'ลบช่วงเวลา',
                          onPressed: () =>
                              setState(() => slots.removeAt(entry.key)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => slots.add(_Slot(1, '09:00', '17:00'))),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มช่วงเวลา'),
                ),
              ],
            ],
          ),
    actions: [
      OutlinedButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: saving || loading || error != null ? null : save,
        icon: const Icon(Icons.save_outlined),
        label: Text(saving ? 'กำลังบันทึก' : 'บันทึก'),
      ),
    ],
  );
}
