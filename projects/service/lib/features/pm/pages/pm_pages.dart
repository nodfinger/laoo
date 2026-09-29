import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/pm_api.dart';

String _pmErrorDescription(Object error) {
  if (error is ApiException) {
    return error.description ??
        'กรุณาตรวจสอบข้อมูลและลองอีกครั้ง หากยังพบปัญหาให้ติดต่อผู้ดูแลระบบ';
  }
  return 'การเชื่อมต่อหรือบริการขัดข้อง กรุณาลองอีกครั้ง หากยังพบปัญหาให้ติดต่อผู้ดูแลระบบ';
}

Widget _pmPopupTitle(BuildContext context, String title, IconData icon) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: LaooLayout.popupHeaderMinHeight,
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: LaooLayout.cardPadding),
              Expanded(
                child: Text(title, style: LaooTypography.screenCaptionStyle),
              ),
            ],
          ),
        ),
        const Divider(color: LaooColors.border, height: 1),
      ],
    );

Widget _pmPopupFormTheme(BuildContext context, Widget child) {
  final primary = Theme.of(context).colorScheme.primary;
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(LaooRadius.xs),
    borderSide: const BorderSide(color: LaooColors.border),
  );
  return Theme(
    data: Theme.of(context).copyWith(
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(borderSide: BorderSide(color: primary)),
      ),
    ),
    child: child,
  );
}

Future<bool> _confirmPmDelete(BuildContext context, String name) async {
  final color = Theme.of(context).colorScheme.error;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
            side: BorderSide(color: color),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.delete_outline, color: color),
                  const SizedBox(width: LaooLayout.cardPadding),
                  Expanded(
                    child: Text(
                      'ยืนยันการลบ',
                      style: LaooTypography.screenCaptionStyle.copyWith(
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: LaooColors.border),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            child: Text(
              'ลบ “$name” ถาวรใช่หรือไม่? รายการที่มีใบงาน PM อ้างอิงจะลบไม่ได้ และรายการที่ลบแล้วไม่สามารถเรียกคืนได้',
            ),
          ),
          actions: [
            const SizedBox(
              width: double.infinity,
              child: Divider(color: LaooColors.border),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบ'),
            ),
          ],
        ),
      ) ??
      false;
}

class PmPlansPage extends StatefulWidget {
  const PmPlansPage({super.key, this.api});
  final PmApi? api;
  @override
  State<PmPlansPage> createState() => _PmPlansState();
}

class _PmPlansState extends State<PmPlansPage> {
  late final PmApi api = widget.api ?? PmApi();
  late Future<Map<String, dynamic>> data;
  bool canCreate = false;
  bool canEdit = false;
  bool canDelete = false;
  @override
  void initState() {
    super.initState();
    data = api.plans;
    api.planActions
        .then((actions) {
          if (mounted) {
            setState(() {
              canCreate =
                  actions['screenType'] == 1 && actions['create'] == true;
              canEdit = actions['screenType'] == 1 && actions['edit'] == true;
              canDelete =
                  actions['screenType'] == 1 && actions['delete'] == true;
            });
          }
        })
        .catchError((Object _) {
          // Never expose mutation controls if effective permissions are unavailable.
        });
  }

