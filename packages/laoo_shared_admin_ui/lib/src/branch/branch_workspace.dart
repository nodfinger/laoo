import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

import '../shared/shared_admin_ui_tokens.dart';

class BranchCompanyOption {
  const BranchCompanyOption({required this.companyId, required this.name});
  final int companyId;
  final String name;
}

typedef BranchCompanyLoader = Future<List<BranchCompanyOption>> Function();

class BranchWorkspace extends StatefulWidget {
  const BranchWorkspace({
    super.key,
    required this.caption,
    required this.repository,
    required this.loadCompanies,
    required this.errorText,
    required this.titleBuilder,
    required this.messageBuilder,
    required this.tokens,
    required this.screenType,
    required this.companyScope,
    this.pageSize = 20,
  });

  final String caption;
  final BranchRepository repository;
  final BranchCompanyLoader loadCompanies;
  final SharedAdminErrorText errorText;
  final SharedAdminTitleBuilder titleBuilder;
  final SharedAdminMessageBuilder messageBuilder;
  final SharedAdminUiTokens tokens;
  final int screenType;
  final bool companyScope;
  final int pageSize;

  @override
  State<BranchWorkspace> createState() => _BranchWorkspaceState();
}

class _BranchWorkspaceState extends State<BranchWorkspace> {
  static const all = 'ทั้งหมด';
  static const active = 'เปิดใช้งาน';
  static const inactive = 'ปิดใช้งาน';

  final formKey = GlobalKey<FormState>();
  final search = TextEditingController();
  final code = TextEditingController();
  final name = TextEditingController();
  final nameEn = TextEditingController();
  final email = TextEditingController();
  final telephone = TextEditingController();
  final address = TextEditingController();
  final contact = TextEditingController();
  final contactPhone = TextEditingController();
  final position = TextEditingController();

  List<BranchRecord> items = const [];
  List<BranchCompanyOption> companies = const [];
  BranchRecord? editing;
  int? companyFilterId;
  int? formCompanyId;
  int page = 0;
  int sortColumn = 3;
  bool sortAscending = true;
  bool loading = true;
  bool saving = false;
  bool formActive = true;
  bool showForm = false;
  bool cardMode = false;
  bool canCreate = false;
  bool canEdit = false;
  bool canDelete = false;
  String status = all;
  String? message;
  bool messageError = false;

  List<BranchRecord> get filtered => items
      .where((item) {
        if (status == active) return item.isActive;
        if (status == inactive) return !item.isActive;
        return true;
      })
      .toList(growable: false);

  int get pageCount =>
      filtered.isEmpty ? 1 : (filtered.length / widget.pageSize).ceil();

