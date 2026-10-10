import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'pet_host.dart';

class PetOwnerInfoPage extends StatefulWidget {
  const PetOwnerInfoPage({super.key});
  @override
  State<PetOwnerInfoPage> createState() => _PetOwnerInfoPageState();
}

class _PetOwnerInfoPageState extends State<PetOwnerInfoPage> {
  late final api = petApi();
  Map<String, dynamic> meta = {};
  bool loading = true;
  String? error;
  LaooWorkspaceUiTokens get tokens => petTokens();
  String get title => meta['MenuName']?.toString() ?? 'กำลังโหลด...';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    petDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = Map<String, dynamic>.from(
        await api.get('/api/company/pet/actions/62009') as Map,
      );
      meta = Map<String, dynamic>.from(data['metadata'] as Map);
      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = petErrorText(e, 'โหลดข้อมูลพอร์ทัลเจ้าของสัตว์');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => petShell(
    pageTitle: title,
    activeMenu: 'pet-owner-portal',
    child: ColoredBox(
      color: tokens.backgroundColor,
      child: SingleChildScrollView(
        padding: tokens.contentMargin,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LaooCaptionCard(
              tokens: tokens,
              caption: title,
              favoriteKey: 'pet-owner-portal',
              leading: Icon(
                petMenuIcon(meta['IconName']?.toString()),
                color: tokens.primaryColor,
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            LaooSurfaceCard(
              tokens: tokens,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(error!),
                        OutlinedButton.icon(
                          onPressed: load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองอีกครั้ง'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('สำหรับเจ้าของสัตว์', style: tokens.sectionStyle),
                        const SizedBox(height: 12),
                        const Text(
                          'เจ้าของสัตว์เข้าสู่ระบบด้วยบัญชีสมาชิก Booking เพื่อดูสัตว์และประวัติบริการของตนเอง',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'ก่อนเปิดข้อมูล ต้องผูกบัญชีสมาชิกกับโปรไฟล์สัตว์จากหน้าทะเบียนสัตว์เลี้ยง',
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/booking/member'),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('เปิดพอร์ทัลสมาชิก'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
