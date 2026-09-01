import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/partner_repository.dart';
import '../models/partner.dart';

class PartnerListController {
  PartnerListController(this._repository);

  final PartnerRepository _repository;

  AsyncValue<List<Partner>> state = const AsyncValue<List<Partner>>.loading();

  Future<void> load({String? search, bool? isActive}) async {
    state = const AsyncValue<List<Partner>>.loading();

    state = await AsyncValue.guard(
      () => _repository.getPartners(search: search, isActive: isActive),
    );
  }

  Future<void> refresh() => load();
}
