import 'package:go_router/go_router.dart';

import '../../core/auth/app_auth_controller.dart';
import '../../core/auth/auth_session.dart';
import '../../core/navigation/navigation_route_authorization.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/home/presentation/pages/authenticated_home_page.dart';
import '../../features/support/partner/pages/partner_module_page.dart';
import '../../features/partner/pages/partner_company_page.dart';
import '../../features/support/company_setup/pages/company_setup_page.dart';
import '../../features/support/presentation/pages/support_home_page.dart';
import '../../features/support/presentation/pages/support_placeholder_page.dart';
import '../../features/support/presentation/widgets/support_workspace_shell.dart';
import '../../features/support/technical_info/pages/technical_info_page.dart';
import '../../features/support/branch/pages/shared_branch_page.dart';
import '../../features/support/master_data/pages/master_data_page.dart';
import '../../features/support/organization/pages/shared_organization_structure_page.dart';
import '../../features/support/organization/pages/organization_supervisor_page.dart';
import '../../features/support/employee/pages/employee_shared_page.dart';
import '../../features/support/partner_user/pages/shared_partner_user_page.dart';
import '../../features/partner/pages/partner_company_user_page.dart';
import '../../features/meeting/pages/meeting_building_page.dart';
import '../../features/meeting/pages/meeting_facility_page.dart';
import '../../features/meeting/pages/meeting_food_page.dart';
import '../../features/meeting/pages/meeting_room_page.dart';
import '../../features/meeting/pages/meeting_room_booking_page.dart';
import '../../features/meeting/pages/meeting_room_approval_page.dart';
import '../../features/meeting/pages/meeting_food_plan_page.dart';
import '../../features/meeting/pages/meeting_invitation_page.dart';
import '../../features/access/role_group/pages/role_group_page.dart';
import '../../features/access/menu_permission/pages/menu_permission_page.dart';
import 'app_menu_route_registry.dart';
import 'route_names.dart';
import 'route_paths.dart';

final NavigationRouteAuthorization _navigationRouteAuthorization =
    NavigationRouteAuthorization();

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.landing,
  refreshListenable: appAuthController,
  redirect: (context, state) async {
    final isAuthenticated = appAuthController.isAuthenticated;
    final path = state.uri.path;
    Set<String> allowedMenuCodes = const <String>{};

    if (!isAuthenticated) {
      _navigationRouteAuthorization.clear();
    } else if (AppMenuRouteRegistry.containsPath(path)) {
      final session = appAuthController.session;
      if (session != null) {
        final requestedSessionKey = _navigationSessionKey(session);
        try {
          allowedMenuCodes = await _navigationRouteAuthorization
              .allowedMenuCodes(sessionKey: requestedSessionKey);
          final currentSession = appAuthController.session;
          if (!appAuthController.isAuthenticated || currentSession == null) {
            return RoutePaths.login;
          }
          if (_navigationSessionKey(currentSession) != requestedSessionKey) {
            return _authorizedHome(
              isLaooSupport: appAuthController.isLaooSupport,
            );
          }
        } catch (_) {
          // Navigation API is the VIEW-permission source of truth. If it is
          // unavailable, protected menu routes remain closed.
          allowedMenuCodes = const <String>{};
        }
      }
    }

    return resolveAppRouteRedirect(
      path: path,
      isChecking: appAuthController.isChecking,
      isAuthenticated: isAuthenticated,
      isLaooSupport: appAuthController.isLaooSupport,
      isCompanyUser: appAuthController.isCompanyUser,
      isPartnerUser: appAuthController.isPartnerUser,
      allowedMenuCodes: allowedMenuCodes,
    );
  },
  routes: [
    GoRoute(
      path: RoutePaths.landing,
      name: RouteNames.landing,
      builder: (context, state) => const LandingPage(),
    ),
    GoRoute(
      path: RoutePaths.login,
      name: RouteNames.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: RoutePaths.resetPassword,
      name: RouteNames.resetPassword,
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      path: RoutePaths.authenticatedHome,
      name: RouteNames.authenticatedHome,
      builder: (context, state) => const AuthenticatedHomePage(),
    ),
    GoRoute(
      path: RoutePaths.partnerCompanies,
      name: RouteNames.partnerCompanies,
      builder: (context, state) =>
          const PartnerCompanyPage(menuScope: WorkspaceMenuScope.partner),
    ),
    GoRoute(
      path: RoutePaths.partnerBranches,
      name: RouteNames.partnerBranches,
      builder: (context, state) =>
          const BranchPage(menuScope: WorkspaceMenuScope.partner),
    ),
    GoRoute(
      path: RoutePaths.companyBranches,
      name: RouteNames.companyBranches,
      builder: (context, state) =>
          const BranchPage(menuScope: WorkspaceMenuScope.company),
    ),
    GoRoute(
      path: RoutePaths.partnerUsers,
      name: RouteNames.partnerUsers,
      builder: (context, state) => const PartnerCompanyUserPage(),
    ),
    GoRoute(
      path: RoutePaths.supportHome,
      name: RouteNames.supportHome,
      builder: (context, state) => const SupportHomePage(),
    ),
    GoRoute(
      path: RoutePaths.partner,
      name: RouteNames.partner,
      builder: (context, state) => const PartnerModulePage(),
    ),
    ..._placeholderRoutes,
    ..._meetingRoomPlaceholderRoutes,
    GoRoute(
      path: RoutePaths.companySetup,
      name: RouteNames.companySetup,
      builder: (context, state) => SupportWorkspaceShell(
        pageTitle: 'กำหนดค่าระบบ',
        activeMenu: 'companySetup',
        menuScope: appAuthController.isLaooSupport
            ? WorkspaceMenuScope.support
            : appAuthController.isPartnerUser
            ? WorkspaceMenuScope.partner
            : WorkspaceMenuScope.company,
        child: CompanySetupPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.masterData,
      name: RouteNames.masterData,
      builder: (context, state) => MasterDataPage(
        menuScope: appAuthController.isLaooSupport
            ? WorkspaceMenuScope.support
            : appAuthController.isPartnerUser
            ? WorkspaceMenuScope.partner
            : WorkspaceMenuScope.company,
      ),
    ),
  ],
);

