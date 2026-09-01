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
          Padding(
            padding: t.contentMargin,
            child: showForm ? buildForm() : buildList(),
          ),
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

  Widget surface(Widget child, {BorderRadius? radius}) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: radius ?? BorderRadius.circular(widget.tokens.radius),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget buildList() {
    final t = widget.tokens;
    return surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    if (canCreate) add,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(padding: t.cardPadding, child: buildFilters()),
          const Divider(height: 1),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (_, constraints) =>
                        constraints.maxWidth < t.compactBreakpoint
                        ? buildCards()
                        : buildTable(),
                  ),
          ),
          const Divider(height: 1),
          buildPagination(),
        ],
      ),
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
            suffixIcon: IconButton(
              tooltip: 'ค้นหา',
              onPressed: load,
              icon: const Icon(Icons.arrow_forward),
            ),
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
      ),
      OutlinedButton.icon(
        onPressed: clearFilters,
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('ล้าง Filter'),
      ),
    ],
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: .10),
          ),
          headingTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            const DataColumn(numeric: true, label: Text('ID')),
            const DataColumn(label: Text('Action')),
            sortableColumn('ลูกค้า', 2, (x) => x.companyName.toLowerCase()),
            sortableColumn('รหัสสาขา', 3, (x) => x.branchCode.toLowerCase()),
            sortableColumn('ชื่อสาขา', 4, (x) => x.branchNameTh.toLowerCase()),
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
                    DataCell(Text(rowNumber.toString())),
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
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(t.radius),
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

  Widget rowActions(BranchRecord item) => Wrap(
    spacing: 2,
    alignment: WrapAlignment.center,
    children: [
      if (canEdit)
        IconButton(
          tooltip: 'แก้ไข',
          visualDensity: VisualDensity.compact,
          onPressed: () => openForm(item),
          color: Theme.of(context).colorScheme.primary,
          icon: const Icon(Icons.edit_outlined),
        ),
      if (canDelete)
        IconButton(
          tooltip: 'ลบ',
          visualDensity: VisualDensity.compact,
          onPressed: () => confirmDelete(item),
          color: Theme.of(context).colorScheme.error,
          icon: const Icon(Icons.delete_outline),
        ),
      if (!canEdit && !canDelete) const Text('-'),
    ],
  );

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
    return SizedBox(
      height: widget.tokens.paginationHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.tokens.cardPadding.left,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'ก่อนหน้า',
              onPressed: page > 0 ? () => setState(() => page--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(widget.tokens.radius),
              ),
              child: Text(
                (page + 1).toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'ถัดไป',
              onPressed: page < pageCount - 1
                  ? () => setState(() => page++)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                '$first-$last จาก $total',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        surface(
          Padding(
            padding: t.cardPadding,
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (_, constraints) {
                    final title = widget.titleBuilder(
                      context,
                      '${widget.caption} > $action',
                      false,
                    );
                    final buttons = formButtons();
                    if (constraints.maxWidth < 600) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          title,
                          SizedBox(height: t.cardSpacing),
                          Align(
                            alignment: Alignment.centerRight,
                            child: buttons,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: title),
                        buttons,
                      ],
                    );
                  },
                ),
                const Divider(),
              ],
            ),
          ),
          radius: BorderRadius.vertical(top: Radius.circular(t.radius)),
        ),
        Expanded(
          child: surface(
            SingleChildScrollView(
              padding: t.cardPadding,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: formFields(),
                ),
              ),
            ),
            radius: BorderRadius.vertical(bottom: Radius.circular(t.radius)),
          ),
        ),
      ],
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
    field(code, 'รหัสสาขา *', validator: requiredValue),
    const SizedBox(height: 12),
    field(name, 'ชื่อสาขา *', validator: requiredValue),
    const SizedBox(height: 12),
    field(nameEn, 'ชื่อสาขา (ภาษาอังกฤษ)'),
    const SizedBox(height: 12),
    field(
      email,
      'อีเมล',
      keyboard: TextInputType.emailAddress,
      validator: emailValue,
    ),
    const SizedBox(height: 12),
    field(telephone, 'โทรศัพท์สาขา', keyboard: TextInputType.phone),
    const SizedBox(height: 12),
    field(address, 'ที่อยู่', minLines: 2, maxLines: 3),
    const SizedBox(height: 12),
    field(contact, 'ชื่อผู้ติดต่อ'),
    const SizedBox(height: 12),
    field(contactPhone, 'โทรศัพท์ผู้ติดต่อ', keyboard: TextInputType.phone),
    const SizedBox(height: 12),
    field(position, 'ตำแหน่ง'),
  ];

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
        for (final controller in [
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
          controller.clear();
        }
        await load(clearMessage: false);
        showMessage('เพิ่มข้อมูลสาขาสำเร็จ');
      } else {
        await widget.repository.update(current.branchId, request);
        closeForm();
        await load(clearMessage: false);
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
