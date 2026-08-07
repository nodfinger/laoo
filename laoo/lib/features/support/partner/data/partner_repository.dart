import '../models/partner.dart';

abstract class PartnerRepository {
  Future<List<Partner>> getPartners({String? search, bool? isActive});

  Future<Partner> getPartner(int partnerId);

  Future<Partner> createPartner(PartnerUpsertInput input);

  Future<void> updatePartner(int partnerId, PartnerUpsertInput input);

  Future<void> changeStatus(int partnerId, bool isActive);
}
