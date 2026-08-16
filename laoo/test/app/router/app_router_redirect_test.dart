import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_router.dart';
import 'package:laoo/app/router/route_paths.dart';

void main() {
  String? redirect({
    required String path,
    bool isChecking = false,
    bool isAuthenticated = false,
    bool isLaooSupport = false,
    bool isCompanyUser = false,
    bool isPartnerUser = false,
    Set<String> allowedMenuCodes = const <String>{},
  }) {
    return resolveAppRouteRedirect(
      path: path,
      isChecking: isChecking,
      isAuthenticated: isAuthenticated,
      isLaooSupport: isLaooSupport,
      isCompanyUser: isCompanyUser,
      isPartnerUser: isPartnerUser,
      allowedMenuCodes: allowedMenuCodes,
    );
  }

  group('route security', () {
    test('waits while authentication is checking', () {
      expect(redirect(path: RoutePaths.supportHome, isChecking: true), isNull);
    });

    test('allows only public routes while unauthenticated', () {
      for (final path in <String>[
        RoutePaths.landing,
        RoutePaths.login,
        RoutePaths.resetPassword,
      ]) {
        expect(redirect(path: path), isNull, reason: path);
      }

      for (final path in <String>[
        RoutePaths.authenticatedHome,
        RoutePaths.supportHome,
        RoutePaths.companyProducts,
        RoutePaths.partnerCompanies,
        RoutePaths.masterData,
        '/private-route',
      ]) {
        expect(redirect(path: path), RoutePaths.login, reason: path);
      }
    });

    test('sends authenticated users away from landing and login by role', () {
      for (final path in <String>[RoutePaths.landing, RoutePaths.login]) {
        expect(
          redirect(path: path, isAuthenticated: true, isLaooSupport: true),
          RoutePaths.supportHome,
          reason: path,
        );
        expect(
          redirect(path: path, isAuthenticated: true, isPartnerUser: true),
          RoutePaths.authenticatedHome,
          reason: path,
        );
        expect(
          redirect(path: path, isAuthenticated: true, isCompanyUser: true),
          RoutePaths.authenticatedHome,
          reason: path,
        );
      }
    });

    test('keeps reset password public for authenticated users', () {
      expect(
        redirect(
          path: RoutePaths.resetPassword,
          isAuthenticated: true,
          isLaooSupport: true,
        ),
        isNull,
      );
    });

    test('keeps support scope guard without redirect loops', () {
      expect(
        redirect(
          path: RoutePaths.supportHome,
          isAuthenticated: true,
          isLaooSupport: true,
        ),
        isNull,
      );
      expect(
        redirect(
          path: RoutePaths.supportHome,
          isAuthenticated: true,
          isPartnerUser: true,
        ),
        RoutePaths.login,
      );
      expect(
        redirect(
          path: RoutePaths.login,
          isAuthenticated: true,
          isPartnerUser: true,
        ),
        RoutePaths.authenticatedHome,
      );
    });

    test('keeps company and partner scope guards', () {
      expect(
        redirect(
          path: RoutePaths.companyProducts,
          isAuthenticated: true,
          isCompanyUser: true,
          allowedMenuCodes: const {'08001'},
        ),
        isNull,
      );
      expect(
        redirect(
          path: RoutePaths.companyProducts,
          isAuthenticated: true,
          isPartnerUser: true,
        ),
        RoutePaths.authenticatedHome,
      );
      expect(
        redirect(
          path: RoutePaths.partnerCompanies,
          isAuthenticated: true,
          isPartnerUser: true,
          allowedMenuCodes: const {'06001'},
        ),
        isNull,
      );
      expect(
        redirect(
          path: RoutePaths.partnerCompanies,
          isAuthenticated: true,
          isCompanyUser: true,
        ),
        RoutePaths.authenticatedHome,
      );
    });

    test('keeps company setup shared scope', () {
      for (final role in <Map<String, bool>>[
        <String, bool>{'support': true},
        <String, bool>{'company': true},
        <String, bool>{'partner': true},
      ]) {
        expect(
          redirect(
            path: RoutePaths.companySetup,
            isAuthenticated: true,
            isLaooSupport: role['support'] ?? false,
            isCompanyUser: role['company'] ?? false,
            isPartnerUser: role['partner'] ?? false,
            allowedMenuCodes: const {'05001'},
          ),
          isNull,
        );
      }

      expect(
        redirect(path: RoutePaths.companySetup, isAuthenticated: true),
        RoutePaths.authenticatedHome,
      );
    });

    test('allows a direct menu URL only with VIEW permission by MenuCode', () {
      expect(
        redirect(
          path: RoutePaths.branch,
          isAuthenticated: true,
          isLaooSupport: true,
          allowedMenuCodes: const {'01003'},
        ),
        isNull,
      );
      expect(
        redirect(
          path: RoutePaths.branch,
          isAuthenticated: true,
          isLaooSupport: true,
          allowedMenuCodes: const {'01001', '01002'},
        ),
        RoutePaths.supportHome,
      );
    });

    test('uses role-specific MenuCode when scopes share one URL', () {
      expect(
        redirect(
          path: RoutePaths.organizationStructure,
          isAuthenticated: true,
          isPartnerUser: true,
          allowedMenuCodes: const {'11005'},
        ),
        isNull,
      );
      expect(
        redirect(
          path: RoutePaths.organizationStructure,
          isAuthenticated: true,
          isPartnerUser: true,
          allowedMenuCodes: const {'12005'},
        ),
        RoutePaths.authenticatedHome,
      );
    });

    test('keeps unknown authenticated routes protected', () {
      expect(
        redirect(
          path: '/unknown-route',
          isAuthenticated: true,
          isLaooSupport: true,
        ),
        RoutePaths.supportHome,
      );
      expect(
        redirect(
          path: '/unknown-route',
          isAuthenticated: true,
          isCompanyUser: true,
        ),
        RoutePaths.authenticatedHome,
      );
    });
  });
}
