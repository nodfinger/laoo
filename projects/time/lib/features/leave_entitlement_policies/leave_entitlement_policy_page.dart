import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'leave_entitlement_policy_repository.dart';

class LeaveEntitlementPolicyPage extends StatefulWidget {
  const LeaveEntitlementPolicyPage({super.key});
  @override
  State<LeaveEntitlementPolicyPage> createState() =>
      _LeaveEntitlementPolicyPageState();
}

class _LeaveEntitlementPolicyPageState
    extends State<LeaveEntitlementPolicyPage> {
  late final dynamic api;
  late final LeaveEntitlementPolicyRepository repo;
  Map<String, dynamic>? actions;
  List<Map<String, dynamic>> types = [], items = [];
  int? selectedType;
  bool? active = true;
  int total = 0, page = 1;
  bool loading = true, error = false;
  String? message;
  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    repo = LeaveEntitlementPolicyRepository(api);
    initialize();
  }

  @override
  void dispose() {
    disposeTimeApiClient(api);
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      actions = await repo.actions();
      types = await repo.leaveTypes();
      await load();
    } catch (e) {
      notice(timeErrorText(e), true);
    }
  }

  Future<void> load({int target = 1}) async {
    setState(() => loading = true);
    try {
      final v = await repo.list(
        leaveTypeId: selectedType,
        active: active,
        page: target,
        pageSize: timePageSize,
      );
      if (!mounted) return;
      setState(() {
        page = (v['page'] as num?)?.toInt() ?? target;
        total = (v['total'] as num?)?.toInt() ?? 0;
        items = (v['items'] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
      });
    } catch (e) {
      notice(timeErrorText(e), true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void notice(String x, bool e) => setState(() {
    message = x;
    error = e;
  });
  Future<void> edit([Map<String, dynamic>? item]) async {
    if (types.isEmpty) {
      notice('ยังไม่มีประเภทการลา กรุณาเพิ่มประเภทลาก่อน', true);
      return;
    }
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PolicyDialog(
        caption: actions?['caption'] as String? ?? '',
        types: types,
        item: item,
      ),
    );
    if (value == null) return;
    try {
      await repo.save(value);
      await load(target: page);
      notice('บันทึกเกณฑ์สิทธิ์สำเร็จ', false);
    } catch (e) {
      notice(timeErrorText(e), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = actions?['caption'] as String? ?? '';
    final pages = total == 0 ? 1 : (total / timePageSize).ceil();
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: TimeMenuCodes.leaveEntitlementPolicies,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: timeUiTokens.workspace,
            caption: TimeCaptionCard(
              api: api,
              menuCode: TimeMenuCodes.leaveEntitlementPolicies,
              caption: caption,
              trailing: actions?['create'] == true
                  ? FilledButton.icon(
                      onPressed: () => edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                    )
                  : null,
            ),
            filter: Wrap(
              spacing: timeUiTokens.itemSpacing,
              runSpacing: timeUiTokens.itemSpacing,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<int?>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'ประเภทการลา'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      ...types.map(
                        (x) => DropdownMenuItem(
                          value: x['id'] as int,
                          child: Text('${x['code']} - ${x['name']}'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => selectedType = v),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<bool?>(
                    initialValue: active,
                    decoration: const InputDecoration(labelText: 'สถานะ'),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('ใช้งาน')),
                      DropdownMenuItem(value: false, child: Text('ไม่ใช้งาน')),
                      DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                    ],
                    onChanged: (v) => setState(() => active = v),
                  ),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : () => load(),
                  icon: const Icon(Icons.search),
                  label: const Text('ค้นหา'),
                ),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      selectedType = null;
                      active = true;
                    });
                    load();
                  },
                  child: const Text('ล้าง Filter'),
                ),
              ],
            ),
            table: loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: c.maxWidth),
                        child: DataTable(
                          headingTextStyle: timeUiTokens.tableStyle.copyWith(
                            color: timeUiTokens.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                          dataTextStyle: timeUiTokens.tableStyle,
                          columns: const [
                            LaooWorkspaceTableColumns.id,
                            DataColumn(label: Text('จัดการ')),
                            DataColumn(label: Text('ประเภทการลา')),
                            DataColumn(label: Text('เกณฑ์')),
                            DataColumn(label: Text('สิทธิ์')),
                            DataColumn(label: Text('เริ่มใช้')),
                            DataColumn(label: Text('สิ้นสุด')),
                            DataColumn(label: Text('สถานะ')),
                          ],
                          rows: items.asMap().entries.map((e) {
                            final x = e.value;
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '${(page - 1) * timePageSize + e.key + 1}',
                                  ),
                                ),
                                DataCell(
                                  actions?['edit'] == true
                                      ? IconButton(
                                          onPressed: () => edit(x),
                                          icon: const Icon(Icons.edit_outlined),
                                        )
                                      : const SizedBox(),
                                ),
                                DataCell(
                                  Text(
                                    '${x['leaveTypeCode']} - ${x['leaveTypeName']}',
                                  ),
                                ),
                                DataCell(Text('${x['policyName']}')),
                                DataCell(
                                  Text(
                                    '${x['entitlementQuantity']} ${x['unitCode'] == 'DAY' ? 'วัน' : 'นาที'}',
                                  ),
                                ),
                                DataCell(Text(_date(x['effectiveFrom']))),
                                DataCell(
                                  Text(
                                    x['effectiveTo'] == null
                                        ? '-'
                                        : _date(x['effectiveTo']),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    x['isActive'] == true
                                        ? 'ใช้งาน'
                                        : 'ไม่ใช้งาน',
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
            pagination: LaooPaginationCard(
              tokens: timeUiTokens.workspace,
              page: page,
              pageCount: pages,
              pageSize: timePageSize,
              total: total,
              onPrevious: page > 1 ? () => load(target: page - 1) : null,
              onNext: page < pages ? () => load(target: page + 1) : null,
            ),
          ),
          if (message != null)
            Positioned(
              right: 16,
              top: 16,
              child: buildTimeMessage(
                message: message!,
                error: error,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }

  String _date(dynamic v) {
    if (v is String) return v.split('T').first;
    return '$v';
  }
}

class _PolicyDialog extends StatefulWidget {
  const _PolicyDialog({required this.caption, required this.types, this.item});
  final String caption;
  final List<Map<String, dynamic>> types;
  final Map<String, dynamic>? item;
  @override
  State<_PolicyDialog> createState() => _PolicyDialogState();
}

class _PolicyDialogState extends State<_PolicyDialog> {
  final key = GlobalKey<FormState>();
  late int typeId;
  late final TextEditingController name, quantity;
  late DateTime effectiveFrom;
  DateTime? effectiveTo;
  late bool active;
  @override
  void initState() {
    super.initState();
    typeId =
        widget.item?['leaveTypeId'] as int? ?? widget.types.first['id'] as int;
    name = TextEditingController(text: widget.item?['policyName'] as String?);
    quantity = TextEditingController(
      text: '${widget.item?['entitlementQuantity'] ?? ''}',
    );
    effectiveFrom =
        DateTime.tryParse('${widget.item?['effectiveFrom'] ?? ''}') ??
        DateTime.now();
    effectiveTo = widget.item?['effectiveTo'] == null
        ? null
        : DateTime.tryParse('${widget.item?['effectiveTo']}');
    active = widget.item?['isActive'] as bool? ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> pick(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? effectiveFrom : (effectiveTo ?? effectiveFrom),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null)
      setState(() {
        if (start)
          effectiveFrom = picked;
        else
          effectiveTo = picked;
      });
  }

  @override
  Widget build(BuildContext context) => TimeActionDialog(
    icon: Icons.rule_outlined,
    title:
        '${widget.caption} > ${widget.item == null ? 'เพิ่ม' : 'สร้าง Version ใหม่'}',
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.item != null)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ระบบจะเก็บ Version เดิมไว้จนถึงวันก่อนวันที่เริ่มใช้ใหม่',
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('สถานะ'),
              const SizedBox(width: 8),
              Switch(
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: typeId,
            decoration: const InputDecoration(labelText: 'ประเภทการลา'),
            items: widget.types
                .map(
                  (x) => DropdownMenuItem(
                    value: x['id'] as int,
                    child: Text('${x['code']} - ${x['name']}'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => typeId = v ?? typeId),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'ชื่อเกณฑ์ *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'จำนวนสิทธิ์ *'),
            validator: (v) => num.tryParse(v ?? '') == null || num.parse(v!) < 0
                ? 'กรุณาระบุจำนวนที่ถูกต้อง'
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => pick(true),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('เริ่มใช้ ${_format(effectiveFrom)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => pick(false),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    effectiveTo == null
                        ? 'สิ้นสุด (ไม่กำหนด)'
                        : _format(effectiveTo!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: () {
          if (key.currentState?.validate() != true) return;
          Navigator.pop(context, {
            'id': widget.item?['id'],
            'leaveTypeId': typeId,
            'policyName': name.text.trim(),
            'entitlementQuantity': num.parse(quantity.text),
            'effectiveFrom': _iso(effectiveFrom),
            'effectiveTo': effectiveTo == null ? null : _iso(effectiveTo!),
            'isActive': active,
            'rowVersion': widget.item?['rowVersion'],
          });
        },
        icon: const Icon(Icons.save_outlined),
        label: const Text('บันทึก'),
      ),
    ],
  );
  String _format(DateTime x) =>
      '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
  String _iso(DateTime x) =>
      '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
}
