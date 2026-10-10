import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'booking_host.dart';

class BookingForm extends StatefulWidget {
  const BookingForm({
    super.key,
    required this.code,
    required this.title,
    required this.row,
    required this.options,
    required this.settings,
    required this.api,
    required this.tokens,
    required this.icon,
  });
  final String code, title;
  final Map<String, dynamic>? row;
  final Map<String, dynamic> options, settings;
  final JsonApiClient api;
  final LaooWorkspaceUiTokens tokens;
  final IconData icon;
  @override
  State<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<BookingForm> {
  static const base = '/api/company/booking';
  final key = GlobalKey<FormState>();
  final values = <String, TextEditingController>{};
  bool saving = false, needsProvider = false, needsResource = false;
  int? memberId, branchId, serviceId, personId;
  final selectedServices = <int>{};
  final providersByService = <int, int?>{};
  final resourcesByService = <int, int?>{};
  DateTime start = DateTime.now().add(const Duration(hours: 1));
  DateTime end = DateTime.now().add(const Duration(hours: 2));

  String value(String name) => values[name]?.text.trim() ?? '';
  TextEditingController field(
    String name, [
    String? source,
  ]) => values.putIfAbsent(
    name,
    () => TextEditingController(
      text:
          '${widget.row?[source ?? name] ?? widget.settings[source ?? name] ?? ''}',
    ),
  );
  List<Map<String, dynamic>> list(String name) =>
      (widget.options[name] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  @override
  void initState() {
    super.initState();
    final row = widget.row;
    if (row != null) {
      memberId = (row['memberId'] as num?)?.toInt();
      branchId = (row['branchId'] as num?)?.toInt();
      personId = (row['personId'] as num?)?.toInt();
      needsProvider = row['requiresProvider'] == true;
      needsResource = row['requiresResource'] == true;
    }
  }

  @override
  void dispose() {
    for (final c in values.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget textField(
    String label,
    String name, {
    bool required = true,
    TextInputType? keyboard,
  }) => TextFormField(
    controller: field(name),
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: required ? '$label *' : label,
      border: const OutlineInputBorder(),
    ),
    validator: required
        ? (v) => v == null || v.trim().isEmpty ? 'กรุณากรอก$label' : null
        : null,
  );

  Widget choice(
    String label,
    String source,
    int? current,
    ValueChanged<int?> onChanged, {
    bool required = false,
  }) {
    final options = list(source);
    return DropdownButtonFormField<int>(
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (e) => DropdownMenuItem<int>(
              value: (e['id'] as num).toInt(),
              child: Text(
                '${e['name'] ?? e['code']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      validator: required ? (v) => v == null ? 'กรุณาเลือก$label' : null : null,
      onChanged: onChanged,
    );
  }

  Widget formFields() => switch (widget.code) {
    '61001' => Column(
      children: [
        textField(
          'จำนวนวันจองล่วงหน้า',
          'advanceDays',
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 16),
        textField(
          'ชั่วโมงก่อนเริ่มที่ยกเลิกได้',
          'cancelBeforeHours',
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 16),
        textField(
          'นาทีรอผู้ใช้บริการ',
          'noShowGraceMinutes',
          keyboard: TextInputType.number,
        ),
      ],
    ),
    '61002' => Column(
      children: [
        if (widget.row == null) ...[
          textField('รหัสบริการ', 'code'),
          const SizedBox(height: 16),
        ],
        textField('ชื่อบริการ', 'name'),
        const SizedBox(height: 16),
        textField(
          'ระยะเวลา (นาที)',
          'durationMinutes',
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 16),
        textField('ราคา', 'price', keyboard: TextInputType.number),
        SwitchListTile(
          title: const Text('ต้องเลือกผู้ให้บริการ'),
          value: needsProvider,
          onChanged: (v) => setState(() => needsProvider = v),
        ),
        SwitchListTile(
          title: const Text('ต้องเลือกห้อง/ทรัพยากร'),
          value: needsResource,
          onChanged: (v) => setState(() => needsResource = v),
        ),
      ],
    ),
    '61003' => choice(
      'บุคลากร',
      'people',
      personId,
      (v) => setState(() => personId = v),
      required: true,
    ),
    '61004' => Column(
      children: [
        textField('ชื่อห้อง/ทรัพยากร', 'name'),
        const SizedBox(height: 16),
        textField('ประเภท', 'type'),
        const SizedBox(height: 16),
        choice(
          'สาขา',
          'branches',
          branchId,
          (v) => setState(() => branchId = v),
        ),
      ],
    ),
    '61005' => Column(
      children: [
        choice(
          'บุคคล',
          'people',
          personId,
          (v) => setState(() => personId = v),
          required: true,
        ),
        const SizedBox(height: 16),
        textField('รหัสสมาชิก', 'code'),
        const SizedBox(height: 16),
        textField('ระดับสมาชิก', 'tierCode'),
        const SizedBox(height: 16),
        textField('วันเริ่ม YYYY-MM-DD', 'startsOn'),
        const SizedBox(height: 16),
        textField('วันหมดอายุ YYYY-MM-DD', 'expiresOn', required: false),
      ],
    ),
    '61006' => Column(
      children: [
        textField('รหัสโปรโมชั่น', 'code'),
        const SizedBox(height: 16),
        textField('ชื่อโปรโมชั่น', 'name'),
        const SizedBox(height: 16),
        textField('ประเภทส่วนลด AMOUNT/PERCENT', 'discountType'),
        const SizedBox(height: 16),
        textField('ส่วนลด', 'discountValue', keyboard: TextInputType.number),
        const SizedBox(height: 16),
        textField('เริ่ม YYYY-MM-DD', 'startsAt'),
        const SizedBox(height: 16),
        textField('สิ้นสุด YYYY-MM-DD', 'endsAt'),
        const SizedBox(height: 16),
        choice(
          'บริการ (ว่าง = ทุกบริการ)',
          'services',
          serviceId,
          (v) => setState(() => serviceId = v),
        ),
      ],
    ),
    '61007' => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        choice(
          'สมาชิก (ไม่บังคับ)',
          'members',
          memberId,
          (v) => setState(() => memberId = v),
        ),
        if (memberId == null) ...[
          const SizedBox(height: 16),
          textField('ชื่อลูกค้าทั่วไป', 'guestName'),
          const SizedBox(height: 16),
          textField('เบอร์โทร', 'guestPhone', required: false),
        ],
        const SizedBox(height: 16),
        choice(
          'สาขา',
          'branches',
          branchId,
          (v) => setState(() => branchId = v),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => selectTime(true),
          icon: const Icon(Icons.schedule),
          label: Text('เริ่ม: ${start.toLocal()}'),
        ),
        OutlinedButton.icon(
          onPressed: () => selectTime(false),
          icon: const Icon(Icons.schedule),
          label: Text('สิ้นสุด: ${end.toLocal()}'),
        ),
        const SizedBox(height: 12),
        const Text('บริการที่เลือก *'),
        ...list('services').map((s) {
          final id = (s['id'] as num).toInt();
          return Column(
            children: [
              CheckboxListTile(
                title: Text('${s['name']} — ${s['price']}'),
                value: selectedServices.contains(id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    selectedServices.add(id);
                  } else {
                    selectedServices.remove(id);
                    providersByService.remove(id);
                    resourcesByService.remove(id);
                  }
                }),
              ),
              if (selectedServices.contains(id)) ...[
                choice(
                  'ผู้ให้บริการ',
                  'providers',
                  providersByService[id],
                  (v) => setState(() => providersByService[id] = v),
                  required: s['requiresProvider'] == true,
                ),
                const SizedBox(height: 8),
                choice(
                  'ห้อง/ทรัพยากร',
                  'resources',
                  resourcesByService[id],
                  (v) => setState(() => resourcesByService[id] = v),
                  required: s['requiresResource'] == true,
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        }),
        const SizedBox(height: 16),
        textField('หมายเหตุ', 'note', required: false),
      ],
    ),
    _ => const Text('ไม่รองรับการแก้ไขรายการนี้'),
  };

  Future<void> selectTime(bool begin) async {
    final current = begin ? start : end;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: current,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final next = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (begin) {
        start = next;
      } else {
        end = next;
      }
    });
  }

  Future<void> save() async {
    if (saving || !key.currentState!.validate()) return;
    final code = widget.code;
    if (code == '61007' && (selectedServices.isEmpty || !end.isAfter(start))) {
      bookingMessage(
        context,
        message: 'เลือกบริการและช่วงเวลาที่ถูกต้อง',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      final Map<String, dynamic> body;
      final String path;
      switch (code) {
        case '61001':
          path = 'settings';
          body = {
            'advanceDays': int.parse(value('advanceDays')),
            'cancelBeforeHours': int.parse(value('cancelBeforeHours')),
            'noShowGraceMinutes': int.parse(value('noShowGraceMinutes')),
          };
          break;
        case '61002':
          path = 'services';
          body = {
            'serviceCode': value('code'),
            'serviceName': value('name'),
            'durationMinutes': int.parse(value('durationMinutes')),
            'price': double.parse(value('price')),
            'requiresProvider': needsProvider,
            'requiresResource': needsResource,
          };
          break;
        case '61003':
          path = 'providers';
          body = {'personId': personId};
          break;
        case '61004':
          path = 'resources';
          body = {
            'branchId': branchId,
            'resourceName': value('name'),
            'resourceType': value('type'),
            if (widget.row != null) 'isActive': widget.row?['active'] == true,
          };
          break;
        case '61005':
          path = 'members';
          body = {
            'personId': personId,
            'memberCode': value('code'),
            'tierCode': value('tierCode'),
            'startsOn': value('startsOn').substring(0, 10),
            'expiresOn': value('expiresOn').isEmpty
                ? null
                : value('expiresOn').substring(0, 10),
            if (widget.row != null) 'isActive': widget.row?['active'] == true,
          };
          break;
        case '61006':
          path = 'promotions';
          body = {
            'promotionCode': value('code'),
            'promotionName': value('name'),
            'serviceId': serviceId,
            'tierCode': null,
            'startsAt': DateTime.parse(
              value('startsAt'),
            ).toUtc().toIso8601String(),
            'endsAt': DateTime.parse(value('endsAt')).toUtc().toIso8601String(),
            'discountType': value('discountType').toUpperCase(),
            'discountValue': double.parse(value('discountValue')),
          };
          break;
        case '61007':
          path = 'bookings';
          body = {
            'memberId': memberId,
            'guestName': memberId == null ? value('guestName') : null,
            'guestPhone': memberId == null ? value('guestPhone') : null,
            'branchId': branchId,
            'startsAt': start.toUtc().toIso8601String(),
            'endsAt': end.toUtc().toIso8601String(),
            'note': value('note'),
            'services': selectedServices
                .map(
                  (id) => {
                    'serviceId': id,
                    'providerId': providersByService[id],
                    'resourceId': resourcesByService[id],
                  },
                )
                .toList(),
          };
          break;
        default:
          return;
      }
      final id = widget.row?['id'];
      if (code == '61001' || id != null) {
        if (id != null) {
          if (code == '61002') body.remove('serviceCode');
        }
        await widget.api.put(
          '$base/$path${id == null ? '' : '/$id'}',
          body: body,
        );
      } else {
        await widget.api.post('$base/$path', body: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        bookingMessage(
          context,
          message: bookingErrorText(e, 'บันทึกข้อมูล'),
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
    icon: widget.icon,
    title: '${widget.title} > ${widget.row == null ? 'เพิ่ม' : 'แก้ไข'}',
    content: Form(key: key, child: formFields()),
    actions: [
      OutlinedButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: saving ? null : save,
        icon: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
}