  List<BranchRecord> get visible {
    final safePage = page.clamp(0, pageCount - 1);
    final start = safePage * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    for (final controller in [
      search,
      code,
      name,
      nameEn,
      email,
      telephone,
      address,
      contact,
      contactPhone,
      position,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> initialize() async {
    Map<String, bool> actions = const {};
    try {
      actions = await widget.repository.actions();
    } catch (_) {
      // Permissions fail closed.
    }
    if (!widget.companyScope) {
      try {
        companies = await widget.loadCompanies();
      } catch (_) {
        companies = const [];
      }
    }
    if (!mounted) return;
    setState(() {
      canCreate = widget.screenType == 1 && actions['create'] == true;
      canEdit =
          (widget.screenType == 1 || widget.screenType == 2) &&
          actions['edit'] == true;
      canDelete = widget.screenType == 1 && actions['delete'] == true;
    });
    await load();
  }

  Future<void> load({bool clearMessage = true}) async {
    if (mounted) {
      setState(() {
        loading = true;
        page = 0;
        if (clearMessage) message = null;
      });
    }
    try {
      final result = await widget.repository.get(
        search: search.text.trim(),
        companyId: companyFilterId,
      );
      if (!mounted) return;
      setState(() => items = result);
      applySort();
    } catch (error) {
      if (mounted) showMessage(widget.errorText(error), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String value, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      message = value;
      messageError = error;
    });
  }

  void sortBy(
    int index,
    Comparable<dynamic> Function(BranchRecord) selector,
    bool ascending,
  ) {
    setState(() {
      sortColumn = index;
      sortAscending = ascending;
      items = [...items]
        ..sort((a, b) {
          final value = selector(a).compareTo(selector(b));
          return ascending ? value : -value;
        });
    });
  }

  void applySort() {
    final selectors = <int, Comparable<dynamic> Function(BranchRecord)>{
      2: (item) => item.companyName.toLowerCase(),
      3: (item) => item.branchCode.toLowerCase(),
      4: (item) => item.branchNameTh.toLowerCase(),
      7: (item) => item.isActive ? 1 : 0,
    };
    final selector = selectors[sortColumn];
    if (selector != null) sortBy(sortColumn, selector, sortAscending);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(padding: t.contentMargin, child: buildList()),
          if (showForm) ...[
            const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Colors.black54),
            ),
            Positioned.fill(child: buildForm()),
          ],
          if (message != null)
            Positioned(
              top: t.contentMargin.top,
              left: t.contentMargin.left,
              right: t.contentMargin.right,
              child: Align(
                alignment: Alignment.topRight,
                child: widget.messageBuilder(
                  context,
                  message!,
                  messageError,
                  () => setState(() => message = null),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget surface(Widget child, {BorderRadius? radius}) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: radius ?? BorderRadius.circular(widget.tokens.radius),
      side: BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget buildList() {
    final t = widget.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        surface(
          Padding(
            padding: t.cardPadding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = widget.titleBuilder(
                  context,
                  widget.caption,
                  true,
                );
                final add = FilledButton.icon(
                  onPressed: canCreate ? () => openForm() : null,
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่ม'),
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      if (canCreate) ...[
                        SizedBox(height: t.cardSpacing),
                        Align(alignment: Alignment.centerRight, child: add),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    if (constraints.maxWidth >= t.compactBreakpoint) ...[
                      OutlinedButton(
                        onPressed: () => setState(() => cardMode = !cardMode),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(44, 40),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(t.radius),
                          ),
                        ),
                        child: Icon(
                          cardMode
                              ? Icons.view_list_outlined
                              : Icons.grid_view_outlined,
                        ),
                      ),
                      SizedBox(width: t.cardSpacing),
                    ],
                    if (canCreate) add,
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        surface(Padding(padding: t.cardPadding, child: buildFilters())),
        SizedBox(height: t.cardSpacing),
        Expanded(
          child: surface(
            Column(
              children: [
                if (loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (_, constraints) =>
                              constraints.maxWidth < t.compactBreakpoint ||
                                  cardMode
                              ? buildCards()
                              : buildTable(),
                        ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: t.cardSpacing),
        buildPagination(),
      ],
    );
  }

  Widget buildFilters() => Wrap(
    spacing: widget.tokens.cardSpacing,
    runSpacing: widget.tokens.cardSpacing,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 260,
        child: TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => load(),
          decoration: InputDecoration(
            labelText: 'ค้นหาสาขา',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
      ),
      SizedBox(
        width: 180,
        child: DropdownButtonFormField<String>(
          key: ValueKey(status),
          initialValue: status,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'สถานะ'),
          items: const [
            DropdownMenuItem(value: all, child: Text(all)),
            DropdownMenuItem(value: active, child: Text(active)),
            DropdownMenuItem(value: inactive, child: Text(inactive)),
          ],
          onChanged: (value) => setState(() {
            status = value ?? all;
            page = 0;
          }),
        ),
      ),
      if (!widget.companyScope)
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<int?>(
            key: ValueKey(companyFilterId),
            initialValue: companyFilterId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'ลูกค้า'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text(all)),
              ...companies.map(
                (company) => DropdownMenuItem<int?>(
                  value: company.companyId,
                  child: Text(company.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => companyFilterId = value);
              load();
            },
          ),
        ),
      FilledButton.icon(
        onPressed: load,
        icon: const Icon(Icons.search),
        label: const Text('ค้นหา'),
        style: filterButtonStyle,
      ),
      OutlinedButton.icon(
        onPressed: clearFilters,
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('ล้าง Filter'),
        style: filterButtonStyle,
      ),
    ],
  );

  ButtonStyle get filterButtonStyle => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.tokens.radius),
      ),
    ),
  );

  void clearFilters() {
    search.clear();
    setState(() {
      status = all;
      companyFilterId = null;
      page = 0;
    });
    load();
  }

  Widget buildTable() {
    if (visible.isEmpty) return const Center(child: Text('ไม่พบข้อมูลสาขา'));
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 900 ? 900 : constraints.maxWidth,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                scheme.primary.withValues(alpha: .10),
              ),
              headingTextStyle: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
              sortColumnIndex: sortColumn,
              sortAscending: sortAscending,
              horizontalMargin: 10,
              columnSpacing: 18,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: .5,
                ),
              ),
              columns: [
                const DataColumn(
                  numeric: true,
                  label: SizedBox(width: 32, child: Text('ID')),
                ),
                const DataColumn(
                  label: SizedBox(
                    width: 108,
                    child: Center(child: Text('Action')),
                  ),
                ),
                sortableColumn('ลูกค้า', 2, (x) => x.companyName.toLowerCase()),
                sortableColumn(
                  'รหัสสาขา',
                  3,
                  (x) => x.branchCode.toLowerCase(),
                ),
                sortableColumn(
                  'ชื่อสาขา',
                  4,
                  (x) => x.branchNameTh.toLowerCase(),
                ),
                const DataColumn(label: Text('ผู้ติดต่อ')),
                const DataColumn(label: Text('เบอร์โทร')),
                sortableColumn('สถานะ', 7, (x) => x.isActive ? 1 : 0),
              ],
              rows: visible.indexed
                  .map((entry) {
                    final rowNumber = (page * widget.pageSize) + entry.$1 + 1;
                    final item = entry.$2;
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 32,
                            child: Text(rowNumber.toString()),
                          ),
                        ),
                        DataCell(rowActions(item)),
                        DataCell(Text(item.companyName)),
                        DataCell(Text(item.branchCode)),
                        DataCell(Text(item.branchNameTh)),
                        DataCell(Text(orDash(item.contName))),
                        DataCell(Text(orDash(item.contPhone))),
                        DataCell(statusText(item.isActive)),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn sortableColumn(
    String label,
    int index,
    Comparable<dynamic> Function(BranchRecord) selector,
  ) => DataColumn(
    label: Text(label),
    onSort: (_, ascending) => sortBy(index, selector, ascending),
  );

