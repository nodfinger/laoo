import 'package:flutter/material.dart';

import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/api_partner_repository.dart';
import '../data/core_partner_api_client.dart';
import '../models/partner.dart';
import 'partner_form_page.dart';
import 'partner_list_page.dart';

class PartnerModulePage extends StatefulWidget {
  const PartnerModulePage({super.key});

  @override
  State<PartnerModulePage> createState() => _PartnerModulePageState();
}

class _PartnerModulePageState extends State<PartnerModulePage> {
  late final ApiPartnerRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = ApiPartnerRepository(CorePartnerApiClient());
  }

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceShell(
      pageTitle: 'Partner',
      activeMenu: 'partner',
      child: PartnerListPage(
        loadPartners: ({String? search, bool? isActive}) {
          return _repository.getPartners(search: search, isActive: isActive);
        },
        openCreate: _openCreate,
        openEdit: _openEdit,
        changeStatus: (partner, isActive) {
          return _repository.changeStatus(partner.partnerId, isActive);
        },
        deletePartner: (partner) {
          return _repository.deletePartner(partner.partnerId);
        },
        createPartnerAdmin: (partner, username, password) =>
            _repository.createPartnerAdmin(
              partner.partnerId,
              username: username,
              password: password,
            ),
        updatePartnerAdmin: (partner, username, password) =>
            _repository.updatePartnerAdmin(
              partner.partnerAdminUserId!,
              username: username,
              password: password,
            ),
      ),
    );
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SupportWorkspaceShell(
          pageTitle: 'Partner > เพิ่ม',
          activeMenu: 'partner',
          child: PartnerFormPage(
            onSave: (input) async {
              await _repository.createPartner(input);
            },
          ),
        ),
      ),
    );
  }

  Future<bool> _openEdit(Partner partner) async {
    final fresh = await _repository.getPartner(partner.partnerId);

    if (!mounted) return false;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SupportWorkspaceShell(
          pageTitle: 'Partner > แก้ไข',
          activeMenu: 'partner',
          child: PartnerFormPage(
            partner: fresh,
            onSave: (input) async {
              await _repository.updatePartner(fresh.partnerId, input);
            },
          ),
        ),
      ),
    );

    return updated == true;
  }
}
