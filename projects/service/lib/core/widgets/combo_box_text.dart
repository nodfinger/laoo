import 'package:flutter/material.dart';

import '../../app/theme/laoo_typography.dart';

class LaooComboBoxText extends StatelessWidget {
  const LaooComboBoxText(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: LaooTypography.comboBox,
      height: LaooTypography.inputLineHeight,
    ),
  );
}
