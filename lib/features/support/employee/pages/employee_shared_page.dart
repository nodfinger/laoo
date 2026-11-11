import 'dart:typed_data';
import 'dart:convert';

import 'employee_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_date_formatter.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/master/master_group_codes.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../access/role_group/data/role_group_repository.dart';
import '../../../access/role_group/models/role_group.dart';
import '../../../access/role_group/pages/role_group_page.dart';
import '../../../partner/models/partner_company.dart';
import '../../../partner/data/partner_company_repository.dart';
import '../../master_data/data/master_data_api.dart';
import '../../master_data/pages/master_data_page.dart';
import '../../master_data/pages/simple_master_search_dialog.dart';
import '../../organization/data/organization_repository.dart' as local_org;
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/employee_repository.dart' as local_employee;

class EmployeeUxPage extends StatefulWidget {
  const EmployeeUxPage({
    super.key,
    this.customer = false,
    this.companyScoped = false,
    this.menuScope = WorkspaceMenuScope.support,
  });

  final bool customer;
  final bool companyScoped;
  final WorkspaceMenuScope menuScope;

  @override
  State<EmployeeUxPage> createState() => _EmployeeUxPageState();
}

class _EmployeeUxPageState extends State<EmployeeUxPage> {
  late final ApiClient _api;
  late final EmployeeOwnerScope _employeeScope;
  late final LaooOwnerScope _ownerScope;
  late final ScreenContract _contract;
  late final local_employee.EmployeeRepository _repository;
  late final local_org.OrganizationRepository _organizationRepository;
  late final PartnerCompanyRepository _companyRepository;
  late final RoleGroupRepository _roleGroupRepository;
  late final MasterDataApi _masterDataApi;
  late final MasterDataApi _positionMasterApi;
  late final MasterDataApi _vehicleMasterApi;