  Widget buildCards() {
    if (visible.isEmpty) return const Center(child: Text('ไม่พบข้อมูลสาขา'));
    final t = widget.tokens;
    return ListView.separated(
      padding: t.cardPadding,
      itemCount: visible.length,
      separatorBuilder: (_, _) => SizedBox(height: t.itemSpacing),
      itemBuilder: (_, index) {
        final item = visible[index];
        final number = (page * widget.pageSize) + index + 1;
        return Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radius),
            side: BorderSide.none,
          ),
          child: Padding(
            padding: t.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$number. ${item.branchCode} - ${item.branchNameTh}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    rowActions(item),
                  ],
                ),
                SizedBox(height: t.itemSpacing),
                Text('ลูกค้า: ${item.companyName}'),
                SizedBox(height: t.itemSpacing),
                Wrap(
                  spacing: 16,
                  runSpacing: t.itemSpacing,
                  children: [
                    Text('ผู้ติดต่อ: ${orDash(item.contName)}'),
                    Text('โทร: ${orDash(item.contPhone)}'),
                    statusText(item.isActive),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget rowActions(BranchRecord item) => SizedBox(
    width: 108,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (canEdit)
          IconButton(
            tooltip: 'แก้ไข',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => openForm(item),
            color: Theme.of(context).colorScheme.primary,
            icon: const Icon(Icons.edit_outlined),
          ),
        if (widget.companyScope && canEdit)
          IconButton(
            tooltip: 'กำหนดผู้มีสิทธิ์',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => openAccess(item),
            color: Theme.of(context).colorScheme.primary,
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
        if (canDelete)
          IconButton(
            tooltip: 'ลบ',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => confirmDelete(item),
            color: Theme.of(context).colorScheme.error,
            icon: const Icon(Icons.delete_outline),
          ),
        if (!canEdit && !canDelete) const Text('-'),
      ],
    ),
  );

  Future<void> openAccess(BranchRecord item) async {
    BranchAccessConfiguration configuration;
    try {
      configuration = await widget.repository.access(item.branchId);
    } catch (error) {
      showMessage(widget.errorText(error), error: true);
      return;
    }
    if (!mounted) return;
    final searchController = TextEditingController();
    var mode = configuration.accessModeCode;
    var selected = configuration.users
        .where((user) => user.isSelected)
        .map((user) => user.userId)
        .toSet();
    var query = '';
    var savingAccess = false;
    String? popupMessage;
    var popupHasError = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final scheme = Theme.of(dialogContext).colorScheme;
          final visibleUsers = configuration.users
              .where((user) {
                final term = query.toLowerCase();
                return term.isEmpty ||
                    user.displayName.toLowerCase().contains(term) ||
                    user.username.toLowerCase().contains(term);
              })
              .toList(growable: false);
          final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.tokens.radius),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          );
          final buttonStyle = ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.tokens.radius),
              ),
            ),
          );
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.tokens.radius),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Padding(
                  padding: widget.tokens.cardPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.manage_accounts_outlined,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'กำหนดสิทธิ์เข้าถึงสาขา',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                      const SizedBox(height: 12),
                      Text(
                        '${configuration.branchCode} | ${configuration.branchName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(mode),
                        initialValue: mode,
                        isExpanded: true,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'การเข้าถึง *',
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide: BorderSide(
                              color: scheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ALL',
                            child: Text('ทุกคนในบริษัท'),
                          ),
                          DropdownMenuItem(
                            value: 'RESTRICTED',
                            child: Text('เฉพาะผู้เลือก'),
                          ),
                        ],
                        onChanged: savingAccess
                            ? null
                            : (value) => setDialogState(() {
                                mode = value ?? 'RESTRICTED';
                                popupMessage = null;
                                popupHasError = false;
                              }),
                      ),
                      if (mode == 'RESTRICTED') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'ค้นหาชื่อหรือ Username',
                            prefixIcon: const Icon(Icons.search),
                            border: border,
                            enabledBorder: border,
                            focusedBorder: border.copyWith(
                              borderSide: BorderSide(
                                color: scheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (value) =>
                              setDialogState(() => query = value.trim()),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: visibleUsers.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('ไม่พบผู้ใช้งาน'),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: visibleUsers.length,
                                  itemBuilder: (_, index) {
                                    final user = visibleUsers[index];
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      value: selected.contains(user.userId),
                                      title: Text(
                                        user.displayName,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        user.username,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onChanged: savingAccess
                                          ? null
                                          : (checked) => setDialogState(() {
                                              checked == true
                                                  ? selected.add(user.userId)
                                                  : selected.remove(
                                                      user.userId,
                                                    );
                                              popupMessage = null;
                                              popupHasError = false;
                                            }),
                                    );
                                  },
                                ),
                        ),
                      ],
                      if (popupMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          popupMessage!,
                          style: TextStyle(
                            color: popupHasError
                                ? scheme.error
                                : scheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: buttonStyle,
                            onPressed: savingAccess
                                ? null
                                : () => Navigator.pop(dialogContext),
                            child: const Text('ยกเลิก'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: buttonStyle,
                            onPressed: savingAccess
                                ? null
                                : () async {
                                    setDialogState(() => savingAccess = true);
                                    try {
                                      await widget.repository.updateAccess(
                                        item.branchId,
                                        accessModeCode: mode,
                                        userIds: mode == 'ALL'
                                            ? const []
                                            : selected,
                                      );
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        savingAccess = false;
                                        popupMessage = 'บันทึกสิทธิ์สาขาแล้ว';
                                        popupHasError = false;
                                      });
                                      Navigator.pop(dialogContext);
                                      showMessage('บันทึกสิทธิ์สาขาแล้ว');
                                    } catch (error) {
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        savingAccess = false;
                                        popupMessage = widget.errorText(error);
                                        popupHasError = true;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('บันทึก'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
  }

  Widget statusText(bool value) {
    final color = value
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Text(
      value ? active : inactive,
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }

  String orDash(String? value) =>
      value == null || value.trim().isEmpty ? '-' : value;

  Widget buildPagination() {
    final total = filtered.length;
    final first = total == 0 ? 0 : (page * widget.pageSize) + 1;
    final last = total == 0 ? 0 : (first + widget.pageSize - 1).clamp(0, total);
    return surface(
      SizedBox(
        height: widget.tokens.paginationHeight,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.tokens.cardPadding.left,
                ),
                child: Row(
                  children: [
                    paginationButton(
                      tooltip: 'ก่อนหน้า',
                      onPressed: page > 0 ? () => setState(() => page--) : null,
                      label: '<',
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(
                          widget.tokens.radius,
                        ),
                      ),
                      child: Text(
                        (page + 1).toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    paginationButton(
                      tooltip: 'ถัดไป',
                      onPressed: page < pageCount - 1
                          ? () => setState(() => page++)
                          : null,
                      label: '>',
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '$first-$last จาก $total',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget paginationButton({
    required String tooltip,
    required String label,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: 36,
    height: 36,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.tokens.radius),
        ),
      ),
      child: Tooltip(message: tooltip, child: Text(label)),
    ),
  );

  void openForm([BranchRecord? item]) {
    editing = item;
    code.text = item?.branchCode ?? '';
    name.text = item?.branchNameTh ?? '';
    nameEn.text = item?.branchNameEn ?? '';
    email.text = item?.email ?? '';
    telephone.text = item?.telephone ?? '';
    address.text = item?.addressText ?? '';
    contact.text = item?.contName ?? '';
    contactPhone.text = item?.contPhone ?? '';
    position.text = item?.contPositionName ?? '';
    formCompanyId =
        item?.companyId ??
        (companies.isNotEmpty ? companies.first.companyId : null);
    formActive = item?.isActive ?? true;
    setState(() {
      showForm = true;
      message = null;
    });
  }

  Widget buildForm() {
    final t = widget.tokens;
    final action = editing == null ? 'เพิ่ม' : 'แก้ไข';
    final primary = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: (constraints.maxHeight - t.contentMargin.vertical)
                .clamp(0, double.infinity)
                .toDouble(),
          ),
          child: Material(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radius),
              side: BorderSide.none,
            ),
            child: SingleChildScrollView(
              padding: t.cardPadding,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_outlined, color: primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${widget.caption} > $action',
                            style: widget.tokens.captionStyle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    ...formFields(),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: formButtons(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> formFields() => [
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('สถานะ'),
        SizedBox(width: widget.tokens.cardSpacing),
        Switch.adaptive(
          value: formActive,
          onChanged: saving
              ? null
              : (value) => setState(() => formActive = value),
        ),
        Text(formActive ? active : inactive),
      ],
    ),
    if (!widget.companyScope) ...[
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        key: ValueKey((editing?.branchId, formCompanyId)),
        initialValue: formCompanyId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'ลูกค้า *'),
        items: companies
            .map(
              (company) => DropdownMenuItem<int>(
                value: company.companyId,
                child: Text(company.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(growable: false),
        onChanged: editing != null || saving
            ? null
            : (value) => setState(() => formCompanyId = value),
        validator: (value) => value == null ? 'กรุณาเลือกลูกค้า' : null,
      ),
    ],
    const SizedBox(height: 12),
    twoFields(
      field(code, 'รหัสสาขา *', validator: requiredValue),
      field(name, 'ชื่อสาขา *', validator: requiredValue),
    ),
    const SizedBox(height: 12),
    field(nameEn, 'ชื่อสาขา (ภาษาอังกฤษ)'),
    const SizedBox(height: 12),
    twoFields(
      field(
        email,
        'อีเมล',
        keyboard: TextInputType.emailAddress,
        validator: emailValue,
      ),
      field(telephone, 'โทรศัพท์สาขา', keyboard: TextInputType.phone),
    ),
    const SizedBox(height: 12),
    field(address, 'ที่อยู่', minLines: 2, maxLines: 3),
    const SizedBox(height: 12),
    field(contact, 'ชื่อผู้ติดต่อ'),
    const SizedBox(height: 12),
    field(contactPhone, 'โทรศัพท์ผู้ติดต่อ', keyboard: TextInputType.phone),
    const SizedBox(height: 12),
    field(position, 'ตำแหน่ง'),
  ];

  Widget twoFields(Widget first, Widget second) => LayoutBuilder(
    builder: (_, constraints) {
      if (constraints.maxWidth < 400) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 12), second],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    },
  );

  Widget field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int? minLines,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    enabled: !saving,
    decoration: InputDecoration(labelText: label),
    validator: validator,
    keyboardType: keyboard,
    minLines: minLines,
    maxLines: maxLines,
  );

  String? requiredValue(String? value) =>
      value == null || value.trim().isEmpty ? 'กรุณาระบุข้อมูล' : null;

  String? emailValue(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
        ? null
        : 'รูปแบบอีเมลไม่ถูกต้อง';
  }

  Widget formButtons() {
    final canSave =
        (editing == null && canCreate) || (editing != null && canEdit);
    return Wrap(
      spacing: widget.tokens.cardSpacing,
      children: [
        OutlinedButton.icon(
          onPressed: saving ? null : closeForm,
          icon: const Icon(Icons.close),
          label: const Text('ยกเลิก'),
        ),
        if (canSave)
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('บันทึก'),
          ),
      ],
    );
  }

  void closeForm() => setState(() {
    showForm = false;
    editing = null;
    message = null;
  });

  Future<void> save() async {
    if (saving || !(formKey.currentState?.validate() ?? false)) return;
    final current = editing;
    setState(() => saving = true);
    try {
      final request = BranchUpsertRequest(
        companyId: widget.companyScope ? null : formCompanyId,
        branchCode: code.text.trim().toUpperCase(),
        branchNameTh: name.text.trim(),
        branchNameEn: nullable(nameEn.text),
        email: nullable(email.text),
        telephone: nullable(telephone.text),
        addressText: nullable(address.text),
        contName: nullable(contact.text),
        contPhone: nullable(contactPhone.text),
        contPositionName: nullable(position.text),
        isActive: formActive,
      );
      if (current == null) {
        await widget.repository.create(request);
        await load(clearMessage: false);
        editing = _findSavedBranch(
          (item) =>
              item.branchCode == request.branchCode &&
              (widget.companyScope || item.companyId == request.companyId),
        );
        if (editing != null) formCompanyId = editing!.companyId;
        showMessage('เพิ่มข้อมูลสาขาสำเร็จ');
      } else {
        await widget.repository.update(current.branchId, request);
        await load(clearMessage: false);
        editing = _findSavedBranch((item) => item.branchId == current.branchId);
        showMessage('แก้ไขข้อมูลสาขาสำเร็จ');
      }
    } catch (error) {
      showMessage(widget.errorText(error), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? nullable(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  BranchRecord? _findSavedBranch(bool Function(BranchRecord item) matches) {
    for (final item in items) {
      if (matches(item)) return item;
    }
    return null;
  }

  Future<void> confirmDelete(BranchRecord item) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: scheme.error),
            SizedBox(width: widget.tokens.cardSpacing),
            Expanded(
              child: Text('ยืนยันการลบสาขา', style: widget.tokens.captionStyle),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(widget.tokens.radius),
              ),
              child: Padding(
                padding: widget.tokens.cardPadding,
                child: Text('${item.branchCode} - ${item.branchNameTh}'),
              ),
            ),
            SizedBox(height: widget.tokens.cardSpacing),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
            const Divider(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.delete(item.branchId);
      await load(clearMessage: false);
      showMessage('ลบข้อมูลสาขาสำเร็จ');
    } catch (error) {
      showMessage(widget.errorText(error), error: true);
    }
  }
}
