import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../../core/widgets/pinned_data_table.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/company_setup/company_date_formatter.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../features/support/presentation/widgets/support_workspace_shell.dart';
import '../data/customer_api.dart';
import '../data/customer_file_api.dart';
import '../../../../core/master/master_group_codes.dart';
import '../../../../features/support/master_data/data/master_data_api.dart';
import '../../../../features/profile/data/user_profile_repository.dart';
import '../../../access/sub_permission/data/sub_permission_api.dart';

String _customerError(String action, Object error) {
  final detail = error.toString().trim();
  return 'ไม่สามารถ$actionได้\nรายละเอียด: $detail';
}

class CustomerFilesDialog extends StatefulWidget {
  const CustomerFilesDialog({
    required this.customerId,
    required this.fileType,
    required this.accent,
    required this.customerName,
    required this.canEdit,
    required this.canDelete,
    super.key,
  });

  final int customerId;
  final String fileType;
  final Color accent;
  final String customerName;
  final bool canEdit;
  final bool canDelete;

  @override
  State<CustomerFilesDialog> createState() => _CustomerFilesDialogState();
}

class _CustomerFilesDialogState extends State<CustomerFilesDialog> {
  final api = CustomerFileApi();
  List<Map<String, dynamic>> files = const [];
  bool loading = true;
  bool uploading = false;
  List<int>? pendingBytes;
  String? pendingFileName;
  final description = TextEditingController();

  bool get isCard => widget.fileType == 'BUSINESS_CARD';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    api.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final result = await api.list(widget.customerId);
      if (mounted) {
        setState(
          () => files = result
              .where((x) => x['fileType'] == widget.fileType)
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _customerError('โหลดไฟล์', e),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pick() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: isCard
          ? ['jpg', 'jpeg', 'png', 'webp']
          : ['doc', 'docx', 'xls', 'xlsx', 'pdf', 'txt', 'csv'],
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    setState(() {
      pendingBytes = file.bytes;
      pendingFileName = file.name;
    });
  }

  Future<void> savePending() async {
    if (pendingBytes == null || pendingFileName == null) return;
    setState(() => uploading = true);
    try {
      await api.upload(
        widget.customerId,
        fileName: pendingFileName!,
        bytes: pendingBytes!,
        fileType: widget.fileType,
        description: description.text.trim(),
      );
      pendingBytes = null;
      pendingFileName = null;
      description.clear();
      await load();
      if (mounted) showTimedSnackBar(context, message: 'แนบไฟล์สำเร็จ');
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _customerError('แนบไฟล์', e),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> openFile(Map<String, dynamic> file) async {
    final id = (file['customerFileID'] as num?)?.toInt();
    if (id == null) return;
    try {
      final bytes = await api.downloadBytes(widget.customerId, id);
      final contentType = '${file['contentType'] ?? ''}'.toLowerCase();
      final extension = '${file['extension'] ?? ''}'.toLowerCase();
      final isImage =
          contentType.startsWith('image/') ||
          const {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension);
      if (isImage) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              minScale: .5,
              maxScale: 4,
              child: Image.memory(
                Uint8List.fromList(bytes),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      } else {
        final downloadType = contentType.isEmpty
            ? 'application/octet-stream'
            : contentType;
        await launchUrl(
          Uri.dataFromBytes(bytes, mimeType: downloadType),
          webOnlyWindowName: '_blank',
        );
      }
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _customerError('เปิดไฟล์', e),
          error: true,
        );
      }
    }
  }

  Future<void> downloadFile(Map<String, dynamic> file) async {
    final id = (file['customerFileID'] as num?)?.toInt();
    if (id == null) return;
    try {
      final bytes = await api.downloadBytes(widget.customerId, id);
      final contentType =
          '${file['contentType'] ?? 'application/octet-stream'}';
      await launchUrl(
        Uri.dataFromBytes(bytes, mimeType: contentType),
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _customerError('ดาวน์โหลดไฟล์', e),
          error: true,
        );
      }
    }
  }

