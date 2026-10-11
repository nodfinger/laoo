import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'site_form.dart';
import 'site_host.dart';
import 'site_tasks_dialog.dart';

class SiteScreen extends StatefulWidget {
  const SiteScreen({
    super.key,
    required this.menuCode,
    required this.routeName,
  });
  final String menuCode;
  final String routeName;
  @override
  State<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends State<SiteScreen> {
  static const base = '/api/company/site';
  late final api = siteApi();
  Map<String, dynamic> metadata = {}, actions = {}, settings = {};
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic> options = {};
  int page = 1, total = 0;
  bool loading = true, cards = false, busy = false;
  bool canManagePortal = false;
  String? error;
  final search = TextEditingController();
  LaooWorkspaceUiTokens get tokens => siteTokens();
  String get title => metadata['MenuName']?.toString() ?? 'กำลังโหลด';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant SiteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuCode != widget.menuCode) {
      page = 1;
      rows = [];
      load();
    }
  }

  @override
  void dispose() {
    search.dispose();
    siteDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final access = Map<String, dynamic>.from(
        await api.get('$base/actions/${widget.menuCode}') as Map,
      );
      metadata = Map<String, dynamic>.from(access['metadata'] as Map);
      actions = Map<String, dynamic>.from(access['actions'] as Map);
      if (widget.menuCode == '63007') {
        try {
          final projectAccess = Map<String, dynamic>.from(
            await api.get('$base/actions/63002') as Map,
          );
          canManagePortal =
              Map<String, dynamic>.from(
                projectAccess['actions'] as Map,
              )['edit'] ==
              true;
        } catch (_) {
          canManagePortal = false;
        }
      }
      if (actions['view'] != true) throw StateError('ไม่มีสิทธิ์ดูเมนูนี้');
      if (widget.menuCode == '63001') {
        settings = Map<String, dynamic>.from(
          await api.get('$base/settings') as Map,
        );
        rows = [settings];
        total = 1;
      } else {
        final path = switch (widget.menuCode) {
          '63002' => '$base/projects',
          '63003' => '$base/reports',
          '63004' => '$base/publications',
          '63005' => '$base/issues',
          '63006' => '$base/handovers',
          '63007' => '/api/site/customer/access',
          _ => '$base/dashboard',
        };
        final query = <String, String>{};
        if (widget.menuCode != '63007' && widget.menuCode != '63008') {
          query.addAll({'page': '$page', 'pageSize': '20'});
        }
        if (widget.menuCode == '63002' && search.text.trim().isNotEmpty) {
          query['search'] = search.text.trim();
        }
        final data = Map<String, dynamic>.from(
          await api.get(path, query: query) as Map,
        );
        rows = (data['items'] as List? ?? [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        total = (data['total'] as num?)?.toInt() ?? 0;
      }
      if (mounted) setState(() => loading = false);
    } catch (exception) {
      if (mounted) {
        setState(() {
          loading = false;
          error = siteErrorText(exception, 'โหลดข้อมูลไซต์งาน');
        });
      }
    }
  }

  Future<void> openForm([Map<String, dynamic>? row]) async {
    try {
      if (options.isEmpty && widget.menuCode != '63001') {
        options = Map<String, dynamic>.from(
          await api.get('$base/options') as Map,
        );
        final projects = Map<String, dynamic>.from(
          await api.get(
                '$base/projects',
                query: {'page': '1', 'pageSize': '100'},
              )
              as Map,
        );
        options['projects'] = projects['items'] as List? ?? [];
        if (widget.menuCode == '63003') {
          final setting = Map<String, dynamic>.from(
            await api.get('$base/settings') as Map,
          );
          options['allowOfflineDraft'] = setting['allowOfflineDraft'];
        }
      }
      var item = row;
      if (widget.menuCode == '63003' && row != null) {
        final detail = Map<String, dynamic>.from(
          await api.get('$base/reports/${row['id']}') as Map,
        );
        item = Map<String, dynamic>.from(detail['report'] as Map);
        item['lines'] = detail['lines'];
        item['photos'] = detail['photos'];
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SiteForm(
          menuCode: widget.menuCode,
          title: title,
          icon: siteMenuIcon(metadata['IconName']?.toString()),
          row: item,
          options: options,
          api: api,
          onSaved: load,
        ),
      );
    } catch (exception) {
      if (mounted) {
        siteMessage(
          context,
          message: siteErrorText(exception, 'เปิดแบบฟอร์ม'),
          error: true,
        );
      }
    }
  }

  Future<void> act(String path, String label, {Object? body}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await api.post(path, body: body);
      if (mounted) siteMessage(context, message: '$labelสำเร็จ', error: false);
      await load();
    } catch (exception) {
      if (mounted) {
        siteMessage(
          context,
          message: siteErrorText(exception, label),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteRow(Map<String, dynamic> row) async {
    if (busy) return;
    final isIssue = widget.menuCode == '63005';
    final label = isIssue ? 'ปิดปัญหา' : 'ยกเลิกโครงการ';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => LaooActionDialog(
        tokens: tokens,
        icon: Icons.delete_outline,
        title: '$title > $label',
        content: Text(
          '${heading(row)}\n${isIssue ? 'ต้องแก้ไขปัญหาให้เสร็จก่อนปิด' : 'ยกเลิกได้เฉพาะโครงการที่ยังไม่มีรายงานหรือส่งมอบ'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialog, true),
            icon: const Icon(Icons.delete_outline),
            label: Text(label),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await api.delete('$base/${isIssue ? 'issues' : 'projects'}/${row['id']}');
      if (mounted) siteMessage(context, message: '$labelสำเร็จ', error: false);
      await load();
    } catch (error) {
      if (mounted) {
        siteMessage(context, message: siteErrorText(error, label), error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String value(Map<String, dynamic> row, String key) => '${row[key] ?? '—'}';
  Future<void> portalAccount([Map<String, dynamic>? existing]) async {
    try {
      final data = Map<String, dynamic>.from(
        await api.get('$base/projects', query: {'page': '1', 'pageSize': '100'})
            as Map,
      );
      final projects = (data['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      final email = TextEditingController(), password = TextEditingController();
      int? selected;
      bool saving = false;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(
          builder: (context, update) => LaooActionDialog(
            tokens: tokens,
            icon: Icons.account_circle_outlined,
            title:
                '$title > ${existing == null ? 'เพิ่มบัญชี' : 'เพิ่มสิทธิ์โครงการ'}',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'โครงการ *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final p in projects)
                      DropdownMenuItem(
                        value: (p['id'] as num).toInt(),
                        child: Text(
                          '${p['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => update(() => selected = v),
                ),
                if (existing == null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'อีเมลลูกค้า *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'รหัสผ่านเริ่มต้น *',
                      border: OutlineInputBorder(),
                      helperText:
                          'อย่างน้อย 12 ตัว มีพิมพ์ใหญ่ พิมพ์เล็ก ตัวเลข และสัญลักษณ์',
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: saving ? null : () => Navigator.pop(dialog),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (selected == null) {
                          siteMessage(
                            context,
                            message: 'กรุณาเลือกโครงการ',
                            error: true,
                          );
                          return;
                        }
                        if (existing == null &&
                            (email.text.trim().isEmpty ||
                                password.text.isEmpty)) {
                          siteMessage(
                            context,
                            message: 'กรุณากรอกอีเมลและรหัสผ่าน',
                            error: true,
                          );
                          return;
                        }
                        update(() => saving = true);
                        try {
                          if (existing == null) {
                            await api.post(
                              '/api/site/customer/accounts',
                              body: {
                                'projectId': selected,
                                'email': email.text.trim(),
                                'password': password.text,
                              },
                            );
                          } else {
                            await api.post(
                              '/api/site/customer/access',
                              body: {
                                'projectId': selected,
                                'customerAccountId': existing['accountId'],
                              },
                            );
                          }
                          if (dialog.mounted) Navigator.pop(dialog);
                          if (mounted) {
                            siteMessage(
                              this.context,
                              message: 'บันทึกสิทธิ์ลูกค้าแล้ว',
                              error: false,
                            );
                            await load();
                          }
                        } catch (error) {
                          if (dialog.mounted) {
                            siteMessage(
                              dialog,
                              message: siteErrorText(error, 'บันทึกสิทธิ์'),
                              error: true,
                            );
                          }
                        } finally {
                          if (dialog.mounted) update(() => saving = false);
                        }
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(saving ? 'กำลังบันทึก' : 'บันทึก'),
              ),
            ],
          ),
        ),
      );
      email.dispose();
      password.dispose();
    } catch (error) {
      if (mounted) {
        siteMessage(
          context,
          message: siteErrorText(error, 'เปิดบัญชีลูกค้า'),
          error: true,
        );
      }
    }
  }

  String heading(Map<String, dynamic> row) => switch (widget.menuCode) {
    '63002' => value(row, 'name'),
    '63003' => value(row, 'summary'),
    '63004' => value(row, 'summary'),
    '63005' => value(row, 'title'),
    '63006' => value(row, 'stageName'),
    '63007' => value(row, 'email'),
    '63008' => value(row, 'name'),
    _ => title,
  };
  String subtitle(Map<String, dynamic> row) => switch (widget.menuCode) {
    '63002' => '${value(row, 'code')} · ${value(row, 'customerName')}',
    '63003' ||
    '63004' => '${value(row, 'projectName')} · ${value(row, 'workDate')}',
    '63005' || '63006' => value(row, 'projectName'),
    '63007' => value(row, 'projectName'),
    '63008' => 'ความคืบหน้า ${row['progressPercent'] ?? 0}%',
    _ => '',
  };
  String status(Map<String, dynamic> row) =>
      '${row['status'] ?? (widget.menuCode == '63007' ? (row['active'] == true ? 'ใช้งาน' : 'ปิด') : '—')}';

  List<Widget> rowActions(Map<String, dynamic> row) {
    final id = row['id'];
    return [
      if (widget.menuCode == '63002' && actions['edit'] == true)
        IconButton(
          tooltip: 'งานย่อยและความคืบหน้า',
          onPressed: busy
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      SiteTasksDialog(project: row, api: api, title: title),
                ).then((_) => load()),
          icon: const Icon(Icons.rule_folder_outlined),
        ),
      if (widget.menuCode == '63001' && actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: busy ? null : () => openForm(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if ({'63002', '63003', '63005', '63006'}.contains(widget.menuCode) &&
          actions['edit'] == true &&
          (row['status'] == 'DRAFT' ||
              row['status'] == 'RETURNED' ||
              row['status'] == 'ACTIVE' ||
              widget.menuCode == '63005'))
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: busy ? null : () => openForm(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (widget.menuCode == '63003' &&
          actions['submit'] == true &&
          row['status'] == 'DRAFT')
        IconButton(
          tooltip: 'ส่งตรวจ',
          onPressed: busy
              ? null
              : () => act('$base/reports/$id/submit', 'ส่งตรวจ'),
          icon: const Icon(Icons.send_outlined),
        ),
      if (widget.menuCode == '63004' &&
          row['status'] == 'SUBMITTED' &&
          actions['review'] == true)
        IconButton(
          tooltip: 'ผ่านการตรวจ',
          onPressed: busy
              ? null
              : () => act(
                  '$base/publications/$id/review',
                  'ตรวจผ่าน',
                  body: {'return': false},
                ),
          icon: const Icon(Icons.check_circle_outline),
        ),
      if (widget.menuCode == '63004' &&
          row['status'] == 'SUBMITTED' &&
          actions['return'] == true)
        IconButton(
          tooltip: 'ส่งกลับ',
          onPressed: busy ? null : () => _returnReport(id),
          icon: const Icon(Icons.undo_outlined),
        ),
      if (widget.menuCode == '63004' &&
          row['status'] == 'REVIEWED' &&
          actions['publish'] == true)
        IconButton(
          tooltip: 'เลือกเผยแพร่',
          onPressed: busy ? null : () => _publish(id),
          icon: const Icon(Icons.public_outlined),
        ),
      if (widget.menuCode == '63006' &&
          row['status'] == 'DRAFT' &&
          actions['submit'] == true)
        IconButton(
          tooltip: 'ส่งมอบ',
          onPressed: busy
              ? null
              : () => act('$base/handovers/$id/submit', 'ส่งมอบ'),
          icon: const Icon(Icons.send_outlined),
        ),
      if (widget.menuCode == '63007' && canManagePortal)
        IconButton(
          tooltip: 'เพิ่มสิทธิ์โครงการ',
          onPressed: busy ? null : () => portalAccount(row),
          icon: const Icon(Icons.add_link_outlined),
        ),
      if (actions['delete'] == true &&
          ((widget.menuCode == '63002' && row['status'] == 'ACTIVE') ||
              (widget.menuCode == '63005' && row['status'] == 'RESOLVED')))
        IconButton(
          tooltip: widget.menuCode == '63005' ? 'ปิดปัญหา' : 'ยกเลิกโครงการ',
          onPressed: busy ? null : () => deleteRow(row),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
    ];
  }

  Future<void> _returnReport(Object? id) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => LaooActionDialog(
        tokens: tokens,
        icon: Icons.undo_outlined,
        title: '$title > ส่งกลับ',
        content: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'เหตุผล *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('ส่งกลับ'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed == true && text.isNotEmpty) {
      await act(
        '$base/publications/$id/review',
        'ส่งกลับ',
        body: {'return': true, 'reason': text},
      );
    }
  }

  Future<void> _publish(Object? id) async {
    var workers = true, materials = true, problems = false, photos = true;
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => LaooActionDialog(
          tokens: tokens,
          icon: Icons.public_outlined,
          title: '$title > เผยแพร่',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('รายชื่อคนงาน'),
                value: workers,
                onChanged: (v) => update(() => workers = v ?? false),
              ),
              CheckboxListTile(
                title: const Text('วัสดุ'),
                value: materials,
                onChanged: (v) => update(() => materials = v ?? false),
              ),
              CheckboxListTile(
                title: const Text('ปัญหา'),
                value: problems,
                onChanged: (v) => update(() => problems = v ?? false),
              ),
              CheckboxListTile(
                title: const Text('รูปภาพ'),
                value: photos,
                onChanged: (v) => update(() => photos = v ?? false),
              ),
              const Text('ค่าใช้จ่ายภายในจะไม่เผยแพร่'),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, {
                'includeWorkers': workers,
                'includeMaterials': materials,
                'includeProblems': problems,
                'includePhotos': photos,
              }),
              child: const Text('เผยแพร่'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await act('$base/publications/$id/publish', 'เผยแพร่', body: result);
    }
  }

  Widget content(bool compact) {
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
            const SizedBox(height: 10),
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
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('ยังไม่มีข้อมูล')),
        ),
      );
    }
    if (compact || cards) {
      return Column(
        children: [
          for (final row in rows)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.itemSpacing),
              child: LaooSurfaceCard(
                tokens: tokens,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heading(row),
                      style: tokens.sectionStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle(row),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(status(row)),
                    if (rowActions(row).isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(children: rowActions(row)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return LaooSurfaceCard(
      tokens: tokens,
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('รายการ')),
            DataColumn(label: Text('รายละเอียด')),
            DataColumn(label: Text('สถานะ')),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  DataCell(Text(value(row, 'id'))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: rowActions(row),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 260,
                      child: Text(
                        heading(row),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 260,
                      child: Text(
                        subtitle(row),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(status(row))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => siteShell(
    pageTitle: title,
    activeMenu: widget.routeName,
    child: ColoredBox(
      color: tokens.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < tokens.compactBreakpoint;
          return SingleChildScrollView(
            padding: tokens.contentMargin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LaooCaptionCard(
                  tokens: tokens,
                  caption: title,
                  favoriteKey: widget.routeName,
                  leading: Icon(
                    siteMenuIcon(metadata['IconName']?.toString()),
                    color: tokens.primaryColor,
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      if (!compact &&
                          widget.menuCode != '63001' &&
                          widget.menuCode != '63008')
                        LaooListCardToggle(
                          tokens: tokens,
                          cards: cards,
                          onChanged: (v) => setState(() => cards = v),
                        ),
                      if (actions['create'] == true &&
                          {
                            '63002',
                            '63003',
                            '63005',
                            '63006',
                          }.contains(widget.menuCode))
                        FilledButton.icon(
                          onPressed: loading || busy ? null : () => openForm(),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่ม'),
                        ),
                      if (widget.menuCode == '63007' && canManagePortal)
                        FilledButton.icon(
                          onPressed: loading || busy
                              ? null
                              : () => portalAccount(),
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('เพิ่มบัญชี'),
                        ),
                      if (widget.menuCode == '63001' && actions['edit'] == true)
                        FilledButton.icon(
                          onPressed: loading || busy
                              ? null
                              : () => openForm(rows.first),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('แก้ไข'),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: tokens.sectionSpacing),
                if (widget.menuCode == '63002') ...[
                  LaooSurfaceCard(
                    tokens: tokens,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: search,
                            onSubmitted: (_) {
                              page = 1;
                              load();
                            },
                            decoration: const InputDecoration(
                              labelText: 'ค้นหารหัสหรือชื่อโครงการ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            page = 1;
                            load();
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('ค้นหา'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.sectionSpacing),
                ],
                content(compact),
                if (!loading &&
                    error == null &&
                    !{'63001', '63007', '63008'}.contains(widget.menuCode)) ...[
                  SizedBox(height: tokens.sectionSpacing),
                  LaooPaginationCard(
                    tokens: tokens,
                    page: page,
                    pageCount: (total / 20).ceil().clamp(1, 999999),
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
          );
        },
      ),
    ),
  );
}
