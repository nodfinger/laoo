import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_date_formatter.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/master/master_group_codes.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../access/role_group/data/role_group_repository.dart';
import '../../../partner/data/partner_company_repository.dart';
import '../../master_data/data/master_data_api.dart';
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

  String _caption = 'พนักงาน';
  bool _loading = true;
  Object? _loadError;
  List<EmployeeCompanyOption> _companies = const [];
  List<OrganizationUnitRecord> _organizationUnits = const [];
  int _organizationMode = 1;
  List<EmployeeRoleGroupOption> _roleGroups = const [];
  List<EmployeeMasterOption> _carTypes = const [];
  List<EmployeeMasterOption> _oilTypes = const [];

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
        NavigationMenuRepository(apiClient: _api).resolveMenuName(
          menuCode: _contract.menuCode,
          routeName: _contract.routeName,
          fallback: _caption,
        ),
        _organizationRepository.load(),
        _roleGroupRepository.list(
          widget.customer || widget.companyScoped ? 'customer' : 'partner',
        ),
        _masterDataApi.list(MasterGroupCodes.carType),
        _masterDataApi.list(MasterGroupCodes.oilType),
        widget.customer && !widget.companyScoped
            ? _companyRepository.getCompanies(
                support: _ownerScope == LaooOwnerScope.support,
              )
            : Future.value(const <dynamic>[]),
      ]);
      final organization = results[1] as OrganizationStructureSnapshot;
      final roleGroups = results[2] as List;
      final carTypes = results[3] as List;
      final oilTypes = results[4] as List;
      final companies = results[5] as List;
      if (!mounted) return;
      setState(() {
        _caption = (results[0] as String).trim();
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

  Future<EmployeeImageInput?> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final source = picked?.files.single.bytes;
    if (source == null) return null;
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw StateError('ไม่สามารถอ่านไฟล์รูปภาพได้ กรุณาเลือกไฟล์ใหม่');
    }
    var quality = 85;
    var bytes = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
    while (bytes.length > 102400 && quality > 20) {
      quality -= 10;
      bytes = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
    }
    if (bytes.length > 102400) {
      throw StateError(
        'รูปภาพมีขนาดใหญ่เกินไปและลดขนาดไม่สำเร็จ กรุณาเลือกไฟล์ที่เล็กกว่า',
      );
    }
    return EmployeeImageInput(
      bytes: bytes,
      fileName: picked!.files.single.name,
      width: decoded.width,
      height: decoded.height,
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
    child: ColoredBox(
      color: LaooColors.background,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _loadErrorView()
          : EmployeeWorkspace(
              caption: _caption,
              repository: _repository,
              screenType: _contract.screenType,
              pageSize: companySetupController.pageSize,
              companies: _companies,
              organizationUnits: _organizationUnits,
              organizationMode: _organizationMode,
              customerScope: widget.customer && !widget.companyScoped,
              roleGroups: _roleGroups,
              carTypes: _carTypes,
              oilTypes: _oilTypes,
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
            ),
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