  void refresh() => setState(() {
    data = api.plans;
  });
  Future<void> openPlan({Map? plan}) async {
    if (plan == null && !canCreate || plan != null && !canEdit) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _NewPlanDialog(api, plan: plan),
    );
    if (changed == true) refresh();
  }

  Future<void> deletePlan(Map plan) async {
    if (!canDelete) return;
    final confirmed = await _confirmPmDelete(
      context,
      plan['planName']?.toString() ?? '-',
    );
    if (!confirmed || !mounted) return;
    try {
      await api.deletePlan((plan['pmPlanId'] as num).toInt());
      if (!mounted) return;
      refresh();
      showTimedSnackBar(context, message: 'ลบแผน PM แล้ว');
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'ไม่สามารถลบแผน PM ได้\nรายละเอียดเพิ่มเติม: ${_pmErrorDescription(error)}',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) => SupportWorkspaceShell(
    pageTitle: 'แผนและรอบเวลา PM',
    activeMenu: 'pmPlans',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canCreate)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => openPlan(),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มแผน PM'),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: data,
              builder: (c, s) {
                if (s.hasError) {
                  return _PmLoadError(onRetry: refresh);
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = ((s.data!['items'] as List?) ?? []).cast<Map>();
                if (rows.isEmpty) {
                  return const Center(child: Text('ยังไม่มีแผน PM'));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return Card(
                      child: ListTile(
                        onTap: !canEdit
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: c,
                                  builder: (_) =>
                                      _AssetAssignmentDialog(api, r),
                                );
                                if (ok == true) refresh();
                              },
                        leading: const Icon(Icons.settings_suggest),
                        title: Text(r['planName']?.toString() ?? '-'),
                        subtitle: Text(
                          'ประเภท ${r['itemTypeCode'] ?? '-'} • Asset ${r['assetCount'] ?? 0}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (canEdit)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'แก้ไขแผน PM',
                                onPressed: () => openPlan(plan: r),
                              ),
                            if (canDelete)
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(c).colorScheme.error,
                                ),
                                tooltip: 'ลบแผน PM',
                                onPressed: () => deletePlan(r),
                              ),
                            if (canEdit)
                              IconButton(
                                icon: const Icon(Icons.checklist),
                                tooltip: 'ผูก Checklist',
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: c,
                                    builder: (_) =>
                                        _PlanChecklistDialog(api, r),
                                  );
                                  if (ok == true) refresh();
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class PmChecklistsPage extends StatefulWidget {
  const PmChecklistsPage({super.key, this.api});
  final PmApi? api;
  @override
  State<PmChecklistsPage> createState() => _PmChecklistsState();
}

class _PmChecklistsState extends State<PmChecklistsPage> {
  late final PmApi api = widget.api ?? PmApi();
  late Future<Map<String, dynamic>> data;
  bool canCreate = false;
  bool canEdit = false;
  bool canDelete = false;
  @override
  void initState() {
    super.initState();
    data = api.checklists;
    api.checklistActions
        .then((actions) {
          if (mounted) {
            setState(() {
              canCreate =
                  actions['screenType'] == 1 && actions['create'] == true;
              canEdit = actions['screenType'] == 1 && actions['edit'] == true;
              canDelete =
                  actions['screenType'] == 1 && actions['delete'] == true;
            });
          }
        })
        .catchError((Object _) {
          // Never expose mutation controls if effective permissions are unavailable.
        });
  }

  void refresh() => setState(() {
    data = api.checklists;
  });
  Future<void> openChecklist({Map? checklist}) async {
    if (checklist == null && !canCreate || checklist != null && !canEdit) {
      return;
    }
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _NewChecklistDialog(api, checklist: checklist),
    );
    if (changed == true) refresh();
  }

  Future<void> deleteChecklist(Map checklist) async {
    if (!canDelete) return;
    final confirmed = await _confirmPmDelete(
      context,
      checklist['checklistName']?.toString() ?? '-',
    );
    if (!confirmed || !mounted) return;
    try {
      await api.deleteChecklist((checklist['pmChecklistId'] as num).toInt());
      if (!mounted) return;
      refresh();
      showTimedSnackBar(context, message: 'ลบ Checklist แล้ว');
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'ไม่สามารถลบ Checklist ได้\nรายละเอียดเพิ่มเติม: ${_pmErrorDescription(error)}',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) => SupportWorkspaceShell(
    pageTitle: 'รายการตรวจเช็กมาตรฐาน',
    activeMenu: 'pmChecklists',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canCreate)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => openChecklist(),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่ม Checklist'),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _Rows(
              future: data,
              name: 'checklistName',
              onRetry: refresh,
              onEdit: canEdit ? (row) => openChecklist(checklist: row) : null,
              onDelete: canDelete ? deleteChecklist : null,
            ),
          ),
        ],
      ),
    ),
  );
}

