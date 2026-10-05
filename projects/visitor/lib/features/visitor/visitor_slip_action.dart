import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'visitor_feature_host.dart';
import 'visitor_inside_repository.dart';

Future<void> printVisitorSlip({
  required BuildContext context,
  required VisitorInsideRepository repository,
  required int visitId,
}) async {
  final detail = await repository.detail(visitId);
  Uint8List? logo;
  final logoPath = detail.company['logoPath']?.toString().trim() ?? '';
  if (logoPath.isNotEmpty) {
    try {
      logo = Uint8List.fromList(await repository.fileBytes(logoPath));
    } catch (_) {
      logo = null;
    }
  }
  if (!context.mounted) return;
  await presentVisitorSlip(
    context,
    visit: detail.visit,
    company: detail.company,
    companyLogo: logo,
  );
}
