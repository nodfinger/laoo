import 'package:flutter/material.dart';

import 'pos_feature_host.dart';

const _radius = BorderRadius.all(Radius.circular(4));

Widget posCard({required Widget child, EdgeInsetsGeometry? padding}) =>
    Container(
      width: double.infinity,
      padding: padding ?? posUiTokens.cardPadding,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: _radius,
      ),
      child: child,
    );

InputDecoration posInput(String label, {IconData? icon}) => InputDecoration(
  labelText: label,
  prefixIcon: icon == null ? null : Icon(icon, size: 20),
  border: const OutlineInputBorder(borderRadius: _radius),
  enabledBorder: OutlineInputBorder(
    borderRadius: _radius,
    borderSide: BorderSide(color: posUiTokens.borderColor),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: _radius,
    borderSide: BorderSide(color: posUiTokens.primaryColor, width: 1.5),
  ),
);

ButtonStyle posFilledStyle() => FilledButton.styleFrom(
  minimumSize: const Size(100, 48),
  shape: const RoundedRectangleBorder(borderRadius: _radius),
  textStyle: posUiTokens.buttonStyle,
);

ButtonStyle posOutlinedStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size(84, 48),
  shape: const RoundedRectangleBorder(borderRadius: _radius),
  side: BorderSide(color: posUiTokens.primaryColor),
  foregroundColor: posUiTokens.primaryColor,
  textStyle: posUiTokens.buttonStyle,
);

class PosCaption extends StatelessWidget {
  const PosCaption({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => posCard(
    child: Row(
      children: [
        Icon(Icons.point_of_sale_outlined, color: posUiTokens.primaryColor),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: posUiTokens.captionStyle)),
        ?trailing,
      ],
    ),
  );
}

class PosDialog extends StatelessWidget {
  const PosDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    required this.onSave,
    this.saving = false,
  });
  final String title;
  final IconData icon;
  final Widget content;
  final VoidCallback onSave;
  final bool saving;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: _radius),
    insetPadding: const EdgeInsets.all(24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: posUiTokens.cardPadding,
            child: Row(
              children: [
                Icon(icon, color: posUiTokens.primaryColor, size: 24),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: posUiTokens.captionStyle)),
              ],
            ),
          ),
          Divider(height: 1, color: posUiTokens.borderColor),
          Flexible(
            child: SingleChildScrollView(
              padding: posUiTokens.cardPadding,
              child: content,
            ),
          ),
          Divider(height: 1, color: posUiTokens.borderColor),
          Padding(
            padding: posUiTokens.cardPadding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: posOutlinedStyle(),
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: posFilledStyle(),
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'กำลังบันทึก' : 'บันทึก'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class PosErrorState extends StatelessWidget {
  const PosErrorState({super.key, required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => posCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 36),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        OutlinedButton(
          style: posOutlinedStyle(),
          onPressed: retry,
          child: const Text('ลองอีกครั้ง'),
        ),
      ],
    ),
  );
}
