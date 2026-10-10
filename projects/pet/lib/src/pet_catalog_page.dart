import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'pet_host.dart';

class PetCatalogPage extends StatefulWidget {
  const PetCatalogPage({super.key, required this.menuCode})
    : assert(menuCode == '62002' || menuCode == '62003');
  final String menuCode;

  @override
  State<PetCatalogPage> createState() => _PetCatalogPageState();
}

class _PetCatalogPageState extends State<PetCatalogPage> {
  static const base = '/api/company/pet';
  late final api = petApi();
  final search = TextEditingController();
  Map<String, dynamic> metadata = {}, actions = {};
  List<Map<String, dynamic>> rows = [];
  int page = 1, total = 0;
  bool loading = true, cards = false;
  String? error;
  bool get isService => widget.menuCode == '62002';
  String get path => isService ? 'services' : 'rooms';
  String get title => metadata['MenuName']?.toString() ?? '';
  LaooWorkspaceUiTokens get tokens => petTokens();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PetCatalogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuCode != widget.menuCode) {
      page = 1;
      rows = [];
      search.clear();
      load();
    }
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
        await api.get('$base/actions/${widget.menuCode}') as Map,
      );
      metadata = Map<String, dynamic>.from(access['metadata'] as Map);
      actions = Map<String, dynamic>.from(access['actions'] as Map);
      if (actions['view'] != true) throw StateError('ไม่มีสิทธิ์ดูรายการนี้');
      final data = Map<String, dynamic>.from(
        await api.get(
              '$base/$path',
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
      if (mounted) setState(() => loading = false);
    } catch (exception) {
      if (mounted) {
        setState(() {
          loading = false;
          error = petErrorText(exception, 'โหลดรายการสัตว์เลี้ยง');
        });
      }
    }
  }

  Future<void> openForm([Map<String, dynamic>? row]) async {
    if (actions[row == null ? 'create' : 'edit'] != true) return;
    try {
      final options = Map<String, dynamic>.from(
        await api.get('$base/options/${widget.menuCode}') as Map,
      );
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CatalogForm(
          title: title,
          icon: petMenuIcon(metadata['IconName']?.toString()),
          service: isService,
          row: row,
          options: options,
          api: api,
          onCreated: () {
            petMessage(context, message: 'เพิ่มรายการแล้ว', error: false);
            page = 1;
            load();
          },
        ),
      );
      if (saved == true && mounted) {
        petMessage(context, message: 'แก้ไขรายการแล้ว', error: false);
        await load();
      }
    } catch (exception) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(exception, 'เปิดแบบฟอร์ม'),
          error: true,
        );
      }
    }
  }

  String cell(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return '—';
    if (key == 'active') return value == true ? 'ใช้งาน' : 'ปิดใช้งาน';
    if (key == 'price' && value is num) return value.toStringAsFixed(2);
    return value.toString();
  }

  List<MapEntry<String, String>> get columns => isService
      ? const [
          MapEntry('code', 'รหัส'),
          MapEntry('name', 'บริการ'),
          MapEntry('kind', 'ประเภท'),
          MapEntry('unit', 'หน่วย'),
          MapEntry('price', 'ราคา'),
          MapEntry('active', 'สถานะ'),
        ]
      : const [
          MapEntry('code', 'รหัส'),
          MapEntry('name', 'ห้อง/กรง'),
          MapEntry('capacity', 'ความจุ'),
          MapEntry('branchId', 'สาขา'),
          MapEntry('active', 'สถานะ'),
        ];

  Widget actionsFor(Map<String, dynamic> row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          icon: const Icon(Icons.edit_outlined),
          color: tokens.primaryColor,
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
            child: Text('ไม่พบรายการตามเงื่อนไขที่เลือก'),
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
                    '${rows[i]['code'] ?? rows[i]['id']} · ${rows[i]['name'] ?? ''}',
                    style: tokens.sectionStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                  for (final column in columns.skip(2))
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '${column.value}: ${cell(rows[i], column.key)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: actionsFor(rows[i]),
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
            columns: [
              const DataColumn(label: Text('ID')),
              const DataColumn(label: Text('Action')),
              for (final column in columns)
                DataColumn(label: Text(column.value)),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text('${row['id']}')),
                    DataCell(actionsFor(row)),
                    for (final column in columns)
                      DataCell(Text(cell(row, column.key))),
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
    activeMenu: isService ? 'pet-services' : 'pet-rooms',
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
                favoriteKey: isService ? 'pet-services' : 'pet-rooms',
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
                        labelText: 'ค้นหารหัสหรือชื่อ',
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

class _CatalogForm extends StatefulWidget {
  const _CatalogForm({
    required this.title,
    required this.icon,
    required this.service,
    required this.row,
    required this.options,
    required this.api,
    required this.onCreated,
  });
  final String title;
  final IconData icon;
  final bool service;
  final Map<String, dynamic>? row;
  final Map<String, dynamic> options;
  final JsonApiClient api;
  final VoidCallback onCreated;
  @override
  State<_CatalogForm> createState() => _CatalogFormState();
}

class _CatalogFormState extends State<_CatalogForm> {
  final key = GlobalKey<FormState>();
  late final code = TextEditingController(
    text: widget.row?['code']?.toString() ?? '',
  );
  late final name = TextEditingController(
    text: widget.row?['name']?.toString() ?? '',
  );
  late final capacity = TextEditingController(
    text: widget.row?['capacity']?.toString() ?? '1',
  );
  late int? sourceId =
      (widget.row?[widget.service ? 'id' : 'resourceId'] as num?)?.toInt();
  late String kind = widget.row?['kind']?.toString() ?? 'GROOMING';
  late String unit = widget.row?['unit']?.toString() ?? 'VISIT';
  late bool active = widget.row?['active'] != false;
  bool saving = false;
  int formVersion = 0;
  LaooWorkspaceUiTokens get tokens => petTokens();
  @override
  void dispose() {
    code.dispose();
    name.dispose();
    capacity.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get sources {
    final available =
        (widget.options[widget.service ? 'bookingServices' : 'resources']
                    as List? ??
                [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
    if (widget.row != null &&
        sourceId != null &&
        !available.any((item) => item['id'] == sourceId)) {
      available.add({
        'id': sourceId,
        'name': widget.row?['name'] ?? 'รายการเดิม',
      });
    }
    return available;
  }

  Future<void> save() async {
    if (saving || !key.currentState!.validate() || sourceId == null) return;
    setState(() => saving = true);
    try {
      final body = widget.service
          ? {
              'serviceId': sourceId,
              'kind': kind,
              'unit': unit,
              'active': active,
            }
          : {
              'resourceId': sourceId,
              'code': code.text.trim(),
              'name': name.text.trim(),
              'capacity': int.parse(capacity.text.trim()),
              'active': active,
            };
      final path = '/api/company/pet/${widget.service ? 'services' : 'rooms'}';
      if (widget.row == null) {
        await widget.api.post(path, body: body);
        widget.onCreated();
        setState(() {
          sourceId = null;
          kind = 'GROOMING';
          unit = 'VISIT';
          active = true;
          formVersion++;
          code.clear();
          name.clear();
          capacity.text = '1';
        });
      } else {
        await widget.api.put('$path/${widget.row!['id']}', body: body);
        if (mounted) Navigator.pop(context, true);
      }
    } catch (exception) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(exception, 'บันทึกรายการ'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget input(
    String label,
    TextEditingController controller, {
    bool locked = false,
    bool number = false,
  }) => TextFormField(
    controller: controller,
    readOnly: locked,
    keyboardType: number ? TextInputType.number : null,
    decoration: InputDecoration(
      labelText: '$label *',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
    ),
    validator: (value) {
      if (value == null || value.trim().isEmpty) return 'กรุณาระบุ$label';
      if (number && (int.tryParse(value) ?? 0) < 1) return 'ต้องมากกว่า 0';
      return null;
    },
  );

  @override
  Widget build(BuildContext context) => LaooActionDialog(
    tokens: tokens,
    icon: widget.icon,
    title: '${widget.title} > ${widget.row == null ? 'เพิ่ม' : 'แก้ไข'}',
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          DropdownButtonFormField<int>(
            key: ValueKey('source-$formVersion'),
            initialValue: sourceId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.service
                  ? 'บริการจาก Booking *'
                  : 'ทรัพยากรจาก Booking *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radius),
              ),
            ),
            items: sources
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
            onChanged: widget.row == null
                ? (value) => setState(() => sourceId = value)
                : null,
            validator: (value) => value == null ? 'กรุณาเลือกรายการ' : null,
          ),
          if (widget.service) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('kind-$formVersion'),
              initialValue: kind,
              decoration: InputDecoration(
                labelText: 'ประเภทบริการ *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radius),
                ),
              ),
              items: const ['HOTEL', 'GROOMING', 'DAYCARE', 'TRANSPORT']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => kind = value ?? kind),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('unit-$formVersion'),
              initialValue: unit,
              decoration: InputDecoration(
                labelText: 'หน่วยบริการ *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radius),
                ),
              ),
              items: const ['VISIT', 'NIGHT', 'DAY']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => unit = value ?? unit),
            ),
          ] else ...[
            const SizedBox(height: 16),
            input('รหัสห้อง/กรง', code, locked: widget.row != null),
            const SizedBox(height: 16),
            input('ชื่อห้อง/กรง', name),
            const SizedBox(height: 16),
            input('ความจุ', capacity, number: true),
          ],
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
