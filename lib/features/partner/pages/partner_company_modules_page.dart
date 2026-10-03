import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/partner_company_repository.dart';
import '../models/partner_company.dart';

class PartnerCompanyModulesPage extends StatefulWidget {
  const PartnerCompanyModulesPage({
    required this.company,
    required this.menuName,
    super.key,
  });

  final PartnerCompany company;
  final String menuName;

  @override
  State<PartnerCompanyModulesPage> createState() =>
      _PartnerCompanyModulesPageState();
}

class _PartnerCompanyModulesPageState extends State<PartnerCompanyModulesPage> {
  final PartnerCompanyRepository _repository = PartnerCompanyRepository();
  List<PartnerCompanySubscription> _projects = const [];
  Map<int, int?> _packageByProject = const {};
  Map<int, String> _statusByProject = const {};
  Map<int, DateTime> _startByProject = const {};
  Map<int, DateTime?> _expireByProject = const {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projects = await _repository.getCompanySubscriptions(
        widget.company.companyId,
      );
      if (!mounted) return;
      setState(() {
        _projects = projects;
        final today = DateUtils.dateOnly(DateTime.now());
        _packageByProject = {
          for (final project in projects) project.projectId: project.packageId,
        };
        _statusByProject = {
          for (final project in projects)
            project.projectId: project.statusCode ?? 'ACTIVE',
        };
        _startByProject = {
          for (final project in projects)
            project.projectId: project.startDate ?? today,
        };
        _expireByProject = {
          for (final project in projects) project.projectId: project.expireDate,
        };
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'โหลดรายการระบบไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _projects.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      for (final project in _projects) {
        final packageId = _packageByProject[project.projectId];
        if (packageId == null) continue;
        await _repository.updateCompanySubscription(
          widget.company.companyId,
          project.projectId,
          packageId: packageId,
          statusCode: _statusByProject[project.projectId] ?? 'ACTIVE',
          startDate: _startByProject[project.projectId]!,
          expireDate: _expireByProject[project.projectId],
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'บันทึกแพ็กเกจไม่สำเร็จ: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.menuName} > กำหนดแพ็กเกจ';
    final compact = MediaQuery.sizeOf(context).width < 900;
    return SupportWorkspaceShell(
      pageTitle: title,
      activeMenu: 'partnerCompanies',
      menuScope: WorkspaceMenuScope.partner,
      child: ColoredBox(
        color: LaooColors.background,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(LaooLayout.cardMargin),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
                child: ColoredBox(
                  color: LaooColors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(LaooLayout.cardPadding),
                        child: WorkspaceActionHeader(
                          title: title,
                          favoriteKey: 'partnerCompanies',
                          actions: [
                            OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              icon: const Icon(Icons.close),
                              label: const Text('ยกเลิก'),
                            ),
                            FilledButton.icon(
                              onPressed: _saving || _loading ? null : _save,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('บันทึก'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: LaooColors.border),
                      Padding(
                        padding: const EdgeInsets.all(LaooLayout.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _companyContext(context, compact: compact),
                            const SizedBox(height: 12),
                            _sectionHeader(context),
                            const SizedBox(height: 12),
                            if (_loading)
                              const _LoadingFeatures()
                            else if (_projects.isEmpty)
                              const _EmptyFeatures()
                            else
                              _featureGrid(context, compact: compact),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null)
              Positioned(
                top: 12,
                right: 12,
                left: compact ? 12 : null,
                child: AutoDismissMessage(
                  key: ValueKey(_error),
                  message: _error!,
                  error: true,
                  onClose: () => setState(() => _error = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _companyContext(BuildContext context, {required bool compact}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _companyIdentity(context),
                const SizedBox(height: 8),
                _companyCode(context),
              ],
            )
          : Row(
              children: [
                Expanded(child: _companyIdentity(context)),
                const SizedBox(width: 12),
                _companyCode(context),
              ],
            ),
    );
  }

  Widget _companyIdentity(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: LaooColors.white,
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          child: Icon(Icons.business_outlined, color: primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ลูกค้าที่กำหนดระบบ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LaooColors.textSecondary,
                ),
              ),
              Text(
                widget.company.companyNameTh,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: LaooTypography.sectionTitle,
                  fontWeight: LaooTypography.emphasizedWeight,
                  color: LaooColors.textPrimary,
                  height: LaooTypography.titleLineHeight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _companyCode(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.tag_outlined, size: 18, color: LaooColors.textSecondary),
      const SizedBox(width: 6),
      Text(
        widget.company.companyCode,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: LaooTypography.emphasizedWeight,
          color: LaooColors.textPrimary,
        ),
      ),
    ],
  );

  Widget _sectionHeader(BuildContext context) {
    final enabledCount = _packageByProject.values.whereType<int>().length;
    final primary = Theme.of(context).colorScheme.primary;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps_outlined, color: primary),
            const SizedBox(width: 8),
            Text(
              'แพ็กเกจรายระบบ',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: LaooTypography.sectionTitle,
                fontWeight: LaooTypography.emphasizedWeight,
                color: LaooColors.textPrimary,
              ),
            ),
          ],
        ),
        Text(
          'กำหนดแล้ว $enabledCount จาก ${_projects.length} ระบบ',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: LaooColors.textSecondary),
        ),
      ],
    );
  }

  Widget _featureGrid(BuildContext context, {required bool compact}) {
    return Column(
      children: [
        for (var index = 0; index < _projects.length; index++) ...[
          _projectRow(_projects[index]),
          if (index < _projects.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _projectRow(PartnerCompanySubscription project) {
    final selectedPackage = _packageByProject[project.projectId];
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      decoration: BoxDecoration(
        color: selectedPackage != null
            ? primary.withValues(alpha: 0.08)
            : LaooColors.surfaceSoft,
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: LaooColors.white,
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
                child: Icon(_iconFor(project.projectCode), color: primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.projectNameTh,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: LaooTypography.emphasizedWeight,
                        color: LaooColors.textPrimary,
                      ),
                    ),
                    Text(
                      project.projectCode,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LaooColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _accessBadge(project.accessMode),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: constraints.maxWidth < 640
                      ? constraints.maxWidth
                      : 280,
                  child: DropdownButtonFormField<int?>(
                    initialValue: selectedPackage,
                    decoration: const InputDecoration(labelText: 'แพ็กเกจ *'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ยังไม่กำหนด'),
                      ),
                      ...project.packages.map(
                        (item) => DropdownMenuItem<int?>(
                          value: item.packageId,
                          child: Text(item.packageNameTh),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => _selectPackage(project, value),
                  ),
                ),
                if (selectedPackage != null) ...[
                  SizedBox(
                    width: constraints.maxWidth < 640
                        ? constraints.maxWidth
                        : 190,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          _statusByProject[project.projectId] ?? 'ACTIVE',
                      decoration: const InputDecoration(labelText: 'สถานะ *'),
                      items: const [
                        DropdownMenuItem(
                          value: 'ACTIVE',
                          child: Text('ใช้งาน'),
                        ),
                        DropdownMenuItem(
                          value: 'TRIAL',
                          child: Text('ทดลองใช้'),
                        ),
                        DropdownMenuItem(
                          value: 'SUSPENDED',
                          child: Text('ระงับ'),
                        ),
                        DropdownMenuItem(
                          value: 'CANCELLED',
                          child: Text('ยกเลิก'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _statusByProject = {
                                ..._statusByProject,
                                project.projectId: value ?? 'ACTIVE',
                              };
                            }),
                    ),
                  ),
                  _dateField(project, start: true),
                  _dateField(project, start: false),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectPackage(PartnerCompanySubscription project, int? packageId) {
    final package = project.packages
        .where((item) => item.packageId == packageId)
        .firstOrNull;
    final start = DateUtils.dateOnly(DateTime.now());
    DateTime? expire;
    if (package?.billingCycle == 'MONTHLY') {
      expire = DateTime(start.year, start.month + 1, start.day);
    } else if (package?.billingCycle == 'YEARLY') {
      expire = DateTime(start.year + 1, start.month, start.day);
    }
    setState(() {
      _packageByProject = {..._packageByProject, project.projectId: packageId};
      _startByProject = {..._startByProject, project.projectId: start};
      _expireByProject = {..._expireByProject, project.projectId: expire};
    });
  }

  Widget _dateField(PartnerCompanySubscription project, {required bool start}) {
    final value = start
        ? _startByProject[project.projectId]
        : _expireByProject[project.projectId];
    return SizedBox(
      width: 180,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _saving
            ? null
            : () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (selected == null || !mounted) return;
                setState(() {
                  if (start) {
                    _startByProject = {
                      ..._startByProject,
                      project.projectId: selected,
                    };
                  } else {
                    _expireByProject = {
                      ..._expireByProject,
                      project.projectId: selected,
                    };
                  }
                });
              },
        icon: const Icon(Icons.calendar_month_outlined, size: 18),
        label: Text(
          value == null
              ? (start ? 'วันเริ่ม' : 'ไม่หมดอายุ')
              : '${value.day.toString().padLeft(2, '0')}/'
                    '${value.month.toString().padLeft(2, '0')}/${value.year}',
        ),
      ),
    );
  }

  Widget _accessBadge(String? mode) {
    final label = switch (mode) {
      'FULL' => 'ใช้งาน',
      'READ_ONLY' => 'อ่านอย่างเดียว',
      'BLOCKED' => 'ปิดใช้งาน',
      _ => 'ยังไม่กำหนด',
    };
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static IconData _iconFor(String code) => switch (code) {
    'LAOO' => Icons.hub_outlined,
    'LAOO_SERVICE' => Icons.home_repair_service_outlined,
    'LAOO_MEETING' => Icons.meeting_room_outlined,
    _ => Icons.apps_outlined,
  };
}

class _EmptyFeatures extends StatelessWidget {
  const _EmptyFeatures();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Icon(
          Icons.apps_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 10),
        Text(
          'ยังไม่มีระบบที่พร้อมให้กำหนด',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}

class _LoadingFeatures extends StatelessWidget {
  const _LoadingFeatures();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 160,
    child: Center(child: CircularProgressIndicator()),
  );
}
