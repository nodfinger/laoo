import 'dart:math';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'host.dart';

String sportKey() {
  final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

InputDecoration sportInput(LaooWorkspaceUiTokens t, String label) {
  OutlineInputBorder line(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(t.radius),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    border: line(t.borderColor),
    enabledBorder: line(t.borderColor),
    focusedBorder: line(t.primaryColor),
  );
}

class SportForm extends StatefulWidget {
  const SportForm({
    super.key,
    required this.code,
    required this.title,
    required this.iconName,
    required this.row,
    required this.settings,
    required this.sports,
    required this.levels,
    required this.facilities,
    required this.packages,
    required this.people,
    required this.branches,
    required this.members,
    required this.api,
    required this.tokens,
  });
  final String code, title;
  final String? iconName;
  final Map<String, dynamic>? row;
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> sports,
      levels,
      facilities,
      packages,
      members,
      people,
      branches;
  final JsonApiClient api;
  final LaooWorkspaceUiTokens tokens;
  @override
  State<SportForm> createState() => _SportFormState();
}

class _SportFormState extends State<SportForm> {
  static const base = '/api/company/sport';
  final key = GlobalKey<FormState>();
  final input = <String, TextEditingController>{};
  final picked = <String, int?>{};
  final selectedSports = <int>{};
  bool active = true, resident = false, saving = false, changed = false;
  bool detailsLoading = false;
  bool detailsFailed = false;
  String? error;
  String quotaUnit = 'VISIT', payment = 'CASH', gender = 'UNSPECIFIED';
  bool renew = false, useMembership = false, changeHours = false;
  final selectedDays = <int>{1, 2, 3, 4, 5, 6, 0};
  List<Map<String, dynamic>> memberships = [];
  List<Map<String, dynamic>> existingHours = [];

  @override
  void initState() {
    super.initState();
    final source = widget.row ?? widget.settings;
    for (final field in [
      'code',
      'name',
      'capacity',
      'days',
      'quota',
      'price',
      'PaymentHoldMinutes',
      'CancelBeforeMinutes',
      'CheckInGraceMinutes',
      'ExpiryNoticeDays',
      'priceLevelCode',
      'birthDate',
      'paymentReference',
      'reason',
      'startDate',
      'startTime',
      'endTime',
      'opensAt',
      'closesAt',
      'memberCode',
    ]) {
      input[field] = TextEditingController(
        text:
            (field == 'priceLevelCode' ? source['priceLevel'] : source[field])
                ?.toString() ??
            '',
      );
    }
    active = source['active'] != false;
    resident = source['resident'] == true;
    gender = source['gender']?.toString() ?? 'UNSPECIFIED';
    quotaUnit = source['unit']?.toString() ?? 'VISIT';
    picked['levelId'] = (source['levelId'] as num?)?.toInt();
    picked['sportTypeId'] = (source['sportTypeId'] as num?)?.toInt();
    picked['branchId'] = (source['branchId'] as num?)?.toInt();
    picked['personId'] = (source['personId'] as num?)?.toInt();
    picked['memberId'] = (source['memberId'] as num?)?.toInt();
    picked['packageId'] = (source['packageId'] as num?)?.toInt();
    picked['facilityId'] = (source['facilityId'] as num?)?.toInt();
    if (widget.code == '54003') {
      input['opensAt']!.text = '08:00';
      input['closesAt']!.text = '22:00';
      changeHours = widget.row == null;
    }
    if (widget.code == '54006' && input['birthDate']!.text.length >= 10) {
      input['birthDate']!.text = input['birthDate']!.text.substring(0, 10);
    }
    if (widget.code == '54007') {
      input['startDate']!.text = DateTime.now().toIso8601String().substring(
        0,
        10,
      );
    }
    if (widget.code == '54008') {
      final next = DateTime.now().add(const Duration(days: 1));
      input['startDate']!.text =
          '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
      input['startTime']!.text = '09:00';
      input['endTime']!.text = '10:00';
    }
    if ((widget.code == '54003' || widget.code == '54005') &&
        widget.row != null) {
      detailsLoading = true;
      loadDetails();
    }
  }

  Future<void> loadDetails() async {
    if (widget.row?['id'] is! num) return;
    try {
      final id = (widget.row!['id'] as num).toInt();
      if (widget.code == '54003') {
        final result = await widget.api.get('$base/facilities/$id/hours');
        existingHours = result is List
            ? result.map((v) => Map<String, dynamic>.from(v as Map)).toList()
            : [];
        if (existingHours.isEmpty) changeHours = true;
        if (existingHours.isNotEmpty) {
          selectedDays
            ..clear()
            ..addAll(existingHours.map((h) => (h['day'] as num).toInt()));
          input['opensAt']!.text = '${existingHours.first['opensAt']}'
              .substring(0, 5);
          input['closesAt']!.text = '${existingHours.first['closesAt']}'
              .substring(0, 5);
        }
      }
      if (widget.code == '54005') {
        final result = await widget.api.get('$base/packages/$id/sports');
        if (result is List) {
          selectedSports.addAll(result.whereType<num>().map((n) => n.toInt()));
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          detailsFailed = true;
          error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => detailsLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in input.values) {
      c.dispose();
    }
    super.dispose();
  }

  String text(String field) => input[field]!.text.trim();
  int? number(String field) => int.tryParse(text(field));
  double? decimal(String field) => double.tryParse(text(field));

  Widget field(
    String id,
    String title, {
    bool numeric = false,
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: input[id],
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: widget.tokens.inputStyle,
      decoration: sportInput(widget.tokens, title),
      validator: (v) => required && (v == null || v.trim().isEmpty)
          ? 'กรุณาระบุ$title'
          : numeric && v != null && v.isNotEmpty && double.tryParse(v) == null
          ? 'กรุณาระบุตัวเลข'
          : null,
    ),
  );

  Widget choice(
    String id,
    String label,
    List<Map<String, dynamic>> rows, {
    bool required = true,
  }) {
    final allowed = rows.where((r) => r['id'] is num).toList();
    final value = allowed.any((r) => r['id'] == picked[id]) ? picked[id] : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: sportInput(widget.tokens, label),
        items: allowed
            .map(
              (r) => DropdownMenuItem<int>(
                value: (r['id'] as num).toInt(),
                child: Text(
                  '${r['code'] ?? ''}  ${r['name'] ?? r['level'] ?? r['facility'] ?? ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => picked[id] = v),
        validator: (v) => required && v == null ? 'กรุณาเลือก$label' : null,
      ),
    );
  }

  Widget status() => Row(
    children: [
      const Text('สถานะ'),
      const SizedBox(width: 8),
      Switch(value: active, onChanged: (v) => setState(() => active = v)),
    ],
  );

  Widget formFields() => switch (widget.code) {
    '54001' => Column(
      children: [
        field('PaymentHoldMinutes', 'รอชำระ (นาที)', numeric: true),
        field('CancelBeforeMinutes', 'ยกเลิกล่วงหน้า (นาที)', numeric: true),
        field('CheckInGraceMinutes', 'เผื่อเวลาเช็กอิน (นาที)', numeric: true),
        field('ExpiryNoticeDays', 'แจ้งเตือนก่อนหมดอายุ (วัน)', numeric: true),
      ],
    ),
    '54002' => Column(
      children: [
        status(),
        field('code', 'รหัสประเภทกีฬา'),
        field('name', 'ชื่อประเภทกีฬา'),
      ],
    ),
    '54004' => Column(
      children: [
        status(),
        field('code', 'รหัสระดับ'),
        field('name', 'ชื่อระดับ'),
        SwitchListTile(
          title: const Text('เฉพาะผู้พักอาศัย'),
          value: resident,
          onChanged: (v) => setState(() => resident = v),
        ),
      ],
    ),
    '54003' => Column(
      children: [
        status(),
        field('code', 'รหัสสนาม'),
        field('name', 'ชื่อสนาม'),
        choice('branchId', 'สาขา', widget.branches),
        choice('sportTypeId', 'ประเภทกีฬา', widget.sports),
        field('capacity', 'ความจุ', numeric: true),
        if (widget.row != null)
          SwitchListTile(
            title: const Text('เปลี่ยนเวลาเปิดสนาม'),
            value: changeHours,
            onChanged: (v) => setState(() => changeHours = v),
          ),
        const Text('เวลาเปิดให้บริการ'),
        if (changeHours)
          Wrap(
            spacing: 3,
            children: List.generate(
              7,
              (day) => FilterChip(
                label: Text(['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'][day]),
                selected: selectedDays.contains(day),
                onSelected: (v) => setState(() {
                  if (v) {
                    selectedDays.add(day);
                  } else {
                    selectedDays.remove(day);
                  }
                }),
              ),
            ),
          ),
        if (changeHours) field('opensAt', 'เปิดเวลา (HH:mm)'),
        if (changeHours) field('closesAt', 'ปิดเวลา (HH:mm)'),
      ],
    ),
    '54005' => Column(
      children: [
        status(),
        field('code', 'รหัสแพ็กเกจ'),
        field('name', 'ชื่อแพ็กเกจ'),
        choice('levelId', 'ระดับสมาชิก', widget.levels, required: false),
        const Text('ประเภทกีฬาที่ใช้ได้'),
        ...widget.sports.map(
          (s) => CheckboxListTile(
            title: Text('${s['name']}'),
            value: selectedSports.contains(s['id']),
            onChanged: (v) => setState(() {
              final id = (s['id'] as num).toInt();
              if (v == true) {
                selectedSports.add(id);
              } else {
                selectedSports.remove(id);
              }
            }),
          ),
        ),
        field('days', 'ระยะเวลา (วัน)', numeric: true),
        DropdownButtonFormField<String>(
          initialValue: quotaUnit,
          decoration: sportInput(widget.tokens, 'หน่วยโควตา'),
          items: const [
            DropdownMenuItem(value: 'VISIT', child: Text('ครั้ง')),
            DropdownMenuItem(value: 'HOUR', child: Text('ชั่วโมง')),
            DropdownMenuItem(value: 'UNLIMITED', child: Text('ไม่จำกัด')),
          ],
          onChanged: (v) => setState(() => quotaUnit = v ?? 'VISIT'),
        ),
        if (quotaUnit != 'UNLIMITED')
          field('quota', 'จำนวนโควตา', numeric: true),
        field('price', 'ราคา', numeric: true),
      ],
    ),
    '54006' => Column(
      children: [
        status(),
        choice('personId', 'บุคคล', widget.people),
        field('code', 'รหัสสมาชิก'),
        choice('levelId', 'ระดับสมาชิก', widget.levels),
        field('birthDate', 'วันเกิด YYYY-MM-DD', required: false),
        DropdownButtonFormField<String>(
          initialValue: gender,
          decoration: sportInput(widget.tokens, 'เพศ'),
          items: const [
            DropdownMenuItem(value: 'UNSPECIFIED', child: Text('ไม่ระบุ')),
            DropdownMenuItem(value: 'MALE', child: Text('ชาย')),
            DropdownMenuItem(value: 'FEMALE', child: Text('หญิง')),
            DropdownMenuItem(value: 'OTHER', child: Text('อื่น ๆ')),
          ],
          onChanged: (v) => setState(() => gender = v ?? 'UNSPECIFIED'),
        ),
      ],
    ),
    '54007' => Column(
      children: [
        choice('memberId', 'สมาชิก', widget.members),
        choice('packageId', 'แพ็กเกจ', widget.packages),
        field('startDate', 'วันเริ่ม YYYY-MM-DD'),
        SwitchListTile(
          title: const Text('ต่ออายุ'),
          value: renew,
          onChanged: (v) => setState(() => renew = v),
        ),
        DropdownButtonFormField<String>(
          initialValue: payment,
          decoration: sportInput(widget.tokens, 'วิธีรับเงิน'),
          items: const [
            DropdownMenuItem(value: 'CASH', child: Text('เงินสด')),
            DropdownMenuItem(value: 'TRANSFER', child: Text('โอน')),
          ],
          onChanged: (v) => setState(() => payment = v ?? 'CASH'),
        ),
        field('paymentReference', 'เลขอ้างอิง', required: false),
      ],
    ),
    '54008' => Column(
      children: [
        choice('facilityId', 'สนาม', widget.facilities),
        choice('memberId', 'สมาชิก', widget.members),
        SwitchListTile(
          title: const Text('ใช้สิทธิ์แพ็กเกจสมาชิก'),
          value: useMembership,
          onChanged: (v) {
            setState(() => useMembership = v);
            loadMemberships();
          },
        ),
        if (useMembership)
          choice('membershipId', 'สิทธิ์แพ็กเกจ', memberships)
        else
          choice('packageId', 'แพ็กเกจรายครั้ง', widget.packages),
        field('startDate', 'วันที่ YYYY-MM-DD'),
        field('startTime', 'เริ่ม HH:mm'),
        field('endTime', 'สิ้นสุด HH:mm'),
      ],
    ),
    '54010' => Column(
      children: [
        status(),
        choice('levelId', 'ระดับสมาชิก', widget.levels),
        field('priceLevelCode', 'รหัสระดับราคาสินค้า'),
      ],
    ),
    _ => const SizedBox.shrink(),
  };

  Future<void> loadMemberships() async {
    final member = picked['memberId'];
    if (!useMembership || member == null) return;
    try {
      final result = await widget.api.get(
        '$base/bookings/member/$member/entitlements',
      );
      memberships = result is List
          ? result.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  String? pendingKey;
  Future<void> save() async {
    if (saving ||
        detailsLoading ||
        detailsFailed ||
        !(key.currentState?.validate() ?? false)) {
      return;
    }
    final code = widget.code;
    if (code == '54005' && selectedSports.isEmpty) {
      setState(() => error = 'กรุณาเลือกประเภทกีฬาอย่างน้อยหนึ่งรายการ');
      return;
    }
    if (code == '54003' && selectedDays.isEmpty) {
      setState(() => error = 'กรุณาเลือกวันเปิดสนาม');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    pendingKey ??= sportKey();
    try {
      final id = widget.row?['id'];
      final path = switch (code) {
        '54001' => 'settings',
        '54002' => 'sport-types',
        '54003' => 'facilities',
        '54004' => 'levels',
        '54005' => 'packages',
        '54006' => 'members',
        '54007' => 'memberships',
        '54008' => 'bookings',
        '54010' => 'pos-pricing/${picked['levelId']}',
        _ => '',
      };
      Object body;
      switch (code) {
        case '54001':
          body = {
            'paymentHoldMinutes': number('PaymentHoldMinutes'),
            'cancelBeforeMinutes': number('CancelBeforeMinutes'),
            'checkInGraceMinutes': number('CheckInGraceMinutes'),
            'expiryNoticeDays': number('ExpiryNoticeDays'),
          };
          break;
        case '54002':
          body = {'code': text('code'), 'name': text('name'), 'active': active};
          break;
        case '54003':
          body = {
            'branchID': picked['branchId'],
            'sportTypeID': picked['sportTypeId'],
            'code': text('code'),
            'name': text('name'),
            'capacity': number('capacity'),
            'active': active,
            'hours': selectedDays.toList()..sort(),
          };
          body = {
            ...(body as Map<String, dynamic>),
            'hours': selectedDays
                .map(
                  (day) => {
                    'dayOfWeek': day,
                    'opensAt': '${text('opensAt')}:00',
                    'closesAt': '${text('closesAt')}:00',
                  },
                )
                .toList(),
          };
          break;
        case '54004':
          body = {
            'code': text('code'),
            'name': text('name'),
            'requiresResident': resident,
            'active': active,
          };
          break;
        case '54005':
          body = {
            'code': text('code'),
            'name': text('name'),
            'levelID': picked['levelId'],
            'durationDays': number('days'),
            'quotaUnit': quotaUnit,
            'quotaAmount': quotaUnit == 'UNLIMITED' ? null : number('quota'),
            'price': decimal('price'),
            'sportTypeIDs': selectedSports.toList(),
            'active': active,
          };
          break;
        case '54006':
          body = {
            'personID': picked['personId'],
            'code': text('code'),
            'levelID': picked['levelId'],
            'birthDate': text('birthDate').isEmpty ? null : text('birthDate'),
            'genderCode': gender,
            'active': active,
          };
          break;
        case '54007':
          body = {
            'memberID': picked['memberId'],
            'packageID': picked['packageId'],
            'startsOn': text('startDate'),
            'renew': renew,
            'paymentCode': payment,
            'paymentReference': text('paymentReference'),
            'idempotencyKey': pendingKey,
          };
          break;
        case '54008':
          body = {
            'facilityID': picked['facilityId'],
            'memberID': picked['memberId'],
            'membershipID': useMembership ? picked['membershipId'] : null,
            'dropInPackageID': useMembership ? null : picked['packageId'],
            'startsAt': "${text('startDate')}T${text('startTime')}:00+07:00",
            'endsAt': "${text('startDate')}T${text('endTime')}:00+07:00",
            'idempotencyKey': pendingKey,
          };
          break;
        case '54010':
          body = {'priceLevelCode': text('priceLevelCode'), 'active': active};
          break;
        default:
          throw StateError('เมนูนี้ไม่รองรับการบันทึก');
      }
      if (code == '54003' && widget.row != null && !changeHours) {
        (body as Map<String, dynamic>)['hours'] = existingHours
            .map(
              (h) => {
                'dayOfWeek': h['day'],
                'opensAt': h['opensAt'],
                'closesAt': h['closesAt'],
              },
            )
            .toList();
      }
      if (code == '54001' || code == '54010' || id != null) {
        await widget.api.put(
          '$base/$path${id == null || code == '54010' ? '' : '/$id'}',
          body: body,
        );
      } else {
        await widget.api.post('$base/$path', body: body);
      }
      pendingKey = null;
      changed = true;
      if (!mounted) return;
      sportMessage(context, message: 'บันทึกข้อมูลแล้ว', error: false);
      if (id != null || code == '54001' || code == '54010') {
        Navigator.pop(context, true);
      } else {
        key.currentState?.reset();
        for (final controller in input.values) {
          controller.clear();
        }
        setState(() {
          picked.clear();
          selectedSports.clear();
          active = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
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
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    sportMenuIcon(widget.iconName),
                    color: t.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.title} > ${widget.row == null && widget.code != '54001' && widget.code != '54010' ? 'เพิ่ม' : 'แก้ไข'}',
                      style: t.captionStyle,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: t.borderColor),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Form(
                  key: key,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      formFields(),
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
            ),
            Divider(height: 1, color: t.borderColor),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(context, changed),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: saving || detailsLoading || detailsFailed
                        ? null
                        : save,
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('บันทึก'),
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

Future<bool> sportConfirmDelete(BuildContext context, String record) async {
  final t = sportTokens();
  final danger = Theme.of(context).colorScheme.error;
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.all(t.dialogInsetPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radius),
            side: BorderSide(color: danger),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: t.popupMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ยืนยันการลบข้อมูล',
                          style: t.captionStyle.copyWith(color: danger),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: t.borderColor),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        color: danger.withValues(alpha: .1),
                        child: Text(record, style: TextStyle(color: danger)),
                      ),
                      const SizedBox(height: 10),
                      const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
                    ],
                  ),
                ),
                Divider(height: 1, color: t.borderColor),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('ยกเลิก'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(dialog, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: danger,
                          minimumSize: Size(100, t.buttonHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(t.radius),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('ลบ'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}

class SportBookingAction extends StatefulWidget {
  const SportBookingAction({
    super.key,
    required this.api,
    required this.tokens,
    required this.booking,
    required this.action,
  });
  final JsonApiClient api;
  final LaooWorkspaceUiTokens tokens;
  final Map<String, dynamic> booking;
  final String action;
  @override
  State<SportBookingAction> createState() => _SportBookingActionState();
}

class _SportBookingActionState extends State<SportBookingAction> {
  final reference = TextEditingController();
  bool saving = false;
  String? error;
  String payment = 'CASH';
  String? pendingKey;
  @override
  void dispose() {
    reference.dispose();
    super.dispose();
  }

  String get title => switch (widget.action) {
    'pay' => 'รับชำระเงิน',
    'check-in' => 'เช็กอินเข้าเล่น',
    'no-show' => 'บันทึกไม่มา',
    _ => 'ยกเลิกการจอง',
  };
  Future<void> submit() async {
    if (saving) return;
    if (widget.action == 'cancel' && reference.text.trim().isEmpty) {
      setState(() => error = 'กรุณาระบุเหตุผลการยกเลิก');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final body = switch (widget.action) {
        'pay' => <String, dynamic>{
          'idempotencyKey': pendingKey ??= sportKey(),
          'paymentCode': payment,
          'paymentReference': reference.text.trim(),
        },
        'cancel' => <String, dynamic>{'reason': reference.text.trim()},
        _ => <String, dynamic>{},
      };
      await widget.api.post(
        '/api/company/sport/bookings/${widget.booking['id']}/${widget.action}',
        body: body,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.all(t.dialogInsetPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.popupMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(Icons.sports_score_outlined, color: t.primaryColor),
                  const SizedBox(width: 8),
                  Text(title, style: t.captionStyle),
                ],
              ),
            ),
            Divider(height: 1, color: t.borderColor),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${widget.booking['facility']} · ${widget.booking['memberName']}',
                  ),
                  if (widget.action == 'pay')
                    DropdownButtonFormField<String>(
                      initialValue: payment,
                      decoration: sportInput(t, 'วิธีรับเงิน'),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('เงินสด')),
                        DropdownMenuItem(value: 'TRANSFER', child: Text('โอน')),
                      ],
                      onChanged: (v) => setState(() => payment = v ?? 'CASH'),
                    ),
                  if (widget.action == 'pay' || widget.action == 'cancel')
                    TextField(
                      controller: reference,
                      decoration: sportInput(
                        t,
                        widget.action == 'pay' ? 'เลขอ้างอิง' : 'เหตุผล',
                      ),
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
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: saving ? null : submit,
                    icon: const Icon(Icons.check),
                    label: const Text('ยืนยัน'),
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
