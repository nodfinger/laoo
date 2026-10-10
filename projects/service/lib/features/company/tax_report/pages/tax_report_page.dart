import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../services/tax_report_pdf_service.dart';
import '../services/tax_report_xlsx_service.dart';

class TaxReportPage extends StatefulWidget {
  const TaxReportPage({required this.sales, super.key});
  final bool sales;
  @override
  State<TaxReportPage> createState() => _TaxReportPageState();
}

class _TaxReportPageState extends State<TaxReportPage> {
  final _api = ApiClient();
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  String _caption = '';
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _branches = [];
  int? _branchId;
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _report = {};
  bool _loading = true;
  bool _card = false;
  bool _printing = false;
  bool _exporting = false;
  int _page = 0;
  String get _route =>
      widget.sales ? 'companySalesTaxReport' : 'companyPurchaseTaxReport';
  String get _path => widget.sales ? 'sales' : 'purchases';
  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 20;
  int get _pages => math.max(1, (_rows.length / _pageSize).ceil());
  List<Map<String, dynamic>> get _visible =>
      _rows.skip(_page * _pageSize).take(_pageSize).toList();

  @override
  void initState() {
    super.initState();
    _caption = widget.sales ? 'รายงานภาษีขาย' : 'รายงานภาษีซื้อ';
    _resolve();
    _loadBranches();
    _load();
  }

