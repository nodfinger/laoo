import 'package:flutter/material.dart';

import '../../../../app/laoo_app.dart';
import '../../../auth/data/services/auth_session_service.dart';

class AuthenticatedHomePage extends StatefulWidget {
  const AuthenticatedHomePage({super.key});

  @override
  State<AuthenticatedHomePage> createState() =>
      _AuthenticatedHomePageState();
}

class _AuthenticatedHomePageState
    extends State<AuthenticatedHomePage> {
  final _sessionService = AuthSessionService();

  AuthSession? _session;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await _sessionService.read();

    if (!mounted) {
      return;
    }

    if (session == null) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        LaooApp.loginRoute,
        (route) => false,
      );
      return;
    }

    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _sessionService.clear();

    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      LaooApp.landingRoute,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final session = _session!;
    final user = session.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F5),
      appBar: AppBar(
        title: const Text('Laoo Solutions'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('ออกจากระบบ'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                children: [
                  if (user.showSupportBanner)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE8C77B),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.support_agent_rounded),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Laoo Support กำลังใช้งานอยู่',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFDCE7DF),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 72,
                          color: Color(0xFF32C766),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'เข้าสู่ระบบสำเร็จ',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF16351F),
                          ),
                        ),
                        const SizedBox(height: 26),
                        _InfoRow(
                          label: 'ชื่อผู้ใช้',
                          value: user.displayName,
                        ),
                        _InfoRow(
                          label: 'Username',
                          value: user.username,
                        ),
                        _InfoRow(
                          label: 'Project',
                          value: user.projectCode,
                        ),
                        _InfoRow(
                          label: 'Login Mode',
                          value: user.loginMode,
                        ),
                        _InfoRow(
                          label: 'Login As User',
                          value: user.canLoginAsUser ? 'อนุญาต' : 'ไม่อนุญาต',
                        ),
                        _InfoRow(
                          label: 'Token หมดอายุ',
                          value: session.expiresAt?.toLocal().toString() ?? '-',
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'หน้านี้เป็น Dashboard ทดสอบสำหรับยืนยันว่า '
                          'Flutter เชื่อม Login API และรับ JWT สำเร็จแล้ว',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            height: 1.6,
                            color: Color(0xFF657368),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF536458),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF16351F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
