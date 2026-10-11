import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';

class PurchaseDeliveryPage extends StatefulWidget {
  const PurchaseDeliveryPage({super.key});
  @override
  State<PurchaseDeliveryPage> createState() => _PurchaseDeliveryPageState();
}

class _PurchaseDeliveryPageState extends State<PurchaseDeliveryPage> {
  final _api = ApiClient();
  final _search = TextEditingController();
  final _supplierCode = TextEditingController();
  final _remark = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _creditDays = TextEditingController(text: '30');
  String _caption =
      '\u{e43}\u{e1a}\u{e2a}\u{e48}\u{e07}\u{e02}\u{e2d}\u{e07}\u{e0b}\u{e37}\u{e49}\u{e2d}';
  String _statusFilter = 'ALL';
  String _paymentType = 'CASH';
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _lines = [];
  Map<String, bool> _actions = {};
  int? _vendorId, _branchId, _editingId;
  int _page = 1, _total = 0;
  DateTime _date = DateTime.now();
  bool _loading = true, _saving = false, _form = false;
  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 20;
  int get _pages => math.max(1, (_total / _pageSize).ceil());
  Color get _primary => workspaceThemeController.value.primary;

  @override
  void initState() {
    super.initState();
    _resolveCaption();
    _load();
  }

  Future<void> _resolveCaption() async {
    final name = await NavigationMenuRepository().resolveMenuName(
      routeName: 'companyPurchaseDeliveries',
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = name);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _api.get(
          '/api/company/purchase-deliveries?page=$_page&pageSize=$_pageSize&search=${Uri.encodeQueryComponent(_search.text)}&status=$_statusFilter',
        ),
        _api.get('/api/company/purchase-deliveries/lookup'),
        _api.get('/api/company/purchase-deliveries/actions'),
      ]);
      if (!mounted) return;
      final data = Map<String, dynamic>.from(values[0] as Map);
      final lookup = Map<String, dynamic>.from(values[1] as Map);
      setState(() {
        _rows = (data['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _total = (data['total'] as num).toInt();
        _vendors = (lookup['vendors'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _branches = (lookup['branches'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _actions = Map<String, dynamic>.from(
          values[2] as Map,
        ).map((k, v) => MapEntry(k, v == true));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _notify(
        '\u{e42}\u{e2b}\u{e25}\u{e14}\u{e02}\u{e49}\u{e2d}\u{e21}\u{e39}\u{e25}\u{e44}\u{e21}\u{e48}\u{e2a}\u{e33}\u{e40}\u{e23}\u{e47}\u{e08}',
        e,
      );
    }
  }

  void _notify(String title, Object detail, {bool error = true}) {
    showTimedSnackBar(
      context,
      message:
          '$title\n\u{e23}\u{e32}\u{e22}\u{e25}\u{e30}\u{e40}\u{e2d}\u{e35}\u{e22}\u{e14}\u{e40}\u{e1e}\u{e34}\u{e48}\u{e21}\u{e40}\u{e15}\u{e34}\u{e21}: $detail',
      error: error,
    );
  }

  String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _dateText(dynamic value) {
    if (value == null) return '-';
    final d = DateTime.parse(value.toString());
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _new() {
    setState(() {
      _form = true;
      _editingId = null;
      _vendorId = null;
      _branchId = null;
      _supplierCode.clear();
      _remark.clear();
      _lines.clear();
      _paymentType = 'CASH';
      _creditDays.text = '30';
      _date = DateTime.now();
    });
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    try {
      final result = Map<String, dynamic>.from(
        await _api.get(
              '/api/company/purchase-deliveries/${row['purchaseDeliveryId']}',
            )
            as Map,
      );
      final h = Map<String, dynamic>.from(result['header'] as Map);
      if (!mounted) return;
      setState(() {
        _form = true;
        _editingId = (row['purchaseDeliveryId'] as num).toInt();
        _vendorId = (h['vendorId'] as num).toInt();
        _branchId = (h['branchId'] as num?)?.toInt();
        _supplierCode.text = '${h['supplierDocumentCode'] ?? ''}';
        _remark.text = '${h['remark'] ?? ''}';
        _paymentType = '${h['paymentType']}';
        _creditDays.text = '${h['creditDays']}';
        _date = DateTime.parse('${h['deliveryDate']}');
        _lines = (result['lines'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        _notify(
          '\u{e40}\u{e1b}\u{e34}\u{e14}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e44}\u{e21}\u{e48}\u{e2a}\u{e33}\u{e40}\u{e23}\u{e47}\u{e08}',
          e,
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  void _addLine() {
    final q = double.tryParse(_quantity.text);
    final p = double.tryParse(_price.text);
    if (_description.text.trim().isEmpty ||
        q == null ||
        q <= 0 ||
        p == null ||
        p < 0) {
      _notify(
        '\u{e02}\u{e49}\u{e2d}\u{e21}\u{e39}\u{e25}\u{e23}\u{e32}\u{e22}\u{e01}\u{e32}\u{e23}\u{e44}\u{e21}\u{e48}\u{e04}\u{e23}\u{e1a}',
        '\u{e01}\u{e23}\u{e2d}\u{e01}\u{e0a}\u{e37}\u{e48}\u{e2d}\u{e2a}\u{e34}\u{e19}\u{e04}\u{e49}\u{e32} \u{e08}\u{e33}\u{e19}\u{e27}\u{e19}\u{e21}\u{e32}\u{e01}\u{e01}\u{e27}\u{e48}\u{e32} 0 \u{e41}\u{e25}\u{e30}\u{e23}\u{e32}\u{e04}\u{e32}\u{e44}\u{e21}\u{e48}\u{e15}\u{e34}\u{e14}\u{e25}\u{e1a}',
      );
      return;
    }
    setState(() {
      _lines.add({
        'description': _description.text.trim(),
        'quantity': q,
        'unitPrice': p,
      });
      _description.clear();
      _quantity.text = '1';
      _price.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_vendorId == null ||
        _lines.isEmpty ||
        (_paymentType == 'CREDIT' &&
            ((int.tryParse(_creditDays.text) ?? 0) < 1))) {
      _notify(
        '\u{e02}\u{e49}\u{e2d}\u{e21}\u{e39}\u{e25}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e44}\u{e21}\u{e48}\u{e04}\u{e23}\u{e1a}',
        '\u{e40}\u{e25}\u{e37}\u{e2d}\u{e01}\u{e1c}\u{e39}\u{e49}\u{e02}\u{e32}\u{e22} \u{e40}\u{e1e}\u{e34}\u{e48}\u{e21}\u{e23}\u{e32}\u{e22}\u{e01}\u{e32}\u{e23}\u{e2d}\u{e22}\u{e48}\u{e32}\u{e07}\u{e19}\u{e49}\u{e2d}\u{e22} 1 \u{e23}\u{e32}\u{e22}\u{e01}\u{e32}\u{e23} \u{e41}\u{e25}\u{e30}\u{e23}\u{e30}\u{e1a}\u{e38}\u{e27}\u{e31}\u{e19}\u{e40}\u{e04}\u{e23}\u{e14}\u{e34}\u{e15}\u{e40}\u{e21}\u{e37}\u{e48}\u{e2d}\u{e0b}\u{e37}\u{e49}\u{e2d}\u{e40}\u{e0a}\u{e37}\u{e48}\u{e2d}',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.post(
        '/api/company/purchase-deliveries',
        body: {
          'purchaseDeliveryId': _editingId,
          'vendorId': _vendorId,
          'branchId': _branchId,
          'supplierDocumentCode': _supplierCode.text.trim(),
          'deliveryDate': _iso(_date),
          'paymentType': _paymentType,
          'creditDays': _paymentType == 'CASH'
              ? 0
              : int.parse(_creditDays.text),
          'remark': _remark.text.trim(),
          'lines': _lines
              .map(
                (e) => {
                  'description': e['description'],
                  'quantity': e['quantity'],
                  'unitPrice': e['unitPrice'],
                },
              )
              .toList(),
        },
      );
      if (!mounted) return;
      setState(() {
        _form = false;
        _page = 1;
      });
      _notify(
        '\u{e1a}\u{e31}\u{e19}\u{e17}\u{e36}\u{e01}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e23}\u{e48}\u{e32}\u{e07}\u{e41}\u{e25}\u{e49}\u{e27}',
        '\u{e01}\u{e14}\u{e22}\u{e37}\u{e19}\u{e22}\u{e31}\u{e19}\u{e40}\u{e21}\u{e37}\u{e48}\u{e2d}\u{e02}\u{e49}\u{e2d}\u{e21}\u{e39}\u{e25}\u{e16}\u{e39}\u{e01}\u{e15}\u{e49}\u{e2d}\u{e07}',
        error: false,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        _notify(
          '\u{e1a}\u{e31}\u{e19}\u{e17}\u{e36}\u{e01}\u{e44}\u{e21}\u{e48}\u{e2a}\u{e33}\u{e40}\u{e23}\u{e47}\u{e08}',
          e,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirm(Map<String, dynamic> row) async {
    try {
      await _api.post(
        '/api/company/purchase-deliveries/${row['purchaseDeliveryId']}/confirm',
      );
      if (!mounted) return;
      _notify(
        '\u{e22}\u{e37}\u{e19}\u{e22}\u{e31}\u{e19}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e41}\u{e25}\u{e49}\u{e27}',
        row['paymentType'] == 'CASH'
            ? '\u{e1a}\u{e31}\u{e19}\u{e17}\u{e36}\u{e01}\u{e01}\u{e32}\u{e23}\u{e0a}\u{e33}\u{e23}\u{e30}\u{e40}\u{e07}\u{e34}\u{e19}\u{e2a}\u{e14}\u{e41}\u{e25}\u{e30}\u{e1b}\u{e34}\u{e14}\u{e22}\u{e2d}\u{e14}\u{e40}\u{e08}\u{e49}\u{e32}\u{e2b}\u{e19}\u{e35}\u{e49}\u{e41}\u{e25}\u{e49}\u{e27}'
            : '\u{e2a}\u{e23}\u{e49}\u{e32}\u{e07}\u{e22}\u{e2d}\u{e14}\u{e40}\u{e08}\u{e49}\u{e32}\u{e2b}\u{e19}\u{e35}\u{e49}\u{e15}\u{e32}\u{e21}\u{e27}\u{e31}\u{e19}\u{e04}\u{e23}\u{e1a}\u{e01}\u{e33}\u{e2b}\u{e19}\u{e14}\u{e41}\u{e25}\u{e49}\u{e27}',
        error: false,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        _notify(
          '\u{e22}\u{e37}\u{e19}\u{e22}\u{e31}\u{e19}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e44}\u{e21}\u{e48}\u{e2a}\u{e33}\u{e40}\u{e23}\u{e47}\u{e08}',
          e,
        );
      }
    }
  }

  Future<void> _voidDraft(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: LaooColors.error),
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delete_outline, color: LaooColors.error),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '\u{e22}\u{e37}\u{e19}\u{e22}\u{e31}\u{e19}\u{e01}\u{e32}\u{e23}\u{e22}\u{e01}\u{e40}\u{e25}\u{e34}\u{e01}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}',
                        style: TextStyle(
                          color: LaooColors.error,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LaooColors.error.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${row['deliveryCode']} \u{2022} ${row['vendorName']}',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e23}\u{e48}\u{e32}\u{e07}\u{e17}\u{e35}\u{e48}\u{e22}\u{e01}\u{e40}\u{e25}\u{e34}\u{e01}\u{e41}\u{e25}\u{e49}\u{e27}\u{e08}\u{e30}\u{e44}\u{e21}\u{e48}\u{e2a}\u{e32}\u{e21}\u{e32}\u{e23}\u{e16}\u{e19}\u{e33}\u{e01}\u{e25}\u{e31}\u{e1a}\u{e21}\u{e32}\u{e43}\u{e0a}\u{e49}\u{e44}\u{e14}\u{e49}',
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        '\u{e22}\u{e01}\u{e40}\u{e25}\u{e34}\u{e01}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: LaooColors.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text(
                        '\u{e22}\u{e01}\u{e40}\u{e25}\u{e34}\u{e01}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete(
        '/api/company/purchase-deliveries/${row['purchaseDeliveryId']}',
      );
      if (mounted) {
        _notify(
          '\u{e22}\u{e01}\u{e40}\u{e25}\u{e34}\u{e01}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e41}\u{e25}\u{e49}\u{e27}',
          row['deliveryCode'],
          error: false,
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        _notify(
          '\u{e22}\u{e01}\u{e40}\u{e25}\u{e34}\u{e01}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e44}\u{e21}\u{e48}\u{e2a}\u{e33}\u{e40}\u{e23}\u{e47}\u{e08}',
          e,
        );
      }
    }
  }

  InputDecoration _field(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: LaooColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: _primary),
    ),
  );

  Widget _surface(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: LaooLayout.listSectionSpacing),
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: child,
  );

  Widget _list() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _surface(
        Row(
          children: [
            Expanded(
              child: WorkspacePageTitle(
                title: _caption,
                favoriteKey: 'companyPurchaseDeliveries',
                titleColor: LaooColors.textPrimary,
              ),
            ),
            if (_actions['create'] == true)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _new,
                icon: const Icon(Icons.add),
                label: const Text('\u{e40}\u{e1e}\u{e34}\u{e48}\u{e21}'),
              ),
          ],
        ),
      ),
      _surface(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _search,
                decoration: _field(
                  '\u{e04}\u{e49}\u{e19}\u{e2b}\u{e32}\u{e40}\u{e25}\u{e02}\u{e17}\u{e35}\u{e48}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e2b}\u{e23}\u{e37}\u{e2d}\u{e1c}\u{e39}\u{e49}\u{e02}\u{e32}\u{e22}',
                ),
                onSubmitted: (_) {
                  _page = 1;
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                decoration: _field('\u{e2a}\u{e16}\u{e32}\u{e19}\u{e30}'),
                items: const [
                  DropdownMenuItem(
                    value: 'ALL',
                    child: Text(
                      '\u{e17}\u{e31}\u{e49}\u{e07}\u{e2b}\u{e21}\u{e14}',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'DRAFT',
                    child: Text('\u{e23}\u{e48}\u{e32}\u{e07}'),
                  ),
                  DropdownMenuItem(
                    value: 'CONFIRMED',
                    child: Text(
                      '\u{e22}\u{e37}\u{e19}\u{e22}\u{e31}\u{e19}\u{e41}\u{e25}\u{e49}\u{e27}',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'VOID',
                    child: Text('\u{e22}\u{e01}\u{e40}\u{e25}\u{e34}\u{e01}'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _statusFilter = v;
                      _page = 1;
                    });
                    _load();
                  }
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _page = 1;
                _load();
              },
              icon: const Icon(Icons.search),
              label: const Text('\u{e04}\u{e49}\u{e19}\u{e2b}\u{e32}'),
            ),
          ],
        ),
      ),
      _surface(
        _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 22,
                  columns: const [
                    DataColumn(
                      label: Text('\u{e08}\u{e31}\u{e14}\u{e01}\u{e32}\u{e23}'),
                    ),
                    DataColumn(
                      label: Text(
                        '\u{e40}\u{e25}\u{e02}\u{e17}\u{e35}\u{e48}\u{e23}\u{e30}\u{e1a}\u{e1a}',
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e1c}\u{e39}\u{e49}\u{e02}\u{e32}\u{e22}',
                      ),
                    ),
                    DataColumn(
                      label: Text('\u{e27}\u{e31}\u{e19}\u{e17}\u{e35}\u{e48}'),
                    ),
                    DataColumn(
                      label: Text('\u{e1c}\u{e39}\u{e49}\u{e02}\u{e32}\u{e22}'),
                    ),
                    DataColumn(label: Text('\u{e0a}\u{e33}\u{e23}\u{e30}')),
                    DataColumn(
                      label: Text('\u{e22}\u{e2d}\u{e14}\u{e23}\u{e27}\u{e21}'),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text('\u{e2a}\u{e16}\u{e32}\u{e19}\u{e30}'),
                    ),
                  ],
                  rows: _rows
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(
                              Wrap(
                                spacing: 2,
                                children: [
                                  IconButton(
                                    tooltip:
                                        '\u{e14}\u{e39}/\u{e41}\u{e01}\u{e49}\u{e44}\u{e02}',
                                    onPressed: _actions['view'] == true
                                        ? () => _edit(r)
                                        : null,
                                    icon: Icon(
                                      r['statusCode'] == 'DRAFT'
                                          ? Icons.edit_outlined
                                          : Icons.visibility_outlined,
                                      color: _primary,
                                    ),
                                  ),
                                  if (_actions['confirm'] == true &&
                                      r['statusCode'] == 'DRAFT')
                                    IconButton(
                                      tooltip:
                                          '\u{e22}\u{e37}\u{e19}\u{e22}\u{e31}\u{e19}',
                                      onPressed: () => _confirm(r),
                                      icon: Icon(
                                        Icons.check_circle_outline,
                                        color: _primary,
                                      ),
                                    ),
                                  if (_actions['delete'] == true &&
                                      r['statusCode'] == 'DRAFT')
                                    IconButton(
                                      tooltip:
                                          '\u{e22}\u{e01}\u{e40}\u{e25}\u{e34}\u{e01}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}',
                                      onPressed: () => _voidDraft(r),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: LaooColors.error,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(Text('${r['deliveryCode']}')),
                            DataCell(
                              Text('${r['supplierDocumentCode'] ?? '-'}'),
                            ),
                            DataCell(Text(_dateText(r['deliveryDate']))),
                            DataCell(Text('${r['vendorName']}')),
                            DataCell(
                              Text(
                                r['paymentType'] == 'CASH'
                                    ? '\u{e40}\u{e07}\u{e34}\u{e19}\u{e2a}\u{e14}'
                                    : '\u{e40}\u{e04}\u{e23}\u{e14}\u{e34}\u{e15} ${r['creditDays']} \u{e27}\u{e31}\u{e19}',
                              ),
                            ),
                            DataCell(
                              Text(
                                (r['totalAmount'] as num).toStringAsFixed(2),
                              ),
                            ),
                            DataCell(Text('${r['statusCode']}')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
      ),
      _surface(
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '\u{e2b}\u{e19}\u{e49}\u{e32} $_page / $_pages \u{2022} $_total \u{e23}\u{e32}\u{e22}\u{e01}\u{e32}\u{e23}',
            ),
            IconButton(
              onPressed: _page > 1
                  ? () {
                      setState(() => _page--);
                      _load();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: _page < _pages
                  ? () {
                      setState(() => _page++);
                      _load();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _formView() {
    final total = _lines.fold<double>(
      0,
      (sum, line) =>
          sum +
          ((line['quantity'] as num).toDouble() *
              (line['unitPrice'] as num).toDouble()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _surface(
          Row(
            children: [
              Expanded(
                child: WorkspacePageTitle(
                  title: '$_caption > \u{0e01}\u{0e49}\u{0e44}\u{0e02}',
                  favoriteKey: 'companyPurchaseDeliveries',
                  titleColor: LaooColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _form = false),
                child: const Text('\u{e22}\u{e01}\u{e40}\u{e25}\u{e34}\u{e01}'),
              ),
            ],
          ),
        ),
        _surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Header \u{2022} \u{e02}\u{e49}\u{e2d}\u{e21}\u{e39}\u{e25}\u{e43}\u{e1a}\u{e0b}\u{e37}\u{e49}\u{e2d}',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<int>(
                      initialValue: _vendorId,
                      decoration: _field(
                        '\u{e1c}\u{e39}\u{e49}\u{e02}\u{e32}\u{e22} *',
                      ),
                      items: _vendors
                          .map(
                            (v) => DropdownMenuItem<int>(
                              value: (v['vendorId'] as num).toInt(),
                              child: Text('${v['code']} \u{2022} ${v['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _vendorId = v),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _branchId,
                      decoration: _field('\u{e2a}\u{e32}\u{e02}\u{e32}'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            '\u{e44}\u{e21}\u{e48}\u{e23}\u{e30}\u{e1a}\u{e38}',
                          ),
                        ),
                        ..._branches.map(
                          (b) => DropdownMenuItem<int?>(
                            value: (b['branchId'] as num).toInt(),
                            child: Text('${b['code']} \u{2022} ${b['name']}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _branchId = v),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        '\u{e27}\u{e31}\u{e19}\u{e17}\u{e35}\u{e48} ${_dateText(_iso(_date))}',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _supplierCode,
                      decoration: _field(
                        '\u{e40}\u{e25}\u{e02}\u{e17}\u{e35}\u{e48}\u{e40}\u{e2d}\u{e01}\u{e2a}\u{e32}\u{e23}\u{e1c}\u{e39}\u{e49}\u{e02}\u{e32}\u{e22}',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _paymentType,
                      decoration: _field(
                        '\u{e27}\u{e34}\u{e18}\u{e35}\u{e0a}\u{e33}\u{e23}\u{e30} *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CASH',
                          child: Text(
                            '\u{e40}\u{e07}\u{e34}\u{e19}\u{e2a}\u{e14}/\u{e08}\u{e48}\u{e32}\u{e22}\u{e17}\u{e31}\u{e19}\u{e17}\u{e35}',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'CREDIT',
                          child: Text(
                            '\u{e0b}\u{e37}\u{e49}\u{e2d}\u{e40}\u{e0a}\u{e37}\u{e48}\u{e2d}',
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _paymentType = v ?? 'CASH'),
                    ),
                  ),
                  if (_paymentType == 'CREDIT')
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _creditDays,
                        keyboardType: TextInputType.number,
                        decoration: _field(
                          '\u{e40}\u{e04}\u{e23}\u{e14}\u{e34}\u{e15} (\u{e27}\u{e31}\u{e19}) *',
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _remark,
                      decoration: _field(
                        '\u{e2b}\u{e21}\u{e32}\u{e22}\u{e40}\u{e2b}\u{e15}\u{e38}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Detail \u{2022} \u{e23}\u{e32}\u{e22}\u{e01}\u{e32}\u{e23}\u{e0b}\u{e37}\u{e49}\u{e2d}',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _description,
                      decoration: _field(
                        '\u{e2a}\u{e34}\u{e19}\u{e04}\u{e49}\u{e32}/\u{e23}\u{e32}\u{e22}\u{e25}\u{e30}\u{e40}\u{e2d}\u{e35}\u{e22}\u{e14} *',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      decoration: _field(
                        '\u{e08}\u{e33}\u{e19}\u{e27}\u{e19} *',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: _field(
                        '\u{e23}\u{e32}\u{e04}\u{e32}\u{e15}\u{e48}\u{e2d}\u{e2b}\u{e19}\u{e48}\u{e27}\u{e22} *',
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      '\u{e40}\u{e1e}\u{e34}\u{e48}\u{e21}\u{e23}\u{e32}\u{e22}\u{e01}\u{e32}\u{e23}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_lines.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(
                        label: Text(
                          '\u{e23}\u{e32}\u{e22}\u{e01}\u{e32}\u{e23}',
                        ),
                      ),
                      DataColumn(
                        label: Text('\u{e08}\u{e33}\u{e19}\u{e27}\u{e19}'),
                      ),
                      DataColumn(label: Text('\u{e23}\u{e32}\u{e04}\u{e32}')),
                      DataColumn(label: Text('\u{e23}\u{e27}\u{e21}')),
                      DataColumn(label: Text('\u{e25}\u{e1a}')),
                    ],
                    rows: _lines.indexed
                        .map(
                          (e) => DataRow(
                            cells: [
                              DataCell(Text('${e.$2['description']}')),
                              DataCell(Text('${e.$2['quantity']}')),
                              DataCell(Text('${e.$2['unitPrice']}')),
                              DataCell(
                                Text(
                                  ((e.$2['quantity'] as num) *
                                          (e.$2['unitPrice'] as num))
                                      .toStringAsFixed(2),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _lines.removeAt(e.$1)),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: LaooColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '\u{e22}\u{e2d}\u{e14}\u{e23}\u{e27}\u{e21} ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        _surface(
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                _saving
                    ? '\u{e01}\u{e33}\u{e25}\u{e31}\u{e07}\u{e1a}\u{e31}\u{e19}\u{e17}\u{e36}\u{e01}'
                    : '\u{e1a}\u{e31}\u{e19}\u{e17}\u{e36}\u{e01}\u{e23}\u{e48}\u{e32}\u{e07}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'companyPurchaseDeliveries',
    menuScope: WorkspaceMenuScope.company,
    child: ListView(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      children: [_form ? _formView() : _list()],
    ),
  );

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    _supplierCode.dispose();
    _remark.dispose();
    _description.dispose();
    _quantity.dispose();
    _price.dispose();
    _creditDays.dispose();
    super.dispose();
  }
}