  String _caption = 'พนักงาน';
  String _organizationCaption = 'โครงสร้างองค์กร';
  bool _canManageRoleGroups = false;
  bool _canManageVehicleMaster = false;
  bool _canChangeMasterData = false;
  bool _canOpenPositionLookup = false;
  bool _canShowEmployeeImages = false;
  bool _canSetEmployeeSignature = false;
  String? _signatureMessage;
  bool _signatureMessageError = false;
  int _signatureMessageId = 0;
  bool _loading = true;
  Object? _loadError;
  List<EmployeeCompanyOption> _companies = const [];
  List<OrganizationUnitRecord> _organizationUnits = const [];
  int _organizationMode = 1;
  List<EmployeeRoleGroupOption> _roleGroups = const [];
  List<EmployeeMasterOption> _carTypes = const [];
  List<EmployeeMasterOption> _oilTypes = const [];
  List<EmployeeMasterOption> _positions = const [];

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _employeeScope = widget.companyScoped
        ? EmployeeOwnerScope.company
        : widget.customer
        ? EmployeeOwnerScope.partnerCustomer
        : EmployeeOwnerScope.partner;
    _ownerScope = switch (widget.menuScope) {
      WorkspaceMenuScope.support => LaooOwnerScope.support,
      WorkspaceMenuScope.partner => LaooOwnerScope.partner,
      WorkspaceMenuScope.company => LaooOwnerScope.company,
    };
    _contract = EmployeeScreenContracts.forScope(_employeeScope);
    _repository = local_employee.EmployeeRepository(
      scope: _employeeScope,
      api: _api,
    );
    _organizationRepository = local_org.OrganizationRepository(
      scope: _ownerScope,
      api: _api,
    );
    _companyRepository = PartnerCompanyRepository(apiClient: _api);
    _roleGroupRepository = RoleGroupRepository(client: _api);
    _masterDataApi = MasterDataApi(apiClient: _api);
    _positionMasterApi = MasterDataApi(
      apiClient: _api,
      lookup: widget.companyScoped ? 'employee-position' : null,
    );
    _vehicleMasterApi = MasterDataApi(
      apiClient: _api,
      lookup: widget.companyScoped ? 'employee-vehicle' : null,
    );
    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final results = await Future.wait<Object?>([
        NavigationMenuRepository(apiClient: _api)
            .resolveMenuName(
              menuCode: _contract.menuCode,
              routeName: _contract.routeName,
              fallback: _caption,
            )
            .catchError((_) => _caption),
        widget.companyScoped
            ? _repository.organizationOptions()
            : _organizationRepository.load(),
        _roleGroupRepository
            .list(
              widget.customer || widget.companyScoped ? 'customer' : 'partner',
            )
            .catchError((_) => const <RoleGroup>[]),
        widget.companyScoped
            ? _vehicleMasterApi.list(MasterGroupCodes.carType)
            : _vehicleMasterApi
                  .list(MasterGroupCodes.carType)
                  .catchError((_) => const <Map<String, dynamic>>[]),
        widget.companyScoped
            ? _vehicleMasterApi.list(MasterGroupCodes.oilType)
            : _vehicleMasterApi
                  .list(MasterGroupCodes.oilType)
                  .catchError((_) => const <Map<String, dynamic>>[]),
        widget.customer && !widget.companyScoped
            ? _companyRepository
                  .getCompanies(support: _ownerScope == LaooOwnerScope.support)
                  .catchError((_) => const <PartnerCompany>[])
            : Future.value(const <dynamic>[]),
        NavigationMenuRepository(apiClient: _api)
            .resolveMenuName(
              menuCode: _organizationRepository.contract.menuCode,
              routeName: _organizationRepository.contract.routeName,
              fallback: _organizationCaption,
            )
            .catchError((_) => _organizationCaption),
        _roleGroupRepository
            .actions(
              widget.customer || widget.companyScoped ? 'customer' : 'partner',
            )
            .catchError((_) => <String, bool>{}),
        _masterDataApi.actions().catchError((_) => <String, bool>{}),
        _positionMasterApi
            .list(MasterGroupCodes.position)
            .catchError((_) => const <Map<String, dynamic>>[]),
        widget.companyScoped
            ? _api
                  .get(
                    '/api/company/sub-permissions/current',
                    query: {'menuCode': _contract.menuCode},
                  )
                  .then(
                    (value) => (value as List).map((e) => e.toString()).toSet(),
                  )
                  .catchError((_) => <String>{})
            : Future.value(<String>{}),
      ]);
      final organization = results[1] as OrganizationStructureSnapshot;
      final roleGroups = results[2] as List;
      final carTypes = results[3] as List;
      final oilTypes = results[4] as List;
      final companies = results[5] as List;
      final roleActions = results[7] as Map<String, bool>;
      final masterActions = results[8] as Map<String, bool>;
      final positions = results[9] as List;
      final imagePermissions = results[10] as Set<String>;
      if (!mounted) return;
      setState(() {
        _caption = (results[0] as String).trim();
        _canShowEmployeeImages =
            imagePermissions.contains('*') ||
            imagePermissions.contains('SHOW_EMPLOYEE_IMAGE');
        _canSetEmployeeSignature =
            imagePermissions.contains('*') ||
            imagePermissions.contains('MANAGE_EMPLOYEE_SIGNATURE');
        _organizationCaption = (results[6] as String).trim();
        _canChangeMasterData =
            masterActions['view'] == true &&
            (masterActions['create'] == true ||
                masterActions['edit'] == true ||
                masterActions['delete'] == true);
        _canManageVehicleMaster =
            widget.companyScoped ||
            (!(widget.customer && !widget.companyScoped) &&
                masterActions['view'] == true);
        _canOpenPositionLookup =
            widget.companyScoped ||
            (!(widget.customer && !widget.companyScoped) &&
                masterActions['view'] == true);
        _canManageRoleGroups =
            !(widget.customer && !widget.companyScoped) &&
            roleActions['view'] == true;
        _organizationUnits = organization.units;
        _organizationMode = organization.orgStructureType;
        _roleGroups = roleGroups
            .where((value) => value.isActive == true)
            .map(
              (value) => EmployeeRoleGroupOption(
                id: value.id as int,
                name: value.name as String,
              ),
            )
            .toList(growable: false);
        _carTypes = _masterOptions(carTypes);
        _oilTypes = _masterOptions(oilTypes);
        _positions = _masterOptions(positions);
        _companies = companies
            .map(
              (value) => EmployeeCompanyOption(
                id: value.companyId as int,
                name: value.companyNameTh as String,
              ),
            )
            .toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<List<EmployeeMasterOption>?> _manageMasterGroup(
    String groupCode,
  ) async {
    final actions = await _masterDataApi.actions().catchError(
      (_) => <String, bool>{},
    );
    if (!mounted) return null;
    final positionLookup = groupCode == MasterGroupCodes.position;
    final vehicleLookup =
        groupCode == MasterGroupCodes.carType ||
        groupCode == MasterGroupCodes.oilType;
    if (actions['view'] != true &&
        !((positionLookup || vehicleLookup) && widget.companyScoped)) {
      throw StateError('ไม่มีสิทธิ์ดูรหัสพื้นฐาน กรุณาติดต่อผู้ดูแลระบบ');
    }
    final simple =
        actions['view'] != true ||
        !(actions['create'] == true ||
            actions['edit'] == true ||
            actions['delete'] == true);
    final source = positionLookup
        ? _positionMasterApi
        : vehicleLookup
        ? _vehicleMasterApi
        : _masterDataApi;
    final rows = simple
        ? await source.list(groupCode)
        : <Map<String, dynamic>>[];
    if (!mounted) return null;
    final selectedCode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => simple
          ? SimpleMasterSearchDialog(
              title: positionLookup
                  ? 'ตำแหน่ง'
                  : groupCode == MasterGroupCodes.carType
                  ? 'ประเภทรถ'
                  : 'เชื้อเพลิง',
              rows: rows,
            )
          : Theme(
              data: workspaceThemeController.value.toThemeData(),
              child: Dialog(
                insetPadding: const EdgeInsets.all(24),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
                child: SizedBox(
                  width: 1000,
                  height: (MediaQuery.sizeOf(dialogContext).height - 48).clamp(
                    0.0,
                    700.0,
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'ปิดหน้าจัดการรหัสพื้นฐาน',
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      Expanded(
                        child: MasterDataPage(
                          menuScope: widget.menuScope,
                          embedded: true,
                          masterGroupCode: groupCode,
                          simpleWhenReadOnly: true,
                          onSelected: (code) =>
                              Navigator.of(dialogContext).pop(code),
                          api:
                              widget.companyScoped &&
                                  (positionLookup || vehicleLookup)
                              ? MasterDataApi(
                                  lookup: positionLookup
                                      ? 'employee-position'
                                      : 'employee-vehicle',
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
    final loadedOptions = _masterOptions(
      await (positionLookup
              ? _positionMasterApi
              : vehicleLookup
              ? _vehicleMasterApi
              : _masterDataApi)
          .list(groupCode),
    );
    final options = loadedOptions
        .map(
          (option) => EmployeeMasterOption(
            code: option.code,
            name: option.name,
            selected: option.code == selectedCode,
          ),
        )
        .toList(growable: false);
    if (mounted) {
      setState(() {
        if (groupCode == MasterGroupCodes.position) {
          _positions = options;
        } else if (groupCode == MasterGroupCodes.carType) {
          _carTypes = options;
        } else {
          _oilTypes = options;
        }
      });
    }
    return options;
  }

  Future<List<EmployeeRoleGroupOption>?> _manageRoleGroups() async {
    final scope = widget.customer || widget.companyScoped
        ? 'customer'
        : 'partner';
    final actions = await _roleGroupRepository.actions(scope);
    if (!mounted) return null;
    if (actions['view'] != true) {
      setState(() => _canManageRoleGroups = false);
      throw StateError('ไม่มีสิทธิ์จัดการกลุ่มสิทธิ์ กรุณาติดต่อผู้ดูแลระบบ');
    }
    final selectedId = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Theme(
        data: workspaceThemeController.value.toThemeData(),
        child: Dialog(
          insetPadding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          child: SizedBox(
            width: 1000,
            height: (MediaQuery.sizeOf(dialogContext).height - 48).clamp(
              0.0,
              700.0,
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'ปิดหน้าจัดการกลุ่มสิทธิ์',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(
                  child: RoleGroupPage(
                    scope: scope,
                    activeMenu: scope == 'customer' ? '10003' : '11003',
                    embedded: true,
                    onSelected: (group) =>
                        Navigator.of(dialogContext).pop(group.id),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final groups = await _roleGroupRepository.list(scope);
    final roles = groups
        .where((group) => group.isActive)
        .map(
          (group) => EmployeeRoleGroupOption(
            id: group.id,
            name: group.name,
            selected: group.id == selectedId,
          ),
        )
        .toList(growable: false);
    if (mounted) setState(() => _roleGroups = roles);
    return roles;
  }

  List<EmployeeMasterOption> _masterOptions(List values) => values
      .whereType<Map>()
      .where((value) => value['isActive'] != false)
      .map(
        (value) => EmployeeMasterOption(
          code: (value['code'] ?? '').toString(),
          name: (value['name'] ?? '').toString(),
        ),
      )
      .where((value) => value.code.isNotEmpty)
      .toList(growable: false);

  Future<void> _setSignature(EmployeeRecord employee) async {
    final path = '/api/company/employees/${employee.employeeId}/signature';
    try {
      final response = await _api.get(path);
      if (!mounted) return;
      final data = response is Map ? response : {};
      final encoded = data['imageDataBase64'] as String?;
      Uint8List? bytes = encoded == null ? null : base64Decode(encoded);
      String? fileName = data['fileName'] as String?;
      final hadImage = bytes != null;
      bool changed = false, saving = false;
      String? errorMessage;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.draw_outlined,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'กำหนดลายเซ็น',
                        style: LaooTypography.popupTitleStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: .6, thickness: .6),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Text(employee.fullName),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              try {
                                final picked = await pickEmployeeImage();
                                if (picked == null || !dialogContext.mounted) {
                                  return;
                                }
                                final file = picked.files.single;
                                final selected = file.bytes;
                                if (selected == null ||
                                    selected.isEmpty ||
                                    selected.length > 2000000) {
                                  throw StateError(
                                    'กรุณาเลือกรูปขนาดไม่เกิน 2 MB',
                                  );
                                }
                                if (img.decodeImage(selected) == null) {
                                  throw StateError('ไฟล์รูปภาพไม่ถูกต้อง');
                                }
                                update(() {
                                  bytes = selected;
                                  fileName = file.name;
                                  changed = true;
                                  errorMessage = null;
                                });
                              } catch (e) {
                                if (dialogContext.mounted) {
                                  update(() => errorMessage = _errorText(e));
                                }
                              }
                            },
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('เลือกรูปลายเซ็น'),
                    ),
                    const SizedBox(height: 8),
                    const Text('รองรับ JPG, PNG และ WEBP ไม่เกิน 2 MB'),
                    const SizedBox(height: 12),
                    if (bytes != null) ...[
                      Container(
                        height: 180,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(dialogContext).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Image.memory(bytes!, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      Text(fileName ?? ''),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: saving
                              ? null
                              : () => update(() {
                                  bytes = null;
                                  fileName = null;
                                  changed = true;
                                  errorMessage = null;
                                }),
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                          label: const Text('ลบรูป'),
                        ),
                      ),
                    ] else
                      const Text('ยังไม่มีรูปลายเซ็น'),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              const Divider(height: .6, thickness: .6),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: !changed || saving
                        ? null
                        : () async {
                            update(() {
                              saving = true;
                              errorMessage = null;
                            });
                            try {
                              if (bytes == null) {
                                if (hadImage) await _api.delete(path);
                              } else {
                                await _api.put(
                                  path,
                                  body: {
                                    'fileName': fileName,
                                    'imageDataBase64': base64Encode(bytes!),
                                  },
                                );
                              }
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                update(() {
                                  saving = false;
                                  errorMessage = _errorText(e);
                                });
                              }
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
      );
      if (saved == true && mounted) {
        _showSignatureMessage('บันทึกลายเซ็นเรียบร้อยแล้ว');
      }
    } catch (error) {
      if (!mounted) return;
      _showSignatureMessage(
        'โหลดลายเซ็นไม่สำเร็จ: ${_errorText(error)}',
        error: true,
      );
    }
  }

  void _showSignatureMessage(String message, {bool error = false}) {
    setState(() {
      _signatureMessage = message;
      _signatureMessageError = error;
      _signatureMessageId++;
    });
  }

  Future<EmployeeImageInput?> _pickImage() async {
    final picked = await pickEmployeeImage();
    final source = picked?.files.single.bytes;
    if (source == null) return null;
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw StateError('ไม่สามารถอ่านไฟล์รูปภาพได้ กรุณาเลือกไฟล์ใหม่');
    }
    var image = decoded;
    var quality = 85;
    var bytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    while (bytes.length > 102400 && quality > 25) {
      quality -= 10;
      bytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
    while (bytes.length > 102400 && image.width > 1 && image.height > 1) {
      image = img.copyResize(
        image,
        width: (image.width * .8).round().clamp(1, image.width),
      );
      bytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
    if (bytes.length > 102400) {
      throw StateError(
        'รูปภาพมีขนาดใหญ่เกินไปและลดขนาดไม่สำเร็จ กรุณาเลือกไฟล์ที่เล็กกว่า',
      );
    }
    return EmployeeImageInput(
      bytes: bytes,
      fileName: picked!.files.single.name,
      width: image.width,
      height: image.height,
    );
  }

  String _errorText(Object error) =>
      error is ApiException ? error.message : error.toString();

  Future<bool> _confirmDelete(
    BuildContext context,
    EmployeeRecord employee,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final error = scheme.error;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.md),
              side: BorderSide(color: error),
            ),
            title: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: error.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.delete_outline, color: error),
                  ),
                ),
                const SizedBox(width: LaooLayout.cardSpacing),
                Expanded(
                  child: Text(
                    'ยืนยันการลบข้อมูล',
                    style: const TextStyle(
                      fontFamily: LaooTypography.fontFamily,
                      fontFamilyFallback: LaooTypography.fontFallback,
                      fontSize: LaooTypography.workspaceCaption,
                      fontWeight: LaooTypography.workspaceCaptionWeight,
                    ).copyWith(color: error),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: error.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(LaooLayout.cardPadding),
                    child: Text(
                      '${employee.employeeCode} - ${employee.fullName}',
                      style: TextStyle(color: error),
                    ),
                  ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
                const Divider(height: 24),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('ลบ'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: _contract.menuCode,
    menuScope: widget.menuScope,
    child: Stack(
      children: [
        ColoredBox(
          color: LaooColors.background,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? _loadErrorView()
              : EmployeeWorkspace(
                  caption: _caption,
                  repository: _repository,
                  organizationRepository:
                      widget.customer && !widget.companyScoped
                      ? null
                      : _organizationRepository,
                  organizationCaption: _organizationCaption,
                  onOrganizationChanged: (units) {
                    if (mounted) setState(() => _organizationUnits = units);
                  },
                  screenType: _contract.screenType,
                  pageSize: companySetupController.pageSize,
                  companies: _companies,
                  organizationUnits: _organizationUnits,
                  organizationMode: _organizationMode,
                  customerScope: widget.customer && !widget.companyScoped,
                  roleGroups: _roleGroups,
                  manageRoleGroups: _canManageRoleGroups
                      ? _manageRoleGroups
                      : null,
                  carTypes: _carTypes,
                  oilTypes: _oilTypes,
                  positions: _positions,
                  canChangeMasterData: _canChangeMasterData,
                  managePositions: _canOpenPositionLookup
                      ? () => _manageMasterGroup(MasterGroupCodes.position)
                      : null,
                  manageCarTypes: _canManageVehicleMaster
                      ? () => _manageMasterGroup(MasterGroupCodes.carType)
                      : null,
                  manageOilTypes: _canManageVehicleMaster
                      ? () => _manageMasterGroup(MasterGroupCodes.oilType)
                      : null,
                  titleBuilder: (context, title, showFavorite) =>
                      WorkspacePageTitle(
                        title: title,
                        favoriteKey: showFavorite ? _contract.menuCode : null,
                      ),
                  messageBuilder: (context, message, error, onClose) =>
                      AutoDismissMessage(
                        key: ValueKey((message, error)),
                        message: message,
                        error: error,
                        onClose: onClose,
                      ),
                  tokens: _tokens,
                  formatDate: (value) =>
                      CompanyDateFormatter.formatDateByYearFormat(
                        value,
                        companySetupController.current?.yearFormat ?? 'C',
                      ),
                  errorText: _errorText,
                  confirmDelete: _confirmDelete,
                  pickImage: _pickImage,
                  canShowEmployeeImages: _canShowEmployeeImages,
                  onSignature: widget.companyScoped && _canSetEmployeeSignature
                      ? _setSignature
                      : null,
                ),
        ),
        if (_signatureMessage != null)
          Positioned(
            top: 10,
            right: 10,
            child: AutoDismissMessage(
              key: ValueKey(_signatureMessageId),
              message: _signatureMessage!,
              error: _signatureMessageError,
              onClose: () {
                if (mounted) setState(() => _signatureMessage = null);
              },
            ),
          ),
      ],
    ),
  );

  Widget _loadErrorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: LaooLayout.cardSpacing),
          Text(
            'โหลดข้อมูลสำหรับหน้าพนักงานไม่สำเร็จ: ${_errorText(_loadError!)}',
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: _loadDependencies,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    ),
  );

  static const _tokens = SharedAdminUiTokens(
    contentMargin: EdgeInsets.all(LaooLayout.cardMargin),
    cardPadding: EdgeInsets.all(LaooLayout.cardPadding),
    cardSpacing: LaooLayout.cardSpacing,
    itemSpacing: 6,
    radius: LaooRadius.xs,
    compactBreakpoint: 900,
    paginationHeight: LaooLayout.paginationCardHeight,
    filterActionHeight: LaooLayout.filterActionHeight,
    listViewToggleSize: LaooLayout.listViewToggleSize,
    paginationButtonSize: LaooLayout.paginationButtonSize,
    fieldSpacing: LaooLayout.popupFieldSpacing,
    inputLabelStyle: TextStyle(
      fontFamily: LaooTypography.fontFamily,
      fontFamilyFallback: LaooTypography.fontFallback,
      fontSize: LaooTypography.inputLabel,
    ),
    floatingLabelStyle: TextStyle(
      fontFamily: LaooTypography.fontFamily,
      fontFamilyFallback: LaooTypography.fontFallback,
      fontSize: LaooTypography.materialFloatingLabelSource,
    ),
    sectionTitleStyle: TextStyle(
      fontFamily: LaooTypography.fontFamily,
      fontFamilyFallback: LaooTypography.fontFallback,
      fontSize: LaooTypography.sectionTitle,
      fontWeight: FontWeight.w700,
    ),
    captionStyle: TextStyle(
      fontFamily: LaooTypography.fontFamily,
      fontFamilyFallback: LaooTypography.fontFallback,
      fontSize: LaooTypography.workspaceCaption,
      height: LaooTypography.titleLineHeight,
      fontWeight: LaooTypography.workspaceCaptionWeight,
      color: Colors.black,
    ),
  );
}
