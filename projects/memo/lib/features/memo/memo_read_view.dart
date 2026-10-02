// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'memo_feature_host.dart';

class MemoReadView extends StatelessWidget {
  const MemoReadView({
    super.key,
    required this.api,
    required this.menuCode,
    required this.value,
    required this.actions,
    required this.cards,
    required this.onChanged,
  });
  final JsonApiClient api;
  final String menuCode;
  final dynamic value;
  final Map<String, dynamic> actions;
  final bool cards;
  final Future<void> Function() onChanged;
  @override
  Widget build(BuildContext context) {
    if (menuCode == '50009') return _reports(context);
    final items = _list(value);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (items.isEmpty) {
                return LaooTableCard(
                  tokens: memoTokens,
                  child: const Center(child: Text('ยังไม่มีข้อมูล')),
                );
              }
              if (!cards &&
                  constraints.maxWidth >= memoTokens.compactBreakpoint) {
                return _table(context, items);
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: memoTokens.itemSpacing),
                itemBuilder: (context, index) {
                  final x = _map(items[index]);
                  return LaooSurfaceCard(
                    tokens: memoTokens,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_rowIcon, color: memoTokens.primaryColor),
                      title: Text(
                        '${x['subject'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${x['memoNo'] ?? ''}  •  ${_status('${x['status'] ?? ''}')}',
                      ),
                      trailing: Wrap(
                        spacing: 2,
                        children: _rowActions(context, x),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SizedBox(height: memoTokens.sectionSpacing),
        LaooPaginationCard(
          tokens: memoTokens,
          page: 1,
          pageCount: 1,
          pageSize: items.isEmpty ? 20 : items.length,
          total: items.length,
          onPrevious: null,
          onNext: null,
        ),
      ],
    );
  }

  IconData get _rowIcon => menuCode == '50006'
      ? Icons.approval_outlined
      : menuCode == '50007'
      ? Icons.mark_email_unread_outlined
      : Icons.history_outlined;

  List<Widget> _rowActions(BuildContext context, Map<String, dynamic> row) => [
    IconButton(
      tooltip: 'ดูรายละเอียด',
      onPressed: () => _view(context, row),
      icon: const Icon(Icons.visibility_outlined),
    ),
    if (menuCode == '50006' && actions['return'] == true)
      IconButton(
        tooltip: 'ส่งกลับ',
        onPressed: () => _decide(context, row, 'RETURN'),
        icon: const Icon(Icons.undo_outlined),
      ),
    if (menuCode == '50006' && actions['approve'] == true)
      IconButton(
        tooltip: 'อนุมัติ',
        onPressed: () => _decide(context, row, 'APPROVE'),
        icon: const Icon(Icons.check_circle_outline),
      ),
  ];