class PmCalendarPage extends StatefulWidget {
  const PmCalendarPage({
    super.key,
    this.menuCode = '16003',
    this.routeName = 'pmCalendar',
    this.pageTitle = 'ปฏิทินงานบำรุงรักษา',
    this.portalSchedule = false,
    this.api,
  });
  final String menuCode;
  final String routeName;
  final String pageTitle;
  final bool portalSchedule;
  final PmApi? api;
  @override
  State<PmCalendarPage> createState() => _CalendarState();
}

class _CalendarState extends State<PmCalendarPage> {
  late final PmApi api = widget.api ?? PmApi();
  late Future<Map<String, dynamic>> data;
  String status = '';
  bool canCreate = false;
  bool canEdit = false;
  bool generating = false;
  String? generateError;
  @override
  void initState() {
    super.initState();
    data = api.workOrders(
      status: status,
      portalSchedule: widget.portalSchedule,
    );
    api
        .workOrderActions(portalSchedule: widget.portalSchedule)
        .then((value) {
          if (mounted) {
            setState(() {
              canCreate = value['create'] == true;
              canEdit = value['edit'] == true;
            });
          }
        })
        .catchError((Object _) {
          // Keep mutation actions hidden if permissions cannot be loaded.
        });
  }

  void refresh() => setState(() {
    data = api.workOrders(
      status: status,
      portalSchedule: widget.portalSchedule,
    );
  });
  Future<void> open(Map row) async {
    final id = (row['pmWorkOrderId'] as num).toInt();
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PmWorkDialog(
        api,
        id,
        portalSchedule: widget.portalSchedule,
        canEdit: canEdit,
      ),
    );
    if (changed == true) refresh();
  }

  @override
  Widget build(BuildContext c) => SupportWorkspaceShell(
    pageTitle: widget.pageTitle,
    activeMenu: widget.routeName,
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'สถานะ'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                    DropdownMenuItem(
                      value: 'PENDING',
                      child: Text('รอดำเนินการ'),
                    ),
                    DropdownMenuItem(
                      value: 'IN_PROGRESS',
                      child: Text('กำลังดำเนินการ'),
                    ),
                    DropdownMenuItem(
                      value: 'COMPLETED',
                      child: Text('เสร็จสิ้น'),
                    ),
                    DropdownMenuItem(value: 'SKIPPED', child: Text('ข้าม')),
                  ],
                  onChanged: (value) {
                    status = value ?? '';
                    refresh();
                  },
                ),
              ),
              if (canCreate)
                FilledButton.icon(
                  onPressed: generating
                      ? null
                      : () async {
                          setState(() {
                            generating = true;
                            generateError = null;
                          });
                          try {
                            await api.generate(
                              portalSchedule: widget.portalSchedule,
                            );
                            if (mounted) refresh();
                          } catch (error) {
                            if (mounted) {
                              setState(
                                () =>
                                    generateError = _pmErrorDescription(error),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => generating = false);
                          }
                        },
                  icon: const Icon(Icons.event_available),
                  label: const Text('สร้างงานตามรอบ'),
                ),
            ],
          ),
          if (generateError != null)
            Text(
              'ไม่สามารถสร้างงานตามรอบได้\nรายละเอียดเพิ่มเติม: $generateError',
              style: TextStyle(color: Theme.of(c).colorScheme.error),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: data,
              builder: (c, s) {
                if (s.hasError) {
                  return _PmLoadError(onRetry: refresh);
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = ((s.data!['items'] as List?) ?? []).cast<Map>();
                if (rows.isEmpty) {
                  return const Center(child: Text('ยังไม่มีงาน PM'));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return Card(
                      child: ListTile(
                        onTap: () => open(r),
                        leading: const Icon(Icons.build_circle_outlined),
                        title: Text(r['planNameSnapshot']?.toString() ?? '-'),
                        subtitle: Text(
                          '${r['itemSnapshot'] ?? '-'}\n${r['locationSnapshot'] ?? '-'}${r['residentNames'] == null ? '' : '\nผู้พักอาศัย: ${r['residentNames']}'}\nกำหนด ${r['dueDate'] ?? '-'}',
                        ),
                        isThreeLine: true,
                        trailing: Text(r['statusCode']?.toString() ?? '-'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _PmWorkDialog extends StatefulWidget {
  const _PmWorkDialog(
    this.api,
    this.id, {
    this.portalSchedule = false,
    required this.canEdit,
  });
  final PmApi api;
  final int id;
  final bool portalSchedule;
  final bool canEdit;
  @override
  State<_PmWorkDialog> createState() => _PmWorkDialogState();
}

class _PmWorkDialogState extends State<_PmWorkDialog> {
  late Future<Map<String, dynamic>> data;
  final result = TextEditingController();
  bool saving = false;
  String? actionError;
  @override
  void initState() {
    super.initState();
    data = widget.api.workOrder(
      widget.id,
      portalSchedule: widget.portalSchedule,
    );
  }

  Future<void> action(String value) async {
    if (value != 'start' && result.text.trim().isEmpty) {
      setState(
        () => actionError = value == 'skip'
            ? 'กรุณาระบุเหตุผลการข้ามงานก่อนบันทึก'
            : 'กรุณาระบุผลการตรวจก่อนปิดงาน',
      );
      return;
    }
    setState(() {
      saving = true;
      actionError = null;
    });
    try {
      await widget.api.action(
        widget.id,
        value,
        value == 'start' ? null : result.text.trim(),
        widget.portalSchedule,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          saving = false;
          actionError =
              'ไม่สามารถบันทึกงาน PM ได้\nรายละเอียดเพิ่มเติม: ${_pmErrorDescription(error)}';
        });
      }
    }
  }

  @override
  void dispose() {
    result.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('รายละเอียดงาน PM'),
    content: SizedBox(
      width: 620,
      child: FutureBuilder<Map<String, dynamic>>(
        future: data,
        builder: (c, s) {
          if (s.hasError) {
            return SizedBox(
              height: 120,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ไม่สามารถโหลดรายละเอียดงาน PM ได้'),
                  Text('รายละเอียดเพิ่มเติม: ${_pmErrorDescription(s.error!)}'),
                  TextButton(
                    onPressed: () => setState(() {
                      data = widget.api.workOrder(
                        widget.id,
                        portalSchedule: widget.portalSchedule,
                      );
                    }),
                    child: const Text('ลองอีกครั้ง'),
                  ),
                ],
              ),
            );
          }
          if (!s.hasData) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final work = Map<String, dynamic>.from(s.data!['workOrder'] as Map);
          final checks = ((s.data!['checks'] as List?) ?? []).cast<Map>();
          final status = work['statusCode']?.toString() ?? '';
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (actionError != null) ...[
                  Text(
                    actionError!,
                    style: TextStyle(color: Theme.of(c).colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  work['planNameSnapshot']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(work['itemSnapshot']?.toString() ?? '-'),
                Text(work['locationSnapshot']?.toString() ?? '-'),
                if (work['residentNames'] != null)
                  Text('ผู้พักอาศัย: ${work['residentNames']}'),
                Text('กำหนด: ${work['dueDate'] ?? '-'}'),
                const Divider(),
                ...checks.map(
                  (x) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: x['isChecked'] == true,
                    onChanged:
                        widget.canEdit && !saving && status == 'IN_PROGRESS'
                        ? (v) async {
                            setState(() {
                              saving = true;
                              actionError = null;
                            });
                            try {
                              await widget.api.saveChecks(
                                widget.id,
                                checks
                                    .map(
                                      (e) => {
                                        'pmWorkOrderCheckId':
                                            e['pmWorkOrderCheckId'],
                                        'isChecked': identical(e, x)
                                            ? v == true
                                            : e['isChecked'] == true,
                                        'resultNote': e['resultNote'],
                                      },
                                    )
                                    .toList(),
                                portalSchedule: widget.portalSchedule,
                              );
                              if (mounted) {
                                setState(() => x['isChecked'] = v == true);
                              }
                            } catch (error) {
                              if (mounted) {
                                setState(
                                  () => actionError =
                                      'ไม่สามารถบันทึกรายการตรวจได้\nรายละเอียดเพิ่มเติม: ${_pmErrorDescription(error)}',
                                );
                              }
                            } finally {
                              if (mounted) setState(() => saving = false);
                            }
                          }
                        : null,
                    title: Text(x['checkItemSnapshot']?.toString() ?? '-'),
                  ),
                ),
                if (status == 'IN_PROGRESS' || status == 'PENDING')
                  TextField(
                    controller: result,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: status == 'PENDING'
                          ? 'เหตุผลการข้ามงาน (กรอกเมื่อข้าม)'
                          : 'ผลการตรวจ *',
                    ),
                  ),
                if (status == 'COMPLETED' && work['resultDetail'] != null)
                  Text('ผลการตรวจ: ${work['resultDetail']}'),
                if (status == 'SKIPPED' && work['skipReason'] != null)
                  Text('เหตุผลการข้าม: ${work['skipReason']}'),
              ],
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(c),
        child: const Text('ปิด'),
      ),
      FutureBuilder<Map<String, dynamic>>(
        future: data,
        builder: (c, s) {
          if (!widget.canEdit || !s.hasData) return const SizedBox();
          final st = (s.data!['workOrder'] as Map)['statusCode'];
          if (st == 'PENDING') {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: saving ? null : () => action('skip'),
                  child: const Text('ข้ามงาน'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: saving ? null : () => action('start'),
                  child: const Text('เริ่มงาน'),
                ),
              ],
            );
          }
          if (st == 'IN_PROGRESS') {
            return FilledButton(
              onPressed: saving ? null : () => action('complete'),
              child: const Text('บันทึกปิดงาน'),
            );
          }
          return const SizedBox();
        },
      ),
    ],
  );
}

class _Rows extends StatelessWidget {
  const _Rows({
    required this.future,
    required this.name,
    required this.onRetry,
    this.onEdit,
    this.onDelete,
  });
  final Future<Map<String, dynamic>> future;
  final String name;
  final VoidCallback onRetry;
  final void Function(Map row)? onEdit;
  final void Function(Map row)? onDelete;
  @override
  Widget build(BuildContext c) => FutureBuilder<Map<String, dynamic>>(
    future: future,
    builder: (c, s) {
      if (s.hasError) return _PmLoadError(onRetry: onRetry);
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final rows = ((s.data!['items'] as List?) ?? []).cast<Map>();
      if (rows.isEmpty) return const Center(child: Text('ยังไม่มีข้อมูล'));
      return ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = rows[i];
          return Card(
            child: ListTile(
              onTap: onEdit == null ? null : () => onEdit!(r),
              leading: const Icon(Icons.build_circle_outlined),
              title: Text(r[name]?.toString() ?? '-'),
              subtitle: Text(
                r['itemTypeCode']?.toString() ??
                    r['locationSnapshot']?.toString() ??
                    '',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r['statusCode']?.toString() ??
                        (r['isActive'] == false ? 'ปิด' : 'ใช้งาน'),
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'แก้ไข Checklist',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEdit!(r),
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'ลบ Checklist',
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(c).colorScheme.error,
                      ),
                      onPressed: () => onDelete!(r),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _PmLoadError extends StatelessWidget {
  const _PmLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: LaooLayout.cardSpacing),
            const Text('ไม่สามารถโหลดข้อมูลได้'),
            const SizedBox(height: LaooLayout.cardSpacing),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AssetAssignmentDialog extends StatefulWidget {
  const _AssetAssignmentDialog(this.api, this.plan);
  final PmApi api;
  final Map plan;
  @override
  State<_AssetAssignmentDialog> createState() => _AssetAssignmentDialogState();
}

class _PlanChecklistDialog extends StatefulWidget {
  const _PlanChecklistDialog(this.api, this.plan);
  final PmApi api;
  final Map plan;
  @override
  State<_PlanChecklistDialog> createState() => _PlanChecklistDialogState();
}

class _PlanChecklistDialogState extends State<_PlanChecklistDialog> {
  late Future<Map<String, dynamic>> all;
  final ids = <int>{};
  @override
  void initState() {
    super.initState();
    all = widget.api.checklists;
    widget.api.planChecklists((widget.plan['pmPlanId'] as num).toInt()).then((
      x,
    ) {
      for (final r in ((x['items'] as List?) ?? []).cast<Map>()) {
        ids.add((r['pmChecklistId'] as num).toInt());
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> save() async {
    await widget.api.setPlanChecklists(
      (widget.plan['pmPlanId'] as num).toInt(),
      ids.toList(),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('ผูก Checklist กับแผน PM'),
    content: SizedBox(
      width: 560,
      child: FutureBuilder<Map<String, dynamic>>(
        future: all,
        builder: (c, s) {
          if (!s.hasData) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final rows = ((s.data!['items'] as List?) ?? []).cast<Map>();
          return SingleChildScrollView(
            child: Column(
              children: rows.map((r) {
                final id = (r['pmChecklistId'] as num).toInt();
                return CheckboxListTile(
                  value: ids.contains(id),
                  onChanged: (v) =>
                      setState(() => v == true ? ids.add(id) : ids.remove(id)),
                  title: Text(r['checklistName']?.toString() ?? '-'),
                  subtitle: Text('${r['itemCount'] ?? 0} รายการตรวจ'),
                );
              }).toList(),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(onPressed: save, child: const Text('บันทึก Checklist')),
    ],
  );
}

class _AssetAssignmentDialogState extends State<_AssetAssignmentDialog> {
  late Future<Map<String, dynamic>> candidates;
  late Future<Map<String, dynamic>> assigned;
  final ids = <int>{};
  @override
  void initState() {
    super.initState();
    candidates = widget.api.assets(widget.plan['itemTypeCode'].toString());
    assigned = widget.api.planAssets((widget.plan['pmPlanId'] as num).toInt());
    assigned.then((x) {
      for (final a in ((x['items'] as List?) ?? []).cast<Map>()) {
        if (a['isActive'] == true) {
          ids.add((a['itemInstanceId'] as num).toInt());
        }
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> save() async {
    await widget.api.setPlanAssets(
      (widget.plan['pmPlanId'] as num).toInt(),
      ids.toList(),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: Text('ผูก Asset: ${widget.plan['planName']}'),
    content: SizedBox(
      width: 700,
      child: FutureBuilder<Map<String, dynamic>>(
        future: candidates,
        builder: (c, s) {
          if (!s.hasData) {
            return const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final rows = ((s.data!['items'] as List?) ?? []).cast<Map>();
          return SingleChildScrollView(
            child: Column(
              children: rows.map((a) {
                final id = (a['itemInstanceId'] as num).toInt();
                return CheckboxListTile(
                  value: ids.contains(id),
                  onChanged: (v) =>
                      setState(() => v == true ? ids.add(id) : ids.remove(id)),
                  title: Text(
                    '${a['itemName'] ?? '-'} / ${a['serialNo'] ?? '-'}',
                  ),
                  subtitle: Text(a['locationSnapshot']?.toString() ?? '-'),
                );
              }).toList(),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(onPressed: save, child: const Text('บันทึก Asset')),
    ],
  );
}

class _NewPlanDialog extends StatefulWidget {
  const _NewPlanDialog(this.api, {this.plan});
  final PmApi api;
  final Map? plan;
  @override
  State<_NewPlanDialog> createState() => _NewPlanDialogState();
}

class _NewPlanDialogState extends State<_NewPlanDialog> {
  final n = TextEditingController();
  final interval = TextEditingController(text: '1');
  String? t;
  String u = 'MONTH';
  int v = 1;
  bool active = true;
  late Future<Map<String, dynamic>> types;
  bool saving = false;
  String? formError;
  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    if (plan != null) {
      n.text = plan['planName']?.toString() ?? '';
      t = plan['itemTypeCode']?.toString();
      u = plan['intervalUnit']?.toString() ?? 'MONTH';
      v = (plan['intervalValue'] as num?)?.toInt() ?? 1;
      interval.text = '$v';
      active = plan['isActive'] == true;
    }
    types = widget.api.types;
  }

  Future<void> save() async {
    if (n.text.trim().isEmpty || t == null || v < 1) {
      setState(
        () =>
            formError = 'กรุณาระบุชื่อแผน ประเภทอุปกรณ์ และรอบเวลาที่มากกว่า 0',
      );
      return;
    }
    setState(() {
      saving = true;
      formError = null;
    });
    try {
      await widget.api.savePlan({
        'planName': n.text.trim(),
        'itemTypeCode': t,
        'intervalUnit': u,
        'intervalValue': v,
        'startDate':
            widget.plan?['startDate']?.toString() ??
            DateTime.now().toIso8601String(),
        'isActive': active,
        'itemInstanceIds': <int>[],
      }, id: (widget.plan?['pmPlanId'] as num?)?.toInt());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => formError =
              'ไม่สามารถบันทึกแผน PM ได้\nรายละเอียดเพิ่มเติม: ${_pmErrorDescription(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    n.dispose();
    interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    title: _pmPopupTitle(
      c,
      widget.plan == null ? 'เพิ่มแผน PM' : 'แก้ไขแผน PM',
      widget.plan == null ? Icons.add_circle_outline : Icons.edit_outlined,
    ),
    actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    content: FutureBuilder<Map<String, dynamic>>(
      future: types,
      builder: (c, s) {
        if (s.hasError) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ไม่สามารถโหลดประเภทอุปกรณ์ได้'),
              Text('รายละเอียดเพิ่มเติม: ${_pmErrorDescription(s.error!)}'),
              TextButton(
                onPressed: () => setState(() {
                  types = widget.api.types;
                }),
                child: const Text('ลองอีกครั้ง'),
              ),
            ],
          );
        }
        if (!s.hasData) {
          return const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final x = ((s.data!['items'] as List?) ?? []).cast<Map>();
        final availableTypes = x
            .map((e) => e['itemTypeCode']?.toString())
            .whereType<String>()
            .toSet();
        if (t != null) availableTypes.add(t!);
        return _pmPopupFormTheme(
          c,
          SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('สถานะ'),
                    value: active,
                    onChanged: (value) => setState(() => active = value),
                  ),
                  const SizedBox(height: LaooLayout.popupFieldSpacing),
                  TextField(
                    controller: n,
                    decoration: const InputDecoration(labelText: 'ชื่อแผน *'),
                  ),
                  const SizedBox(height: LaooLayout.popupFieldSpacing),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: t,
                    decoration: const InputDecoration(
                      labelText: 'ประเภทอุปกรณ์ *',
                    ),
                    items: availableTypes
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged:
                        widget.plan != null &&
                            ((widget.plan?['assetCount'] as num?)?.toInt() ??
                                    0) >
                                0
                        ? null
                        : (z) => setState(() => t = z),
                  ),
                  const SizedBox(height: LaooLayout.popupFieldSpacing),
                  DropdownButtonFormField<String>(
                    initialValue: u,
                    items: const [
                      DropdownMenuItem(value: 'DAY', child: Text('วัน')),
                      DropdownMenuItem(value: 'MONTH', child: Text('เดือน')),
                    ],
                    onChanged: (z) => setState(() => u = z ?? 'MONTH'),
                  ),
                  const SizedBox(height: LaooLayout.popupFieldSpacing),
                  TextField(
                    controller: interval,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ทุก N *'),
                    onChanged: (z) => v = int.tryParse(z) ?? 0,
                  ),
                  if (formError != null)
                    Text(
                      formError!,
                      style: TextStyle(color: Theme.of(c).colorScheme.error),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    actions: [
      const SizedBox(
        width: double.infinity,
        child: Divider(color: LaooColors.border),
      ),
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(c),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
      ),
    ],
  );
}

class _NewChecklistDialog extends StatefulWidget {
  const _NewChecklistDialog(this.api, {this.checklist});
  final PmApi api;
  final Map? checklist;
  @override
  State<_NewChecklistDialog> createState() => _NewChecklistDialogState();
}

class _NewChecklistDialogState extends State<_NewChecklistDialog> {
  final n = TextEditingController();
  final lines = <TextEditingController>[TextEditingController()];
  final requiredLines = <bool>[true];
  bool active = true;
  bool loading = false;
  bool saving = false;
  String? loadError;
  String? formError;

  @override
  void initState() {
    super.initState();
    if (widget.checklist != null) {
      n.text = widget.checklist?['checklistName']?.toString() ?? '';
      loadDetails();
    }
  }

  Future<void> loadDetails() async {
    final id = (widget.checklist?['pmChecklistId'] as num?)?.toInt();
    if (id == null) return;
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final details = await widget.api.checklist(id);
      if (!mounted) return;
      final header = Map<String, dynamic>.from(details['checklist'] as Map);
      final items = ((details['items'] as List?) ?? []).cast<Map>();
      setState(() {
        n.text = header['checklistName']?.toString() ?? '';
        active = header['isActive'] == true;
        for (final line in lines) {
          line.dispose();
        }
        lines
          ..clear()
          ..addAll(
            items.map(
              (item) => TextEditingController(
                text: item['checkItem']?.toString() ?? '',
              ),
            ),
          );
        requiredLines
          ..clear()
          ..addAll(items.map((item) => item['isRequired'] == true));
        if (lines.isEmpty) {
          lines.add(TextEditingController());
          requiredLines.add(true);
        }
        loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = _pmErrorDescription(error);
        });
      }
    }
  }

  Future<void> save() async {
    if (n.text.trim().isEmpty ||
        lines.isEmpty ||
        lines.any((line) => line.text.trim().isEmpty)) {
      setState(
        () => formError = 'กรุณาระบุชื่อ Checklist และรายการตรวจให้ครบทุกข้อ',
      );
      return;
    }
    setState(() {
      saving = true;
      formError = null;
    });
    try {
      final body = {
        'checklistName': n.text.trim(),
        'isActive': active,
        'items': [
          for (var index = 0; index < lines.length; index++)
            {
              'text': lines[index].text.trim(),
              'required': requiredLines[index],
            },
        ],
      };
      final id = (widget.checklist?['pmChecklistId'] as num?)?.toInt();
      if (id == null) {
        await widget.api.createChecklist(body);
      } else {
        await widget.api.updateChecklist(id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => formError =
              'ไม่สามารถบันทึก Checklist ได้\nรายละเอียดเพิ่มเติม: ${_pmErrorDescription(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    n.dispose();
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    title: _pmPopupTitle(
      c,
      widget.checklist == null ? 'เพิ่ม Checklist' : 'แก้ไข Checklist',
      widget.checklist == null ? Icons.add_circle_outline : Icons.edit_outlined,
    ),
    actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    content: _pmPopupFormTheme(
      c,
      SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) const CircularProgressIndicator(),
              if (loadError != null) ...[
                const Text('ไม่สามารถโหลด Checklist ได้'),
                Text('รายละเอียดเพิ่มเติม: $loadError'),
                TextButton(
                  onPressed: loadDetails,
                  child: const Text('ลองอีกครั้ง'),
                ),
              ],
              if (!loading && loadError == null) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('สถานะ'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
                const SizedBox(height: LaooLayout.popupFieldSpacing),
                TextField(
                  controller: n,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อ Checklist *',
                  ),
                ),
                for (var index = 0; index < lines.length; index++) ...[
                  const SizedBox(height: LaooLayout.popupFieldSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lines[index],
                          decoration: InputDecoration(
                            labelText: 'รายการตรวจ ${index + 1} *',
                          ),
                        ),
                      ),
                      if (lines.length > 1)
                        IconButton(
                          tooltip: 'ลบรายการตรวจ',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setState(() {
                            lines.removeAt(index).dispose();
                            requiredLines.removeAt(index);
                          }),
                        ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('บังคับตรวจ'),
                    value: requiredLines[index],
                    onChanged: (value) =>
                        setState(() => requiredLines[index] = value == true),
                  ),
                ],
                TextButton.icon(
                  onPressed: () => setState(() {
                    lines.add(TextEditingController());
                    requiredLines.add(true);
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มรายการตรวจ'),
                ),
              ],
              if (formError != null)
                Text(
                  formError!,
                  style: TextStyle(color: Theme.of(c).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      const SizedBox(
        width: double.infinity,
        child: Divider(color: LaooColors.border),
      ),
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(c),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: saving || loading || loadError != null ? null : save,
        child: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
      ),
    ],
  );
}
