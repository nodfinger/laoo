import 'package:go_router/go_router.dart';
import 'pet_appointments_page.dart';
import 'pet_catalog_page.dart';
import 'pet_packages_page.dart';
import 'pet_owner_info_page.dart';
import 'pet_profile_page.dart';
import 'pet_reports_page.dart';
import 'pet_settings_page.dart';
import 'pet_work_page.dart';

class PetRoute {
  const PetRoute(this.menuCode, this.slug);
  final String menuCode;
  final String slug;
  String get routeName => 'pet-$slug';
  String get routePath => '/company/$routeName';
}

abstract final class PetRoutes {
  static const all = <PetRoute>[
    PetRoute('62001', 'settings'),
    PetRoute('62002', 'services'),
    PetRoute('62003', 'rooms'),
    PetRoute('62004', 'profiles'),
    PetRoute('62005', 'packages'),
    PetRoute('62006', 'appointments'),
    PetRoute('62007', 'work'),
    PetRoute('62008', 'history'),
    PetRoute('62009', 'owner-portal'),
    PetRoute('62010', 'dashboard'),
  ];
}

List<GoRoute> buildPetRoutes() => PetRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (context, state) => switch (route.menuCode) {
          '62001' => const PetSettingsPage(),
          '62002' => const PetCatalogPage(menuCode: '62002'),
          '62003' => const PetCatalogPage(menuCode: '62003'),
          '62004' => const PetProfilePage(),
          '62005' => const PetPackagesPage(),
          '62006' => const PetAppointmentsPage(),
          '62007' => const PetWorkPage(),
          '62008' => const PetReportsPage(menuCode: '62008'),
          '62009' => const PetOwnerInfoPage(),
          _ => const PetReportsPage(menuCode: '62010'),
        },
      ),
    )
    .toList();
