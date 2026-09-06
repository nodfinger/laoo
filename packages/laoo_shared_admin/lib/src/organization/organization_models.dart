abstract final class OrganizationUnitTypes {
  static const division = 'DIV';
  static const department = 'DEP';
}

class OrganizationUnitRecord {
  const OrganizationUnitRecord({
    required this.orgUnitId,
    this.companyId,
    required this.unitType,
    this.parentOrgUnitId,
    required this.unitCode,
    required this.nameTh,
    this.nameEn,
    required this.isActive,
    this.companyName,
  });

  factory OrganizationUnitRecord.fromJson(Map<String, dynamic> json) =>
      OrganizationUnitRecord(
        orgUnitId: (json['orgUnitId'] as num).toInt(),
        companyId: (json['companyId'] as num?)?.toInt(),
        unitType: '${json['unitType'] ?? ''}',
        parentOrgUnitId: (json['parentOrgUnitId'] as num?)?.toInt(),
        unitCode: '${json['unitCode'] ?? ''}',
        nameTh: '${json['nameTh'] ?? ''}',
        nameEn: json['nameEn'] as String?,
        isActive: json['isActive'] == true,
        companyName: json['companyName'] as String?,
      );

  final int orgUnitId;
  final int? companyId;
  final String unitType;
  final int? parentOrgUnitId;
  final String unitCode;
  final String nameTh;
  final String? nameEn;
  final bool isActive;
  final String? companyName;

  Map<String, dynamic> toJson() => {
    'orgUnitId': orgUnitId,
    'companyId': companyId,
    'unitType': unitType,
    'parentOrgUnitId': parentOrgUnitId,
    'unitCode': unitCode,
    'nameTh': nameTh,
    'nameEn': nameEn,
    'isActive': isActive,
    'companyName': companyName,
  };

  // Transitional indexer keeps the existing UI stable while it moves from
  // dynamic maps to typed properties.
  Object? operator [](String key) => switch (key) {
    'orgUnitId' => orgUnitId,
    'companyId' => companyId,
    'unitType' => unitType,
    'parentOrgUnitId' => parentOrgUnitId,
    'unitCode' => unitCode,
    'nameTh' => nameTh,
    'nameEn' => nameEn,
    'isActive' => isActive,
    'companyName' => companyName,
    _ => null,
  };
}

class OrganizationStructureSnapshot {
  const OrganizationStructureSnapshot({
    required this.orgStructureType,
    required this.units,
  });

  factory OrganizationStructureSnapshot.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['units'];
    return OrganizationStructureSnapshot(
      orgStructureType: (json['orgStructureType'] as num?)?.toInt() ?? 1,
      units: rawUnits is List
          ? rawUnits
                .whereType<Map>()
                .map(
                  (item) => OrganizationUnitRecord.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  final int orgStructureType;
  final List<OrganizationUnitRecord> units;

  // Transitional indexer supports consumers that have not yet moved to the
  // typed snapshot. Remove it after Employee extraction is complete.
  Object? operator [](String key) => switch (key) {
    'orgStructureType' => orgStructureType,
    'units' => units.map((unit) => unit.toJson()).toList(growable: false),
    _ => null,
  };
}

class OrganizationUnitUpsertRequest {
  const OrganizationUnitUpsertRequest({
    this.companyId,
    required this.unitType,
    this.parentOrgUnitId,
    required this.unitCode,
    required this.nameTh,
    this.nameEn,
    this.isActive = true,
  });

  final int? companyId;
  final String unitType;
  final int? parentOrgUnitId;
  final String unitCode;
  final String nameTh;
  final String? nameEn;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    if (companyId != null) 'companyId': companyId,
    'unitType': unitType,
    'parentOrgUnitId': parentOrgUnitId,
    'unitCode': unitCode,
    'nameTh': nameTh,
    'nameEn': nameEn,
    'isActive': isActive,
  };
}