  Widget _table(BuildContext context, List<dynamic> items) => LaooTableCard(
    tokens: memoTokens,
    child: LaooWorkspaceDataTable(
      tokens: memoTokens,
      columns: const [
        LaooWorkspaceTableColumns.id,
        DataColumn(
          label: Center(child: Text('Action')),
          columnWidth: FixedColumnWidth(100),
        ),
        DataColumn(label: Text('เลขที่ Memo')),
        DataColumn(label: Text('เรื่อง')),
        DataColumn(label: Text('สถานะ')),
      ],
      rows: List<DataRow>.generate(items.length, (index) {
        final row = _map(items[index]);
        return DataRow(
          cells: [
            DataCell(Text('${index + 1}')),
            DataCell(
              Center(
                child: Wrap(spacing: 2, children: _rowActions(context, row)),
              ),
            ),
            DataCell(Text('${row['memoNo'] ?? '-'}')),
            DataCell(
              SizedBox(
                width: 420,
                child: Text(
                  '${row['subject'] ?? ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(Text(_status('${row['status'] ?? ''}'))),
          ],
        );
      }),
    ),
  );

  Widget _reports(BuildContext context) {
    final root = _map(value),
        total = _map(root['totals']),
        types = _list(root['byType']),
        months = _list(root['byMonth']);
    return SingleChildScrollView(
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth < 680 ? c.maxWidth : (c.maxWidth - 24) / 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metric(
                    w,
                    'Memo ทั้งหมด',
                    total['total'],
                    Icons.description_outlined,
                  ),
                  _metric(w, 'ร่าง', total['draft'], Icons.edit_note_outlined),
                  _metric(
                    w,
                    'รออนุมัติ',
                    total['inApproval'],
                    Icons.hourglass_top,
                  ),
                  _metric(
                    w,
                    'แจกจ่ายแล้ว',
                    total['distributed'],
                    Icons.outbox_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          LaooSurfaceCard(
            tokens: memoTokens,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สรุปตามประเภท',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...types.map((e) {
                  final x = _map(e);
                  return ListTile(
                    dense: true,
                    title: Text('${x['name']}'),
                    trailing: Text('${x['value']}'),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LaooSurfaceCard(
            tokens: memoTokens,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สรุปรายเดือน',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ...months.map((e) {
                  final x = _map(e);
                  return ListTile(
                    dense: true,
                    title: Text('${x['name']}'),
                    trailing: Text('${x['value']}'),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(double width, String title, dynamic value, IconData icon) =>
      SizedBox(
        width: width,
        child: LaooSurfaceCard(
          tokens: memoTokens,
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    Text(
                      '${value ?? 0}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  Future<void> _decide(
    BuildContext context,
    Map<String, dynamic> x,
    String action,
  ) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(action == 'APPROVE' ? 'อนุมัติ Memo' : 'ส่งกลับ Memo'),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: action == 'RETURN' ? 'เหตุผล *' : 'หมายเหตุ',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action == 'APPROVE' ? 'อนุมัติ' : 'ส่งกลับ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.post(
        '/api/company/memo/approvals/${x['id']}/decision',
        body: {'action': action, 'note': note.text},
      );
      if (context.mounted)
        memoMessage(
          context,
          action == 'APPROVE' ? 'อนุมัติแล้ว' : 'ส่งกลับแล้ว',
        );
      await onChanged();
    } catch (e) {
      if (context.mounted)
        memoMessage(context, 'ดำเนินการไม่สำเร็จ: $e', error: true);
    } finally {
      note.dispose();
    }
  }

  Future<void> _printPdf(Map<String, dynamic> memo) async {
    final bytes = await rootBundle.load(
      'assets/fonts/NotoSansThai-Variable.ttf',
    );
    final font = pw.Font.ttf(bytes);
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        margin: const pw.EdgeInsets.all(42),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('หน้า ${context.pageNumber} / ${context.pagesCount}'),
        ),
        build: (_) => [
          pw.Text(
            'บันทึกข้อความ',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text('เลขที่  ${memo['memoNo'] ?? '-'}'),
          pw.Text('เรื่อง  ${memo['subject'] ?? ''}'),
          pw.Text('เรียน  ${memo['recipient'] ?? ''}'),
          pw.Divider(),
          pw.Text(
            '${memo['body'] ?? ''}',
            style: const pw.TextStyle(fontSize: 14, lineSpacing: 5),
          ),
          pw.SizedBox(height: 28),
          pw.Text('อนุมัติผ่านระบบอิเล็กทรอนิกส์'),
          ..._list(memo['approvals']).map((raw) {
            final step = _map(raw);
            return pw.Text(
              'ขั้น ${step['stepOrder']}  ${step['name'] ?? ''}  ${_status('${step['status']}')}',
            );
          }),
        ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: '${memo['memoNo'] ?? 'memo'}.pdf',
    );
  }

  Future<void> _view(BuildContext context, Map<String, dynamic> x) async {
    try {
      final raw = await api.get('/api/company/memo/documents/${x['id']}');
      final d = _map(raw);
      if (context.mounted)
        await showDialog<void>(
          context: context,
          builder: (c) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          color: Theme.of(c).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${d['memoNo'] ?? d['temporaryNo']} > ดู',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${d['subject']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('เรียน  ${d['recipient']}'),
                          const SizedBox(height: 24),
                          SelectableText(
                            '${d['body']}',
                            style: const TextStyle(fontSize: 14, height: 1.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (['APPROVED', 'DISTRIBUTED'].contains(d['status']))
                            OutlinedButton.icon(
                              onPressed: () => _printPdf(d),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('พิมพ์ PDF'),
                            ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('ปิด'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    } catch (e) {
      if (context.mounted)
        memoMessage(context, 'เปิด Memo ไม่สำเร็จ: $e', error: true);
    }
  }
}

Map<String, dynamic> _map(dynamic v) => v is Map<String, dynamic>
    ? v
    : v is Map
    ? v.map((k, v) => MapEntry('$k', v))
    : <String, dynamic>{};
List<dynamic> _list(dynamic v) => v is List ? v : <dynamic>[];
String _status(String s) =>
    const {
      'PENDING': 'รอพิจารณา',
      'APPROVED': 'อนุมัติแล้ว',
      'RETURNED': 'ส่งกลับ',
      'DISTRIBUTED': 'แจกจ่ายแล้ว',
    }[s] ??
    s;
