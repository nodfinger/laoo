import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/auth/app_auth_controller.dart';

/// Compatibility page retained during the navigation migration.
///
/// The active Laoo Support flow now uses SupportHomePage.
/// This page intentionally contains no legacy MaterialApp named-route calls.
class AuthenticatedHomePage extends StatelessWidget {
  const AuthenticatedHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = appAuthController.session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laoo Solutions'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await appAuthController.logout();
              appRouter.goNamed(RouteNames.landing);
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('ออกจากระบบ'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: Color(0xFF32C766),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'เข้าสู่ระบบแล้ว',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'User Type: '
                    '${session?.userType ?? '-'}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Project: '
                    '${session?.projectCode ?? '-'}',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      appRouter.goNamed(RouteNames.supportHome);
                    },
                    child: const Text('ไป Support Workspace'),
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
