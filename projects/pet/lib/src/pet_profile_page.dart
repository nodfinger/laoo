import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'pet_host.dart';
import 'pet_photos_dialog.dart';

class PetProfilePage extends StatefulWidget {
  const PetProfilePage({super.key});
  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  late final api = petApi();
  final search = TextEditingController();
  Map<String, dynamic> metadata = {}, actions = {};
  List<Map<String, dynamic>> rows = [];
  int page = 1, total = 0;
  bool loading = true, cards = false;
  String? error;
  LaooWorkspaceUiTokens get tokens => petTokens();
  String get title => metadata['MenuName']?.toString() ?? 'กำลังโหลด...';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
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
        await api.get('/api/company/pet/actions/62004') as Map,
      );
      metadata = Map<String, dynamic>.from(access['metadata'] as Map);
      actions = Map<String, dynamic>.from(access['actions'] as Map);
      if (actions['view'] != true) {
        throw StateError('ไม่มีสิทธิ์ดูโปรไฟล์สัตว์เลี้ยง');
      }
      final data = Map<String, dynamic>.from(
        await api.get(
              '/api/company/pet/profiles',
              query: {
                'page': '$page',
                'pageSize': '20',
                'search': search.text.trim(),
              },
            )
            as Map,
      );
      rows = (data['items'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      total = (data['total'] as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() => loading = false);
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          loading = false;
          error = petErrorText(exception, 'โหลดโปรไฟล์สัตว์เลี้ยง');
        });
      }
    }
  }

  Future<void> openForm([Map<String, dynamic>? row]) async {
    if (actions[row == null ? 'create' : 'edit'] != true ||
        row?['active'] == false) {
      return;
    }
    try {
      final options = Map<String, dynamic>.from(
        await api.get('/api/company/pet/options/62004') as Map,
      );
      if (!mounted) {
        return;
      }
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ProfileForm(
          title: title,
          icon: petMenuIcon(metadata['IconName']?.toString()),
          row: row,
          options: options,
          api: api,
          onCreated: () {
            petMessage(context, message: 'เพิ่มโปรไฟล์แล้ว', error: false);
            page = 1;
            load();
          },
        ),
      );
      if (saved == true && mounted) {
        petMessage(context, message: 'แก้ไขโปรไฟล์แล้ว', error: false);
        await load();
      }
    } catch (exception) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(exception, 'เปิดโปรไฟล์สัตว์เลี้ยง'),
          error: true,
        );
      }
    }
  }

  Widget actionFor(Map<String, dynamic> row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'รูปสัตว์เลี้ยง',
        color: tokens.primaryColor,
        icon: const Icon(Icons.photo_library_outlined),
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => PetPhotosDialog(
            title: title,
            petId: (row['id'] as num).toInt(),
            canEdit: actions['edit'] == true && row['active'] == true,
          ),
        ),
      ),
      if (actions['edit'] == true && row['active'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          color: tokens.primaryColor,
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => openForm(row),
        ),
    ],
  );

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
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('ไม่พบสัตว์เลี้ยงตามเงื่อนไขที่เลือก'),
          ),
        ),
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
                    '${rows[i]['code'] ?? ''} · ${rows[i]['name'] ?? ''}',
                    style: tokens.sectionStyle,
                  ),
                  Text(
                    '${rows[i]['species'] ?? '—'} · ${rows[i]['breed'] ?? 'ไม่ระบุพันธุ์'}',
                  ),
                  Text('รหัสเจ้าของ ${rows[i]['ownerCustomerId'] ?? '—'}'),
                  Align(
                    alignment: Alignment.centerRight,
                    child: actionFor(rows[i]),
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
              DataColumn(label: Text('รหัส')),
              DataColumn(label: Text('ชื่อสัตว์')),
              DataColumn(label: Text('ชนิด')),
              DataColumn(label: Text('พันธุ์')),
              DataColumn(label: Text('รหัสเจ้าของ')),
              DataColumn(label: Text('สถานะ')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text('${row['id']}')),
                    DataCell(actionFor(row)),
                    DataCell(Text('${row['code'] ?? '—'}')),
                    DataCell(Text('${row['name'] ?? '—'}')),
                    DataCell(Text('${row['species'] ?? '—'}')),
                    DataCell(Text('${row['breed'] ?? '—'}')),
                    DataCell(Text('${row['ownerCustomerId'] ?? '—'}')),
                    DataCell(
                      Text(row['active'] == true ? 'ใช้งาน' : 'ปิดใช้งาน'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => petShell(
    pageTitle: title,
    activeMenu: 'pet-profiles',
    child: ColoredBox(
      color: tokens.backgroundColor,
      child: SingleChildScrollView(
        padding: tokens.contentMargin,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => LaooCaptionCard(
                tokens: tokens,
                caption: title,
                favoriteKey: 'pet-profiles',
                leading: Icon(
                  petMenuIcon(metadata['IconName']?.toString()),
                  color: tokens.primaryColor,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (constraints.maxWidth >= tokens.compactBreakpoint)
                      LaooListCardToggle(
                        tokens: tokens,
                        cards: cards,
                        onChanged: (value) => setState(() => cards = value),
                      ),
                    if (actions['create'] == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilledButton.icon(
                          onPressed: () => openForm(),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่ม'),
                          style: FilledButton.styleFrom(
                            minimumSize: Size(0, tokens.buttonHeight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                tokens.radius,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            LaooFilterCard(
              tokens: tokens,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: search,
                      decoration: InputDecoration(
                        labelText: 'ค้นหารหัสหรือชื่อสัตว์',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(tokens.radius),
                        ),
                      ),
                      onSubmitted: (_) {
                        page = 1;
                        load();
                      },
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      page = 1;
                      load();
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      search.clear();
                      page = 1;
                      load();
                    },
                    child: const Text('ล้าง Filter'),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            LayoutBuilder(
              builder: (context, constraints) => result(constraints.maxWidth),
            ),
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
        ),
      ),
    ),
  );
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    required this.title,
    required this.icon,
    required this.row,
    required this.options,
    required this.api,
    required this.onCreated,
  });
  final String title;
  final IconData icon;
  final Map<String, dynamic>? row;
  final Map<String, dynamic> options;
  final JsonApiClient api;
  final VoidCallback onCreated;
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final key = GlobalKey<FormState>();
  late final code = TextEditingController(
    text: widget.row?['code']?.toString() ?? '',
  );
  late final name = TextEditingController(
    text: widget.row?['name']?.toString() ?? '',
  );
  late final species = TextEditingController(
    text: widget.row?['species']?.toString() ?? '',
  );
  late final breed = TextEditingController(
    text: widget.row?['breed']?.toString() ?? '',
  );
  late final size = TextEditingController(
    text: widget.row?['sizeCode']?.toString() ?? '',
  );
  late final caution = TextEditingController(
    text: widget.row?['caution']?.toString() ?? '',
  );
  late final emergencyName = TextEditingController(
    text: widget.row?['emergencyName']?.toString() ?? '',
  );
  late final emergencyPhone = TextEditingController(
    text: widget.row?['emergencyPhone']?.toString() ?? '',
  );
  late int? owner = (widget.row?['ownerCustomerId'] as num?)?.toInt();
  late int? member = (widget.row?['memberId'] as num?)?.toInt();
  late DateTime? birth = DateTime.tryParse(
    widget.row?['birthDate']?.toString() ?? '',
  );
  bool saving = false;
  int version = 0;
  LaooWorkspaceUiTokens get tokens => petTokens();

  @override
  void dispose() {
    for (final controller in [
      code,
      name,
      species,
      breed,
      size,
      caution,
      emergencyName,
      emergencyPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> options(String key) {
    final result = (widget.options[key] as List? ?? [])
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final selected = key == 'customers' ? owner : member;
    if (selected != null && !result.any((value) => value['id'] == selected)) {
      result.add({'id': selected, 'name': 'รายการเดิม #$selected'});
    }
    return result;
  }

  Widget input(
    String label,
    TextEditingController controller, {
    bool required = false,
    int lines = 1,
  }) => TextFormField(
    controller: controller,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: required ? '$label *' : label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
    ),
    validator: required
        ? (value) =>
              value == null || value.trim().isEmpty ? 'กรุณาระบุ$label' : null
        : null,
  );

  Future<void> chooseBirth() async {
    final chosen = await showDatePicker(
      context: context,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      initialDate: birth ?? DateTime.now(),
    );
    if (chosen != null) setState(() => birth = chosen);
  }

  Future<void> save() async {
    if (saving || !key.currentState!.validate() || owner == null) return;
    setState(() => saving = true);
    try {
      String? text(TextEditingController controller) =>
          controller.text.trim().isEmpty ? null : controller.text.trim();
      final body = <String, dynamic>{
        'code': code.text.trim(),
        'ownerCustomerId': owner,
        'memberId': member,
        'name': name.text.trim(),
        'species': species.text.trim(),
        'breed': text(breed),
        'sizeCode': text(size),
        'birthDate': birth == null
            ? null
            : '${birth!.year.toString().padLeft(4, '0')}-${birth!.month.toString().padLeft(2, '0')}-${birth!.day.toString().padLeft(2, '0')}',
        'caution': text(caution),
        'emergencyName': text(emergencyName),
        'emergencyPhone': text(emergencyPhone),
      };
      if (widget.row == null) {
        await widget.api.post('/api/company/pet/profiles', body: body);
        widget.onCreated();
        setState(() {
          owner = null;
          member = null;
          birth = null;
          version++;
          for (final controller in [
            code,
            name,
            species,
            breed,
            size,
            caution,
            emergencyName,
            emergencyPhone,
          ]) {
            controller.clear();
          }
        });
      } else {
        await widget.api.put(
          '/api/company/pet/profiles/${widget.row!['id']}',
          body: body,
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (exception) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(exception, 'บันทึกโปรไฟล์สัตว์'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LaooActionDialog(
    tokens: tokens,
    icon: widget.icon,
    title: '${widget.title} > ${widget.row == null ? 'เพิ่ม' : 'แก้ไข'}',
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('สถานะ'),
              Switch(value: widget.row?['active'] != false, onChanged: null),
            ],
          ),
          const SizedBox(height: 16),
          input('รหัสสัตว์', code, required: true),
          const SizedBox(height: 16),
          input('ชื่อสัตว์', name, required: true),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('owner-$version'),
            initialValue: owner,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'เจ้าของ (ลูกค้า) *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radius),
              ),
            ),
            items: options('customers')
                .map(
                  (row) => DropdownMenuItem<int>(
                    value: (row['id'] as num).toInt(),
                    child: Text(
                      row['name']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => owner = value),
            validator: (value) => value == null ? 'กรุณาเลือกเจ้าของ' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('member-$version'),
            initialValue: member,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'บัญชีสมาชิก Booking สำหรับพอร์ทัล',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radius),
              ),
              helperText: 'เลือกเฉพาะบัญชีของเจ้าของสัตว์จริง',
            ),
            items: options('members')
                .map(
                  (row) => DropdownMenuItem<int>(
                    value: (row['id'] as num).toInt(),
                    child: Text(
                      row['name']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => member = value),
          ),
          const SizedBox(height: 16),
          input('ชนิดสัตว์', species, required: true),
          const SizedBox(height: 16),
          input('พันธุ์', breed),
          const SizedBox(height: 16),
          input('ขนาด', size),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: chooseBirth,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              birth == null ? 'วันเกิดโดยประมาณ' : petDateFormat(birth!),
            ),
          ),
          const SizedBox(height: 16),
          input('ข้อควรระวัง', caution, lines: 3),
          const SizedBox(height: 16),
          input('ชื่อผู้ติดต่อฉุกเฉิน', emergencyName),
          const SizedBox(height: 16),
          input('โทรศัพท์ฉุกเฉิน', emergencyPhone),
        ],
      ),
    ),
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
