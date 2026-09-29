import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'evaluation_feature_host.dart';
import 'evaluation_popup_theme.dart';
import 'evaluation_response_dialog.dart';
import 'evaluation_results_dialog.dart';
import 'evaluation_round_dialog.dart';
import 'evaluation_template_dialog.dart';

ButtonStyle _filterFilledStyle() => FilledButton.styleFrom(
  minimumSize: const Size(0, 40),
  maximumSize: const Size(double.infinity, 40),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(evaluationUiTokens.radius),
  ),
  textStyle: evaluationUiTokens.buttonStyle,
);

ButtonStyle _filterOutlinedStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size(0, 40),
  maximumSize: const Size(double.infinity, 40),
  foregroundColor: evaluationUiTokens.primaryColor,
  side: BorderSide(color: evaluationUiTokens.primaryColor),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(evaluationUiTokens.radius),
  ),
  textStyle: evaluationUiTokens.buttonStyle,
);

class EvaluationListPage extends StatefulWidget {
  const EvaluationListPage({
    super.key,
    required this.menu,
    required this.title,
    required this.path,
  });
  final String menu, title, path;
  @override
  State<EvaluationListPage> createState() => _EvaluationListPageState();
}

class _EvaluationListPageState extends State<EvaluationListPage> {
  late final JsonApiClient _api;
  List<Map<String, dynamic>> _items = [];
  final _search = TextEditingController();
  String _sourceFilter = 'ALL';
  String _roundStatusFilter = 'ALL';
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canSubmit = false;
  bool _canApprove = false;
  String? _error;
  late String _title;
  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _api = createEvaluationApiClient();
    _resolveTitle();
    _load();
  }

  Future<void> _resolveTitle() async {
    final title = await resolveEvaluationMenuTitle(widget.menu, widget.title);
    if (mounted) setState(() => _title = title);
  }

  @override
  void dispose() {
    _search.dispose();
    disposeEvaluationApiClient(_api);
    super.dispose();
  }

  Widget _templateCrud(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = _items
        .where(
          (x) =>
              (_sourceFilter == 'ALL' || x['sourceType'] == _sourceFilter) &&
              (query.isEmpty ||
                  '${x['code']} ${x['name']}'.toLowerCase().contains(query)),
        )
        .toList();
    const size = 10;
    final pages = (filtered.length / size).ceil().clamp(1, 9999);
    if (_page > pages) _page = pages;
    final start = (_page - 1) * size;
    final rows = filtered.skip(start).take(size).toList();
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    Icons.star_border,
                    color: evaluationUiTokens.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_title, style: evaluationUiTokens.captionStyle),
                  ),
                  if (_canCreate)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: Size(100, evaluationUiTokens.buttonHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            evaluationUiTokens.radius,
                          ),
                        ),
                        textStyle: evaluationUiTokens.buttonStyle,
                      ),
                      onPressed: _createTemplate,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: evaluationUiTokens.sectionSpacing),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 40).clamp(
                      0.0,
                      260.0,
                    ),
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) => setState(() => _page = 1),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'ค้นหารหัสหรือชื่อแบบประเมิน',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 40).clamp(
                      0.0,
                      240.0,
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _sourceFilter,
                      decoration: const InputDecoration(labelText: 'ประเภทงาน'),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
                        DropdownMenuItem(
                          value: 'GENERAL',
                          child: Text('ทั่วไป'),
                        ),
                        DropdownMenuItem(
                          value: 'VENDOR',
                          child: Text('Vendor'),
                        ),
                        DropdownMenuItem(
                          value: 'TRAINING_COURSE',
                          child: Text('หลักสูตรอบรม'),
                        ),
                        DropdownMenuItem(
                          value: 'TRAINING_INSTRUCTOR',
                          child: Text('วิทยากร'),
                        ),
                        DropdownMenuItem(
                          value: 'MEETING_ROOM',
                          child: Text('ห้องประชุม'),
                        ),
                        DropdownMenuItem(
                          value: 'SERVICE',
                          child: Text('งานบริการ'),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _sourceFilter = v ?? 'ALL';
                        _page = 1;
                      }),
                    ),
                  ),
                  FilledButton.icon(
                    style: _filterFilledStyle(),
                    onPressed: () => setState(() => _page = 1),
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                  ),
                  OutlinedButton.icon(
                    style: _filterOutlinedStyle(),
                    onPressed: () => setState(() {
                      _search.clear();
                      _sourceFilter = 'ALL';
                      _page = 1;
                    }),
                    icon: const Icon(Icons.clear),
                    label: const Text('ล้าง Filter'),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: evaluationUiTokens.itemSpacing),
          Expanded(
            child: _loading
                ? const Card(
                    margin: EdgeInsets.zero,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                ? Card(
                    margin: EdgeInsets.zero,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ไม่สามารถโหลดข้อมูลได้\n$_error',
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: evaluationUiTokens.itemSpacing),
                          OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.replay_outlined),
                            label: const Text('ลองอีกครั้ง'),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth <
                          evaluationUiTokens.compactBreakpoint) {
                        if (rows.isEmpty) {
                          return const Card(
                            margin: EdgeInsets.zero,
                            child: Center(child: Text('ไม่พบข้อมูล')),
                          );
                        }
                        return ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(height: evaluationUiTokens.itemSpacing),
                          itemBuilder: (context, index) {
                            final x = rows[index];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: evaluationUiTokens.cardPadding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${start + index + 1} · ${x['code'] ?? ''}',
                                      style: evaluationUiTokens.inputStyle
                                          .copyWith(
                                            color:
                                                evaluationUiTokens.primaryColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      '${x['name'] ?? ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: evaluationUiTokens.inputStyle
                                          .copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text('${x['sourceType'] ?? ''}'),
                                    Wrap(
                                      spacing: evaluationUiTokens.itemSpacing,
                                      children: [
                                        IconButton(
                                          tooltip: 'ดู',
                                          onPressed: () => _viewTemplate(x),
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                          ),
                                        ),
                                        if (_canEdit)
                                          IconButton(
                                            tooltip: 'แก้ไข',
                                            onPressed: () => _editTemplate(x),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                        if (_canDelete)
                                          IconButton(
                                            tooltip: 'ลบ',
                                            onPressed: () => _deleteTemplate(x),
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: evaluationUiTokens
                                                  .dangerColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                      if (rows.isEmpty) {
                        return const Card(
                          margin: EdgeInsets.zero,
                          child: Center(child: Text('ไม่พบข้อมูล')),
                        );
                      }
                      return Card(
                        margin: EdgeInsets.zero,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: DataTable(
                              headingRowHeight: 56,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              headingRowColor: WidgetStatePropertyAll(
                                evaluationUiTokens.primaryColor.withValues(
                                  alpha: .10,
                                ),
                              ),
                              headingTextStyle: evaluationUiTokens.inputStyle
                                  .copyWith(
                                    color: evaluationUiTokens.primaryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                              dataTextStyle: evaluationUiTokens.inputStyle,
                              border: TableBorder(
                                horizontalInside: BorderSide(
                                  color: evaluationUiTokens.borderColor,
                                ),
                                bottom: BorderSide(
                                  color: evaluationUiTokens.borderColor,
                                ),
                              ),
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('จัดการ')),
                                DataColumn(label: Text('รหัส')),
                                DataColumn(label: Text('ชื่อแบบประเมิน')),
                                DataColumn(label: Text('ประเภท')),
                              ],
                              rows: rows.indexed.map((e) {
                                final x = e.$2;
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${start + e.$1 + 1}')),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: 'ดู',
                                            onPressed: () => _viewTemplate(x),
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                            ),
                                          ),
                                          if (_canEdit)
                                            IconButton(
                                              tooltip: 'แก้ไข',
                                              onPressed: () => _editTemplate(x),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                          if (_canDelete)
                                            IconButton(
                                              tooltip: 'ลบ',
                                              onPressed: () =>
                                                  _deleteTemplate(x),
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: evaluationUiTokens
                                                    .dangerColor,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text('${x['code'] ?? ''}')),
                                    DataCell(Text('${x['name'] ?? ''}')),
                                    DataCell(Text('${x['sourceType'] ?? ''}')),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: evaluationUiTokens.itemSpacing),
          _EvaluationPaginationCard(
            page: _page,
            pageSize: size,
            total: filtered.length,
            onChanged: (value) => setState(() => _page = value),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _api.get(
        widget.path,
        query: const {'47003', '47006', '47007'}.contains(widget.menu)
            ? {
                'sourceType': _sourceFilter == 'ALL' ? '' : _sourceFilter,
                'status': _roundStatusFilter == 'ALL' ? '' : _roundStatusFilter,
                'page': '$_page',
                'pageSize': '10',
              }
            : null,
      );
      final map = Map<String, dynamic>.from(raw as Map);
      if (mounted) {
        final permissions = Map<String, dynamic>.from(
          map['permissions'] as Map? ?? {},
        );
        setState(() {
          _items = List<Map<String, dynamic>>.from(
            (map['items'] ?? []) as List,
          );
          _total = (map['total'] as num?)?.toInt() ?? _items.length;
          if (_usesLocalPagination) {
            final pages = (_items.length / 10).ceil().clamp(1, 99999);
            if (_page > pages) _page = pages;
          }
          if (widget.menu == '47002' || widget.menu == '47003') {
            _canCreate = permissions['create'] == true;
            _canEdit = permissions['edit'] == true;
            _canDelete = permissions['delete'] == true;
            _canSubmit = permissions['submit'] == true;
          }
          if (widget.menu == '47004') {
            _canApprove = permissions['approve'] == true;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTemplate() async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EvaluationTemplateDialog(title: _title),
    );
    if (request == null) return;
    try {
      await _api.post('/api/company/evaluations/templates', body: request);
      if (mounted) {
        showEvaluationMessage(context, message: 'เพิ่มแบบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'บันทึกแบบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: รหัสอาจซ้ำ หรือข้อมูลคำถามยังไม่ครบ',
          error: true,
        );
      }
    }
  }

  Future<void> _editTemplate(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final initial = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/templates/$id') as Map,
      );
      if (!mounted) return;
      final request = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            EvaluationTemplateDialog(title: _title, initial: initial),
      );
      if (request == null) return;
      await _api.put('/api/company/evaluations/templates/$id', body: request);
      if (mounted) {
        showEvaluationMessage(context, message: 'แก้ไขแบบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'แก้ไขแบบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบข้อมูลและสิทธิ์ใช้งาน',
          error: true,
        );
      }
    }
  }

  Future<void> _viewTemplate(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final initial = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/templates/$id') as Map,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => EvaluationTemplateDialog(
          title: _title,
          initial: initial,
          readOnly: true,
        ),
      );
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'เปิดรายละเอียดแบบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาลองเปิดรายการอีกครั้ง',
          error: true,
        );
      }
    }
  }

  Future<void> _deleteTemplate(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Theme(
        data: evaluationPopupTheme(context),
        child: AlertDialog(
          backgroundColor: evaluationUiTokens.popupSurfaceColor,
          surfaceTintColor: evaluationUiTokens.popupSurfaceColor,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(evaluationUiTokens.radius),
            side: BorderSide(color: evaluationUiTokens.dangerColor),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: evaluationUiTokens.dangerColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ยืนยันการลบข้อมูล',
                  style: evaluationUiTokens.captionStyle.copyWith(
                    color: evaluationUiTokens.dangerColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: evaluationUiTokens.dangerSurfaceColor,
                child: Text('${item['code'] ?? item['name'] ?? '-'}'),
              ),
              const SizedBox(height: 12),
              const Text('เมื่อลบแล้วจะไม่สามารถเรียกคืนข้อมูลได้'),
              const SizedBox(height: 12),
              Divider(height: 1, color: evaluationUiTokens.borderColor),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: evaluationUiTokens.dangerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    evaluationUiTokens.radius,
                  ),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบ'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete('/api/company/evaluations/templates/$id');
      if (mounted) {
        showEvaluationMessage(context, message: 'ลบแบบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'ลบแบบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: รายการอาจถูกนำไปใช้สร้างรอบประเมินแล้ว',
          error: true,
        );
      }
    }
  }

  Future<void> _createRound() async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EvaluationRoundDialog(title: _title),
    );
    if (request == null) return;
    try {
      await _api.post('/api/company/evaluations/rounds', body: request);
      if (mounted) {
        showEvaluationMessage(context, message: 'บันทึกร่างรอบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'บันทึกรอบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจ Template ผู้ตอบ และช่วงเวลาที่กำหนด',
          error: true,
        );
      }
    }
  }

  Future<void> _editRound(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/rounds/$id') as Map,
      );
      final document = Map<String, dynamic>.from(detail['document'] as Map);
      document['respondents'] = detail['respondents'];
      if (!mounted) return;
      final request = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => EvaluationRoundDialog(title: _title, initial: document),
      );
      if (request == null) return;
      await _api.put('/api/company/evaluations/rounds/$id', body: request);
      if (mounted) {
        showEvaluationMessage(context, message: 'แก้ไขร่างรอบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'แก้ไขรอบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: แก้ไขได้เฉพาะร่างที่ยังไม่ส่งอนุมัติ',
          error: true,
        );
      }
    }
  }

  Future<void> _deleteRound(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Theme(
        data: evaluationPopupTheme(context),
        child: AlertDialog(
          backgroundColor: evaluationUiTokens.popupSurfaceColor,
          surfaceTintColor: evaluationUiTokens.popupSurfaceColor,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(evaluationUiTokens.radius),
            side: BorderSide(color: evaluationUiTokens.dangerColor),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: evaluationUiTokens.dangerColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ยืนยันการลบข้อมูล',
                  style: evaluationUiTokens.captionStyle.copyWith(
                    color: evaluationUiTokens.dangerColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: evaluationUiTokens.dangerSurfaceColor,
                child: Text('${item['roundNo'] ?? item['name']}'),
              ),
              const SizedBox(height: 12),
              const Text('เมื่อลบแล้วจะไม่สามารถเรียกคืนข้อมูลได้'),
              const SizedBox(height: 12),
              Divider(height: 1, color: evaluationUiTokens.borderColor),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: evaluationUiTokens.dangerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    evaluationUiTokens.radius,
                  ),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบ'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete('/api/company/evaluations/rounds/$id');
      if (mounted) {
        showEvaluationMessage(context, message: 'ลบร่างรอบประเมินสำเร็จ');
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'ลบรอบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ลบได้เฉพาะร่างที่ยังไม่ส่งอนุมัติ',
          error: true,
        );
      }
    }
  }

  Future<void> _moveRound(Map<String, dynamic> item, String action) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await _api.put('/api/company/evaluations/rounds/$id/$action');
      if (mounted) {
        showEvaluationMessage(
          context,
          message: action == 'submit'
              ? 'ส่งรอบประเมินเพื่ออนุมัติแล้ว'
              : 'อนุมัติและเผยแพร่รอบประเมินแล้ว',
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'ดำเนินการกับรอบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: สถานะรอบอาจเปลี่ยนแล้ว หรือบัญชีไม่มีสิทธิ์ดำเนินการ',
          error: true,
        );
      }
    }
  }

  Future<void> _approveRound(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final raw = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/rounds/$id') as Map,
      );
      final document = Map<String, dynamic>.from(raw['document'] as Map);
      final respondents = List<Map<String, dynamic>>.from(
        raw['respondents'] as List? ?? [],
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Theme(
          data: evaluationPopupTheme(context),
          child: AlertDialog(
            backgroundColor: evaluationUiTokens.popupSurfaceColor,
            surfaceTintColor: evaluationUiTokens.popupSurfaceColor,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(evaluationUiTokens.radius),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: evaluationUiTokens.primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'อนุมัติและเผยแพร่รอบประเมิน',
                    style: evaluationUiTokens.captionStyle,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${document['roundNo']} | ${document['name']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Template: ${document['templateCode']} | ${document['templateName']}',
                  ),
                  Text('ผู้ตอบ: ${respondents.length} คน'),
                  const SizedBox(height: 12),
                  const Text(
                    'เมื่ออนุมัติแล้ว ระบบจะเปิดรอบประเมินตามช่วงเวลาที่กำหนด และแก้ไขร่างนี้ไม่ได้',
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: evaluationUiTokens.borderColor),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('อนุมัติและเผยแพร่'),
              ),
            ],
          ),
        ),
      );
      if (confirmed == true) await _moveRound(item, 'approve');
    } catch (_) {
      if (mounted) {
        showEvaluationMessage(
          context,
          message:
              'เปิดรายละเอียดรอบประเมินไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาลองเปิดรายการอีกครั้ง',
          error: true,
        );
      }
    }
  }

  Widget _itemAction(Map<String, dynamic> x) => widget.menu == '47002'
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'ดู',
              onPressed: () => _viewTemplate(x),
              icon: const Icon(Icons.visibility_outlined),
            ),
            if (_canEdit)
              IconButton(
                tooltip: 'แก้ไข',
                onPressed: () => _editTemplate(x),
                icon: Icon(Icons.edit_outlined),
              ),
            if (_canDelete)
              IconButton(
                tooltip: 'ลบ',
                onPressed: () => _deleteTemplate(x),
                icon: Icon(
                  Icons.delete_outline,
                  color: evaluationUiTokens.dangerColor,
                ),
              ),
          ],
        )
      : widget.menu == '47003' && x['status'] == 'DRAFT'
      ? Wrap(
          spacing: 2,
          children: [
            if (_canEdit)
              IconButton(
                tooltip: 'แก้ไขร่าง',
                onPressed: () => _editRound(x),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (_canDelete)
              IconButton(
                tooltip: 'ลบร่าง',
                onPressed: () => _deleteRound(x),
                icon: Icon(
                  Icons.delete_outline,
                  color: evaluationUiTokens.dangerColor,
                ),
              ),
            if (_canSubmit)
              TextButton.icon(
                onPressed: () => _moveRound(x, 'submit'),
                icon: const Icon(Icons.send_outlined),
                label: const Text('ส่งอนุมัติ'),
              ),
          ],
        )
      : widget.menu == '47004' &&
            x['status'] == 'PENDING_APPROVAL' &&
            _canApprove
      ? FilledButton.icon(
          onPressed: () => _approveRound(x),
          icon: const Icon(Icons.verified_outlined),
          label: const Text('อนุมัติ'),
        )
      : Text((x['status'] ?? '').toString());

  bool get _usesLocalPagination =>
      widget.menu == '47004' || widget.menu == '47005';

  List<Map<String, dynamic>> get _visibleItems => _usesLocalPagination
      ? _items.skip((_page - 1) * 10).take(10).toList()
      : _items;

  @override
  Widget build(BuildContext context) => buildEvaluationWorkspaceShell(
    pageTitle: _title,
    activeMenu: widget.menu,
    child: widget.menu == '47002'
        ? _templateCrud(context)
        : Padding(
            padding: evaluationUiTokens.contentMargin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: evaluationUiTokens.cardPadding,
                    child: Row(
                      children: [
                        Icon(
                          Icons.star_border,
                          color: evaluationUiTokens.primaryColor,
                        ),
                        SizedBox(width: evaluationUiTokens.itemSpacing),
                        Expanded(
                          child: Text(
                            _title,
                            style: evaluationUiTokens.captionStyle,
                          ),
                        ),
                        if (widget.menu == '47003' && _canCreate)
                          SizedBox(
                            height: evaluationUiTokens.buttonHeight,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: Size(
                                  100,
                                  evaluationUiTokens.buttonHeight,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    evaluationUiTokens.radius,
                                  ),
                                ),
                                textStyle: evaluationUiTokens.buttonStyle,
                              ),
                              onPressed: _loading ? null : _createRound,
                              icon: const Icon(Icons.add),
                              label: const Text('เพิ่ม'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: evaluationUiTokens.sectionSpacing),
                if (const {
                  '47003',
                  '47006',
                  '47007',
                }.contains(widget.menu)) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: evaluationUiTokens.cardPadding,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: (MediaQuery.sizeOf(context).width - 40)
                                .clamp(0.0, 220.0),
                            child: DropdownButtonFormField<String>(
                              initialValue: _sourceFilter,
                              decoration: const InputDecoration(
                                labelText: 'ประเภทงาน',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text('ทั้งหมด'),
                                ),
                                DropdownMenuItem(
                                  value: 'GENERAL',
                                  child: Text('ทั่วไป'),
                                ),
                                DropdownMenuItem(
                                  value: 'VENDOR',
                                  child: Text('Vendor'),
                                ),
                                DropdownMenuItem(
                                  value: 'TRAINING_COURSE',
                                  child: Text('หลักสูตรอบรม'),
                                ),
                                DropdownMenuItem(
                                  value: 'TRAINING_INSTRUCTOR',
                                  child: Text('วิทยากร'),
                                ),
                                DropdownMenuItem(
                                  value: 'MEETING_ROOM',
                                  child: Text('ห้องประชุม'),
                                ),
                                DropdownMenuItem(
                                  value: 'SERVICE',
                                  child: Text('งานบริการ'),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _sourceFilter = v ?? 'ALL';
                                  _page = 1;
                                });
                                _load();
                              },
                            ),
                          ),
                          SizedBox(
                            width: (MediaQuery.sizeOf(context).width - 40)
                                .clamp(0.0, 220.0),
                            child: DropdownButtonFormField<String>(
                              initialValue: _roundStatusFilter,
                              decoration: const InputDecoration(
                                labelText: 'สถานะ',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text('ทั้งหมด'),
                                ),
                                DropdownMenuItem(
                                  value: 'DRAFT',
                                  child: Text('ร่าง'),
                                ),
                                DropdownMenuItem(
                                  value: 'PENDING_APPROVAL',
                                  child: Text('รออนุมัติ'),
                                ),
                                DropdownMenuItem(
                                  value: 'PUBLISHED',
                                  child: Text('เผยแพร่แล้ว'),
                                ),
                                DropdownMenuItem(
                                  value: 'CLOSED',
                                  child: Text('ปิดรอบ'),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _roundStatusFilter = v ?? 'ALL';
                                  _page = 1;
                                });
                                _load();
                              },
                            ),
                          ),
                          FilledButton.icon(
                            style: _filterFilledStyle(),
                            onPressed: _load,
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                          OutlinedButton.icon(
                            style: _filterOutlinedStyle(),
                            onPressed: () {
                              setState(() {
                                _sourceFilter = 'ALL';
                                _roundStatusFilter = 'ALL';
                                _page = 1;
                              });
                              _load();
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('ล้าง Filter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: evaluationUiTokens.itemSpacing),
                ],
                Expanded(
                  child: _loading
                      ? const Card(
                          margin: EdgeInsets.zero,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _error != null
                      ? Card(
                          margin: EdgeInsets.zero,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ไม่สามารถโหลดข้อมูลได้\n$_error',
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(
                                  height: evaluationUiTokens.itemSpacing,
                                ),
                                OutlinedButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.replay_outlined),
                                  label: const Text('ลองอีกครั้ง'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                      ? const Card(
                          margin: EdgeInsets.zero,
                          child: Center(child: Text('ไม่พบรายการ')),
                        )
                      : ListView.separated(
                          itemCount: _visibleItems.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(height: evaluationUiTokens.itemSpacing),
                          itemBuilder: (_, i) {
                            final x = _visibleItems[i];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact =
                                      constraints.maxWidth <
                                      evaluationUiTokens.compactBreakpoint;
                                  final actions = _itemAction(x);
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ListTile(
                                        onTap: widget.menu == '47002'
                                            ? () => _editTemplate(x)
                                            : widget.menu == '47005' &&
                                                  x['roundId'] is num
                                            ? () async {
                                                final saved =
                                                    await showDialog<bool>(
                                                      context: context,
                                                      barrierDismissible: false,
                                                      builder: (_) =>
                                                          EvaluationResponseDialog(
                                                            roundId:
                                                                (x['roundId']
                                                                        as num)
                                                                    .toInt(),
                                                          ),
                                                    );
                                                if (saved == true) _load();
                                              }
                                            : (widget.menu == '47006' ||
                                                      widget.menu == '47007') &&
                                                  x['id'] is num
                                            ? () => showDialog<void>(
                                                context: context,
                                                builder: (_) =>
                                                    EvaluationResultsDialog(
                                                      roundId: (x['id'] as num)
                                                          .toInt(),
                                                    ),
                                              )
                                            : null,
                                        title: Text(
                                          (x['name'] ??
                                                  x['roundNo'] ??
                                                  x['code'] ??
                                                  '-')
                                              .toString(),
                                        ),
                                        subtitle: Text(
                                          (x['sourceType'] ??
                                                  x['referenceTitle'] ??
                                                  '')
                                              .toString(),
                                        ),
                                        trailing: compact ? null : actions,
                                      ),
                                      if (compact)
                                        Padding(
                                          padding:
                                              evaluationUiTokens.cardPadding,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: actions,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: evaluationUiTokens.sectionSpacing,
                  ),
                  child: _EvaluationPaginationCard(
                    page: _page,
                    pageSize: 10,
                    total: _usesLocalPagination ? _items.length : _total,
                    onChanged: (value) {
                      setState(() => _page = value);
                      if (!_usesLocalPagination) _load();
                    },
                  ),
                ),
              ],
            ),
          ),
  );
}

class _EvaluationPaginationCard extends StatelessWidget {
  const _EvaluationPaginationCard({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onChanged,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const buttonSize = 34.0;
    final tokens = evaluationUiTokens;
    final theme = Theme.of(context);
    final pages = total == 0 ? 1 : (total / pageSize).ceil();
    final start = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final end = total == 0 ? 0 : (page * pageSize).clamp(0, total);

    Widget arrow(IconData icon, int target, bool enabled) => SizedBox.square(
      dimension: buttonSize,
      child: OutlinedButton(
        onPressed: enabled ? () => onChanged(target) : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: tokens.primaryColor,
          disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
          side: BorderSide(
            color: enabled ? tokens.primaryColor : tokens.borderColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        ),
        child: Icon(icon, size: 20),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        height: tokens.paginationCardHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              arrow(Icons.chevron_left, page - 1, page > 1),
              const SizedBox(width: 6),
              Semantics(
                label: 'หน้าปัจจุบัน $page',
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.primaryColor,
                    border: Border.all(color: tokens.primaryColor),
                    borderRadius: BorderRadius.circular(tokens.radius),
                  ),
                  child: Text(
                    '$page',
                    style: tokens.buttonStyle.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              arrow(Icons.chevron_right, page + 1, page < pages),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '$start-$end จาก $total',
                  overflow: TextOverflow.ellipsis,
                  style: tokens.inputStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
