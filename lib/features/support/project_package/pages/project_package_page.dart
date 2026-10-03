import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/project_package_repository.dart';

class ProjectPackagePage extends StatefulWidget {
  const ProjectPackagePage({super.key});

  @override
  State<ProjectPackagePage> createState() => _ProjectPackagePageState();
}

class _ProjectPackagePageState extends State<ProjectPackagePage> {
  final _repository = ProjectPackageRepository();
  List<ProjectPackageSummary> _items = const [];
  bool _loading = true;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.getPackages();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = 'โหลดแพ็กเกจไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm(ProjectPackageSummary item) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PackageFormDialog(item: item, repository: _repository),
    );
    if (saved == true && mounted) {
      await _load();
      setState(() => _message = 'บันทึก Package Master สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    menuScope: WorkspaceMenuScope.support,
    pageTitle: 'ข้อมูลผู้ใช้บริการ > Package Master',
    activeMenu: 'company',
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkspaceActionHeader(
                title: 'ข้อมูลผู้ใช้บริการ > Package Master',
                favoriteKey: 'company',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('ปิด'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _body()),
            ],
          ),
          if (_message != null)
            Positioned(
              top: 0,
              right: 0,
              child: AutoDismissMessage(
                key: ValueKey(_message),
                message: _message!,
                error: false,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final projects = <int, List<ProjectPackageSummary>>{};
    for (final item in _items) {
      projects.putIfAbsent(item.projectId, () => []).add(item);
    }
    return ListView.separated(
      itemCount: projects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final rows = projects.values.elementAt(index);
        final project = rows.first;
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.apps_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${project.projectName} (${project.projectCode})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _openForm(
                        ProjectPackageSummary(
                          projectId: project.projectId,
                          projectCode: project.projectCode,
                          projectName: project.projectName,
                          sortOrder: rows.length * 10 + 10,
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่มแพ็กเกจ'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: rows
                      .where((x) => x.packageId != null)
                      .map(
                        (item) => SizedBox(
                          width: 280,
                          child: ListTile(
                            tileColor: LaooColors.surfaceSoft,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            title: Text(item.packageName ?? '-'),
                            subtitle: Text(
                              '${item.tierCode} • ${item.billingCycle} • ${item.price.toStringAsFixed(2)} บาท',
                            ),
                            trailing: IconButton(
                              tooltip: 'แก้ไข',
                              onPressed: () => _openForm(item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PackageFormDialog extends StatefulWidget {
  const _PackageFormDialog({required this.item, required this.repository});
  final ProjectPackageSummary item;
  final ProjectPackageRepository repository;

  @override
  State<_PackageFormDialog> createState() => _PackageFormDialogState();
}

class _PackageFormDialogState extends State<_PackageFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _trial;
  String _tier = 'STANDARD';
  String _cycle = 'YEARLY';
  bool _active = true;
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _features = const [];
  List<Map<String, dynamic>> _quotas = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.item.packageCode ?? '');
    _name = TextEditingController(text: widget.item.packageName ?? '');
    _price = TextEditingController(text: widget.item.price.toStringAsFixed(2));
    _trial = TextEditingController(text: '${widget.item.trialDays}');
    _tier = widget.item.tierCode ?? 'STANDARD';
    _cycle = widget.item.billingCycle ?? 'YEARLY';
    _active = widget.item.isActive;
    _load();
  }

  Future<void> _load() async {
    final id = widget.item.packageId;
    if (id == null) {
      try {
        final options = await widget.repository.getFeatureOptions(
          widget.item.projectId,
        );
        if (mounted) {
          setState(() {
            _features = options;
            _quotas = [
              {
                'quotaCode': 'MAX_USERS',
                'quotaNameTh': 'จำนวนผู้ใช้',
                'limitValue': 5,
                'unitCode': 'USER',
              },
              {
                'quotaCode': 'MAX_BRANCHES',
                'quotaNameTh': 'จำนวนสาขา',
                'limitValue': 1,
                'unitCode': 'BRANCH',
              },
              {
                'quotaCode': 'STORAGE_MB',
                'quotaNameTh': 'พื้นที่จัดเก็บไฟล์',
                'limitValue': 1024,
                'unitCode': 'MB',
              },
            ];
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() => _error = 'โหลดตัวเลือก Feature ไม่สำเร็จ: $error');
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    try {
      final data = await widget.repository.getDetail(id);
      if (mounted) {
        setState(() {
          _features = (data['features'] as List? ?? const [])
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
          _quotas = (data['quotas'] as List? ?? const [])
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'โหลดรายละเอียดไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save({
        'projectId': widget.item.projectId,
        'packageCode': _code.text.trim(),
        'packageNameTh': _name.text.trim(),
        'packageNameEn': null,
        'tierCode': _tier,
        'billingCycle': _cycle,
        'price': double.parse(_price.text),
        'currencyCode': 'THB',
        'trialDays': int.parse(_trial.text),
        'sortOrder': widget.item.sortOrder,
        'isActive': _active,
        'features': _features,
        'quotas': _quotas,
      }, packageId: widget.item.packageId);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = 'บันทึกไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Package Master > แก้ไข',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.all(10),
                      children: [
                        Row(
                          children: [
                            const Text('สถานะใช้งาน'),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: _active,
                              onChanged: (v) => setState(() => _active = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _code,
                          decoration: const InputDecoration(
                            labelText: 'รหัสแพ็กเกจ *',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อแพ็กเกจ *',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField(
                          initialValue: _tier,
                          decoration: const InputDecoration(
                            labelText: 'ระดับ *',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'FREE',
                              child: Text('Free'),
                            ),
                            DropdownMenuItem(
                              value: 'STANDARD',
                              child: Text('Standard'),
                            ),
                            DropdownMenuItem(
                              value: 'ENTERPRISE',
                              child: Text('Enterprise'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _tier = v ?? 'STANDARD'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField(
                          initialValue: _cycle,
                          decoration: const InputDecoration(
                            labelText: 'รอบบิล *',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'NONE',
                              child: Text('ไม่มี'),
                            ),
                            DropdownMenuItem(
                              value: 'MONTHLY',
                              child: Text('รายเดือน'),
                            ),
                            DropdownMenuItem(
                              value: 'YEARLY',
                              child: Text('รายปี'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _cycle = v ?? 'YEARLY'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _price,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'ราคา *',
                                ),
                                validator: _number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _trial,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'วันทดลองใช้ *',
                                ),
                                validator: _number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Feature ในแพ็กเกจ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ..._features.map(
                          (f) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('${f['featureCode']}'),
                            value: f['isEnabled'] == true,
                            onChanged: (v) =>
                                setState(() => f['isEnabled'] = v == true),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'โควตา',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ..._quotas.map(
                          (q) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text('${q['quotaNameTh']}')),
                                SizedBox(
                                  width: 130,
                                  child: TextFormField(
                                    initialValue: '${q['limitValue']}',
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: '${q['unitCode']}',
                                    ),
                                    validator: _quota,
                                    onChanged: (value) => q['limitValue'] =
                                        double.tryParse(value),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('บันทึก'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null;
  static String? _number(String? value) =>
      double.tryParse(value ?? '') == null ? 'กรุณาระบุตัวเลข' : null;
  static String? _quota(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number < -1 ? 'ค่าต่ำสุด -1' : null;
  }
}
