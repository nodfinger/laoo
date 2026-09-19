import 'package:flutter/material.dart';

import '../training/training_feature_host.dart';
import '../training/training_route_contract.dart';

class TrainingTestTemplatePlaceholderPage extends StatelessWidget {
  const TrainingTestTemplatePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = trainingUiTokens;
    return buildTrainingWorkspaceShell(
      pageTitle: 'ชุดแบบทดสอบอบรม',
      activeMenu: TrainingMenuCodes.testTemplates,
      child: Center(
        child: Padding(
          padding: tokens.workspace.contentMargin,
          child: Text(
            'อยู่ระหว่างเตรียมหน้าจอจัดการชุดแบบทดสอบอบรม',
            style: tokens.workspace.sectionStyle,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
