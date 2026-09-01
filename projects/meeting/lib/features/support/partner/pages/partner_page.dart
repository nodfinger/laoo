import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';

class PartnerPage extends StatelessWidget {
  const PartnerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LaooColors.background,
      appBar: AppBar(
        title: const Text('Partner'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () {
                // TODO: connect Partner Add form after API integration.
              },
              icon: const Icon(Icons.add),
              label: const Text('เพิ่ม Partner'),
            ),
          ),
        ],
      ),
      body: const Padding(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        child: _PartnerFoundationNotice(),
      ),
    );
  }
}

class _PartnerFoundationNotice extends StatelessWidget {
  const _PartnerFoundationNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Partner Management V1',
                  style: LaooTypography.pageCaptionStyle,
                ),
                SizedBox(height: 12),
                Text(
                  'API และโครงสร้างข้อมูล Partner พร้อมสำหรับขั้น Integration '
                  'ถัดไป โดยฟอร์มจะรองรับผู้ติดต่อ 2 คน วันที่เริ่มติดต่อ และจังหวัด',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
