import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

import '../shared/shared_admin_ui_tokens.dart';
import 'employee_action_workspace.dart';
import 'employee_list_controller.dart';
import 'employee_list_workspace.dart';
import 'employee_workspace_dependencies.dart';

typedef EmployeeDeleteConfirmation =
    Future<bool> Function(BuildContext context, EmployeeRecord employee);

class EmployeeWorkspace extends StatefulWidget {
  const EmployeeWorkspace({
    super.key,
    required this.caption,
    required this.repository,
    required this.screenType,
    required this.pageSize,
    required this.companies,
    required this.organizationUnits,
    required this.organizationMode,
    required this.customerScope,
    required this.roleGroups,
    required this.carTypes,
    required this.oilTypes,
    required this.titleBuilder,
    required this.messageBuilder,
    required this.tokens,
    required this.formatDate,
    required this.errorText,
    required this.confirmDelete,
    this.pickImage,
    this.thumbnailBuilder,
  });

  final String caption;
  final EmployeeRepository repository;
  final int screenType;
  final int pageSize;
  final List<EmployeeCompanyOption> companies;
  final List<OrganizationUnitRecord> organizationUnits;
  final int organizationMode;
  final bool customerScope;
  final List<EmployeeRoleGroupOption> roleGroups;
  final List<EmployeeMasterOption> carTypes;
  final List<EmployeeMasterOption> oilTypes;
  final SharedAdminTitleBuilder titleBuilder;
  final SharedAdminMessageBuilder messageBuilder;
  final SharedAdminUiTokens tokens;
  final EmployeeDateText formatDate;
  final SharedAdminErrorText errorText;
  final EmployeeDeleteConfirmation confirmDelete;
  final EmployeeImagePicker? pickImage;
  final EmployeeThumbnailBuilder? thumbnailBuilder;

  @override
  State<EmployeeWorkspace> createState() => _EmployeeWorkspaceState();
}

class _EmployeeWorkspaceState extends State<EmployeeWorkspace> {
  late final EmployeeListController _controller;
  EmployeeRecord? _editing;
  bool _formOpen = false;
  int _createRevision = 0;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _controller = EmployeeListController(
      repository: widget.repository,
      pageSize: widget.pageSize,
      screenType: widget.screenType,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.initialize();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openAdd() => setState(() {
    _editing = null;
    _formOpen = true;
    _message = null;
  });

  void _openEdit(EmployeeRecord employee) => setState(() {
    _editing = employee;
    _formOpen = true;
    _message = null;
  });

  void _closeForm() => setState(() {
    _formOpen = false;
    _editing = null;
  });

  void _showMessage(String message, bool error) => setState(() {
    _message = message;
    _messageIsError = error;
  });

  Future<void> _saved(EmployeeRecord? original, int employeeId) async {
    await _controller.load();
    if (!mounted) return;
    setState(() {
      if (original == null) {
        _editing = null;
        _formOpen = true;
        _createRevision++;
      } else {
        _editing = null;
        _formOpen = false;
      }
    });
  }

  Future<void> _delete(EmployeeRecord employee) async {
    final confirmed = await widget.confirmDelete(context, employee);
    if (!confirmed || !mounted) return;
    try {
      await widget.repository.delete(
        employee.employeeId,
        companyId: employee.companyId,
      );
      if (!mounted) return;
      _showMessage('ลบข้อมูลพนักงานสำเร็จ', false);
      await _controller.load();
    } catch (error) {
      if (mounted) {
        _showMessage(
          'ลบข้อมูลพนักงานไม่สำเร็จ: ${widget.errorText(error)}',
          true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: widget.tokens.contentMargin,
        child: _formOpen
            ? EmployeeActionWorkspace(
                key: ValueKey((_editing?.employeeId, _createRevision)),
                caption: widget.caption,
                repository: widget.repository,
                employee: _editing,
                companyId: _editing?.companyId ?? _controller.companyId,
                customerScope: widget.customerScope,
                companies: widget.companies,
                organizationUnits: widget.organizationUnits,
                organizationMode: widget.organizationMode,
                roleGroups: widget.roleGroups,
                carTypes: widget.carTypes,
                oilTypes: widget.oilTypes,
                canSave:
                    (_editing == null && _controller.canCreate) ||
                    (_editing != null && _controller.canEdit),
                titleBuilder: widget.titleBuilder,
                tokens: widget.tokens,
                formatDate: widget.formatDate,
                errorText: widget.errorText,
                onCancel: _closeForm,
                onSaved: _saved,
                onMessage: _showMessage,
                pickImage: widget.pickImage,
              )
            : EmployeeListWorkspace(
                caption: widget.caption,
                controller: _controller,
                companies: widget.companies,
                organizationUnits: widget.organizationUnits,
                organizationMode: widget.organizationMode,
                customerScope: widget.customerScope,
                titleBuilder: widget.titleBuilder,
                tokens: widget.tokens,
                onAdd: _openAdd,
                onEdit: _openEdit,
                onDelete: _delete,
                onUser: _openEdit,
                thumbnailBuilder: widget.thumbnailBuilder,
              ),
      ),
      if (_message != null)
        Positioned(
          top: widget.tokens.contentMargin.top,
          right: widget.tokens.contentMargin.right,
          child: widget.messageBuilder(
            context,
            _message!,
            _messageIsError,
            () => setState(() => _message = null),
          ),
        ),
    ],
  );
}