  Future<void> _loadBranches() async {
    try {
      final values =
          await _api.get('/api/company/tax-reports/branches') as List;
      if (mounted) {
        setState(
          () => _branches = values
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _resolve() async {
    final name = await NavigationMenuRepository().resolveMenuName(
      routeName: _route,
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = name);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = Map<String, dynamic>.from(
        await _api.get(
              '/api/company/tax-reports/$_path',
              query: {
                'year': '$_year',
                'month': '$_month',
                if (_branchId != null) 'branchId': '$_branchId',
              },
            )
            as Map,
      );
      if (!mounted) return;
      setState(() {
        _rows = (result['rows'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _summary = Map<String, dynamic>.from(result['summary'] as Map);
        _report = result;
        _page = 0;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showTimedSnackBar(
        context,
        message: 'โหลดรายงานภาษีไม่ได้\nรายละเอียดเพิ่มเติม: $error',
        error: true,
      );
    }
  }

  Future<void> _printPdf() async {
    if (_printing || _loading) return;
    setState(() => _printing = true);
    try {
      await TaxReportPdfService.printReport(
        _report,
        workspaceThemeController.value.primary,
      );
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'สร้าง PDF ไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_exporting || _loading) return;
    setState(() => _exporting = true);
    try {
      final bytes = TaxReportXlsxService.build(_report);
      final name =
          'vat_${widget.sales ? 'sale' : 'purchase'}_${_year}_${_month.toString().padLeft(2, '0')}.xlsx';
      await FilePicker.platform.saveFile(
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
      );
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ส่งออก Excel ไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  String _money(Object? n) => (num.tryParse('$n') ?? 0).toStringAsFixed(2);
  String _date(Object? n) {
    final d = DateTime.tryParse('$n');
    return d == null
        ? '-'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _surface(Widget child, {double? height}) => Container(
    width: double.infinity,
    height: height,
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: _route,
      menuScope: WorkspaceMenuScope.company,
      child: LayoutBuilder(
        builder: (context, size) {
          final compact = size.maxWidth < 900;
          final card = compact || _card;
          return ListView(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            children: [
              _surface(
                compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WorkspacePageTitle(
                            title: _caption,
                            favoriteKey: _route,
                            titleColor: LaooColors.textPrimary,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _loading || _printing
                                    ? null
                                    : _printPdf,
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: const Text('PDF'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _loading || _exporting
                                    ? null
                                    : _exportExcel,
                                icon: const Icon(Icons.table_view_outlined),
                                label: const Text('Excel'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: WorkspacePageTitle(
                              title: _caption,
                              favoriteKey: _route,
                              titleColor: LaooColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _card = !_card),
                            icon: Icon(
                              card
                                  ? Icons.view_list_outlined
                                  : Icons.grid_view_outlined,
                            ),
                            color: accent,
                          ),
                          OutlinedButton.icon(
                            onPressed: _loading || _printing ? null : _printPdf,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('PDF'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _loading || _exporting
                                ? null
                                : _exportExcel,
                            icon: const Icon(Icons.table_view_outlined),
                            label: const Text('Excel'),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              _surface(
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<int>(
                      value: _year,
                      items: List.generate(6, (i) => DateTime.now().year - i)
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text('ปี $y'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _year = v);
                          _load();
                        }
                      },
                    ),
                    DropdownButton<int>(
                      value: _month,
                      items: List.generate(12, (i) => i + 1)
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text('เดือน $m'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _month = v);
                          _load();
                        }
                      },
                    ),
                    DropdownButton<int?>(
                      value: _branchId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('ทุกสาขา'),
                        ),
                        ..._branches.map(
                          (b) => DropdownMenuItem<int?>(
                            value: (b['branchId'] as num).toInt(),
                            child: Text(
                              '${b['name']} (${b['taxBranchCode'] ?? 'รอตรวจ'})',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _branchId = v);
                        _load();
                      },
                    ),
                    Text('เอกสาร ${_summary['count'] ?? 0} ใบ'),
                    Text('มูลค่า ${_money(_summary['taxBase'])}'),
                    if (widget.sales) ...[
                      Text('มีอัตราภาษี ${_money(_summary['ratedTaxBase'])}'),
                      Text('อัตรา 0% ${_money(_summary['zeroRatedTaxBase'])}'),
                    ],
                    Text(
                      'ภาษี ${_money(_summary[widget.sales ? 'taxAmount' : 'eligibleTaxAmount'])}',
                    ),
                    if ((_summary['unassignedBranchCount'] as num?) != null &&
                        (_summary['unassignedBranchCount'] as num) > 0)
                      Text(
                        'รอตรวจสาขา ${_summary['unassignedBranchCount']}',
                        style: const TextStyle(color: LaooColors.error),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              _surface(
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                    ? const Center(child: Text('ไม่มีเอกสารในเดือนนี้'))
                    : card
                    ? Column(
                        children: _visible
                            .map(
                              (row) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${row['invoiceCode']} · ${_date(row['invoiceDate'])}',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${row['counterparty']} · ${row['taxId'] ?? 'รอตรวจเลขภาษี'}',
                                    ),
                                    Text(
                                      'ก่อนภาษี ${_money(row['taxBase'])} · VAT ${_money(row['taxAmount'])}',
                                    ),
                                    if (!widget.sales)
                                      Text(
                                        'วันที่รับ ${_date(row['receivedDate'])} · สิทธิ์ ${row['claimStatus']}',
                                      ),
                                    if (row['needsReview'] == true)
                                      const Text(
                                        'รอตรวจข้อมูล',
                                        style: TextStyle(
                                          color: LaooColors.error,
                                        ),
                                      ),
                                    const Divider(height: 12),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: math.max(size.maxWidth - 40, 1200),
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('เลขใบกำกับฯ')),
                              DataColumn(label: Text('วันที่ใบ')),
                              DataColumn(label: Text('วันที่รับ')),
                              DataColumn(label: Text('คู่ค้า')),
                              DataColumn(label: Text('เลขภาษี')),
                              DataColumn(label: Text('สาขาบริษัท')),
                              DataColumn(label: Text('สาขาคู่ค้า')),
                              DataColumn(
                                label: Text('ก่อนภาษี'),
                                numeric: true,
                              ),
                              DataColumn(label: Text('VAT'), numeric: true),
                              DataColumn(label: Text('สิทธิ์ภาษีซื้อ')),
                              DataColumn(label: Text('ตรวจสอบ')),
                            ],
                            rows: _visible.indexed.map((e) {
                              final row = e.$2;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text('${e.$1 + 1 + _page * _pageSize}'),
                                  ),
                                  DataCell(Text('${row['invoiceCode']}')),
                                  DataCell(Text(_date(row['invoiceDate']))),
                                  DataCell(
                                    Text(
                                      widget.sales
                                          ? '-'
                                          : _date(row['receivedDate']),
                                    ),
                                  ),
                                  DataCell(Text('${row['counterparty']}')),
                                  DataCell(Text('${row['taxId'] ?? '-'}')),
                                  DataCell(
                                    Text('${row['branchTaxCode'] ?? '-'}'),
                                  ),
                                  DataCell(
                                    Text(
                                      '${row['counterpartyTaxBranchCode'] ?? '-'}',
                                    ),
                                  ),
                                  DataCell(Text(_money(row['taxBase']))),
                                  DataCell(Text(_money(row['taxAmount']))),
                                  DataCell(
                                    Text(
                                      widget.sales
                                          ? '-'
                                          : '${row['claimStatus'] ?? '-'}',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      row['needsReview'] == true
                                          ? 'รอตรวจ'
                                          : 'ครบ',
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              _surface(
                Row(
                  children: [
                    IconButton(
                      onPressed: _page > 0
                          ? () => setState(() => _page--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${_page + 1}'),
                    IconButton(
                      onPressed: _page + 1 < _pages
                          ? () => setState(() => _page++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_rows.isEmpty ? 0 : _page * _pageSize + 1}-${math.min((_page + 1) * _pageSize, _rows.length)} จาก ${_rows.length}',
                    ),
                  ],
                ),
                height: LaooLayout.paginationCardHeight,
              ),
              const SizedBox(height: 6),
              _surface(
                const Text(
                  'รายงานนี้มีเฉพาะใบกำกับภาษีส่วนกลาง ยังไม่รวม POS, School Food, Rental และใบเพิ่ม–ลดหนี้ ใช้ตรวจสอบเท่านั้น ไม่ใช่แบบ ภ.พ.30',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