String? resolveAppRouteRedirect({
  required String path,
  required bool isChecking,
  required bool isAuthenticated,
  required bool isLaooSupport,
  required bool isCompanyUser,
  required bool isPartnerUser,
  Set<String> allowedMenuCodes = const <String>{},
}) {
  if (isChecking) {
    return null;
  }

  final isPublicRoute =
      path == RoutePaths.landing ||
      path == RoutePaths.login ||
      path == RoutePaths.resetPassword;

  if (!isAuthenticated) {
    return isPublicRoute ? null : RoutePaths.login;
  }

  if (path == RoutePaths.landing || path == RoutePaths.login) {
    return isLaooSupport
        ? RoutePaths.supportHome
        : RoutePaths.authenticatedHome;
  }

  final isCompanySetupRoute = path == RoutePaths.companySetup;
  final isSupportRoute =
      !isCompanySetupRoute &&
      (path == RoutePaths.supportHome ||
          path.startsWith('${RoutePaths.supportHome}/'));

  // Support Workspace is reserved for Laoo Support users.
  if (isSupportRoute && !isLaooSupport) {
    return RoutePaths.login;
  }

  // Company Setup keeps the existing shared role scope.
  if (isCompanySetupRoute &&
      !isCompanyUser &&
      !isPartnerUser &&
      !isLaooSupport) {
    return RoutePaths.authenticatedHome;
  }

  final isCompanyRoute = path.startsWith('/company/');
  if (isCompanyRoute && !isCompanyUser) {
    return RoutePaths.authenticatedHome;
  }

  final isPartnerRoute = path.startsWith('/partner/');
  if (isPartnerRoute && !isPartnerUser) {
    return RoutePaths.authenticatedHome;
  }

  final routeSpecs = AppMenuRouteRegistry.byPath(path);
  if (routeSpecs.isNotEmpty) {
    final allowedScopes = <AppMenuScope>{
      AppMenuScope.shared,
      if (isLaooSupport) AppMenuScope.support,
      if (isPartnerUser) AppMenuScope.partner,
      if (isCompanyUser) AppMenuScope.company,
    };
    final hasViewPermission = routeSpecs.any(
      (spec) =>
          allowedScopes.contains(spec.scope) &&
          allowedMenuCodes.contains(spec.menuCode),
    );
    if (!hasViewPermission) {
      return _authorizedHome(isLaooSupport: isLaooSupport);
    }
    return null;
  }

  final isKnownNonMenuRoute =
      path == RoutePaths.resetPassword ||
      path == RoutePaths.authenticatedHome ||
      path == RoutePaths.supportHome;
  if (!isKnownNonMenuRoute) {
    return _authorizedHome(isLaooSupport: isLaooSupport);
  }

  return null;
}

