import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../time/time_feature_host.dart';
import '../time/time_route_contract.dart';
import 'payroll_export_repository.dart';

enum PayrollExportMode { profiles, generate, history }

class PayrollExportPage extends StatefulWidget {
  const PayrollExportPage({super.key, required this.mode});
  final PayrollExportMode mode;
  @override
  State<PayrollExportPage> createState() => _PayrollExportPageState();
}

class _PayrollExportPageState extends State<PayrollExportPage> {
  late final JsonApiClient api;
  late final PayrollExportRepository repo;
  Map<String, dynamic>? actions;
  List<Map<String, dynamic>> items = const [];
  List<Map<String, dynamic>> profiles = const [], periods = const [];
  int? selectedProfile, selectedPeriod;
  bool loading = true;
  String? message;
  bool messageIsError = false;

  String get menuCode => switch (widget.mode) {
    PayrollExportMode.profiles => TimeMenuCodes.payrollExportProfiles,
    PayrollExportMode.generate => TimeMenuCodes.payrollExport,
    PayrollExportMode.history => TimeMenuCodes.payrollExportHistory,
  };

  @override
  void initState() {
    super.initState();
    api = createTimeApiClient();
    repo = PayrollExportRepository(api);
    _load();
  }

  @override
  void dispose() {
    disposeTimeApiClient(api);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final a = await repo.actions(menuCode);
      if (widget.mode == PayrollExportMode.profiles) {
        items = await repo.profiles();
      }
      if (widget.mode == PayrollExportMode.generate) {
        profiles = await repo.activeProfileLookup();
        periods = await repo.periods();
      }
      if (widget.mode == PayrollExportMode.history) {
        items = await repo.history();
      }
      if (mounted) {
        setState(() {
          actions = a;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = timeErrorText(e);
          messageIsError = true;
          loading = false;
        });
      }
    }
  }

  void _notice(String text, {bool error = false}) => setState(() {
    message = text;
    messageIsError = error;
  });
  @override
  Widget build(BuildContext context) {
    final caption = actions?['caption']?.toString() ?? '';
    return buildTimeWorkspaceShell(
      pageTitle: caption,
      activeMenu: menuCode,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: timeUiTokens.workspace,
            caption: TimeCaptionCard(
              api: api,
              menuCode: menuCode,
              caption: caption,
              trailing: _trailing(),
            ),
            filter: _filter(),
            table: loading
                ? const Center(child: CircularProgressIndicator())
                : _content(),
            pagination: TimePaginationCard(
              tokens: timeUiTokens.workspace,
              page: 1,
              pageCount: 1,
              pageSize: items.length,
              total: items.length,
              onPrevious: null,
              onNext: null,
            ),
          ),
          if (message != null)
            Positioned(
              top: 16,
              right: 16,
              child: buildTimeMessage(
                message: message!,
                error: messageIsError,
                onClose: () => setState(() => message = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _trailing() =>
      widget.mode == PayrollExportMode.profiles &&
          actions?['screenType'] == 1 &&
          actions?['create'] == true
      ? FilledButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('เพิ่ม'),
        )
      : null;
  Widget _filter() {
    if (widget.mode != PayrollExportMode.generate) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<int>(
            initialValue: selectedPeriod,
            decoration: const InputDecoration(labelText: 'งวดที่ปิดแล้ว'),
            items: [
              for (final x in periods)
                DropdownMenuItem(
                  value: (x['periodId'] as num).toInt(),
                  child: Text('${x['startDate']} - ${x['endDate']}'),
                ),
            ],
            onChanged: (v) => setState(() => selectedPeriod = v),
          ),
        ),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<int>(
            initialValue: selectedProfile,
            decoration: const InputDecoration(labelText: 'รูปแบบ Export'),
            items: [
              for (final x in profiles)
                DropdownMenuItem(
                  value: (x['profileId'] as num).toInt(),
                  child: Text('${x['profileCode']} - ${x['profileName']}'),
                ),
            ],
            onChanged: (v) => setState(() => selectedProfile = v),
          ),
        ),
        FilledButton.icon(
          onPressed:
              selectedPeriod == null ||
                  selectedProfile == null ||
                  actions?['create'] != true
              ? null
              : _generate,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('สร้างไฟล์'),
        ),
      ],
    );
  }

  Widget _content() {
    if (widget.mode == PayrollExportMode.generate) {
      return const Center(
        child: Text('เลือกงวดและรูปแบบ Export แล้วกดสร้างไฟล์'),
      );
    }
    if (items.isEmpty) return const Center(child: Text('ไม่พบข้อมูล'));
    return ListView.separated(
      padding: timeUiTokens.cardPadding,
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: timeUiTokens.itemSpacing),
      itemBuilder: (_, i) {
        final x = items[i];
        final title = widget.mode == PayrollExportMode.profiles
            ? '${x['profileCode']} — ${x['profileName']}'
            : '${x['fileName'] ?? '-'} — ${x['statusCode']}';
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(title),
            subtitle: Text(
              widget.mode == PayrollExportMode.profiles
                  ? '${x['formatCode']} | ${x['encoding']}${x['isActive'] == true ? '' : ' | ปิดใช้งาน'}'
                  : 'จำนวน ${x['totalRows']} รายการ',
            ),
            trailing:
                widget.mode == PayrollExportMode.profiles &&
                    actions?['screenType'] == 1 &&
                    (actions?['edit'] == true || actions?['delete'] == true)
                ? Wrap(
                    spacing: 4,
                    children: [
                      if (actions?['edit'] == true)
                        IconButton(
                          tooltip: x['isActive'] == true
                              ? 'แก้ไขรูปแบบ Export'
                              : 'แก้ไขและเปิดใช้งานรูปแบบ Export',
                          onPressed: () => _edit(x),
                          icon: Icon(
                            Icons.edit_outlined,
                            color: timeUiTokens.primaryColor,
                          ),
                        ),
                      if (actions?['delete'] == true)
                        IconButton(
                          tooltip: 'ลบรูปแบบ Export',
                          onPressed: () => _deleteProfile(x),
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Future<void> _generate() async {
    if (actions?['create'] != true) return;
    try {
      final result = await repo.generate(selectedPeriod!, selectedProfile!);
      _notice('สร้างไฟล์ ${result['fileName']} สำเร็จ');
    } catch (e) {
      _notice(timeErrorText(e), error: true);
    }
  }

  Future<void> _deleteProfile(Map<String, dynamic> item) async {
    if (widget.mode != PayrollExportMode.profiles ||
        actions?['screenType'] != 1 ||
        actions?['delete'] != true) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => TimeDeleteDialog(
        itemLabel: '${item['profileCode']} — ${item['profileName']}',
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await repo.deleteProfile(item);
      await _load();
      if (mounted) _notice('ลบรูปแบบ Export สำเร็จ');
    } catch (error) {
      if (mounted) _notice(timeErrorText(error), error: true);
    }
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    if (widget.mode != PayrollExportMode.profiles ||
        actions?['screenType'] != 1 ||
        actions?[item == null ? 'create' : 'edit'] != true) {
      return;
    }
    final code = TextEditingController(text: item?['profileCode']);
    final name = TextEditingController(text: item?['profileName']);
    var format = item?['formatCode'] ?? 'TEXT';
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) => TimeActionDialog(
          icon: Icons.description_outlined,
          title:
              '${actions?['caption'] ?? 'รูปแบบ Export Payroll'} > ${item == null ? 'เพิ่ม' : 'แก้ไข'}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item?['isActive'] == false) ...[
                const Text(
                  'รายการนี้ปิดใช้งานอยู่ การบันทึกจะเปิดใช้งานอีกครั้ง',
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'รหัส Profile'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'ชื่อ Profile'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: format,
                decoration: const InputDecoration(labelText: 'รูปแบบ'),
                items: const [
                  DropdownMenuItem(value: 'TEXT', child: Text('Text file')),
                  DropdownMenuItem(value: 'EXCEL', child: Text('Excel')),
                ],
                onChanged: (v) => setDialog(() => format = v ?? format),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    try {
      await repo.saveProfile({
        'profileId': item?['profileId'],
        'profileCode': code.text.trim(),
        'profileName': name.text.trim(),
        'formatCode': format,
        'includeHeader': true,
        'rowVersion': item?['rowVersion'],
      });
      await _load();
    } catch (e) {
      _notice(timeErrorText(e), error: true);
    }
  }
}