  Widget filePreview(Map<String, dynamic> file) {
    final type = '${file['contentType'] ?? ''}'.toLowerCase();
    final extension = '${file['extension'] ?? ''}'.toLowerCase();
    final isImage =
        type.startsWith('image/') ||
        const {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension);
    if (!isImage) {
      return Icon(
        isCard ? Icons.badge_outlined : Icons.description_outlined,
        color: widget.accent,
      );
    }
    final id = (file['customerFileID'] as num?)?.toInt();
    if (id == null) return Icon(Icons.image_outlined, color: widget.accent);
    return FutureBuilder<List<int>>(
      future: api.downloadBytes(widget.customerId, id),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              Uint8List.fromList(snapshot.data!),
              width: 54,
              height: 54,
              fit: BoxFit.cover,
            ),
          );
        }
        return Icon(Icons.image_outlined, color: widget.accent);
      },
    );
  }

  Future<void> remove(Map<String, dynamic> file) async {
    final id = (file['customerFileID'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: widget.accent, width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: widget.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: TextStyle(
                  color: widget.accent,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ต้องการลบ ${file['originalFileName'] ?? ''} หรือไม่?',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
            const Divider(height: 24),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(foregroundColor: widget.accent),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await api.delete(widget.customerId, id);
      await load();
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _customerError('ลบไฟล์', e),
          error: true,
        );
      }
    }
  }

  Future<void> editDescription(Map<String, dynamic> file) async {
    final id = (file['customerFileID'] as num?)?.toInt();
    if (id == null) return;
    final controller = TextEditingController(
      text: '${file['description'] ?? ''}',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: widget.accent),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'แก้ไขคำอธิบาย',
              style: TextStyle(
                color: widget.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: widget.accent.withValues(alpha: .5), thickness: 1),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'คำอธิบาย',
            labelStyle: TextStyle(color: widget.accent),
            floatingLabelStyle: TextStyle(color: widget.accent),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: widget.accent.withValues(alpha: .5),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: widget.accent, width: 2),
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(foregroundColor: widget.accent),
            icon: const Icon(Icons.close),
            label: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: widget.accent,
              foregroundColor: Colors.white,
              side: BorderSide.none,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        await api.updateDescription(widget.customerId, id, controller.text);
        await load();
      } catch (e) {
        if (mounted) {
          showTimedSnackBar(
            context,
            message: _customerError('แก้ไขคำอธิบาย', e),
            error: true,
          );
        }
      }
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide.none,
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isCard ? Icons.badge_outlined : Icons.description_outlined,
              color: widget.accent,
            ),
            const SizedBox(width: 10),
            Text(
              isCard ? 'แนบนามบัตร' : 'แนบเอกสารลูกค้า',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.customerName,
            style: TextStyle(
              color: widget.accent,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(color: Color(0xFFE5E7EB), thickness: 1),
        if (pendingBytes != null) ...[
          const SizedBox(height: 10),
          if (isCard)
            InkWell(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 4,
                    child: Image.memory(
                      Uint8List.fromList(pendingBytes!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              child: SizedBox(
                height: 90,
                width: double.infinity,
                child: Image.memory(
                  Uint8List.fromList(pendingBytes!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          Text(pendingFileName ?? '', style: const TextStyle(fontSize: 14)),
          TextField(
            controller: description,
            decoration: InputDecoration(
              labelText: 'คำอธิบาย',
              labelStyle: TextStyle(color: widget.accent),
              floatingLabelStyle: TextStyle(color: widget.accent),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: widget.accent.withValues(alpha: .5),
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: widget.accent, width: 2),
              ),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ],
    ),
    content: SizedBox(
      width: 520,
      child: loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : files.isEmpty
          ? SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'ยังไม่มีไฟล์แนบ',
                  style: TextStyle(color: widget.accent),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: files.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (_, index) {
                final file = files[index];
                final isImage =
                    '${file['contentType'] ?? ''}'.toLowerCase().startsWith(
                      'image/',
                    ) ||
                    const {
                      '.jpg',
                      '.jpeg',
                      '.png',
                      '.webp',
                    }.contains('${file['extension'] ?? ''}'.toLowerCase());
                return ListTile(
                  dense: true,
                  onTap: isCard ? null : () => openFile(file),
                  leading: SizedBox(
                    width: 54,
                    height: 54,
                    child: Center(
                      child: isCard && isImage
                          ? InkWell(
                              onTap: () => openFile(file),
                              child: filePreview(file),
                            )
                          : filePreview(file),
                    ),
                  ),
                  title: GestureDetector(
                    onTap: isCard && isImage ? () => downloadFile(file) : null,
                    child: Text(
                      '${file['originalFileName'] ?? ''}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${file['extension'] ?? ''}  ${file['fileSize'] ?? 0} bytes',
                        style: const TextStyle(fontSize: 14),
                      ),
                      if ('${file['description'] ?? ''}'.trim().isNotEmpty)
                        Text(
                          'คำอธิบาย: ${file['description']}',
                          style: TextStyle(fontSize: 14, color: widget.accent),
                        ),
                    ],
                  ),
                  trailing: Wrap(
                    children: [
                      if (widget.canEdit)
                        IconButton(
                          tooltip: 'แก้ไขคำอธิบาย',
                          icon: Icon(Icons.edit_outlined, color: widget.accent),
                          onPressed: () => editDescription(file),
                        ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new_outlined),
                        onPressed: () => openFile(file),
                      ),
                      if (widget.canDelete)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => remove(file),
                        ),
                    ],
                  ),
                );
              },
            ),
    ),
    actions: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: Color(0xFFE5E7EB), thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (pendingBytes != null && widget.canEdit)
                FilledButton.icon(
                  onPressed: uploading ? null : savePending,
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    side: BorderSide.none,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('บันทึก'),
                ),
              if (pendingBytes != null && widget.canEdit)
                const SizedBox(width: 10),
              if (widget.canEdit)
                FilledButton.icon(
                  onPressed: uploading ? null : pick,
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    side: BorderSide.none,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('เพิ่มไฟล์'),
                ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: widget.accent),
                child: const Text('ปิด'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _CustomerCalendarDelegate extends GregorianCalendarDelegate {
  const _CustomerCalendarDelegate(this.buddhist);

  final bool buddhist;

  @override
  String formatMonthYear(DateTime date, MaterialLocalizations localizations) {
    final formatted = localizations.formatMonthYear(date);
    return buddhist
        ? formatted.replaceAll(date.year.toString(), '${date.year + 543}')
        : formatted;
  }

  @override
  String formatYear(int year, MaterialLocalizations localizations) =>
      buddhist ? '${year + 543}' : '$year';
}

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});
  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  static const _menuCode = '09001';
  static const _businessCardPermissionCode = '001';
  static const _customerDocumentPermissionCode = '002';
  final api = CustomerApi(), search = TextEditingController();
  final _subPermission = SubPermissionApi();
  final _master = MasterDataApi();
  final _profile = UserProfileRepository();
  List<Map<String, dynamic>> rows = [];
  Map<String, bool> actions = {};
  Set<String> _permissionPoints = const {};
  Map<String, dynamic>? editing;
  bool loading = true;
  bool _card = false;
  String? groupFilter;
  String? businessFilter;
  List<Map<String, dynamic>> _groupMasters = const [];
  List<Map<String, dynamic>> _businessMasters = const [];
  int page = 1;
  static const pageSize = 10;
  bool get _canManageBusinessCard =>
      _permissionPoints.contains('*') ||
      _permissionPoints.contains(_businessCardPermissionCode);
  bool get _canManageCustomerDocument =>
      _permissionPoints.contains('*') ||
      _permissionPoints.contains(_customerDocumentPermissionCode);
  @override
  void initState() {
    super.initState();
    load();
    _loadFilterMasters();
    _loadDefaultViewMode();
  }

  Future<void> _loadDefaultViewMode() async {
    try {
      final profile = await _profile.get();
      if (mounted) {
        setState(
          () => _card =
              profile['defaultViewMode']?.toString().toUpperCase() == 'CARD',
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    search.dispose();
    api.dispose();
    _subPermission.dispose();
    _master.dispose();
    super.dispose();
  }

  Future<void> _loadFilterMasters() async {
    try {
      final result = await Future.wait([
        _master.list(MasterGroupCodes.customerGroup),
        _master.list(MasterGroupCodes.customerBusiness),
      ]);
      if (!mounted) return;
      setState(() {
        _groupMasters = result[0];
        _businessMasters = result[1];
      });
    } catch (_) {}
  }

  String _masterDisplay(List<Map<String, dynamic>> options, String code) {
    for (final option in options) {
      if ('${option['code'] ?? ''}'.trim() == code.trim()) {
        return '${option['name'] ?? code}';
      }
    }
    return code;
  }

  Future<void> load() async {
    try {
      final r = await Future.wait([
        api.list(search: search.text, groupCode: groupFilter),
        api.actions(),
        _subPermission.currentCodes(_menuCode),
      ]);
      if (!mounted) return;
      setState(() {
        rows = List<Map<String, dynamic>>.from(r[0] as List);
        actions = Map<String, bool>.from(r[1] as Map);
        _permissionPoints = r[2] as Set<String>;
        loading = false;
        page = 1;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showTimedSnackBar(
          context,
          message: _customerError('โหลดข้อมูลลูกค้า', e),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'ข้อมูลลูกค้า',
    activeMenu: 'companyCustomers',
    menuScope: WorkspaceMenuScope.company,
    child: editing == null
        ? ColoredBox(color: const Color(0xFFF8F9FB), child: listView())
        : CustomerForm(
            initial: editing!,
            api: api,
            canManageBusinessCard: _canManageBusinessCard,
            canManageCustomerDocument: _canManageCustomerDocument,
            onCancel: () => setState(() => editing = null),
            onSaved: () {
              setState(() => editing = null);
              load();
            },
          ),
  );
  Widget listView() {
    final accent = workspaceThemeController.value.primary;
    final groups =
        rows
            .map((x) => '${x['cusGroupCode'] ?? ''}')
            .where((x) => x.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final businesses =
        rows
            .map((x) => '${x['businessTypeCode'] ?? ''}')
            .where((x) => x.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final start = (page - 1) * pageSize;
    final visible = rows.skip(start).take(pageSize).toList();
    final totalPages = rows.isEmpty ? 1 : ((rows.length - 1) ~/ pageSize) + 1;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: WorkspacePageTitle(
                  title: 'ข้อมูลลูกค้า',
                  favoriteKey: '09001',
                  titleColor: Colors.black,
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 600)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    tooltip: 'แสดงแบบการ์ด',
                    color: accent,
                    onPressed: () => setState(() => _card = !_card),
                    icon: Icon(
                      _card
                          ? Icons.view_list_outlined
                          : Icons.grid_view_outlined,
                    ),
                  ),
                ),
              if (false)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: groupFilter,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 14, height: 1.35),
                    decoration: const InputDecoration(labelText: 'กลุ่มลูกค้า'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      ...groups.map(
                        (x) => DropdownMenuItem(value: x, child: Text(x)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => groupFilter = v);
                      load();
                    },
                  ),
                ),
              const SizedBox(width: 8),
              if (false)
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: search,
                    onSubmitted: (_) => load(),
                    decoration: const InputDecoration(
                      labelText: 'ค้นหาลูกค้า',
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              const SizedBox(width: 2),
              if (actions['create'] == true)
                FilledButton.icon(
                  onPressed: () => setState(() => editing = {}),
                  style: FilledButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่ม'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth < 700
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: w,
                    child: TextField(
                      controller: search,
                      onSubmitted: (_) => load(),
                      decoration: const InputDecoration(
                        labelText: 'ค้นหาลูกค้า',
                        suffixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: DropdownButtonFormField<String>(
                      initialValue: groupFilter,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 14, height: 1.35),
                      decoration: const InputDecoration(
                        labelText: 'กลุ่มลูกค้า',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('ทั้งหมด'),
                        ),
                        ...groups.map(
                          (x) => DropdownMenuItem(
                            value: x,
                            child: Text(
                              _masterDisplay(_groupMasters, x),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => groupFilter = v);
                        load();
                      },
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: DropdownButtonFormField<String>(
                      initialValue: businessFilter,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 14, height: 1.35),
                      decoration: const InputDecoration(
                        labelText: 'ประเภทธุรกิจ',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('ทั้งหมด'),
                        ),
                        ...businesses.map(
                          (x) => DropdownMenuItem(
                            value: x,
                            child: Text(
                              _masterDisplay(_businessMasters, x),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => businessFilter = v);
                        load();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : _card
              ? _cards(visible, accent)
              : LayoutBuilder(
                  builder: (context, constraints) => _table(
                    visible,
                    accent,
                    (constraints.maxWidth - 32).clamp(0.0, double.infinity),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        _pager(totalPages, accent),
      ],
    );
  }

  Widget _table(
    List<Map<String, dynamic>> data,
    Color accent,
    double width,
  ) => SizedBox(
    width: double.infinity,
    height: 58 + (data.length * 64),
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide.none,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade300),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: PinnedDataTable(
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
              headingRowColor: WidgetStatePropertyAll(
                accent.withValues(alpha: .10),
              ),
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              columns: [
                LaooTableColumns.id,
                ...[
                  'Action',
                  'แนบไฟล์',
                  'รหัสลูกค้า',
                  'ชื่อลูกค้า',
                  'โทรศัพท์',
                ].map(
                  (h) => DataColumn(
                    label: Text(
                      h,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              rows: data
                  .map(
                    (x) => DataRow(
                      cells: [
                        DataCell(Text('${x['customerID'] ?? ''}')),
                        DataCell(
                          Wrap(
                            children: [
                              if (actions['edit'] == true)
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: accent,
                                  ),
                                  onPressed: () async {
                                    final d = await api.get(
                                      (x['customerID'] as num).toInt(),
                                    );
                                    if (mounted) setState(() => editing = d);
                                  },
                                ),
                              if (actions['delete'] == true)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => remove(x),
                                ),
                            ],
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: _canManageBusinessCard
                                    ? 'แนบนามบัตร'
                                    : 'ไม่มีสิทธิ์จัดการนามบัตร',
                                icon: Icon(
                                  _canManageBusinessCard
                                      ? (x['hasBusinessCard'] == true
                                            ? Icons.badge
                                            : Icons
                                                  .add_photo_alternate_outlined)
                                      : Icons.lock_outline,
                                  color: accent,
                                ),
                                onPressed: _canManageBusinessCard
                                    ? () => _showCustomerFiles(
                                        (x['customerID'] as num).toInt(),
                                        'BUSINESS_CARD',
                                        accent,
                                        customerName: '${x['cusName'] ?? ''}',
                                        canEdit: actions['edit'] == true,
                                        canDelete: actions['delete'] == true,
                                      )
                                    : null,
                              ),
                              IconButton(
                                tooltip: _canManageCustomerDocument
                                    ? 'แนบเอกสาร'
                                    : 'ไม่มีสิทธิ์จัดการเอกสารลูกค้า',
                                icon: Icon(
                                  _canManageCustomerDocument
                                      ? (x['hasCustomerDocument'] == true
                                            ? Icons.description
                                            : Icons.attach_file)
                                      : Icons.lock_outline,
                                  color: accent,
                                ),
                                onPressed: _canManageCustomerDocument
                                    ? () => _showCustomerFiles(
                                        (x['customerID'] as num).toInt(),
                                        'CUSTOMER_DOCUMENT',
                                        accent,
                                        customerName: '${x['cusName'] ?? ''}',
                                        canEdit: actions['edit'] == true,
                                        canDelete: actions['delete'] == true,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            '${x['cusShortCode'] ?? ''}${x['cusShortCode'] != null && '${x['cusShortCode']}'.isNotEmpty ? ' - ' : ''}${x['cusCode'] ?? ''}',
                          ),
                        ),
                        DataCell(Text('${x['cusName'] ?? ''}')),
                        DataCell(Text('${x['phone'] ?? ''}')),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _showCustomerFiles(
    int customerId,
    String fileType,
    Color accent, {
    required String customerName,
    required bool canEdit,
    required bool canDelete,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => CustomerFilesDialog(
        customerId: customerId,
        fileType: fileType,
        accent: accent,
        customerName: customerName,
        canEdit: canEdit,
        canDelete: canDelete,
      ),
    );
    if (mounted) load();
  }

  Widget _cards(
    List<Map<String, dynamic>> data,
    Color accent,
  ) => ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    itemCount: data.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (_, index) {
      final x = data[index];
      final short = '${x['cusShortCode'] ?? ''}';
      return Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$short${short.isEmpty ? '' : ' - '}${x['cusCode'] ?? ''}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${x['cusName'] ?? ''}'),
                    const SizedBox(height: 4),
                    Text(
                      '${x['phone'] ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _canManageBusinessCard
                    ? 'แนบนามบัตร'
                    : 'ไม่มีสิทธิ์จัดการนามบัตร',
                onPressed: _canManageBusinessCard
                    ? () => _showCustomerFiles(
                        (x['customerID'] as num).toInt(),
                        'BUSINESS_CARD',
                        accent,
                        customerName: '${x['cusName'] ?? ''}',
                        canEdit: actions['edit'] == true,
                        canDelete: actions['delete'] == true,
                      )
                    : null,
                icon: Icon(
                  _canManageBusinessCard
                      ? (x['hasBusinessCard'] == true
                            ? Icons.badge
                            : Icons.add_photo_alternate_outlined)
                      : Icons.lock_outline,
                  color: accent,
                ),
              ),
              IconButton(
                tooltip: _canManageCustomerDocument
                    ? 'แนบเอกสาร'
                    : 'ไม่มีสิทธิ์จัดการเอกสารลูกค้า',
                onPressed: _canManageCustomerDocument
                    ? () => _showCustomerFiles(
                        (x['customerID'] as num).toInt(),
                        'CUSTOMER_DOCUMENT',
                        accent,
                        customerName: '${x['cusName'] ?? ''}',
                        canEdit: actions['edit'] == true,
                        canDelete: actions['delete'] == true,
                      )
                    : null,
                icon: Icon(
                  _canManageCustomerDocument
                      ? (x['hasCustomerDocument'] == true
                            ? Icons.description
                            : Icons.attach_file)
                      : Icons.lock_outline,
                  color: accent,
                ),
              ),
              if (actions['edit'] == true)
                IconButton(
                  onPressed: () async {
                    final d = await api.get((x['customerID'] as num).toInt());
                    if (mounted) setState(() => editing = d);
                  },
                  icon: Icon(Icons.edit_outlined, color: accent),
                ),
              if (actions['delete'] == true)
                IconButton(
                  onPressed: () => remove(x),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _pager(int total, Color accent) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: const EdgeInsets.all(10),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    child: Row(
      children: [
        _pageButton(
          Icons.chevron_left,
          page > 1 ? () => setState(() => page--) : null,
          accent,
        ),
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _pageButton(
          Icons.chevron_right,
          page < total ? () => setState(() => page++) : null,
          accent,
        ),
      ],
    ),
  );
  Widget _pageButton(IconData icon, VoidCallback? onPressed, Color accent) =>
      Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: onPressed == null
              ? Colors.grey.shade200
              : accent.withValues(alpha: .12),
        ),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: onPressed == null ? Colors.grey : accent),
        ),
      );
  Future<void> remove(Map<String, dynamic> x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) {
        final accent = workspaceThemeController.value.primary;
        final code =
            '${x['cusShortCode'] ?? ''}${x['cusShortCode'] != null && '${x['cusShortCode']}'.isNotEmpty ? ' - ' : ''}${x['cusCode'] ?? ''}';
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 430,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_outline, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ยืนยันการลบข้อมูล',
                        style: TextStyle(
                          color: accent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ต้องการลบ $code - ${x['cusName'] ?? ''} หรือไม่?',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      style: TextButton.styleFrom(foregroundColor: accent),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(c, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('ลบ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    try {
      await api.delete((x['customerID'] as num).toInt());
      await load();
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _customerError('ลบข้อมูลลูกค้า', e),
          error: true,
        );
      }
    }
  }
}

class CustomerForm extends StatefulWidget {
  const CustomerForm({
    required this.initial,
    required this.api,
    required this.canManageBusinessCard,
    required this.canManageCustomerDocument,
    required this.onCancel,
    required this.onSaved,
    super.key,
  });
  final Map<String, dynamic> initial;
  final CustomerApi api;
  final bool canManageBusinessCard;
  final bool canManageCustomerDocument;
  final VoidCallback onCancel, onSaved;
  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final _master = MasterDataApi();
  final _fileApi = CustomerFileApi();
  List<Map<String, dynamic>> _customerGroups = const [],
      _businessTypes = const [],
      _priceLevels = const [],
      _provinces = const [],
      _paymentTypes = const [],
      _taxTypes = const [],
      _departments = const [],
      _employees = const [];
  String? _customerGroup,
      _businessType,
      _priceLevel,
      _province,
      _paymentType,
      _taxType;
  int? _salespersonEmployeeId;
  bool saving = false, _active = true;
  List<Map<String, dynamic>> _customerFiles = const [];
  bool _filesLoading = false;
  List<int>? _pendingBusinessCardBytes;
  String? _pendingBusinessCardName;
  static const names = <String, String>{
    'cusCode': 'รหัสลูกค้า',
    'cusShortCode': 'รหัสย่อ',
    'cusName': 'ชื่อลูกค้า',
    'cusAddress': 'ที่อยู่',
    'provCode': 'จังหวัด',
    'postCode': 'รหัสไปรษณีย์',
    'startDate': 'วันที่เริ่มติดต่อ',
    'cusGroupCode': 'กลุ่มลูกค้า',
    'businessTypeCode': 'ประเภทธุรกิจลูกค้า',
    'priceLevelCode': 'ระดับราคาที่ใช้',
    'website': 'Website',
    'taxID': 'เลขประจำตัวผู้เสียภาษี',
    'phone': 'โทรศัพท์',
    'email': 'Email',
    'contName1': 'ชื่อผู้ติดต่อคนที่ 1',
    'positionName1': 'ตำแหน่ง',
    'phone1': 'โทรศัพท์ผู้ติดต่อ 1',
    'email1': 'Email ผู้ติดต่อ 1',
    'contName2': 'ชื่อผู้ติดต่อคนที่ 2',
    'positionName2': 'ตำแหน่ง',
    'phone2': 'โทรศัพท์ผู้ติดต่อ 2',
    'email2': 'Email ผู้ติดต่อ 2',
    'creditDays': 'จำนวนวันเครดิต',
    'creditLimit': 'วงเงินเครดิต',
  };
  @override
  void initState() {
    super.initState();
    for (final k in names.keys) {
      fields[k] = TextEditingController(text: '${widget.initial[k] ?? ''}');
    }
    final initialDate = _parseCustomerDate(widget.initial['startDate']);
    if (initialDate != null) {
      fields['startDate']!.text = _displayCustomerDate(initialDate);
    }
    _customerGroup = widget.initial['cusGroupCode']?.toString();
    _businessType = widget.initial['businessTypeCode']?.toString();
    _priceLevel = widget.initial['priceLevelCode']?.toString();
    _province = widget.initial['provCode']?.toString();
    _paymentType = widget.initial['paymentType']?.toString();
    _taxType = widget.initial['taxType']?.toString();
    _salespersonEmployeeId = (widget.initial['salespersonEmployeeID'] as num?)
        ?.toInt();
    _active = widget.initial['isActive'] != false;
    _loadMasters();
    if (widget.initial['customerID'] != null) _loadCustomerFiles();
  }

  Future<void> _loadMasters() async {
    try {
      final result = await Future.wait([
        _master.list(MasterGroupCodes.customerGroup),
        _master.list(MasterGroupCodes.customerBusiness),
        _master.list(MasterGroupCodes.priceLevel),
        _master.list(MasterGroupCodes.province),
        widget.api.salesLookups(),
      ]);
      if (!mounted) return;
      setState(() {
        _customerGroups = List<Map<String, dynamic>>.from(result[0] as List);
        _businessTypes = List<Map<String, dynamic>>.from(result[1] as List);
        _priceLevels = List<Map<String, dynamic>>.from(result[2] as List);
        _provinces = List<Map<String, dynamic>>.from(result[3] as List);
        final sales = result[4] as Map<String, dynamic>;
        _paymentTypes = List<Map<String, dynamic>>.from(
          sales['paymentTypes'] as List? ?? const [],
        );
        _taxTypes = List<Map<String, dynamic>>.from(
          sales['taxTypes'] as List? ?? const [],
        );
        _departments = List<Map<String, dynamic>>.from(
          sales['departments'] as List? ?? const [],
        );
        _employees = List<Map<String, dynamic>>.from(
          sales['employees'] as List? ?? const [],
        );

        // โหมดเพิ่มข้อมูล: ให้ Combo เริ่มต้นที่รายการแรกเสมอ
        // โหมดแก้ไข: คงค่าที่อ่านมาจากฐานข้อมูลไว้เหมือนเดิม
        if (widget.initial['customerID'] == null) {
          _customerGroup = _firstMasterCode(_customerGroups);
          _businessType = _firstMasterCode(_businessTypes);
          _priceLevel = _firstMasterCode(_priceLevels);
          _province = _firstMasterCode(_provinces);
          _paymentType = _firstMasterCode(_paymentTypes);
          _taxType = _firstMasterCode(_taxTypes);
        }
      });
    } catch (_) {}
  }

  String? _firstMasterCode(List<Map<String, dynamic>> options) {
    if (options.isEmpty) return null;
    final value = options.first['code'] ?? options.first['masterCode'];
    final code = value?.toString().trim() ?? '';
    return code.isEmpty ? null : code;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    _master.dispose();
    _fileApi.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerFiles() async {
    final id = (widget.initial['customerID'] as num?)?.toInt();
    if (id == null) return;
    setState(() => _filesLoading = true);
    try {
      final files = await _fileApi.list(id);
      if (mounted) setState(() => _customerFiles = files);
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _customerError('โหลดไฟล์ลูกค้า', e),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _filesLoading = false);
    }
  }

  Future<void> _pickCustomerFile(String fileType) async {
    final id = (widget.initial['customerID'] as num?)?.toInt();
    if (id == null) {
      showTimedSnackBar(
        context,
        message: 'กรุณาบันทึกข้อมูลลูกค้าก่อน',
        error: true,
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: fileType == 'BUSINESS_CARD'
          ? ['jpg', 'jpeg', 'png', 'webp']
          : ['doc', 'docx', 'xls', 'xlsx', 'pdf', 'txt', 'csv'],
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    if (fileType == 'BUSINESS_CARD') {
      setState(() {
        _pendingBusinessCardBytes = file.bytes;
        _pendingBusinessCardName = file.name;
      });
    }
    try {
      await _fileApi.upload(
        id,
        fileName: file.name,
        bytes: file.bytes!,
        fileType: fileType,
      );
      await _loadCustomerFiles();
      if (mounted) showTimedSnackBar(context, message: 'แนบไฟล์สำเร็จ');
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _customerError('แนบไฟล์', e),
          error: true,
        );
      }
    }
  }

  Future<void> _deleteCustomerFile(Map<String, dynamic> file) async {
    final customerId = (widget.initial['customerID'] as num?)?.toInt();
    final fileId = (file['customerFileID'] as num?)?.toInt();
    if (customerId == null || fileId == null) return;
    try {
      await _fileApi.delete(customerId, fileId);
      await _loadCustomerFiles();
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _customerError('ลบไฟล์', e),
          error: true,
        );
      }
    }
  }

  Future<void> _openCustomerFile(Map<String, dynamic> file) async {
    final customerId = (widget.initial['customerID'] as num?)?.toInt();
    final fileId = (file['customerFileID'] as num?)?.toInt();
    if (customerId == null || fileId == null) return;
    try {
      final bytes = await _fileApi.downloadBytes(customerId, fileId);
      final type = '${file['contentType'] ?? 'application/octet-stream'}';
      if (type.startsWith('image/')) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              minScale: .5,
              maxScale: 4,
              child: Image.memory(
                Uint8List.fromList(bytes),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
        return;
      }
      final uri = Uri.dataFromBytes(bytes, mimeType: type);
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _customerError('เปิดไฟล์', e),
          error: true,
        );
      }
    }
  }

  Future<void> save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    final b = <String, dynamic>{
      for (final e in fields.entries)
        if (e.key != 'creditDays' && e.key != 'creditLimit')
          e.key: e.value.text.trim(),
      'cusGroupCode': _customerGroup,
      'businessTypeCode': _businessType,
      'priceLevelCode': _priceLevel,
      'provCode': _province,
      'startDate': _apiCustomerDate(fields['startDate']?.text),
      'paymentType': _paymentType,
      'taxType': _taxType,
      'creditDays': int.tryParse(fields['creditDays']?.text.trim() ?? ''),
      'creditLimit': double.tryParse(fields['creditLimit']?.text.trim() ?? ''),
      'salespersonEmployeeID': _salespersonEmployeeId,
      'isActive': _active,
    };
    try {
      final id = widget.initial['customerID'];
      if (id == null) {
        await widget.api.create(b);
      } else {
        await widget.api.update((id as num).toInt(), b);
      }
      if (mounted) {
        showTimedSnackBar(context, message: 'บันทึกข้อมูลลูกค้าสำเร็จ');
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        showTimedSnackBar(
          context,
          message: _customerError('บันทึกข้อมูลลูกค้า', e),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: ColoredBox(
      color: const Color(0xFFF8F9FB),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: WorkspaceActionHeader(
                title:
                    'ข้อมูลลูกค้า > ${widget.initial['customerID'] == null ? 'เพิ่ม' : 'แก้ไข'}',
                favoriteKey: '09001',
                actions: [
                  const Text('สถานะติดต่อ'),
                  Switch(
                    value: _active,
                    onChanged: (value) => setState(() => _active = value),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('ยกเลิก'),
                  ),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('บันทึก'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 12.0;
                        final compact = constraints.maxWidth < 720;
                        final fieldWidth = compact
                            ? constraints.maxWidth
                            : (constraints.maxWidth - (gap * 2)) / 3;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            _combo(
                              'กลุ่มลูกค้า',
                              _customerGroup,
                              _customerGroups,
                              (v) => setState(() => _customerGroup = v),
                              width: fieldWidth,
                            ),
                            _combo(
                              'ประเภทธุรกิจลูกค้า',
                              _businessType,
                              _businessTypes,
                              (v) => setState(() => _businessType = v),
                              width: fieldWidth,
                            ),
                            _combo(
                              'ระดับราคาขาย',
                              _priceLevel,
                              _priceLevels,
                              (v) => setState(() => _priceLevel = v),
                              width: fieldWidth,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (false)
                    SizedBox(
                      width: ((MediaQuery.sizeOf(context).width - 80) / 4)
                          .clamp(180.0, 280.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('สถานะติดต่อ'),
                          const SizedBox(width: 6),
                          Switch(
                            value: _active,
                            onChanged: (value) =>
                                setState(() => _active = value),
                          ),
                        ],
                      ),
                    ),
                  if (false)
                    _combo(
                      'กลุ่มลูกค้า',
                      _customerGroup,
                      _customerGroups,
                      (v) => setState(() => _customerGroup = v),
                    ),
                  if (false)
                    _combo(
                      'ประเภทธุรกิจลูกค้า',
                      _businessType,
                      _businessTypes,
                      (v) => setState(() => _businessType = v),
                    ),
                  if (false)
                    _combo(
                      'ระดับราคาขาย',
                      _priceLevel,
                      _priceLevels,
                      (v) => setState(() => _priceLevel = v),
                    ),
                  if (false)
                    SizedBox(
                      width: ((MediaQuery.sizeOf(context).width - 80) / 4)
                          .clamp(180.0, 280.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('สถานะติดต่อ'),
                          const SizedBox(width: 6),
                          Switch(
                            value: _active,
                            onChanged: (value) =>
                                setState(() => _active = value),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 12.0;
                        final compact = constraints.maxWidth < 720;
                        final codeWidth = compact
                            ? constraints.maxWidth
                            : constraints.maxWidth * 0.18;
                        final shortCodeWidth = compact
                            ? constraints.maxWidth
                            : constraints.maxWidth * 0.14;
                        final nameWidth = compact
                            ? constraints.maxWidth
                            : constraints.maxWidth -
                                  codeWidth -
                                  shortCodeWidth -
                                  (gap * 2);
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            SizedBox(
                              width: codeWidth,
                              child: TextFormField(
                                controller: fields['cusCode'],
                                decoration: const InputDecoration(
                                  labelText: 'รหัสลูกค้า',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'กรุณาระบุรหัสลูกค้า'
                                    : null,
                              ),
                            ),
                            SizedBox(
                              width: shortCodeWidth,
                              child: TextField(
                                controller: fields['cusShortCode'],
                                decoration: const InputDecoration(
                                  labelText: 'รหัสย่อ',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: nameWidth,
                              child: TextFormField(
                                controller: fields['cusName'],
                                decoration: const InputDecoration(
                                  labelText: 'ชื่อลูกค้า',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'กรุณาระบุชื่อลูกค้า'
                                    : null,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (false)
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: fields['cusCode'],
                        decoration: const InputDecoration(
                          labelText: 'รหัสลูกค้า',
                        ),
                      ),
                    ),
                  if (false)
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: fields['cusShortCode'],
                        decoration: const InputDecoration(labelText: 'รหัสย่อ'),
                      ),
                    ),
                  if (false)
                    SizedBox(
                      width: 500,
                      child: TextField(
                        controller: fields['cusName'],
                        decoration: const InputDecoration(
                          labelText: 'ชื่อลูกค้า',
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: fields['cusAddress'],
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'ที่อยู่'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 12.0;
                        final compact = constraints.maxWidth < 720;
                        final fieldWidth = compact
                            ? constraints.maxWidth
                            : (constraints.maxWidth - (gap * 2)) / 3;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            _combo(
                              'จังหวัด',
                              _province,
                              _provinces,
                              (v) => setState(() => _province = v),
                              width: fieldWidth,
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: TextField(
                                controller: fields['postCode'],
                                decoration: const InputDecoration(
                                  labelText: 'รหัสไปรษณีย์',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: TextField(
                                controller: fields['startDate'],
                                readOnly: true,
                                onTap: _pickStartDate,
                                decoration: const InputDecoration(
                                  labelText: 'วันที่เริ่มติดต่อ',
                                  suffixIcon: Icon(
                                    Icons.calendar_month_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  _customerFieldRow([
                    {'key': 'phone', 'label': 'โทรศัพท์'},
                    {'key': 'email', 'label': 'Email'},
                    {'key': 'website', 'label': 'Website'},
                  ]),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 12.0;
                      final width = constraints.maxWidth < 720
                          ? constraints.maxWidth
                          : (constraints.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          _combo(
                            'ประเภทภาษี',
                            _taxType,
                            _taxTypes,
                            (value) => setState(() => _taxType = value),
                            width: width,
                          ),
                          SizedBox(
                            width: width,
                            child: TextField(
                              controller: fields['taxID'],
                              decoration: const InputDecoration(
                                labelText: 'เลขประจำตัวผู้เสียภาษี',
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 24,
                          child: Divider(color: Color(0xFFE5E7EB)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, right: 12),
                          child: Text(
                            'ผู้ติดต่อ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: workspaceThemeController.value.primary,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: Color(0xFFE5E7EB)),
                        ),
                      ],
                    ),
                  ),
                  _customerFieldRow([
                    {'key': 'contName1', 'label': 'ผู้ติดต่อคนที่ 1'},
                    {'key': 'positionName1', 'label': 'ตำแหน่ง'},
                    {'key': 'phone1', 'label': 'โทรศัพท์ผู้ติดต่อ 1'},
                    {'key': 'email1', 'label': 'Email คนที่ 1'},
                  ]),
                  _customerFieldRow([
                    {'key': 'contName2', 'label': 'ผู้ติดต่อคนที่ 2'},
                    {'key': 'positionName2', 'label': 'ตำแหน่ง'},
                    {'key': 'phone2', 'label': 'โทรศัพท์ผู้ติดต่อ 2'},
                    {'key': 'email2', 'label': 'Email คนที่ 2'},
                  ]),
                  const SizedBox(height: 14),
                  _sectionTitle('การขาย'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 12.0;
                        final compact = constraints.maxWidth < 720;
                        final width = compact
                            ? constraints.maxWidth
                            : (constraints.maxWidth - (gap * 3)) / 4;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            _salespersonField(width),
                            _combo(
                              'ประเภทชำระเงิน',
                              _paymentType,
                              _paymentTypes,
                              (value) => setState(() => _paymentType = value),
                              width: width,
                            ),
                            SizedBox(
                              width: width,
                              child: TextField(
                                controller: fields['creditDays'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'จำนวนวันเครดิต',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: TextField(
                                controller: fields['creditLimit'],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'วงเงินเครดิต',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (false)
                    SizedBox(
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('สถานะติดต่อ'),
                            const SizedBox(width: 8),
                            Switch(
                              value: _active,
                              onChanged: (value) =>
                                  setState(() => _active = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (false)
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: fields['cusCode'],
                        decoration: InputDecoration(
                          labelText: names['cusCode'],
                        ),
                      ),
                    ),
                  if (false)
                    _combo(
                      'กลุ่มลูกค้า',
                      _customerGroup,
                      _customerGroups,
                      (v) => setState(() => _customerGroup = v),
                    ),
                  if (false)
                    _combo(
                      'ประเภทธุรกิจลูกค้า',
                      _businessType,
                      _businessTypes,
                      (v) => setState(() => _businessType = v),
                    ),
                  if (false)
                    _combo(
                      'ระดับราคาขาย',
                      _priceLevel,
                      _priceLevels,
                      (v) => setState(() => _priceLevel = v),
                    ),
                  for (final e in names.entries)
                    if (!{
                      'cusGroupCode',
                      'businessTypeCode',
                      'priceLevelCode',
                      'cusCode',
                      'cusShortCode',
                      'cusName',
                      'cusAddress',
                      'provCode',
                      'postCode',
                      'startDate',
                      'website',
                      'taxID',
                      'creditDays',
                      'creditLimit',
                      'phone',
                      'email',
                      'contName1',
                      'positionName1',
                      'phone1',
                      'email1',
                      'contName2',
                      'positionName2',
                      'phone2',
                      'email2',
                    }.contains(e.key))
                      SizedBox(
                        width: e.key == 'cusAddress' ? 500 : 220,
                        child: TextField(
                          controller: fields[e.key],
                          decoration: InputDecoration(labelText: e.value),
                          maxLines: e.key == 'cusAddress' ? 2 : 1,
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

  Future<void> _pickStartDate() async {
    final current = _parseCustomerDate(fields['startDate']?.text);
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      calendarDelegate: _CustomerCalendarDelegate(_usesBuddhistYear),
    );
    if (selected == null || !mounted) return;
    fields['startDate']?.text = _displayCustomerDate(selected);
  }

  DateTime? _parseCustomerDate(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    var year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (_usesBuddhistYear && year > 2400) year -= 543;
    return DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );
  }

  String _displayCustomerDate(DateTime value) =>
      CompanyDateFormatter.formatDateByYearFormat(
        value,
        companySetupController.current?.yearFormat ?? 'C',
      );

  bool get _usesBuddhistYear {
    switch ((companySetupController.current?.yearFormat ?? 'C')
        .trim()
        .toUpperCase()) {
      case 'B':
      case 'BE':
      case 'T':
      case 'TH':
      case 'THAI':
        return true;
      default:
        return false;
    }
  }

  String? _apiCustomerDate(String? value) {
    final date = _parseCustomerDate(value);
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Widget _sectionTitle(String text) => Row(
    children: [
      const SizedBox(width: 24, child: Divider(color: Color(0xFFE5E7EB))),
      Padding(
        padding: const EdgeInsets.only(left: 8, right: 12),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: workspaceThemeController.value.primary,
          ),
        ),
      ),
      const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
    ],
  );

  Map<String, dynamic>? get _selectedSalesperson {
    for (final employee in _employees) {
      if ((employee['employeeId'] as num?)?.toInt() == _salespersonEmployeeId) {
        return employee;
      }
    }
    return null;
  }

  String get _salespersonLabel {
    final employee = _selectedSalesperson;
    if (employee == null) return 'เลือกพนักงานขาย';
    final code = '${employee['employeeCode'] ?? ''}'.trim();
    final name = '${employee['fullName'] ?? ''}'.trim();
    final nick = '${employee['nickName'] ?? ''}'.trim();
    return '$code - $name${nick.isEmpty ? '' : ' | $nick'}';
  }

  Widget _salespersonField(double width) => SizedBox(
    width: width,
    child: InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: _showSalespersonPicker,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'ผู้รับผิดชอบการขาย',
          suffixIcon: Icon(Icons.search_outlined),
        ),
        child: Text(
          _salespersonLabel,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );

  Future<void> _showSalespersonPicker() async {
    int? departmentId;
    String query = '';
    final search = TextEditingController();
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final rows = _employees.where((employee) {
            final matchesDepartment =
                departmentId == null ||
                (employee['departmentId'] as num?)?.toInt() == departmentId;
            final text =
                '${employee['employeeCode'] ?? ''} '
                        '${employee['fullName'] ?? ''} ${employee['nickName'] ?? ''}'
                    .toLowerCase();
            return matchesDepartment && text.contains(query.toLowerCase());
          }).toList();
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_search_outlined,
                      color: workspaceThemeController.value.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'เลือกผู้รับผิดชอบการขาย',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE5E7EB), height: 1),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: departmentId,
                    decoration: const InputDecoration(labelText: 'แผนก'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ทุกแผนก'),
                      ),
                      ..._departments.map(
                        (department) => DropdownMenuItem<int?>(
                          value: (department['departmentId'] as num?)?.toInt(),
                          child: Text(
                            '${department['departmentName'] ?? department['departmentCode'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => departmentId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: search,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'ค้นหาพนักงาน',
                      prefixIcon: Icon(Icons.search_outlined),
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final employee = rows[index];
                        final nick = '${employee['nickName'] ?? ''}'.trim();
                        return ListTile(
                          tileColor: Colors.white,
                          onTap: () => Navigator.pop(dialogContext, employee),
                          title: Text(
                            '${employee['employeeCode'] ?? ''} - ${employee['fullName'] ?? ''}',
                          ),
                          subtitle: Text(
                            '${employee['departmentName'] ?? 'ไม่ระบุแผนก'}${nick.isEmpty ? '' : ' | $nick'}',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(dialogContext),
                style: OutlinedButton.styleFrom(
                  foregroundColor: workspaceThemeController.value.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                icon: const Icon(Icons.close),
                label: const Text('ยกเลิก'),
              ),
            ],
          );
        },
      ),
    );
    search.dispose();
    if (selected != null && mounted) {
      setState(() {
        _salespersonEmployeeId = (selected['employeeId'] as num?)?.toInt();
      });
    }
  }

  Widget _customerFieldRow(List<Map<String, String>> specs) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 12.0;
      final fieldWidth = constraints.maxWidth < 720
          ? constraints.maxWidth
          : (constraints.maxWidth - (gap * (specs.length - 1))) / specs.length;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: specs
            .map(
              (spec) => SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: fields[spec['key']],
                  decoration: InputDecoration(labelText: spec['label']),
                ),
              ),
            )
            .toList(),
      );
    },
  );

  Widget _customerFilesSection() {
    final accent = workspaceThemeController.value.primary;
    final businessCards = widget.canManageBusinessCard
        ? _customerFiles
              .where((file) => file['fileType'] == 'BUSINESS_CARD')
              .toList()
        : <Map<String, dynamic>>[];
    final documents = widget.canManageCustomerDocument
        ? _customerFiles
              .where((file) => file['fileType'] == 'CUSTOMER_DOCUMENT')
              .toList()
        : <Map<String, dynamic>>[];
    Widget fileList(List<Map<String, dynamic>> files) => Column(
      children: files
          .map(
            (file) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: () => _openCustomerFile(file),
              leading: Icon(
                file['fileType'] == 'BUSINESS_CARD'
                    ? Icons.badge_outlined
                    : Icons.description_outlined,
              ),
              title: Text(
                '${file['originalFileName'] ?? ''}',
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
              subtitle: Text(
                '${file['extension'] ?? ''}  ${file['fileSize'] ?? 0} bytes',
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'เปิดไฟล์',
                    icon: const Icon(Icons.open_in_new_outlined),
                    onPressed: () => _openCustomerFile(file),
                  ),
                  IconButton(
                    tooltip: 'ลบไฟล์',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteCustomerFile(file),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(
                width: 24,
                child: Divider(color: Color(0xFFE5E7EB)),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 12),
                child: Text(
                  'ไฟล์และเอกสารลูกค้า',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: workspaceThemeController.value.primary,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              widget.canManageBusinessCard
                  ? OutlinedButton.icon(
                      onPressed: _filesLoading
                          ? null
                          : () => _pickCustomerFile('BUSINESS_CARD'),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('แนบนามบัตร'),
                    )
                  : IconButton(
                      tooltip: 'ไม่มีสิทธิ์จัดการนามบัตร',
                      onPressed: null,
                      icon: Icon(Icons.lock_outline, color: accent),
                    ),
              widget.canManageCustomerDocument
                  ? OutlinedButton.icon(
                      onPressed: _filesLoading
                          ? null
                          : () => _pickCustomerFile('CUSTOMER_DOCUMENT'),
                      icon: const Icon(Icons.attach_file),
                      label: const Text('แนบเอกสารลูกค้า'),
                    )
                  : IconButton(
                      tooltip: 'ไม่มีสิทธิ์จัดการเอกสารลูกค้า',
                      onPressed: null,
                      icon: Icon(Icons.lock_outline, color: accent),
                    ),
            ],
          ),
          if (_filesLoading) const LinearProgressIndicator(),
          if (_pendingBusinessCardBytes != null) ...[
            const SizedBox(height: 8),
            const Text('ตัวอย่างนามบัตรที่เลือก'),
            InkWell(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 4,
                    child: Image.memory(
                      Uint8List.fromList(_pendingBusinessCardBytes!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              child: SizedBox(
                width: 180,
                height: 110,
                child: Image.memory(
                  Uint8List.fromList(_pendingBusinessCardBytes!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Text(
              _pendingBusinessCardName ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ],
          if (businessCards.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('นามบัตร'),
            fileList(businessCards),
          ],
          if (documents.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('เอกสารลูกค้า'),
            fileList(documents),
          ],
          const SizedBox(height: 4),
          const Text(
            'รองรับรูปภาพนามบัตร และเอกสาร Word, Excel, PDF, TXT, CSV ขนาดไม่เกิน 10 MB ต่อไฟล์',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _combo(
    String label,
    String? value,
    List<Map<String, dynamic>> options,
    ValueChanged<String?> onChanged, {
    double? width,
  }) {
    final valid =
        options.any((x) => '${x['code'] ?? x['masterCode'] ?? ''}' == value)
        ? value
        : null;
    final comboWidth = ((MediaQuery.sizeOf(context).width - 80) / 3).clamp(
      180.0,
      420.0,
    );
    return SizedBox(
      width: width ?? comboWidth,
      child: DropdownButtonFormField<String>(
        initialValue: valid,
        isExpanded: true,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          labelText: '* $label',
          labelStyle: const TextStyle(fontSize: 14),
        ),
        items: options.map((x) {
          final code = '${x['code'] ?? x['masterCode'] ?? ''}';
          final name = '${x['name'] ?? x['masterName'] ?? code}';
          return DropdownMenuItem(
            value: code,
            child: Text(
              name,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        validator: (v) => v == null || v.isEmpty ? 'กรุณาเลือก$label' : null,
        onChanged: options.isEmpty ? null : onChanged,
      ),
    );
  }
}
