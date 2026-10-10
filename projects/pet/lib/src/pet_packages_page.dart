import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'pet_host.dart';

class PetPackagesPage extends StatefulWidget {
  const PetPackagesPage({super.key});
  @override
  State<PetPackagesPage> createState() => _PetPackagesPageState();
}

class _PetPackagesPageState extends State<PetPackagesPage> {
  late final api = petApi();
  final search = TextEditingController();
  Map<String, dynamic> meta = {}, actions = {};
  List<Map<String, dynamic>> packages = [], entitlements = [];
  Map<int, Set<int>> covered = {};
  int page = 1, total = 0, issuedPage = 1, issuedTotal = 0;
  bool loading = true, cards = false;
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
        await api.get('/api/company/pet/actions/62005') as Map,
      );
      meta = Map<String, dynamic>.from(access['metadata'] as Map);
      actions = Map<String, dynamic>.from(access['actions'] as Map);
      if (actions['view'] != true) {
        throw StateError('ไม่มีสิทธิ์ดูแพ็กเกจ');
      }
      final data = Map<String, dynamic>.from(
        await api.get(
              '/api/company/pet/packages',
              query: {
                'page': page.toString(),
                'pageSize': '20',
                'search': search.text.trim(),
              },
            )
            as Map,
      );
      final rights = Map<String, dynamic>.from(
        await api.get(
              '/api/company/pet/entitlements',
              query: {'page': issuedPage.toString(), 'pageSize': '20'},
            )
            as Map,
      );
      packages = (data['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      total = (data['total'] as num?)?.toInt() ?? 0;
      entitlements = (rights['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      issuedTotal = (rights['total'] as num?)?.toInt() ?? 0;
      covered = {};
      for (final raw in data['services'] as List? ?? []) {
        final service = Map<String, dynamic>.from(raw as Map);
        final id = (service['packageId'] as num).toInt();
        covered
            .putIfAbsent(id, () => {})
            .add((service['serviceId'] as num).toInt());
      }
      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = petErrorText(e, 'โหลดแพ็กเกจและสิทธิ์สมาชิก');
        });
      }
    }
  }

  Future<void> form({Map<String, dynamic>? row, bool issue = false}) async {
    if (actions[row == null ? 'create' : 'edit'] != true) {
      return;
    }
    try {
      final options = Map<String, dynamic>.from(
        await api.get('/api/company/pet/options/62005') as Map,
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PetPackageForm(
          api: api,
          title: title,
          icon: petMenuIcon(meta['IconName']?.toString()),
          row: row,
          options: options,
          issue: issue,
          selected: covered[(row?['id'] as num?)?.toInt()] ?? {},
          onSaved: () {
            petMessage(context, message: 'บันทึกข้อมูลแล้ว', error: false);
            load();
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(e, 'เปิดแบบฟอร์มแพ็กเกจ'),
          error: true,
        );
      }
    }
  }

  Widget packageResult(double width) {
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
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }
    if (packages.isEmpty) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: const Text('ไม่พบแพ็กเกจตามเงื่อนไขที่เลือก'),
      );
    }
    if (cards || width < tokens.compactBreakpoint) {
      return Column(
        children: [
          for (var i = 0; i < packages.length; i++) ...[
            if (i > 0) SizedBox(height: tokens.itemSpacing),
            LaooSurfaceCard(
              tokens: tokens,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${packages[i]['code']} · ${packages[i]['name']}',
                    style: tokens.sectionStyle,
                  ),
                  Text(
                    'ราคา ${packages[i]['price']} · ${packages[i]['units']} หน่วย',
                  ),
                  Text(
                    'บริการ ${covered[(packages[i]['id'] as num).toInt()]?.length ?? 0} รายการ',
                  ),
                  Text(packages[i]['active'] == true ? 'ใช้งาน' : 'ปิดใช้งาน'),
                  if (actions['edit'] == true)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'แก้ไข',
                        color: tokens.primaryColor,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => form(row: packages[i]),
                      ),
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
              DataColumn(label: Text('แพ็กเกจ')),
              DataColumn(label: Text('ราคา')),
              DataColumn(label: Text('หน่วย')),
              DataColumn(label: Text('อายุสิทธิ์')),
              DataColumn(label: Text('บริการ')),
              DataColumn(label: Text('สถานะ')),
            ],
            rows: [
              for (final row in packages)
                DataRow(
                  cells: [
                    DataCell(Text(row['id'].toString())),
                    DataCell(
                      actions['edit'] == true
                          ? IconButton(
                              tooltip: 'แก้ไข',
                              color: tokens.primaryColor,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => form(row: row),
                            )
                          : const SizedBox.shrink(),
                    ),
                    DataCell(Text(row['code'].toString())),
                    DataCell(Text(row['name'].toString())),
                    DataCell(Text(row['price'].toString())),
                    DataCell(Text(row['units'].toString())),
                    DataCell(Text('${row['validDays']} วัน')),
                    DataCell(
                      Text(
                        (covered[(row['id'] as num).toInt()]?.length ?? 0)
                            .toString(),
                      ),
                    ),
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

  Widget rightResult(double width) {
    if (loading || error != null) {
      return const SizedBox.shrink();
    }
    if (entitlements.isEmpty) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: const Text('ยังไม่มีสิทธิ์แพ็กเกจของสมาชิก'),
      );
    }
    if (width < tokens.compactBreakpoint) {
      return Column(
        children: [
          for (var i = 0; i < entitlements.length; i++) ...[
            if (i > 0) SizedBox(height: tokens.itemSpacing),
            LaooSurfaceCard(
              tokens: tokens,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entitlements[i]['packageName'].toString(),
                    style: tokens.sectionStyle,
                  ),
                  Text('สมาชิก #${entitlements[i]['memberId']}'),
                  Text(
                    'คงเหลือ ${entitlements[i]['remaining']}/${entitlements[i]['units']}',
                  ),
                  Text('หมดอายุ ${entitlements[i]['expiresOn']}'),
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
              DataColumn(label: Text('สมาชิก')),
              DataColumn(label: Text('แพ็กเกจ')),
              DataColumn(label: Text('คงเหลือ')),
              DataColumn(label: Text('วันหมดอายุ')),
            ],
            rows: [
              for (final row in entitlements)
                DataRow(
                  cells: [
                    DataCell(Text(row['id'].toString())),
                    DataCell(Text(row['memberId'].toString())),
                    DataCell(Text(row['packageName'].toString())),
                    DataCell(Text('${row['remaining']}/${row['units']}')),
                    DataCell(Text(row['expiresOn'].toString())),
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
    activeMenu: 'pet-packages',
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
                favoriteKey: 'pet-packages',
                leading: Icon(
                  petMenuIcon(meta['IconName']?.toString()),
                  color: tokens.primaryColor,
                ),
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (constraints.maxWidth >= tokens.compactBreakpoint)
                      LaooListCardToggle(
                        tokens: tokens,
                        cards: cards,
                        onChanged: (value) => setState(() => cards = value),
                      ),
                    if (actions['create'] == true)
                      FilledButton.icon(
                        onPressed: () => form(),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่มแพ็กเกจ'),
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
                      onSubmitted: (_) {
                        page = 1;
                        load();
                      },
                      decoration: InputDecoration(
                        labelText: 'ค้นหารหัสหรือชื่อแพ็กเกจ',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(tokens.radius),
                        ),
                      ),
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
            LayoutBuilder(builder: (context, c) => packageResult(c.maxWidth)),
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
            SizedBox(height: tokens.sectionSpacing),
            LaooSurfaceCard(
              tokens: tokens,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('สิทธิ์แพ็กเกจของสมาชิก', style: tokens.sectionStyle),
                  if (actions['create'] == true)
                    OutlinedButton.icon(
                      onPressed: () => form(issue: true),
                      icon: const Icon(Icons.card_membership_outlined),
                      label: const Text('ออกสิทธิ์'),
                    ),
                ],
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            LayoutBuilder(builder: (context, c) => rightResult(c.maxWidth)),
            SizedBox(height: tokens.sectionSpacing),
            LaooPaginationCard(
              tokens: tokens,
              page: issuedPage,
              pageCount: issuedTotal == 0 ? 1 : (issuedTotal / 20).ceil(),
              pageSize: 20,
              total: issuedTotal,
              onPrevious: issuedPage > 1
                  ? () {
                      issuedPage--;
                      load();
                    }
                  : null,
              onNext: issuedPage * 20 < issuedTotal
                  ? () {
                      issuedPage++;
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

class _PetPackageForm extends StatefulWidget {
  const _PetPackageForm({
    required this.api,
    required this.title,
    required this.icon,
    required this.row,
    required this.options,
    required this.issue,
    required this.selected,
    required this.onSaved,
  });
  final JsonApiClient api;
  final String title;
  final IconData icon;
  final Map<String, dynamic>? row;
  final Map<String, dynamic> options;
  final bool issue;
  final Set<int> selected;
  final VoidCallback onSaved;
  @override
  State<_PetPackageForm> createState() => _PetPackageFormState();
}

class _PetPackageFormState extends State<_PetPackageForm> {
  final key = GlobalKey<FormState>();
  late final code = TextEditingController(
    text: widget.row?['code']?.toString() ?? '',
  );
  late final name = TextEditingController(
    text: widget.row?['name']?.toString() ?? '',
  );
  late final price = TextEditingController(
    text: widget.row?['price']?.toString() ?? '0',
  );
  late final days = TextEditingController(
    text: widget.row?['validDays']?.toString() ?? '30',
  );
  late final units = TextEditingController(
    text: widget.row?['units']?.toString() ?? '1',
  );
  final reference = TextEditingController(), sale = TextEditingController();
  late Set<int> chosen = widget.selected.toSet();
  late int? itemId = (widget.row?['posItemId'] as num?)?.toInt();
  int? memberId, packageId;
  String method = 'CASH';
  bool pos = false, busy = false;
  late bool active = widget.row?['active'] != false;
  int generation = 0;
  LaooWorkspaceUiTokens get tokens => petTokens();

  @override
  void dispose() {
    for (final c in [code, name, price, days, units, reference, sale]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController c, {
    bool locked = false,
    bool numeric = false,
  }) => TextFormField(
    controller: c,
    readOnly: locked,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    decoration: InputDecoration(
      labelText: '$label *',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
    ),
    validator: (value) =>
        value == null || value.trim().isEmpty ? 'กรุณาระบุ$label' : null,
  );

  Future<void> save() async {
    if (busy || !key.currentState!.validate()) {
      return;
    }
    if (widget.issue && (memberId == null || packageId == null)) {
      return;
    }
    final amount = double.tryParse(price.text.trim());
    final validDays = int.tryParse(days.text.trim());
    final count = int.tryParse(units.text.trim());
    if (!widget.issue &&
        (amount == null ||
            amount < 0 ||
            validDays == null ||
            validDays < 1 ||
            count == null ||
            count < 1 ||
            chosen.isEmpty)) {
      petMessage(
        context,
        message: 'ราคา อายุสิทธิ์ จำนวนหน่วย หรือบริการไม่ถูกต้อง',
        error: true,
      );
      return;
    }
    setState(() => busy = true);
    try {
      if (widget.issue) {
        await widget.api.post(
          '/api/company/pet/entitlements',
          body: {
            'memberId': memberId,
            'packageId': packageId,
            'saleId': pos ? int.parse(sale.text.trim()) : null,
            'paymentMethod': pos ? null : method,
            'paymentReference': pos ? null : reference.text.trim(),
          },
        );
      } else {
        final body = {
          'code': code.text.trim(),
          'name': name.text.trim(),
          'price': amount,
          'validDays': validDays,
          'units': count,
          'serviceIds': chosen.toList(),
          'posItemId': itemId,
          'active': active,
        };
        if (widget.row == null) {
          await widget.api.post('/api/company/pet/packages', body: body);
        } else {
          await widget.api.put(
            '/api/company/pet/packages/${widget.row!['id']}',
            body: body,
          );
        }
      }
      widget.onSaved();
      if (widget.row != null) {
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        setState(() {
          code.clear();
          name.clear();
          price.text = '0';
          days.text = '30';
          units.text = '1';
          reference.clear();
          sale.clear();
          itemId = null;
          memberId = null;
          packageId = null;
          chosen = {};
          active = true;
          pos = false;
          method = 'CASH';
          generation++;
        });
      }
    } catch (e) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(e, 'บันทึกแพ็กเกจหรือสิทธิ์สมาชิก'),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = (widget.options['services'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final items = (widget.options['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (itemId != null && !items.any((e) => e['id'] == itemId)) {
      items.add({'id': itemId, 'code': 'สินค้าเดิม #$itemId'});
    }
    return LaooActionDialog(
      tokens: tokens,
      icon: widget.icon,
      title:
          '${widget.title} > ${widget.issue
              ? 'ออกสิทธิ์'
              : widget.row == null
              ? 'เพิ่ม'
              : 'แก้ไข'}',
      content: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.issue
              ? [
                  DropdownButtonFormField<int>(
                    key: ValueKey('member-$generation'),
                    initialValue: memberId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'สมาชิก *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radius),
                      ),
                    ),
                    items: [
                      for (final raw
                          in widget.options['members'] as List? ?? [])
                        DropdownMenuItem<int>(
                          value: (raw['id'] as num).toInt(),
                          child: Text(
                            raw['name']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => memberId = value),
                    validator: (value) =>
                        value == null ? 'กรุณาเลือกสมาชิก' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: ValueKey('package-$generation'),
                    initialValue: packageId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'แพ็กเกจ *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radius),
                      ),
                    ),
                    items: [
                      for (final raw
                          in widget.options['packages'] as List? ?? [])
                        DropdownMenuItem<int>(
                          value: (raw['id'] as num).toInt(),
                          child: Text(
                            raw['name']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => packageId = value),
                    validator: (value) =>
                        value == null ? 'กรุณาเลือกแพ็กเกจ' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('รับเงินผ่านใบขาย POS'),
                    value: pos,
                    onChanged: (value) => setState(() => pos = value),
                  ),
                  const SizedBox(height: 16),
                  if (pos)
                    TextFormField(
                      controller: sale,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'ID ใบขาย POS *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(tokens.radius),
                        ),
                      ),
                      validator: (value) =>
                          (int.tryParse(value?.trim() ?? '') ?? 0) < 1
                          ? 'ระบุ ID ใบขายที่ชำระแล้ว'
                          : null,
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: InputDecoration(
                        labelText: 'วิธีรับเงิน *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(tokens.radius),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('เงินสด')),
                        DropdownMenuItem(
                          value: 'TRANSFER',
                          child: Text('โอนเงิน'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => method = value ?? 'CASH'),
                    ),
                    const SizedBox(height: 16),
                    field('เลขอ้างอิงรับเงิน', reference),
                  ],
                ]
              : [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('สถานะ'),
                      Switch(
                        value: active,
                        onChanged: (value) => setState(() => active = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  field('รหัสแพ็กเกจ', code, locked: widget.row != null),
                  const SizedBox(height: 16),
                  field('ชื่อแพ็กเกจ', name),
                  const SizedBox(height: 16),
                  field('ราคา', price, numeric: true),
                  const SizedBox(height: 16),
                  field('อายุสิทธิ์ (วัน)', days, numeric: true),
                  const SizedBox(height: 16),
                  field('จำนวนครั้ง/คืน', units, numeric: true),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: ValueKey('item-$generation'),
                    initialValue: itemId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'สินค้า POS (ถ้ามี)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radius),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('ไม่ผูกสินค้า POS'),
                      ),
                      for (final item in items)
                        DropdownMenuItem<int>(
                          value: (item['id'] as num).toInt(),
                          child: Text(
                            item['code']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => itemId = value),
                  ),
                  const SizedBox(height: 16),
                  Text('บริการที่ใช้แพ็กเกจได้ *', style: tokens.sectionStyle),
                  for (final service in services)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(service['name']?.toString() ?? ''),
                      value: chosen.contains((service['id'] as num).toInt()),
                      onChanged: (value) => setState(() {
                        final id = (service['id'] as num).toInt();
                        if (value == true) {
                          chosen.add(id);
                        } else {
                          chosen.remove(id);
                        }
                      }),
                    ),
                ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: busy ? null : save,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(busy ? 'กำลังบันทึก...' : 'บันทึก'),
        ),
      ],
    );
  }
}
