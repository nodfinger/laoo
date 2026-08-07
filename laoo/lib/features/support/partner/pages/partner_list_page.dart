import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../models/partner.dart';

enum PartnerViewMode { table, card }

class PartnerListPage extends StatefulWidget {
  const PartnerListPage({
    super.key,
    required this.loadPartners,
    required this.openCreate,
    required this.openEdit,
    required this.changeStatus,
  });

  final Future<List<Partner>> Function({String? search, bool? isActive})
  loadPartners;

  final Future<void> Function() openCreate;
  final Future<void> Function(Partner partner) openEdit;
  final Future<void> Function(Partner partner, bool isActive) changeStatus;

  @override
  State<PartnerListPage> createState() => _PartnerListPageState();
}

class _PartnerListPageState extends State<PartnerListPage> {
  final _searchController = TextEditingController();

  bool? _activeFilter = true;
  bool _loading = true;
  Object? _error;
  List<Partner> _partners = const [];
  PartnerViewMode _viewMode = PartnerViewMode.table;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final partners = await widget.loadPartners(
        search: _searchController.text,
        isActive: _activeFilter,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _partners = partners;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(
              onCreate: () async {
                await widget.openCreate();
                await _load();
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  children: [
                    _Toolbar(
                      searchController: _searchController,
                      activeFilter: _activeFilter,
                      viewMode: _viewMode,
                      onSearch: _load,
                      onActiveChanged: (value) {
                        setState(() {
                          _activeFilter = value;
                        });
                        _load();
                      },
                      onViewModeChanged: (mode) {
                        setState(() {
                          _viewMode = mode;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildBody(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('โหลดใหม่'),
        ),
      );
    }

    if (_partners.isEmpty) {
      return const Center(
        child: Text(
          'ยังไม่มีข้อมูล Partner',
          style: TextStyle(color: LaooColors.textSecondary),
        ),
      );
    }

    if (_viewMode == PartnerViewMode.card ||
        MediaQuery.sizeOf(context).width < 800) {
      return _cardView();
    }

    return _tableView();
  }

  Widget _tableView() {
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(LaooColors.surfaceSoft),
            columns: const [
              DataColumn(label: Text('รหัส Partner')),
              DataColumn(label: Text('ชื่อ Partner')),
              DataColumn(label: Text('ผู้ติดต่อ')),
              DataColumn(label: Text('เบอร์โทรศัพท์')),
              DataColumn(label: Text('สถานะ')),
              DataColumn(label: Text('จัดการ')),
            ],
            rows: _partners.map((partner) {
              return DataRow(
                cells: [
                  DataCell(Text(partner.partnerCode)),
                  DataCell(Text(partner.partnerNameTh)),
                  DataCell(Text(partner.contactName1 ?? '-')),
                  DataCell(Text(partner.contactPhone1 ?? '-')),
                  DataCell(_StatusChip(active: partner.isActive)),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'แก้ไข',
                          onPressed: () async {
                            await widget.openEdit(partner);
                            await _load();
                          },
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'status') {
                              await widget.changeStatus(
                                partner,
                                !partner.isActive,
                              );
                              await _load();
                            }
                          },
                          itemBuilder: (context) {
                            return [
                              PopupMenuItem(
                                value: 'status',
                                child: Text(
                                  partner.isActive
                                      ? 'ระงับการใช้งาน'
                                      : 'เปิดใช้งาน',
                                ),
                              ),
                            ];
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cardView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 3
            : width >= 700
            ? 2
            : 1;

        const gap = 14.0;

        final itemWidth = (width - gap * (columns - 1)) / columns;

        return SingleChildScrollView(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final partner in _partners)
                SizedBox(
                  width: itemWidth,
                  child: Card(
                    child: InkWell(
                      onTap: () async {
                        await widget.openEdit(partner);
                        await _load();
                      },
                      borderRadius: BorderRadius.circular(LaooRadius.lg),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: LaooColors.greenLight,
                                  child: Icon(
                                    Icons.business_outlined,
                                    color: LaooColors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        partner.partnerCode,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        partner.partnerNameTh,
                                        style: const TextStyle(
                                          color: LaooColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _StatusChip(active: partner.isActive),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _Info(
                              icon: Icons.person_outline,
                              text: partner.contactName1 ?? '-',
                            ),
                            const SizedBox(height: 7),
                            _Info(
                              icon: Icons.phone_outlined,
                              text: partner.contactPhone1 ?? '-',
                            ),
                            const SizedBox(height: 7),
                            _Info(
                              icon: Icons.location_on_outlined,
                              text: partner.province ?? '-',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: LaooColors.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partner',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 3),
                Text(
                  'จัดการข้อมูลผู้แทนจำหน่าย',
                  style: TextStyle(color: LaooColors.textSecondary),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('เพิ่ม Partner'),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.activeFilter,
    required this.viewMode,
    required this.onSearch,
    required this.onActiveChanged,
    required this.onViewModeChanged,
  });

  final TextEditingController searchController;
  final bool? activeFilter;
  final PartnerViewMode viewMode;
  final VoidCallback onSearch;
  final ValueChanged<bool?> onActiveChanged;
  final ValueChanged<PartnerViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 340,
          child: TextField(
            controller: searchController,
            onSubmitted: (value) {
              onSearch();
            },
            decoration: const InputDecoration(
              hintText: 'ค้นหา Partner...',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        DropdownButton<bool?>(
          value: activeFilter,
          items: const [
            DropdownMenuItem(value: true, child: Text('เปิดใช้งาน')),
            DropdownMenuItem(value: false, child: Text('ระงับใช้งาน')),
            DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
          ],
          onChanged: onActiveChanged,
        ),
        SegmentedButton<PartnerViewMode>(
          segments: const [
            ButtonSegment(
              value: PartnerViewMode.table,
              icon: Icon(Icons.table_rows_outlined),
              label: Text('แบบตาราง'),
            ),
            ButtonSegment(
              value: PartnerViewMode.card,
              icon: Icon(Icons.grid_view_outlined),
              label: Text('แบบการ์ด'),
            ),
          ],
          selected: {viewMode},
          onSelectionChanged: (value) {
            onViewModeChanged(value.first);
          },
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onSearch,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F7EF) : const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'เปิดใช้งาน' : 'ระงับใช้งาน',
        style: TextStyle(
          color: active ? LaooColors.success : LaooColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: LaooColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: LaooColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
