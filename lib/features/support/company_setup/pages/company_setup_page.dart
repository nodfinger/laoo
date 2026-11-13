import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:laoo_provider/provider_feature.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/platform/window_title_service.dart';
import '../../../../core/widgets/combo_box_text.dart';
import '../data/company_setup_api.dart';
import '../models/company_setup_constants.dart';
import '../models/company_setup_model.dart';
import '../widgets/company_subscription_card.dart';
import '../widgets/travel_access_settings_card.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../../../company/ocr/business_card_ocr_ui.dart';

class CompanySetupPage extends StatefulWidget {
  const CompanySetupPage({super.key, this.additionalOnly = false});

  final bool additionalOnly;

  @override
  State<CompanySetupPage> createState() => _CompanySetupPageState();
}

class _CompanySetupPageState extends State<CompanySetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _basicSectionKey = GlobalKey<_CollapsibleSectionState>();
  final _accessSettingsKey = GlobalKey<TravelAccessSettingsCardState>();
  final _ownerCode = TextEditingController(text: 'C000001');
  final _ownerName = TextEditingController(text: 'Laoo Foods');
  final _titleHeader = TextEditingController(text: 'Laoo Foods');
  final _customerNameTh = TextEditingController(text: 'ละออแปรรูป');
  final _customerNameEn = TextEditingController(text: 'Laoo Foods');
  final _address = TextEditingController(text: '7/1');
  final _telephone = TextEditingController(text: '086-346-7319');
  final _taxId = TextEditingController(text: '0105566000001');
  final _email = TextEditingController(text: 'm086086@hotmail.com');
  final _rowStd = TextEditingController(text: '30');
  final _rowCardStd = TextEditingController(text: '30');
  final _timeAlert = TextEditingController(text: '30');
  final _itemDigit = TextEditingController(text: '3');
  final _markItem = TextEditingController();
  final _versionId = TextEditingController(text: '1.0.0');
  final _emailHost = TextEditingController(text: 'smtp.gmail.com');
  final _emailPort = TextEditingController(text: '587');
  final _emailCenter = TextEditingController(text: 'nodfinger@gmail.com');
  final _emailAdmin = TextEditingController(text: 'nodfinger@gmail.com');
  final _emailPasswordCenter = TextEditingController();
  final _superUserName = TextEditingController();
  final _passwordCry = TextEditingController();
  final _passwordEmpDefault = TextEditingController();
  final _homePageUrl = TextEditingController();

  final _api = CompanySetupApi();
  final _meetingSettingsApi = MeetingEquipmentRequestSettingsApi();
  final _trainingSettingsApi = TrainingSettingsApi();
  bool _loading = true;
  bool _messageIsError = false;
  String _yearFormat = CompanySetupConstants.yearFormatAd;
  int _orgStructureType = 1;
  String _employeeNameDisplay = CompanySetupConstants.employeeNameFull;
  String _businessTypeCode = 'COMPANY';
  String _requesterCaption = 'ผู้แจ้งซ่อม';
  bool _isBusinessTypeLocked = false;
  List<Map<String, dynamic>> _businessTypeOptions = const [];
  int _passwordPolicyCode = 3;
  String? _runItem;
  List<Map<String, dynamic>> _runItemOptions = const [];
  String? _runCus;
  List<Map<String, dynamic>> _runCusOptions = const [];
  final _customerDigit = TextEditingController(text: '5');
  final _markCus = TextEditingController();
  bool _receiveStockImmediately = true;
  bool _meetingSettingsVisible = false;
  bool _trainingSettingsVisible = false;
  bool _meetingRequireEquipmentRequestReview = false;
  bool _savingMeetingSettings = false;
  String _receiveStockPriceModeCode = 'CUSTOM';
  static const _receiveStockPriceModes = [
    {'code': 'CUSTOM', 'name': 'กำหนดเอง'},
    {'code': 'LAST_RECEIPT', 'name': 'ราคารับเข้าล่าสุด'},
    {'code': 'AVERAGE', 'name': 'ราคาเฉลี่ย'},
  ];

  bool _saving = false;
  bool _canEdit = false;
  String? _message;
  String _ownerType = '';
  String? _partnerNameTh;
  String? _partnerAddress;
  String? _partnerTelephone;
  String? _partnerEmail;
  String? _memberCoverImagePath;
  int? _companyId;
  bool _uploadingMemberCover = false;
  Uint8List? _companyLogo;
  bool _uploadingLogo = false;
  String _approvalLevelOrder = 'SEQUENCE';
  bool _approvalLevelOrderLoaded = false;
  bool _approvalLevelOrderDirty = false;
  int _homePageDefaultMode = 1;
  bool _homePageSettingsLoaded = false;
  bool _homePageSettingsLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadActions();
    _load();
    if (!widget.additionalOnly && appAuthController.isLaooSupport) {
      _loadHomePageSettings();
    }
    if (!widget.additionalOnly) {
      _loadLogo();
    }
    if (widget.additionalOnly) _loadTrainingSettings();
  }

  Future<void> _loadApprovalLevelOrder() async {
    try {
      final result = await _api.loadApprovalLevelOrder();
      if (!mounted || result is! Map) return;
      final method = result['method'];
      if (method is! String ||
          !['NAME', 'SHORTCODE', 'SEQUENCE'].contains(method)) {
        return;
      }
      setState(() {
        _approvalLevelOrder = method;
        _approvalLevelOrderLoaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _messageIsError = true;
          _message =
              'โหลดวิธีจัดระดับตำแหน่งไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> _loadLogo() async {
    try {
      final response = await _api.loadLogo();
      if (!mounted || response is! Map) return;
      final value = response['image'];
      setState(
        () => _companyLogo = value is String && value.isNotEmpty
            ? base64Decode(value)
            : null,
      );
    } catch (_) {
      // The logo is optional; company settings remain available if it cannot load.
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
      setState(() {
        _message = 'กรุณาเลือกรูป JPG หรือ PNG ขนาดไม่เกิน 3 MB';
        _messageIsError = true;
      });
      return;
    }
    setState(() => _uploadingLogo = true);
    try {
      await _api.uploadLogo(file.name, bytes);
      if (!mounted) return;
      setState(() {
        _companyLogo = bytes;
        _message = 'บันทึกโลโก้เรียบร้อยแล้ว';
        _messageIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error is ApiException
            ? error.message
            : 'บันทึกโลโก้ไม่สำเร็จ กรุณาลองใหม่';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Widget _logoField() => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Text('โลโก้บริษัท'),
      const SizedBox(height: 8),
      SizedBox(
        width: 150,
        height: 110,
        child: _companyLogo == null
            ? const Icon(Icons.image_outlined, size: 48)
            : Image.memory(_companyLogo!, fit: BoxFit.contain),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _canEdit && !_uploadingLogo ? _pickLogo : null,
        icon: const Icon(Icons.image_outlined),
        label: const Text('เลือกโลโก้'),
      ),
      const SizedBox(height: 4),
      const Text('JPG, PNG ไม่เกิน 3 MB'),
    ],
  );

  Future<void> _loadActions() async {
    try {
      final permissions = await _api.actions();
      if (mounted) {
        setState(() => _canEdit = permissions['edit'] == true);
      }
    } catch (_) {}
  }

  Future<void> _loadHomePageSettings() async {
    try {
      final settings = await _api.loadHomePageSettings();
      if (!mounted) return;
      final mode = settings['defaultMode'];
      final parsedMode = mode is num
          ? mode.toInt()
          : int.tryParse('$mode') ?? 3;
      setState(() {
        _homePageDefaultMode = parsedMode.clamp(1, 4).toInt();
        _homePageUrl.text = '${settings['externalUrl'] ?? ''}';
        _homePageSettingsLoaded = true;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message = _apiMessage(error);
        _homePageSettingsLoadFailed = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message =
            'ไม่สามารถอ่านรูปแบบการเริ่มต้นหน้าจอจาก appsettings.json ได้';
        _homePageSettingsLoadFailed = true;
      });
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.load(),
        _api.runItemOptions(),
        _api.runItemOptions(groupCode: CompanySetupConstants.cConstRunCus),
        _api.businessTypeOptions(),
      ]);
      final setup = results[0] as CompanySetupModel;
      final itemOptions = results[1] as List<Map<String, dynamic>>;
      final customerOptions = results[2] as List<Map<String, dynamic>>;
      final businessTypeOptions = results[3] as List<Map<String, dynamic>>;
      if (!mounted) return;
      _ownerCode.text = setup.ownerCode;
      _ownerType = setup.ownerType;
      if (!widget.additionalOnly && _ownerType == 'C') {
        _loadApprovalLevelOrder();
      }
      _partnerNameTh = setup.partnerNameTh;
      _partnerAddress = setup.partnerAddress;
      _partnerTelephone = setup.partnerTelephone;
      _partnerEmail = setup.partnerEmail;
      _memberCoverImagePath = setup.memberCoverImagePath;
      _companyId = setup.companyId;
      _ownerName.text = setup.name;
      _titleHeader.text = setup.titleHeader;
      _customerNameTh.text = setup.customerNameTh ?? '';
      _customerNameEn.text = setup.customerNameEn ?? '';
      _address.text = setup.addressText ?? '';
      _telephone.text = setup.telephone ?? '';
      _taxId.text = setup.taxId ?? '';
      _email.text = setup.customerEmail ?? '';
      _rowStd.text = setup.rowStd.toString();
      _rowCardStd.text = setup.rowCardStd.toString();
      _timeAlert.text = setup.timeAlert.toString();
      _receiveStockImmediately = setup.receiveStockImmediately;
      _receiveStockPriceModeCode = setup.receiveStockPriceModeCode;
      _itemDigit.text = setup.itemDigit.toString();
      _markItem.text = setup.markItem ?? '';
      _customerDigit.text = setup.customerDigit.toString();
      _markCus.text = setup.markCus ?? '';
      _orgStructureType = setup.orgStructureType;
      _employeeNameDisplay =
          CompanySetupConstants.employeeNameOptions.contains(
            setup.employeeNameDisplay,
          )
          ? setup.employeeNameDisplay
          : CompanySetupConstants.employeeNameFull;
      _businessTypeCode = setup.businessTypeCode;
      _requesterCaption = setup.requesterCaption;
      _isBusinessTypeLocked = setup.isBusinessTypeLocked;
      _businessTypeOptions = businessTypeOptions;
      _passwordPolicyCode = setup.passwordPolicyCode;
      _versionId.text = setup.versionId ?? '';
      _emailHost.text = setup.emailHost ?? '';
      _emailPort.text = setup.emailPort?.toString() ?? '';
      _emailCenter.text = setup.emailCenter ?? '';
      _emailAdmin.text = setup.emailAdmin ?? '';
      _yearFormat = setup.yearFormat == CompanySetupConstants.yearFormatBe
          ? CompanySetupConstants.yearFormatBe
          : CompanySetupConstants.yearFormatAd;
      _runItemOptions = itemOptions;
      _runItem =
          setup.runItem ??
          (itemOptions.isEmpty ? null : '${itemOptions.first['code']}');
      _runCusOptions = customerOptions;
      _runCus =
          setup.runCus ??
          (customerOptions.isEmpty ? null : '${customerOptions.first['code']}');
      setState(() => _loading = false);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messageIsError = true;
        _message = _apiMessage(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messageIsError = true;
        _message = 'ไม่สามารถโหลดข้อมูลกำหนดค่าระบบได้';
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _ownerCode,
      _ownerName,
      _titleHeader,
      _customerNameTh,
      _customerNameEn,
      _address,
      _telephone,
      _taxId,
      _email,
      _rowStd,
      _rowCardStd,
      _timeAlert,
      _itemDigit,
      _markItem,
      _customerDigit,
      _markCus,
      _versionId,
      _emailHost,
      _emailPort,
      _emailCenter,
      _emailAdmin,
      _emailPasswordCenter,
      _superUserName,
      _passwordCry,
      _passwordEmpDefault,
      _homePageUrl,
    ]) {
      controller.dispose();
    }
    _api.dispose();
    _trainingSettingsApi.dispose();
    super.dispose();
  }

  String _apiMessage(ApiException error) {
    final rawMessage = error.message.trim();
    const marker = 'รายละเอียดเพิ่มเติม:';
    final markerIndex = rawMessage.indexOf(marker);
    final message =
        (markerIndex >= 0 ? rawMessage.substring(0, markerIndex) : rawMessage)
            .trim();
    final embeddedDescription = markerIndex >= 0
        ? rawMessage.substring(markerIndex + marker.length).trim()
        : null;
    final description = (error.description?.trim().isNotEmpty ?? false)
        ? error.description!.trim()
        : (embeddedDescription?.isNotEmpty ?? false)
        ? embeddedDescription!
        : 'กรุณาตรวจสอบการเชื่อมต่อและข้อมูลกำหนดค่าระบบ แล้วลองใหม่อีกครั้ง';
    final parts = <String>[];
    if (message.isNotEmpty) parts.add(message);
    parts.add('$marker $description');
    if (error.statusCode != null) {
      parts.add('รหัส HTTP: ${error.statusCode}');
    }
    return parts.join('\n');
  }

  Future<void> _save() async {
    if (_saving) return;
    final invalidEmail = [_email, _emailCenter, _emailAdmin].any(
      (controller) =>
          controller.text.trim().isNotEmpty && !_isValidEmail(controller.text),
    );
    if (invalidEmail) {
      setState(() {
        _messageIsError = true;
        _message = 'คุณกำหนดรูปแบบ email ไม่ถูกต้อง';
      });
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      _basicSectionKey.currentState?.expand();
      return;
    }
    if (!widget.additionalOnly &&
        appAuthController.isLaooSupport &&
        !_homePageSettingsLoaded) {
      setState(() {
        _messageIsError = true;
        _message =
            'ยังอ่านรูปแบบหน้าจอเริ่มต้นไม่สำเร็จ กรุณาโหลดหน้าใหม่ก่อนบันทึก';
      });
      return;
    }
    setState(() => _saving = true);
    if (DateTime.now().millisecondsSinceEpoch >= 0) {
      try {
        final savedSetup = await _api.save(
          CompanySetupUpdateInput(
            customerNameTh: _customerNameTh.text,
            customerNameEn: _customerNameEn.text,
            addressText: _address.text,
            telephone: _telephone.text,
            taxId: _taxId.text,
            customerEmail: _email.text,
            name: _ownerName.text,
            titleHeader: _titleHeader.text,
            runItem: _runItem,
            markItem: _markItem.text,
            rowStd: int.tryParse(_rowStd.text) ?? 30,
            rowCardStd: int.tryParse(_rowCardStd.text) ?? 30,
            timeAlert: int.tryParse(_timeAlert.text) ?? 30,
            receiveStockImmediately: _receiveStockImmediately,
            receiveStockPriceModeCode: _receiveStockPriceModeCode,
            itemDigit: int.tryParse(_itemDigit.text) ?? 3,
            runCus: _runCus,
            markCus: _markCus.text,
            customerDigit: int.tryParse(_customerDigit.text) ?? 5,
            orgStructureType: _orgStructureType,
            employeeNameDisplay: _employeeNameDisplay,
            businessTypeCode: _businessTypeCode,
            passwordPolicyCode: _passwordPolicyCode,
            yearFormat: _yearFormat,
            versionId: _versionId.text,
            emailHost: _emailHost.text,
            emailPort: int.tryParse(_emailPort.text),
            emailCenter: _emailCenter.text,
            emailAdmin: _emailAdmin.text,
            emailPasswordCenter: _emailPasswordCenter.text,
            superUserName: _superUserName.text,
            passwordCry: _passwordCry.text,
            passwordEmpDefault: _passwordEmpDefault.text,
          ),
          additionalOnly: widget.additionalOnly,
        );
        _itemDigit.text = savedSetup.itemDigit.toString();
        await companySetupController.load();
        WindowTitleService.setTitle(companySetupController.appTitle);
        if (!mounted) return;
        try {
          await _accessSettingsKey.currentState?.saveIfChanged();
          if (_approvalLevelOrderDirty) {
            await _api.saveApprovalLevelOrder(_approvalLevelOrder);
            _approvalLevelOrderDirty = false;
          }
          if (!widget.additionalOnly && appAuthController.isLaooSupport) {
            await _api.saveHomePageSettings(
              defaultMode: _homePageDefaultMode,
              externalUrl: _homePageUrl.text.trim(),
            );
          }
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _saving = false;
            _messageIsError = true;
            _message =
                'บันทึกข้อมูลระบบแล้ว แต่บันทึกรูปแบบหน้าจอเริ่มต้นหรือเงื่อนไขส่วนกลางไม่สำเร็จ กรุณาตรวจสอบสิทธิ์เขียนไฟล์ appsettings.json และลองบันทึกใหม่';
          });
          return;
        }
        if (!mounted) return;
        _superUserName.clear();
        _passwordCry.clear();
        _passwordEmpDefault.clear();
        _emailPasswordCenter.clear();
        setState(() {
          _saving = false;
          _messageIsError = false;
          _message = 'บันทึกข้อมูลกำหนดค่าระบบสำเร็จ';
        });
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _messageIsError = true;
          _message = _apiMessage(error);
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _messageIsError = true;
          _message = 'ไม่สามารถบันทึกข้อมูลได้';
        });
      }
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = 'บันทึกตัวอย่างหน้าจอสำเร็จ (UX Demo ยังไม่เชื่อม API)';
    });
  }

  Widget _runItemCard(Color accent) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.additionalOnly) ...[
              Text(
                'กำหนดค่าระบบเพิ่มเติม',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.additionalOnly) ...[
              Text(
                'ข้อมูลส่วนกลาง',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('รับสินค้าเข้าคลัง–ตัดสต๊อกทันที'),
                subtitle: const Text(
                  'เมื่อยืนยันรับสินค้า ระบบบันทึกยอดคงคลังทันที',
                ),
                value: _receiveStockImmediately,
                onChanged: _canEdit
                    ? (value) =>
                          setState(() => _receiveStockImmediately = value)
                    : null,
              ),
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _receiveStockPriceModes.any(
                          (x) => x['code'] == _receiveStockPriceModeCode,
                        )
                        ? _receiveStockPriceModeCode
                        : 'CUSTOM',
                    decoration: const InputDecoration(
                      labelText: 'ราคาเริ่มต้นรับเข้าสต๊อก',
                    ),
                    items: _receiveStockPriceModes
                        .map(
                          (x) => DropdownMenuItem<String>(
                            value: '${x['code']}',
                            child: Text('${x['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: _canEdit
                        ? (value) => setState(
                            () =>
                                _receiveStockPriceModeCode = value ?? 'CUSTOM',
                          )
                        : null,
                  ),
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 420 : double.infinity,
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _runItemOptions.any((x) => '${x['code']}' == _runItem)
                      ? _runItem
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'รูปแบบการสร้างรหัสสินค้า',
                  ),
                  items: _runItemOptions
                      .map(
                        (x) => DropdownMenuItem<String>(
                          value: '${x['code']}',
                          child: LaooComboBoxText('${x['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: _canEdit
                      ? (value) => setState(() => _runItem = value)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 180 : 240,
                child: TextFormField(
                  controller: _markItem,
                  enabled: _canEdit,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'สัญลักษณ์ก่อนลำดับสินค้า',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 180 : 240,
                child: TextFormField(
                  controller: _itemDigit,
                  enabled: _canEdit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'จำนวนหลักของสินค้า',
                  ),
                  validator: (value) {
                    final digits = int.tryParse(value?.trim() ?? '');
                    return digits == null || digits < 1 || digits > 10
                        ? 'ระบุ 1-10 หลัก'
                        : null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 420 : double.infinity,
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _runCusOptions.any((x) => '${x['code']}' == _runCus)
                      ? _runCus
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'รูปแบบการสร้างรหัสลูกค้า',
                  ),
                  items: _runCusOptions
                      .map(
                        (x) => DropdownMenuItem<String>(
                          value: '${x['code']}',
                          child: LaooComboBoxText('${x['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: _canEdit
                      ? (value) => setState(() => _runCus = value)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 180 : 240,
                child: TextFormField(
                  controller: _markCus,
                  enabled: _canEdit,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'สัญลักษณ์ก่อนลำดับลูกค้า',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 180 : 240,
                child: TextFormField(
                  controller: _customerDigit,
                  enabled: _canEdit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'จำนวนหลักรหัสลูกค้า',
                  ),
                  validator: (value) {
                    final digits = int.tryParse(value?.trim() ?? '');
                    return digits == null || digits < 1 || digits > 10
                        ? 'ระบุ 1-10 หลัก'
                        : null;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  Future<void> _loadMeetingSettings() async {
    if (!widget.additionalOnly) return;
    try {
      final requireReview = await _meetingSettingsApi.load();
      if (mounted) {
        setState(() {
          _meetingSettingsVisible = true;
          _meetingRequireEquipmentRequestReview = requireReview;
        });
      }
    } catch (_) {
      // The Meeting API enforces entitlement and Company Admin scope.
    }
  }

  Future<void> _saveMeetingSettings(bool value) async {
    if (_savingMeetingSettings) return;
    setState(() => _savingMeetingSettings = true);
    try {
      await _meetingSettingsApi.save(value);
      if (!mounted) return;
      setState(() {
        _meetingRequireEquipmentRequestReview = value;
        _messageIsError = false;
        _message = 'บันทึกการตั้งค่าระบบ Meeting สำเร็จ';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message = 'บันทึกการตั้งค่าระบบ Meeting ไม่สำเร็จ';
      });
    } finally {
      if (mounted) setState(() => _savingMeetingSettings = false);
    }
  }

  Future<void> _loadTrainingSettings() async {
    if (!widget.additionalOnly) return;
    try {
      final enabled = await _trainingSettingsApi.load();
      if (mounted && enabled) {
        setState(() => _trainingSettingsVisible = true);
      }
    } catch (_) {
      // The Training API deliberately returns no settings to Companies without
      // the Training entitlement or Company Admin scope.
    }
  }

  Widget _meetingSettingsCard(Color accent) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meeting',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('ต้องตรวจสอบคำขออุปกรณ์เพิ่มเติมก่อนส่งแผนก'),
            subtitle: const Text('ปิดไว้: ส่งคำขอไปยังแผนกรับผิดชอบทันที'),
            value: _meetingRequireEquipmentRequestReview,
            onChanged: _savingMeetingSettings ? null : _saveMeetingSettings,
          ),
        ],
      ),
    ),
  );

  Widget _trainingSettingsCard(Color accent) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Training',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text('ระบบอบรมเปิดใช้งานสำหรับบริษัทนี้แล้ว'),
          const SizedBox(height: 4),
          const Text(
            'การกำหนดหลักสูตร วิทยากร แบบประเมิน และแบบทดสอบจะเพิ่มในระยะถัดไป',
          ),
        ],
      ),
    ),
  );
  void _cancel() => context.goNamed(RouteNames.authenticatedHome);

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return ColoredBox(
      color: preset.isDark ? preset.background : const Color(0xFFF8F9FB),
      child: Form(
        key: _formKey,
        child: Stack(
          children: [
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      LaooLayout.cardMargin,
                      LaooLayout.cardMargin,
                      LaooLayout.cardMargin,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          margin: EdgeInsets.zero,
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide.none,
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFF5F6F7)),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: WorkspaceActionHeader(
                              title: widget.additionalOnly
                                  ? 'กำหนดค่าระบบเพิ่มเติม'
                                  : 'กำหนดค่าระบบ',
                              favoriteKey: widget.additionalOnly
                                  ? '05003'
                                  : '05001',
                              actions: [
                                _TopActions(
                                  saving: _saving,
                                  canSave: _canEdit,
                                  onCancel: _cancel,
                                  onSave: _save,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: LaooLayout.cardSpacing),
                        if (!widget.additionalOnly) ...[
                          _CollapsibleSection(
                            key: _basicSectionKey,
                            title: 'ข้อมูลพื้นฐาน',
                            icon: Icons.business_outlined,
                            child: _CompanySetupUxForm(
                              ownerCode: _ownerCode,
                              ownerName: _ownerName,
                              titleHeader: _titleHeader,
                              customerNameTh: _customerNameTh,
                              customerNameEn: _customerNameEn,
                              address: _address,
                              telephone: _telephone,
                              taxId: _taxId,
                              email: _email,
                              logo: _ownerType == 'C' ? _logoField() : null,
                              businessType: _ownerType == 'C'
                                  ? _CompanyBusinessTypeField(
                                      value: _businessTypeCode,
                                      options: _businessTypeOptions,
                                      requesterCaption: _requesterCaption,
                                      locked: _isBusinessTypeLocked,
                                      enabled: _canEdit,
                                      onChanged: (value) => setState(
                                        () => _businessTypeCode = value,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _legacySetupCards(
                            showCompanyCards:
                                !appAuthController.isLaooSupport &&
                                !appAuthController.isPartnerUser,
                            configurationOnly: true,
                            startupSettingsVisible:
                                appAuthController.isLaooSupport,
                          ),
                          const SizedBox(height: 8),
                          if (_ownerType == 'C') ...[
                            _CollapsibleSection(
                              title: 'การเข้าถึงข้อมูล',
                              icon: Icons.security_outlined,
                              child: TravelAccessSettingsCard(
                                key: _accessSettingsKey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _CollapsibleSection(
                              title: 'การอนุมัติข้อมูลและเอกสาร',
                              icon: Icons.fact_check_outlined,
                              child: DropdownButtonFormField<String>(
                                initialValue: _approvalLevelOrder,
                                isExpanded: true,
                                decoration: ocrInput(
                                  context,
                                  'การจัดระดับตำแหน่งงาน',
                                ),
                                style: businessCardOcrUi(context).inputStyle
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'NAME',
                                    child: Text('จัดตามชื่อ'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'SHORTCODE',
                                    child: Text('จัดตามรหัสย่อ'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'SEQUENCE',
                                    child: Text('จัดตามลำดับ'),
                                  ),
                                ],
                                onChanged: _canEdit && _approvalLevelOrderLoaded
                                    ? (value) => setState(() {
                                        _approvalLevelOrder = value!;
                                        _approvalLevelOrderDirty = true;
                                      })
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _CollapsibleSection(
                              title: 'รูปปกสมาชิก',
                              icon: Icons.image_outlined,
                              child: _memberCoverCard(preset.primary),
                            ),
                            const SizedBox(height: 8),
                            _CollapsibleSection(
                              title: 'Partner',
                              icon: Icons.handshake_outlined,
                              child: _PartnerInfoCard(
                                nameTh: _partnerNameTh,
                                address: _partnerAddress,
                                telephone: _partnerTelephone,
                                email: _partnerEmail,
                              ),
                            ),
                          ],
                        ],
                        if (widget.additionalOnly) ...[
                          _runItemCard(preset.primary),
                          if (_meetingSettingsVisible) ...[
                            const SizedBox(height: 8),
                            _meetingSettingsCard(preset.primary),
                          ],
                          if (_trainingSettingsVisible) ...[
                            const SizedBox(height: 8),
                            _trainingSettingsCard(preset.primary),
                          ],
                        ],
                        if (!widget.additionalOnly) ...[
                          const SizedBox(height: 8),
                          ListenableBuilder(
                            listenable: appAuthController,
                            builder: (context, _) {
                              final showCompanyCards =
                                  !appAuthController.isLaooSupport &&
                                  !appAuthController.isPartnerUser;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (showCompanyCards) ...[
                                    const CompanySubscriptionCard(),
                                    const SizedBox(height: 8),
                                  ],
                                  _legacySetupCards(
                                    showCompanyCards: showCompanyCards,
                                    configurationOnly: false,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
            if (_message != null)
              Positioned(
                top: 12,
                right: 24,
                child: AutoDismissMessage(
                  key: ValueKey(_message),
                  message: _message!,
                  error: _messageIsError,
                  onClose: () => setState(() => _message = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legacySetupCards({
    required bool showCompanyCards,
    required bool configurationOnly,
    bool startupSettingsVisible = false,
  }) => _LegacySetupCards(
    showCompanyCards: showCompanyCards,
    configurationOnly: configurationOnly,
    startupSettingsVisible: startupSettingsVisible,
    startupSettingsLoaded: _homePageSettingsLoaded,
    startupSettingsLoadFailed: _homePageSettingsLoadFailed,
    startupSettingsEditable: _canEdit,
    startupMode: _homePageDefaultMode,
    startupUrlController: _homePageUrl,
    onStartupModeChanged: (value) =>
        setState(() => _homePageDefaultMode = value),
    controllers: {
      'rowStd': _rowStd,
      'rowCardStd': _rowCardStd,
      'timeAlert': _timeAlert,
      'versionId': _versionId,
      'emailHost': _emailHost,
      'emailPort': _emailPort,
      'emailCenter': _emailCenter,
      'emailAdmin': _emailAdmin,
      'emailPasswordCenter': _emailPasswordCenter,
      'superUserName': _superUserName,
      'passwordCry': _passwordCry,
      'passwordEmpDefault': _passwordEmpDefault,
    },
    yearFormat: _yearFormat,
    onYearFormatChanged: (value) => setState(() => _yearFormat = value),
    orgStructureType: _orgStructureType,
    employeeNameDisplay: _employeeNameDisplay,
    onEmployeeNameDisplayChanged: (value) =>
        setState(() => _employeeNameDisplay = value),
    onOrgStructureTypeChanged: (value) =>
        setState(() => _orgStructureType = value),
    passwordPolicyCode: _passwordPolicyCode,
    onPasswordPolicyCodeChanged: (value) =>
        setState(() => _passwordPolicyCode = value),
  );

  Widget _memberCoverCard(Color accent) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox.square(
              dimension: 128,
              child:
                  _memberCoverImagePath == null ||
                      _memberCoverImagePath!.isEmpty
                  ? ColoredBox(
                      color: const Color(0xfff1f5f4),
                      child: Icon(
                        Icons.business_outlined,
                        size: 48,
                        color: accent,
                      ),
                    )
                  : Image.network(
                      '/api/public/providers/companies/$_companyId/cover',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
          ),
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'รูปสี่เหลี่ยมจัตุรัส ระบบจะครอปกึ่งกลางและลดขนาดอัตโนมัติให้ไม่เกิน 1 MB',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: !_canEdit || _uploadingMemberCover
                        ? null
                        : _pickMemberCover,
                    icon: _uploadingMemberCover
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('เลือกรูปปก'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickMemberCover() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;
    setState(() => _uploadingMemberCover = true);
    try {
      final compressed = compressProviderImage(
        picked.files.single.bytes!,
        picked.files.single.name,
        square: true,
      );
      final path = await _api.uploadMemberCover(
        fileName: compressed.fileName,
        bytes: compressed.bytes,
      );
      if (!mounted) return;
      setState(() {
        _memberCoverImagePath = path;
        _messageIsError = false;
        _message = 'อัปโหลดรูปปกสมาชิกแล้ว';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _messageIsError = true;
          _message = 'อัปโหลดรูปปกสมาชิกไม่สำเร็จ: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _uploadingMemberCover = false);
    }
  }
}

class _CompanyBusinessTypeField extends StatelessWidget {
  const _CompanyBusinessTypeField({
    required this.value,
    required this.options,
    required this.requesterCaption,
    required this.locked,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final List<Map<String, dynamic>> options;
  final String requesterCaption;
  final bool locked;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectable = options.any((item) => item['code']?.toString() == value);

    return DropdownButtonFormField<String>(
      initialValue: selectable ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'ประเภทธุรกิจ *',
        helperText: locked
            ? 'ไม่สามารถเปลี่ยนได้ เนื่องจาก Company มีข้อมูลบุคคลแล้ว'
            : 'ใบแจ้งซ่อมจะอ้างอิงผู้แจ้งเป็น $requesterCaption',
      ),
      items: options
          .map(
            (item) => DropdownMenuItem<String>(
              value: item['code']?.toString(),
              child: Text(item['name']?.toString() ?? ''),
            ),
          )
          .toList(),
      onChanged: enabled && !locked
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
    );
  }
}

class _PartnerInfoCard extends StatelessWidget {
  const _PartnerInfoCard({
    required this.nameTh,
    required this.address,
    required this.telephone,
    required this.email,
  });

  final String? nameTh;
  final String? address;
  final String? telephone;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final useTwoColumns = constraints.maxWidth >= 700;
            final itemWidth = useTwoColumns
                ? (constraints.maxWidth - gap) / 2
                : constraints.maxWidth;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.handshake_outlined,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Partner',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'ข้อมูลผู้ดูแลระบบของลูกค้า',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _PartnerInfoItem(
                        icon: Icons.badge_outlined,
                        label: 'ชื่อ Partner (ภาษาไทย)',
                        value: nameTh,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _PartnerInfoItem(
                        icon: Icons.phone_outlined,
                        label: 'เบอร์โทร',
                        value: telephone,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _PartnerInfoItem(
                        icon: Icons.location_on_outlined,
                        label: 'ที่อยู่',
                        value: address,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _PartnerInfoItem(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        value: email,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PartnerInfoItem extends StatelessWidget {
  const _PartnerInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final displayValue = value?.trim().isNotEmpty == true ? value!.trim() : '-';

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  displayValue,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacySetupCards extends StatelessWidget {
  const _LegacySetupCards({
    required this.showCompanyCards,
    required this.configurationOnly,
    required this.startupSettingsVisible,
    required this.startupSettingsLoaded,
    required this.startupSettingsLoadFailed,
    required this.startupSettingsEditable,
    required this.startupMode,
    required this.startupUrlController,
    required this.onStartupModeChanged,
    required this.controllers,
    required this.yearFormat,
    required this.onYearFormatChanged,
    required this.orgStructureType,
    required this.employeeNameDisplay,
    required this.onEmployeeNameDisplayChanged,
    required this.onOrgStructureTypeChanged,
    required this.passwordPolicyCode,
    required this.onPasswordPolicyCodeChanged,
  });

  final Map<String, TextEditingController> controllers;
  final bool showCompanyCards;
  final bool configurationOnly;
  final bool startupSettingsVisible;
  final bool startupSettingsLoaded;
  final bool startupSettingsLoadFailed;
  final bool startupSettingsEditable;
  final int startupMode;
  final TextEditingController startupUrlController;
  final ValueChanged<int> onStartupModeChanged;
  final String yearFormat;
  final ValueChanged<String> onYearFormatChanged;
  final int orgStructureType;
  final String employeeNameDisplay;
  final ValueChanged<String> onEmployeeNameDisplayChanged;
  final ValueChanged<int> onOrgStructureTypeChanged;
  final int passwordPolicyCode;
  final ValueChanged<int> onPasswordPolicyCodeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (configurationOnly)
          _SetupCard(
            title: 'กำหนดข้อมูล',
            icon: Icons.settings_outlined,
            collapsible: true,
            children: [
              _ResponsiveSetupFields(
                maxColumns: 3,
                children: [
                  _OrgStructureField(
                    value: orgStructureType,
                    onChanged: onOrgStructureTypeChanged,
                  ),
                  if (showCompanyCards)
                    DropdownButtonFormField<String>(
                      initialValue: employeeNameDisplay,
                      decoration: const InputDecoration(
                        labelText: 'รูปแบบแสดงชื่อพนักงาน',
                      ),
                      items: CompanySetupConstants.employeeNameOptions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                CompanySetupConstants.employeeNameLabel(value),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onEmployeeNameDisplayChanged(value);
                      },
                    ),
                  _PasswordPolicyField(
                    value: passwordPolicyCode,
                    onChanged: onPasswordPolicyCodeChanged,
                  ),
                  if (startupSettingsVisible && !startupSettingsLoaded)
                    Text(
                      startupSettingsLoadFailed
                          ? 'อ่านรูปแบบการเริ่มต้นหน้าจอไม่สำเร็จ กรุณาตรวจสิทธิ์เข้าถึง appsettings.json'
                          : 'กำลังอ่านรูปแบบการเริ่มต้นหน้าจอจาก appsettings.json…',
                    ),
                  if (startupSettingsVisible && startupSettingsLoaded) ...[
                    DropdownButtonFormField<int>(
                      initialValue: startupMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'รูปแบบการเริ่มต้นหน้าจอ',
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('เข้าสู่ระบบ')),
                        DropdownMenuItem(value: 2, child: Text('URL ภายนอก')),
                        DropdownMenuItem(value: 3, child: Text('ค้นหาช่าง')),
                        DropdownMenuItem(
                          value: 4,
                          child: Text('หน้า Intranet'),
                        ),
                      ],
                      onChanged: startupSettingsEditable
                          ? (value) {
                              if (value != null) onStartupModeChanged(value);
                            }
                          : null,
                    ),
                    TextFormField(
                      controller: startupUrlController,
                      enabled: startupSettingsEditable,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'URL หน้าเริ่มต้น',
                        helperText: 'ใช้เมื่อเลือกรูปแบบ URL ภายนอก',
                      ),
                      validator: (value) {
                        if (startupMode != 2) return null;
                        if (!_isValidHomePageUrl(value ?? '')) {
                          return 'กรุณาระบุ URL แบบ HTTP หรือ HTTPS';
                        }
                        return null;
                      },
                    ),
                  ],
                  _LegacyField(
                    label: 'จำนวนแถว List',
                    value: '30',
                    controller: controllers['rowStd'],
                  ),
                  _LegacyField(
                    label: 'จำนวน Card',
                    value: '30',
                    controller: controllers['rowCardStd'],
                  ),
                  _LegacyField(
                    label: 'เวลา Alert (วินาที)',
                    value: '30',
                    controller: controllers['timeAlert'],
                  ),
                  if (showCompanyCards) ...[
                    _YearFormatField(
                      value: yearFormat,
                      onChanged: onYearFormatChanged,
                    ),
                    _LegacyField(
                      label: 'Version',
                      value: '1.0.0',
                      controller: controllers['versionId'],
                    ),
                    _LegacyField(label: 'Theme', value: 'ตาม Theme Standard'),
                  ],
                ],
              ),
            ],
          ),
        if (showCompanyCards && !configurationOnly) ...[
          _SetupCard(
            title: 'Audit (แถวบน)',
            icon: Icons.history_rounded,
            children: [
              _ResponsiveSetupFields(
                maxColumns: 3,
                children: [
                  _LegacyField(label: 'สถานะ', value: 'ใช้งาน'),
                  _LegacyField(label: 'สร้างเมื่อ', value: '08/08/2569'),
                  _LegacyField(label: 'แก้ไขล่าสุด', value: '11/08/2569'),
                ],
              ),
            ],
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          _SetupCard(
            title: 'Email Configuration',
            icon: Icons.mail_outline_rounded,
            children: [
              _ResponsiveSetupFields(
                maxColumns: 5,
                children: [
                  _LegacyField(
                    label: 'Email Host',
                    value: 'smtp.gmail.com',
                    controller: controllers['emailHost'],
                  ),
                  _LegacyField(
                    label: 'Email Port',
                    value: '587',
                    controller: controllers['emailPort'],
                  ),
                  _LegacyField(
                    label: 'Email Center (ส่งออกอัตโนมัติ)',
                    value: 'nodfinger@gmail.com',
                    controller: controllers['emailCenter'],
                  ),
                  _LegacyField(
                    label: 'Email Center (User แจ้งปัญหา)',
                    value: 'nodfinger@gmail.com',
                    controller: controllers['emailAdmin'],
                  ),
                  if (controllers['emailPasswordCenter'] case final controller?)
                    _SecretField(
                      label: 'Email Password / App Password',
                      controller: controller,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          _SetupCard(
            title: 'Security / Secret',
            icon: Icons.lock_outline_rounded,
            children: [
              _ResponsiveSetupFields(
                maxColumns: 3,
                children: [
                  _LegacyField(
                    label: 'Super User',
                    value: 'ตั้งค่าแล้ว',
                    controller: controllers['superUserName'],
                  ),
                  _LegacyField(
                    label: 'PasswordCry',
                    value: 'ตั้งค่าแล้ว',
                    controller: controllers['passwordCry'],
                  ),
                  _LegacyField(
                    label: 'Password พนักงาน',
                    value: 'ยังไม่ตั้งค่า',
                    controller: controllers['passwordEmpDefault'],
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Keep each settings card full-width and wrap fields on smaller screens.
class _ResponsiveSetupFields extends StatelessWidget {
  const _ResponsiveSetupFields({
    required this.maxColumns,
    required this.children,
  });
  final int maxColumns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 14.0;
      final columns = ((constraints.maxWidth + gap) / (190 + gap))
          .floor()
          .clamp(1, maxColumns);
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  void expand() {
    if (!_expanded) setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '${_expanded ? 'ย่อ' : 'ขยาย'}${widget.title}',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
          ),
        ),
        Visibility(
          visible: _expanded,
          maintainState: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: widget.child,
          ),
        ),
      ],
    ),
  );
}

class _SetupCard extends StatefulWidget {
  const _SetupCard({
    required this.title,
    required this.icon,
    required this.children,
    this.collapsible = true,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool collapsible;

  @override
  State<_SetupCard> createState() => _SetupCardState();
}

class _SetupCardState extends State<_SetupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.title.endsWith('Audit')) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: widget.collapsible
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              child: Row(
                children: [
                  Icon(widget.icon, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.collapsible)
                    IconButton(
                      tooltip: _expanded
                          ? 'ย่อ${widget.title}'
                          : 'ขยาย${widget.title}',
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                ],
              ),
            ),
            Visibility(
              visible: _expanded,
              maintainState: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const SizedBox(height: 16), ...widget.children],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyField extends StatelessWidget {
  const _LegacyField({
    required this.label,
    required this.value,
    this.controller,
  });

  final String label;
  final String value;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = switch (label) {
      'Super User' => 'Super User (เข้าได้ทุกเมนู)',
      'PasswordCry' => 'Password Super User',
      _ => label,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? value : null,
        decoration: InputDecoration(labelText: resolvedLabel),
      ),
    );
  }
}

bool _isValidHomePageUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty || raw.length > 2048 || raw.contains(RegExp(r'\s'))) {
    return false;
  }
  final candidate = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(raw)
      ? raw
      : 'https://$raw';
  final uri = Uri.tryParse(candidate);
  return uri != null &&
      const {'http', 'https'}.contains(uri.scheme.toLowerCase()) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

class _SecretField extends StatefulWidget {
  const _SecretField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: IconButton(
            tooltip: _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }
}

class _OrgStructureField extends StatelessWidget {
  const _OrgStructureField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<int>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'โครงสร้างองค์กร'),
      items: const [
        DropdownMenuItem(value: 1, child: LaooComboBoxText('แผนกเท่านั้น')),
        DropdownMenuItem(value: 2, child: LaooComboBoxText('ฝ่าย > แผนก')),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}

class _PasswordPolicyField extends StatelessWidget {
  const _PasswordPolicyField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<int>(
      initialValue: const [1, 2, 3].contains(value) ? value : 3,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.35),
      decoration: const InputDecoration(
        labelText: 'Password Policy',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(
          value: 1,
          child: Text(
            '1 - อิสระ อย่างน้อย 1 ตัว',
            style: TextStyle(fontSize: 14),
          ),
        ),
        DropdownMenuItem(
          value: 2,
          child: Text('2 - ขั้นต่ำ 4 ตัว', style: TextStyle(fontSize: 14)),
        ),
        DropdownMenuItem(
          value: 3,
          child: Text(
            '3 - ขั้นต่ำ 6 ตัว + เงื่อนไข',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}

class _YearFormatField extends StatelessWidget {
  const _YearFormatField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: CompanySetupConstants.yearFormatOptions.contains(value)
            ? value
            : CompanySetupConstants.yearFormatAd,
        decoration: const InputDecoration(labelText: 'รูปแบบปี'),
        items: CompanySetupConstants.yearFormatOptions
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: LaooComboBoxText(
                  CompanySetupConstants.yearFormatLabel(item),
                ),
              ),
            )
            .toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _CompanySetupUxForm extends StatelessWidget {
  const _CompanySetupUxForm({
    required this.ownerCode,
    required this.ownerName,
    required this.titleHeader,
    required this.customerNameTh,
    required this.customerNameEn,
    required this.address,
    required this.telephone,
    required this.taxId,
    required this.email,
    this.businessType,
    this.logo,
  });

  final TextEditingController ownerCode;
  final TextEditingController ownerName;
  final TextEditingController titleHeader;
  final TextEditingController customerNameTh;
  final TextEditingController customerNameEn;
  final TextEditingController address;
  final TextEditingController telephone;
  final TextEditingController taxId;
  final TextEditingController email;
  final Widget? businessType;
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (logo != null && constraints.maxWidth >= 850) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CompanySetupUxForm(
                      ownerCode: ownerCode,
                      ownerName: ownerName,
                      titleHeader: titleHeader,
                      customerNameTh: customerNameTh,
                      customerNameEn: customerNameEn,
                      address: address,
                      telephone: telephone,
                      taxId: taxId,
                      email: email,
                      businessType: businessType,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(width: 190, child: logo!),
                ],
              );
            }
            const gap = 14.0;
            final threeColumns = constraints.maxWidth >= 900;
            final twoColumns = constraints.maxWidth >= 620;
            final thirdWidth = (constraints.maxWidth - gap * 2) / 3;
            final halfWidth = (constraints.maxWidth - gap) / 2;
            final firstRowWidth =
                businessType != null && constraints.maxWidth >= 1100
                ? (constraints.maxWidth - gap * 3) / 4
                : (businessType != null && twoColumns ? halfWidth : thirdWidth);

            SizedBox field(Widget child, double width) =>
                SizedBox(width: width, child: child);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (logo != null) ...[logo!, const SizedBox(height: 16)],
                Wrap(
                  spacing: gap,
                  runSpacing: 14,
                  children: [
                    field(
                      _text(ownerCode, 'รหัสเจ้าของ', readOnly: true),
                      threeColumns || (businessType != null && twoColumns)
                          ? firstRowWidth
                          : constraints.maxWidth,
                    ),
                    field(
                      _text(ownerName, 'ข้อความแสดง title bar'),
                      threeColumns || (businessType != null && twoColumns)
                          ? firstRowWidth
                          : constraints.maxWidth,
                    ),
                    field(
                      _text(titleHeader, 'หัวข้อระบบ'),
                      threeColumns || (businessType != null && twoColumns)
                          ? firstRowWidth
                          : constraints.maxWidth,
                    ),
                    if (businessType != null)
                      field(
                        businessType!,
                        twoColumns ? firstRowWidth : constraints.maxWidth,
                      ),
                    field(
                      _text(
                        customerNameTh,
                        'ชื่อลูกค้า (ภาษาไทย)',
                        required: true,
                      ),
                      twoColumns ? halfWidth : constraints.maxWidth,
                    ),
                    field(
                      _text(
                        customerNameEn,
                        'ชื่อลูกค้า (ภาษาอังกฤษ)',
                        required: false,
                      ),
                      twoColumns ? halfWidth : constraints.maxWidth,
                    ),
                    field(
                      _text(address, 'ที่อยู่', maxLines: 2),
                      constraints.maxWidth,
                    ),
                    field(
                      _text(
                        telephone,
                        'โทรศัพท์',
                        keyboardType: TextInputType.phone,
                      ),
                      twoColumns ? thirdWidth : constraints.maxWidth,
                    ),
                    field(
                      _text(taxId, 'เลขผู้เสียภาษี'),
                      twoColumns ? thirdWidth : constraints.maxWidth,
                    ),
                    field(
                      _text(
                        email,
                        'Email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      twoColumns ? thirdWidth : constraints.maxWidth,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        label: _RequiredLabel(label, required: required),
      ),
      validator: required
          ? (value) =>
                value == null || value.trim().isEmpty ? 'กรุณาระบุ$label' : null
          : null,
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title}) : description = null;

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (description?.trim().isNotEmpty == true) ...[
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              description!,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions({
    required this.saving,
    required this.onCancel,
    required this.onSave,
    required this.canSave,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool canSave;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: saving ? null : onCancel,
          icon: const Icon(Icons.close_rounded),
          label: const Text('ยกเลิก'),
        ),
        if (canSave)
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('บันทึก'),
          ),
      ],
    );
  }
}
