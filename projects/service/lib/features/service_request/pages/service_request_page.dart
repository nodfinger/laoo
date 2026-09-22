import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_request_api.dart';

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({super.key, this.selfService = false});
  final bool selfService;
  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  final _api = ServiceRequestApi();
  final _search = TextEditingController();
  String _status = '';
  int _page = 1;
  bool _loading = true;
  Map<String, dynamic> _data = const {'items': <dynamic>[], 'total': 0};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final value = widget.selfService
          ? <String, dynamic>{}
          : await _api.list(
              search: _search.text.trim(),
              status: _status,
              page: _page,
            );
      if (mounted) setState(() => _data = value);
    } catch (error) {
      if (mounted) _error(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (widget.selfService) {
      final lookup = await _api.lookup();
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) =>
            _RequestDialog(api: _api, lookup: lookup, selfService: true),
      );
      if (saved == true && mounted)
        showTimedSnackBar(
          context,
          message:
              'เธชเนเธเธเธณเธเธญเนเธเนเธเธเนเธญเธกเธชเธณเน€เธฃเนเธ',
        );
      return;
    }
    final lookup = await _api.lookup();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestDialog(api: _api, lookup: lookup),
    );
    if (saved == true) {
      _page = 1;
      await _load();
      if (mounted)
        showTimedSnackBar(
          context,
          message:
              'เธเธฑเธเธ—เธถเธเนเธเนเธเธเนเธญเธกเธชเธณเน€เธฃเนเธ',
        );
    }
  }

  void _error(Object error) {
    final message = error is ApiException
        ? error.message +
              '\nเธฃเธฒเธขเธฅเธฐเน€เธญเธตเธขเธ”เน€เธเธดเนเธกเน€เธ•เธดเธก: ' +
              (error.description ??
                  'เธเธฃเธธเธ“เธฒเธ•เธฃเธงเธเธชเธญเธเธเนเธญเธกเธนเธฅ')
        : 'เธ”เธณเน€เธเธดเธเธเธฒเธฃเนเธกเนเธชเธณเน€เธฃเนเธ\nเธฃเธฒเธขเธฅเธฐเน€เธญเธตเธขเธ”เน€เธเธดเนเธกเน€เธ•เธดเธก: เธเธฃเธธเธ“เธฒเธฅเธญเธเนเธซเธกเน';
    showTimedSnackBar(context, message: message, error: true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selfService) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'เนเธเนเธเธเนเธญเธก / เธเธญเนเธเนเธเธฃเธดเธเธฒเธฃ',
          ),
        ),
        body: Center(
          child: FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.build_outlined),
            label: const Text('เนเธเนเธเธเนเธญเธก'),
          ),
        ),
      );
    }
    final items = List<Map<String, dynamic>>.from(
      (_data['items'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final total = (_data['total'] as num?)?.toInt() ?? 0;
    return SupportWorkspaceShell(
      pageTitle:
          'เธฃเธฒเธขเธเธฒเธฃเนเธเนเธเธเนเธญเธกเธ—เธฑเนเธเธซเธกเธ”',
      activeMenu: 'cmTickets',
      menuScope: WorkspaceMenuScope.company,
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.build_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'เธฃเธฒเธขเธเธฒเธฃเนเธเนเธเธเนเธญเธกเธ—เธฑเนเธเธซเธกเธ”',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('เน€เธเธดเนเธกเนเธเนเธเธเนเธญเธก'),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) {
                      _page = 1;
                      _load();
                    },
                    decoration: _input(
                      hint:
                          'เธเนเธเธซเธฒเน€เธฅเธเธ—เธตเน เธเธนเนเนเธเนเธ เธซเธฃเธทเธญเธซเธฑเธงเธเนเธญ',
                      icon: Icons.search,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _input(label: 'เธชเธ–เธฒเธเธฐ'),
                    items: const [
                      DropdownMenuItem(
                        value: '',
                        child: Text('เธ—เธฑเนเธเธซเธกเธ”'),
                      ),
                      DropdownMenuItem(
                        value: 'NEW',
                        child: Text('เนเธซเธกเน'),
                      ),
                      DropdownMenuItem(
                        value: 'RECEIVED',
                        child: Text('เธฃเธฑเธเน€เธฃเธทเนเธญเธ'),
                      ),
                      DropdownMenuItem(
                        value: 'IN_PROGRESS',
                        child: Text(
                          'เธเธณเธฅเธฑเธเธ”เธณเน€เธเธดเธเธเธฒเธฃ',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'COMPLETED',
                        child: Text('เน€เธชเธฃเนเธเธชเธดเนเธ'),
                      ),
                      DropdownMenuItem(
                        value: 'CANCELLED',
                        child: Text('เธขเธเน€เธฅเธดเธ'),
                      ),
                    ],
                    onChanged: (v) {
                      _status = v ?? '';
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    _search.clear();
                    _status = '';
                    _page = 1;
                    _load();
                  },
                  child: const Text('เธฅเนเธฒเธ Filter'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('เน€เธฅเธเธ—เธตเน')),
                  DataColumn(label: Text('เธเธนเนเนเธเนเธ')),
                  DataColumn(label: Text('เธชเธ–เธฒเธเธ—เธตเน')),
                  DataColumn(label: Text('เธซเธฑเธงเธเนเธญ')),
                  DataColumn(label: Text('เธชเธ–เธฒเธเธฐ')),
                  DataColumn(label: Text('เธงเธฑเธเธ—เธตเน')),
                ],
                rows: [
                  for (final row in items)
                    DataRow(
                      cells: [
                        DataCell(Text((row['requestNo'] ?? '-').toString())),
                        DataCell(
                          Text((row['requesterName'] ?? '-').toString()),
                        ),
                        DataCell(
                          Text((row['locationSnapshot'] ?? '-').toString()),
                        ),
                        DataCell(Text((row['subject'] ?? '-').toString())),
                        DataCell(
                          Text(
                            _statusText((row['statusCode'] ?? '').toString()),
                          ),
                        ),
                        DataCell(Text((row['requestDate'] ?? '-').toString())),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _pagination(total),
          ],
        ),
      ),
    );
  }

  Widget _pagination(int total) {
    final pages = total == 0 ? 1 : (total / 20).ceil();
    final end = (_page * 20).clamp(0, total);
    return SizedBox(
      height: LaooLayout.paginationCardHeight,
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _page > 1
                ? () {
                    _page--;
                    _load();
                  }
                : null,
            child: const Text('<'),
          ),
          const SizedBox(width: 6),
          FilledButton(onPressed: null, child: Text(_page.toString())),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: _page < pages
                ? () {
                    _page++;
                    _load();
                  }
                : null,
            child: const Text('>'),
          ),
          const SizedBox(width: 12),
          Text(
            total == 0
                ? '0-0 เธเธฒเธ 0'
                : (_page == 1
                          ? '1-'
                          : (((_page - 1) * 20) + 1).toString() + '-') +
                      end.toString() +
                      ' เธเธฒเธ ' +
                      total.toString(),
          ),
        ],
      ),
    );
  }

  InputDecoration _input({String? label, String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      );
  String _statusText(String code) =>
      const {
        'NEW': 'เนเธซเธกเน',
        'RECEIVED': 'เธฃเธฑเธเน€เธฃเธทเนเธญเธ',
        'IN_PROGRESS': 'เธเธณเธฅเธฑเธเธ”เธณเน€เธเธดเธเธเธฒเธฃ',
        'COMPLETED': 'เน€เธชเธฃเนเธเธชเธดเนเธ',
        'CANCELLED': 'เธขเธเน€เธฅเธดเธ',
      }[code] ??
      code;
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({
    required this.api,
    this.lookup,
    this.selfService = false,
  });
  final ServiceRequestApi api;
  final Map<String, dynamic>? lookup;
  final bool selfService;
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _detail = TextEditingController();
  Map<String, dynamic>? _requester;
  Map<String, dynamic>? _equipment;
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    if (_equipment == null) {
      showTimedSnackBar(
        context,
        message:
            'เธเธฃเธธเธ“เธฒเน€เธฅเธทเธญเธเธญเธธเธเธเธฃเธ“เนเธ—เธตเนเนเธเนเธเธฑเธเธฃเธฐเธเธ Service',
        error: true,
      );
      return;
    }
    if (!widget.selfService && _requester == null) {
      showTimedSnackBar(
        context,
        message:
            'เธเธฃเธธเธ“เธฒเน€เธฅเธทเธญเธเธเธนเนเนเธเนเธ\nเธฃเธฒเธขเธฅเธฐเน€เธญเธตเธขเธ”เน€เธเธดเนเธกเน€เธ•เธดเธก: เน€เธฅเธทเธญเธเธเธนเนเธเธฑเธเธญเธฒเธจเธฑเธข เธเธนเนเธ•เธดเธ”เธ•เนเธญ เธซเธฃเธทเธญเธเธนเนเนเธเนเธเธฃเธดเธเธฒเธฃ',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.create(
        selfService: widget.selfService,
        requesterId: (_requester?['id'] as num?)?.toInt(),
        requesterType: _requester?['requesterType']?.toString(),
        equipmentItemId: (_equipment?['itemID'] as num?)?.toInt(),
        subject: _subject.text.trim(),
        detail: _detail.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? error.message +
                    '\nเธฃเธฒเธขเธฅเธฐเน€เธญเธตเธขเธ”เน€เธเธดเนเธกเน€เธ•เธดเธก: ' +
                    (error.description ??
                        'เธเธฃเธธเธ“เธฒเธ•เธฃเธงเธเธชเธญเธเธเนเธญเธกเธนเธฅ')
              : 'เธเธฑเธเธ—เธถเธเนเธกเนเธชเธณเน€เธฃเนเธ\nเธฃเธฒเธขเธฅเธฐเน€เธญเธตเธขเธ”เน€เธเธดเนเธกเน€เธ•เธดเธก: เธเธฃเธธเธ“เธฒเธฅเธญเธเนเธซเธกเน',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requesters = List<Map<String, dynamic>>.from(
      ((widget.lookup?['requesters'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final keys = {
      for (final r in requesters)
        r['requesterType'].toString() + ':' + r['id'].toString(): r,
    };
    final equipment = List<Map<String, dynamic>>.from(
      ((widget.lookup?['equipment'] as List?) ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      title: Row(
        children: [
          const Icon(Icons.build_outlined),
          const SizedBox(width: 10),
          Text(
            widget.selfService
                ? 'เนเธเนเธเธเนเธญเธก / เธเธญเนเธเนเธเธฃเธดเธเธฒเธฃ'
                : 'เธฃเธฒเธขเธเธฒเธฃเนเธเนเธเธเนเธญเธก > เน€เธเธดเนเธก',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                if (!widget.selfService) ...[
                  DropdownButtonFormField<String>(
                    decoration: _input(label: ''),
                    items: [
                      for (final entry in keys.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(_requesterLabel(entry.value)),
                        ),
                    ],
                    onChanged: (key) => setState(
                      () => _requester = key == null ? null : keys[key],
                    ),
                    validator: (_) => _requester == null
                        ? 'เธเธฃเธธเธ“เธฒเน€เธฅเธทเธญเธเธเธนเนเนเธเนเธ'
                        : null,
                  ),
                  if (_requester != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .08),
                      child: Text(
                        'เธชเธ–เธฒเธเธ—เธตเน: ' +
                            ((_requester!['locationSnapshot'] ??
                                    'เธเธนเนเนเธเนเธเธฃเธดเธเธฒเธฃเธ เธฒเธขเธเธญเธ')
                                .toString()),
                      ),
                    ),
                  ],
                ] else
                  Container(
                    padding: const EdgeInsets.all(10),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .08),
                    child: const Text(
                      'เธเธนเนเนเธเนเธ: เธเธนเนเนเธเนเธเธฑเธเธเธธเธเธฑเธ\nเธชเธ–เธฒเธเธ—เธตเน: เธฃเธฐเธเธเธ•เธฃเธงเธเธชเธญเธเธเธฒเธเธเนเธญเธกเธนเธฅเธเธนเนเนเธเน',
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _equipment == null
                      ? null
                      : _equipment!['itemID'].toString(),
                  decoration: _input(
                    label:
                        'เธญเธธเธเธเธฃเธ“เนเธ—เธตเนเนเธเนเธเธฑเธเธฃเธฐเธเธ Service *',
                  ),
                  items: [
                    for (final item in equipment)
                      DropdownMenuItem(
                        value: item['itemID'].toString(),
                        child: Text(
                          '${item['itemCode']} | ${item['itemName']}',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _equipment = value == null
                        ? null
                        : equipment.firstWhere(
                            (item) => item['itemID'].toString() == value,
                          );
                  }),
                  validator: (_) => _equipment == null
                      ? 'เธเธฃเธธเธ“เธฒเน€เธฅเธทเธญเธเธญเธธเธเธเธฃเธ“เน'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subject,
                  decoration: _input(
                    label: 'เธซเธฑเธงเธเนเธญเนเธเนเธเธเนเธญเธก *',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'เธเธฃเธธเธ“เธฒเธฃเธฐเธเธธเธซเธฑเธงเธเนเธญเนเธเนเธเธเนเธญเธก'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _detail,
                  minLines: 4,
                  maxLines: 7,
                  decoration: _input(label: 'เธฃเธฒเธขเธฅเธฐเน€เธญเธตเธขเธ” *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'เธเธฃเธธเธ“เธฒเธฃเธฐเธเธธเธฃเธฒเธขเธฅเธฐเน€เธญเธตเธขเธ”'
                      : null,
                ),
                const SizedBox(height: 14),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('เธขเธเน€เธฅเธดเธ'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('เธเธฑเธเธ—เธถเธ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _requesterLabel(Map<String, dynamic> value) {
    final type = value['requesterType']?.toString();
    final prefix = type == 'SERVICE_CUSTOMER'
        ? 'เธฅเธนเธเธเนเธฒ Walk-in: '
        : '';
    return prefix + value['name'].toString();
  }

  InputDecoration _input({String? label}) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
  );
}