String _authorizedHome({required bool isLaooSupport}) =>
    isLaooSupport ? RoutePaths.supportHome : RoutePaths.authenticatedHome;

String _navigationSessionKey(AuthSession session) => <Object?>[
  session.accessToken,
  session.projectId,
  session.userType,
  session.laooUserId,
  session.userId,
  session.partnerId,
  session.companyId,
].join('|');

Future<void> refreshNavigationRoutePermissions() async {
  final session = appAuthController.session;
  if (session == null) {
    _navigationRouteAuthorization.clear();
  } else {
    try {
      await _navigationRouteAuthorization.allowedMenuCodes(
        sessionKey: _navigationSessionKey(session),
        refresh: true,
      );
    } catch (_) {
      // The next redirect remains fail-closed and can retry the API request.
    }
  }
  appRouter.refresh();
}

final List<GoRoute> _placeholderRoutes = [
  GoRoute(
    path: RoutePaths.companyEmployees,
    name: RouteNames.companyEmployees,
    builder: (context, state) => const EmployeeUxPage(
      customer: true,
      companyScoped: true,
      menuScope: WorkspaceMenuScope.company,
    ),
  ),
  GoRoute(
    path: RoutePaths.companySupervisors,
    name: RouteNames.companySupervisors,
    builder: (context, state) => const OrganizationSupervisorPage(),
  ),
  _scopePlaceholder(
    RoutePaths.companyUsers,
    RouteNames.companyUsers,
    'ผู้ใช้งาน',
    WorkspaceMenuScope.company,
    'companyUsers',
  ),
  GoRoute(
    path: RoutePaths.companyRoleGroups,
    name: RouteNames.companyRoleGroups,
    builder: (context, state) =>
        const RoleGroupPage(scope: 'customer', activeMenu: 'companyRoleGroups'),
  ),
  GoRoute(
    path: RoutePaths.companyMenuPermissions,
    name: RouteNames.companyMenuPermissions,
    builder: (context, state) => const MenuPermissionPage(
      scope: 'customer',
      activeMenu: 'companyMenuPermissions',
    ),
  ),
  GoRoute(
    path: RoutePaths.partnerEmployees,
    name: RouteNames.partnerEmployees,
    builder: (context, state) =>
        const EmployeeUxPage(menuScope: WorkspaceMenuScope.partner),
  ),
  GoRoute(
    path: RoutePaths.partnerRoleGroups,
    name: RouteNames.partnerRoleGroups,
    builder: (context, state) =>
        const RoleGroupPage(scope: 'partner', activeMenu: 'partnerRoleGroups'),
  ),
  GoRoute(
    path: RoutePaths.partnerMenuPermissions,
    name: RouteNames.partnerMenuPermissions,
    builder: (context, state) => const MenuPermissionPage(
      scope: 'partner',
      activeMenu: 'partnerMenuPermissions',
    ),
  ),
  GoRoute(
    path: RoutePaths.customerEmployees,
    name: RouteNames.customerEmployees,
    builder: (context, state) => const EmployeeUxPage(
      customer: true,
      menuScope: WorkspaceMenuScope.partner,
    ),
  ),
  GoRoute(
    path: RoutePaths.laooEmployees,
    name: RouteNames.laooEmployees,
    builder: (context, state) => const EmployeeUxPage(),
  ),
  _scopePlaceholder(
    RoutePaths.laooUsers,
    RouteNames.laooUsers,
    'ผู้ใช้งาน',
    WorkspaceMenuScope.support,
    'laooUsers',
  ),
  _placeholder(
    RoutePaths.laooUser,
    RouteNames.laooUser,
    'Laoo User',
    'laooUser',
  ),
  GoRoute(
    path: RoutePaths.partnerUser,
    name: RouteNames.partnerUser,
    builder: (context, state) => const PartnerUserPage(),
  ),
  _placeholder(
    RoutePaths.companyUser,
    RouteNames.companyUser,
    'Company User',
    'companyUser',
  ),
  _placeholder(RoutePaths.module, RouteNames.module, 'Module', 'module'),
  _placeholder(
    RoutePaths.customerModule,
    RouteNames.customerModule,
    'Customer Module',
    'customerModule',
  ),
  _placeholder(
    RoutePaths.permission,
    RouteNames.permission,
    'Role / Permission',
    'permission',
  ),
  _placeholder(RoutePaths.audit, RouteNames.audit, 'Audit Log', 'audit'),
  _placeholder(
    RoutePaths.loginLog,
    RouteNames.loginLog,
    'Login Log',
    'loginLog',
  ),
  GoRoute(
    path: RoutePaths.technicalInfo,
    name: RouteNames.technicalInfo,
    builder: (context, state) => const TechnicalInfoPage(),
  ),
  GoRoute(
    path: RoutePaths.organizationStructure,
    name: RouteNames.organizationStructure,
    builder: (context, state) => const OrganizationStructurePage(),
  ),
];

