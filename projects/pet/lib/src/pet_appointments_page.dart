import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'pet_host.dart';

class PetAppointmentsPage extends StatefulWidget {
  const PetAppointmentsPage({super.key});
  @override
  State<PetAppointmentsPage> createState() => _PetAppointmentsPageState();
}

class _PetAppointmentsPageState extends State<PetAppointmentsPage> {
  late final api = petApi();
  Map<String, dynamic> meta = {}, actions = {};
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic>? detail;
  int page = 1, total = 0;
  bool loading = true, cards = false, creating = false, busy = false;
  String? error;
  LaooWorkspaceUiTokens get tokens => petTokens();
  String get title => meta['MenuName']?.toString() ?? 'กำลังโหลด...';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    petDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final access = Map<String, dynamic>.from(
        await api.get('/api/company/pet/actions/62006') as Map,
      );
      meta = Map<String, dynamic>.from(access['metadata'] as Map);
      actions = Map<String, dynamic>.from(access['actions'] as Map);
      if (actions['view'] != true) {
        throw StateError('ไม่มีสิทธิ์ดูนัดหมาย');
      }
      final data = Map<String, dynamic>.from(
        await api.get(
              '/api/company/pet/appointments',
              query: {'page': page.toString(), 'pageSize': '20'},
            )
            as Map,
      );
      rows = (data['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      total = (data['total'] as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = petErrorText(e, 'โหลดนัดหมาย');
        });
      }
    }
  }

  Future<void> openDetail(Map<String, dynamic> row) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = Map<String, dynamic>.from(
        await api.get('/api/company/pet/appointments/${row['id']}') as Map,
      );
      if (mounted) {
        setState(() {
          detail = data;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = petErrorText(e, 'โหลดรายละเอียดนัดหมาย');
          loading = false;
        });
      }
    }
  }

  Future<void> cancel(Map<String, dynamic> row) async {
    if (actions['cancel'] != true || row['status'] != 'BOOKED' || busy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => LaooActionDialog(
        tokens: tokens,
        icon: Icons.event_busy_outlined,
        title: '$title > ยกเลิก',
        content: Text(
          'ยืนยันยกเลิกนัดหมาย ${row['bookingNo']} หรือไม่? การยกเลิกจะบันทึกประวัติและไม่ลบข้อมูลเดิม',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await api.post('/api/company/pet/appointments/${row['id']}/cancel');
      if (mounted) {
        petMessage(context, message: 'ยกเลิกนัดหมายแล้ว', error: false);
        detail = null;
        await load();
      }
    } catch (e) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(e, 'ยกเลิกนัดหมาย'),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget result(double width) {
    if (loading) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }
    if (rows.isEmpty) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: const Text('ยังไม่มีนัดหมาย'),
      );
    }
    if (cards || width < tokens.compactBreakpoint) {
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: tokens.itemSpacing),
            LaooSurfaceCard(
              tokens: tokens,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rows[i]['bookingNo']} · ${rows[i]['petName']}',
                    style: tokens.sectionStyle,
                  ),
                  Text('สถานะ: ${rows[i]['status']}'),
                  Text('เริ่ม: ${rows[i]['startsAt']}'),
                  Text('ห้อง: ${rows[i]['roomCode']?.toString() ?? 'ไม่ระบุ'}'),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => openDetail(rows[i]),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('ดูรายละเอียด'),
                      ),
                      if (actions['cancel'] == true &&
                          rows[i]['status'] == 'BOOKED')
                        TextButton(
                          onPressed: busy ? null : () => cancel(rows[i]),
                          child: const Text('ยกเลิกนัดหมาย'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    return LaooSurfaceCard(
      tokens: tokens,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: width),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              tokens.primaryColor.withValues(alpha: 0.1),
            ),
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Action')),
              DataColumn(label: Text('เลขที่')),
              DataColumn(label: Text('สัตว์')),
              DataColumn(label: Text('ห้อง')),
              DataColumn(label: Text('เริ่ม')),
              DataColumn(label: Text('สิ้นสุด')),
              DataColumn(label: Text('สถานะ')),
              DataColumn(label: Text('ยอดรวม')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text(row['id'].toString())),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'ดูรายละเอียด',
                            color: tokens.primaryColor,
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () => openDetail(row),
                          ),
                          if (actions['cancel'] == true &&
                              row['status'] == 'BOOKED')
                            IconButton(
                              tooltip: 'ยกเลิกนัดหมาย',
                              icon: const Icon(Icons.cancel_outlined),
                              onPressed: busy ? null : () => cancel(row),
                            ),
                        ],
                      ),
                    ),
                    DataCell(Text(row['bookingNo'].toString())),
                    DataCell(Text(row['petName'].toString())),
                    DataCell(Text(row['roomCode']?.toString() ?? '—')),
                    DataCell(Text(row['startsAt'].toString())),
                    DataCell(Text(row['endsAt'].toString())),
                    DataCell(Text(row['status'].toString())),
                    DataCell(Text(row['amount'].toString())),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget detailView() {
    final data = detail!;
    final head = Map<String, dynamic>.from(data['header'] as Map);
    final lines = (data['details'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LaooSurfaceCard(
          tokens: tokens,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Header · ${head['bookingNo']}', style: tokens.sectionStyle),
              Text('สัตว์ ID ${head['petId']}'),
              Text('ช่วงเวลา ${head['startsAt']} – ${head['endsAt']}'),
              Text('สถานะ ${head['status']}'),
              Text('ยอดรวม ${head['amount']}'),
            ],
          ),
        ),
        SizedBox(height: tokens.sectionSpacing),
        LaooSurfaceCard(
          tokens: tokens,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detail · บริการ', style: tokens.sectionStyle),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${line['name']} · ${line['amount']} บาท'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => petShell(
    pageTitle: title,
    activeMenu: 'pet-appointments',
    child: ColoredBox(
      color: tokens.backgroundColor,
      child: SingleChildScrollView(
        padding: tokens.contentMargin,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, c) => LaooCaptionCard(
                tokens: tokens,
                caption: title,
                favoriteKey: 'pet-appointments',
                leading: Icon(
                  petMenuIcon(meta['IconName']?.toString()),
                  color: tokens.primaryColor,
                ),
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!creating &&
                        detail == null &&
                        c.maxWidth >= tokens.compactBreakpoint)
                      LaooListCardToggle(
                        tokens: tokens,
                        cards: cards,
                        onChanged: (value) => setState(() => cards = value),
                      ),
                    if (creating || detail != null)
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          creating = false;
                          detail = null;
                        }),
                        icon: const Icon(Icons.arrow_back_outlined),
                        label: const Text('กลับรายการ'),
                      ),
                    if (!creating &&
                        detail == null &&
                        actions['create'] == true)
                      FilledButton.icon(
                        onPressed: () => setState(() => creating = true),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่มนัดหมาย'),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            if (creating)
              _AppointmentForm(
                api: api,
                tokens: tokens,
                onSaved: () async {
                  petMessage(
                    context,
                    message: 'บันทึกนัดหมายแล้ว',
                    error: false,
                  );
                  page = 1;
                  await load();
                },
              )
            else if (detail != null)
              detailView()
            else ...[
              LayoutBuilder(builder: (context, c) => result(c.maxWidth)),
              SizedBox(height: tokens.sectionSpacing),
              LaooPaginationCard(
                tokens: tokens,
                page: page,
                pageCount: total == 0 ? 1 : (total / 20).ceil(),
                pageSize: 20,
                total: total,
                onPrevious: page > 1
                    ? () {
                        page--;
                        load();
                      }
                    : null,
                onNext: page * 20 < total
                    ? () {
                        page++;
                        load();
                      }
                    : null,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _AppointmentForm extends StatefulWidget {
  const _AppointmentForm({
    required this.api,
    required this.tokens,
    required this.onSaved,
  });
  final JsonApiClient api;
  final LaooWorkspaceUiTokens tokens;
  final Future<void> Function() onSaved;
  @override
  State<_AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<_AppointmentForm> {
  final key = GlobalKey<FormState>();
  final note = TextEditingController();
  Map<String, dynamic> options = {};
  Set<int> services = {};
  Map<int, int?> providers = {};
  int? petId, roomId, branchId;
  DateTime from = DateTime.now().add(const Duration(days: 1));
  DateTime to = DateTime.now().add(const Duration(days: 1, hours: 1));
  bool loading = true, saving = false;
  String? error;
  LaooWorkspaceUiTokens get tokens => widget.tokens;

  @override
  void initState() {
    super.initState();
    loadOptions();
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> loadOptions() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      options = Map<String, dynamic>.from(
        await widget.api.get('/api/company/pet/options/62006') as Map,
      );
      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = petErrorText(e, 'โหลดตัวเลือกนัดหมาย');
        });
      }
    }
  }

  List<Map<String, dynamic>> values(String key) => (options[key] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> chooseDate({required bool start}) async {
    final current = start ? from : to;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: current,
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) {
      return;
    }
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        from = selected;
        if (!to.isAfter(from)) {
          to = from.add(const Duration(hours: 1));
        }
      } else {
        to = selected;
      }
    });
  }

  Future<void> save() async {
    if (saving || !key.currentState!.validate()) {
      return;
    }
    if (petId == null ||
        services.isEmpty ||
        !to.isAfter(from) ||
        !from.isAfter(DateTime.now().subtract(const Duration(minutes: 5)))) {
      petMessage(
        context,
        message: 'เลือกสัตว์ บริการ และช่วงเวลาที่เริ่มในอนาคต',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.api.post(
        '/api/company/pet/appointments',
        body: {
          'petId': petId,
          'roomId': roomId,
          'branchId': branchId,
          'startsAt': from.toUtc().toIso8601String(),
          'endsAt': to.toUtc().toIso8601String(),
          'services': [
            for (final id in services)
              {'serviceId': id, 'providerId': providers[id]},
          ],
          'note': note.text.trim().isEmpty ? null : note.text.trim(),
        },
      );
      await widget.onSaved();
      if (mounted) {
        setState(() {
          petId = null;
          roomId = null;
          branchId = null;
          services = {};
          providers = {};
          from = DateTime.now().add(const Duration(days: 1));
          to = from.add(const Duration(hours: 1));
          note.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(e, 'บันทึกนัดหมาย'),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error!),
            OutlinedButton.icon(
              onPressed: loadOptions,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }
    return Form(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LaooSurfaceCard(
            tokens: tokens,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Header · ข้อมูลนัดหมาย', style: tokens.sectionStyle),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey('pet-$petId'),
                  initialValue: petId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'สัตว์เลี้ยง *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radius),
                    ),
                  ),
                  items: [
                    for (final pet in values('pets'))
                      DropdownMenuItem<int>(
                        value: (pet['id'] as num).toInt(),
                        child: Text(
                          pet['name']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => petId = value),
                  validator: (value) =>
                      value == null ? 'กรุณาเลือกสัตว์เลี้ยง' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: branchId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'สาขา',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radius),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('ไม่ระบุสาขา'),
                    ),
                    for (final branch in values('branches'))
                      DropdownMenuItem<int>(
                        value: (branch['id'] as num).toInt(),
                        child: Text(
                          branch['name']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    branchId = value;
                    roomId = null;
                  }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey('room-$branchId'),
                  initialValue: roomId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'ห้อง/กรง (ตามบริการ)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radius),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('ไม่เลือกห้อง'),
                    ),
                    for (final room in values('rooms'))
                      DropdownMenuItem<int>(
                        value: (room['id'] as num).toInt(),
                        child: Text(
                          room['name']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => roomId = value),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => chooseDate(start: true),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        'เริ่ม ${petDateFormat(from)} ${TimeOfDay.fromDateTime(from).format(context)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => chooseDate(start: false),
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        'สิ้นสุด ${petDateFormat(to)} ${TimeOfDay.fromDateTime(to).format(context)}',
                      ),
                    ),
                  ],
                ),
                if (!to.isAfter(from))
                  Text(
                    'เวลาสิ้นสุดต้องหลังเวลาเริ่ม',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: note,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'หมายเหตุ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radius),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.sectionSpacing),
          LaooSurfaceCard(
            tokens: tokens,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Detail · บริการ *', style: tokens.sectionStyle),
                for (final service in values('services')) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(service['name']?.toString() ?? ''),
                    subtitle: Text('ราคา ${service['price']}'),
                    value: services.contains((service['id'] as num).toInt()),
                    onChanged: (value) => setState(() {
                      final id = (service['id'] as num).toInt();
                      if (value == true) {
                        services.add(id);
                      } else {
                        services.remove(id);
                        providers.remove(id);
                      }
                    }),
                  ),
                  if (services.contains((service['id'] as num).toInt()))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<int>(
                        initialValue: providers[(service['id'] as num).toInt()],
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'ผู้ให้บริการ (ถ้าต้องระบุ)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(tokens.radius),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('ไม่เลือกผู้ให้บริการ'),
                          ),
                          for (final provider in values('providers'))
                            DropdownMenuItem<int>(
                              value: (provider['id'] as num).toInt(),
                              child: Text(
                                provider['name']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(
                          () =>
                              providers[(service['id'] as num).toInt()] = value,
                        ),
                      ),
                    ),
                ],
                if (services.isEmpty)
                  const Text('เลือกบริการอย่างน้อย 1 รายการ'),
              ],
            ),
          ),
          SizedBox(height: tokens.sectionSpacing),
          LaooSurfaceCard(
            tokens: tokens,
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'กำลังบันทึก...' : 'บันทึกนัดหมาย'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
