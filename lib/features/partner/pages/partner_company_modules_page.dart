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
  List<PartnerCompanyProject> _projects = const [];
  Map<int, bool> _selection = const {};
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
      final projects = await _repository.getCompanyProjects(
        widget.company.companyId,
      );
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _selection = {
          for (final project in projects) project.projectId: project.isEnabled,
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
      await _repository.updateCompanyProjects(
        widget.company.companyId,
        _selection,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'บันทึกระบบที่เปิดใช้ไม่สำเร็จ: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.menuName} > ระบบที่เปิดใช้';
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
    final enabledCount = _selection.values.where((enabled) => enabled).length;
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
              'ระบบที่เปิดใช้',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: LaooTypography.sectionTitle,
                fontWeight: LaooTypography.emphasizedWeight,
                color: LaooColors.textPrimary,
              ),
            ),
          ],
        ),
        Text(
          'เปิด $enabledCount จาก ${_projects.length} ระบบ',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: LaooColors.textSecondary),
        ),
      ],
    );
  }

  Widget _featureGrid(BuildContext context, {required bool compact}) {
    if (compact) {
      return Column(
        children: [
          for (var index = 0; index < _projects.length; index++) ...[
            _projectRow(_projects[index]),
            if (index < _projects.length - 1) const SizedBox(height: 6),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final project in _projects)
              SizedBox(width: itemWidth, child: _projectRow(project)),
          ],
        );
      },
    );
  }

  Widget _projectRow(PartnerCompanyProject project) {
    final enabled = _selection[project.projectId] == true;
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      decoration: BoxDecoration(
        color: enabled
            ? primary.withValues(alpha: 0.08)
            : LaooColors.surfaceSoft,
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.projectNameTh,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: LaooTypography.emphasizedWeight,
                    color: LaooColors.textPrimary,
                    height: LaooTypography.bodyLineHeight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  project.description?.trim().isNotEmpty == true
                      ? project.description!
                      : project.projectCode,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LaooColors.textSecondary,
                    height: LaooTypography.bodyLineHeight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Switch.adaptive(
                value: enabled,
                onChanged: _saving || project.isCore
                    ? null
                    : (value) => setState(() {
                        _selection = {..._selection, project.projectId: value};
                      }),
                activeThumbColor: primary,
              ),
              Text(
                project.isCore
                    ? 'ระบบหลัก'
                    : enabled
                    ? 'เปิดใช้งาน'
                    : 'ปิดใช้งาน',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: enabled ? primary : LaooColors.textSecondary,
                  fontWeight: LaooTypography.emphasizedWeight,
                ),
              ),
            ],
          ),
        ],
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