final List<GoRoute> _meetingRoomPlaceholderRoutes = [
  GoRoute(
    path: RoutePaths.meetingRoomBookings,
    name: RouteNames.meetingRoomBookings,
    builder: (context, state) => const MeetingRoomBookingPage(),
  ),
  GoRoute(
    path: RoutePaths.meetingRoomApprovals,
    name: RouteNames.meetingRoomApprovals,
    builder: (context, state) => const MeetingRoomApprovalPage(),
  ),
  GoRoute(
    path: RoutePaths.meetingRoomCalendar,
    name: RouteNames.meetingRoomCalendar,
    builder: (context, state) =>
        const MeetingRoomBookingPage(initialCalendar: true, menuCode: '13002'),
  ),
  GoRoute(
    path: RoutePaths.meetingInvitationRsvp,
    name: RouteNames.meetingInvitationRsvp,
    builder: (context, state) => const MeetingInvitationPage(),
  ),
  GoRoute(
    path: RoutePaths.meetingFoodPlans,
    name: RouteNames.meetingFoodPlans,
    builder: (context, state) => const MeetingFoodPlanPage(),
  ),
  _companyPlaceholder(
    RoutePaths.roomCheckIn,
    RouteNames.roomCheckIn,
    'เช็กอินและคืนห้อง',
  ),
  _companyPlaceholder(
    RoutePaths.roomSupportTasks,
    RouteNames.roomSupportTasks,
    'งานเตรียมห้องและอุปกรณ์',
  ),
  _companyPlaceholder(
    RoutePaths.roomIssues,
    RouteNames.roomIssues,
    'แจ้งปัญหาห้องประชุม',
  ),
  GoRoute(
    path: RoutePaths.meetingBuildings,
    name: RouteNames.meetingBuildings,
    builder: (context, state) => const MeetingBuildingPage(),
  ),
  GoRoute(
    path: RoutePaths.meetingRooms,
    name: RouteNames.meetingRooms,
    builder: (context, state) => const MeetingRoomPage(),
  ),
  GoRoute(
    path: RoutePaths.meetingFacilities,
    name: RouteNames.meetingFacilities,
    builder: (context, state) => const MeetingFacilityPage(),
  ),
  GoRoute(
    path: RoutePaths.meetingFoods,
    name: RouteNames.meetingFoods,
    builder: (context, state) => const MeetingFoodPage(),
  ),
  _companyPlaceholder(
    RoutePaths.meetingRoomUtilizationReport,
    RouteNames.meetingRoomUtilizationReport,
    'รายงานการใช้ห้อง',
  ),
  _companyPlaceholder(
    RoutePaths.meetingNoShowReport,
    RouteNames.meetingNoShowReport,
    'รายงาน No-show',
  ),
  _companyPlaceholder(
    RoutePaths.meetingFeedbackReport,
    RouteNames.meetingFeedbackReport,
    'ผลประเมินห้องประชุม',
  ),
];

GoRoute _companyPlaceholder(String path, String name, String title) => GoRoute(
  path: path,
  name: name,
  builder: (context, state) => CompanyModulePlaceholderPage(
    title: title,
    menuScope: WorkspaceMenuScope.company,
    activeMenu: name,
  ),
);

GoRoute _scopePlaceholder(
  String path,
  String name,
  String title,
  WorkspaceMenuScope scope,
  String activeMenu,
) => GoRoute(
  path: path,
  name: name,
  builder: (context, state) => path == RoutePaths.partnerEmployees
      ? const EmployeeUxPage(menuScope: WorkspaceMenuScope.partner)
      : CompanyModulePlaceholderPage(
          title: title,
          menuScope: scope,
          activeMenu: activeMenu,
        ),
);

GoRoute _placeholder(
  String path,
  String name,
  String title,
  String activeMenu,
) {
  return GoRoute(
    path: path,
    name: name,
    builder: (context, state) =>
        SupportPlaceholderPage(title: title, activeMenu: activeMenu),
  );
}
