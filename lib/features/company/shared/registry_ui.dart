import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';

InputDecoration registryInput(
  BuildContext context, {
  String? label,
  String? hint,
  IconData? icon,
}) {
  final primary = Theme.of(context).colorScheme.primary;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(LaooRadius.xs),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, color: primary),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    hintStyle: const TextStyle(fontSize: LaooTypography.inputHint),
    border: border(LaooColors.border),
    enabledBorder: border(LaooColors.border),
    disabledBorder: border(LaooColors.border),
    focusedBorder: border(primary),
    errorBorder: border(LaooColors.error),
    focusedErrorBorder: border(LaooColors.error),
  );
}

ButtonStyle registryButton(Color primary, {bool filled = false}) =>
    (filled ? FilledButton.styleFrom : OutlinedButton.styleFrom)(
      foregroundColor: filled ? Colors.white : primary,
      backgroundColor: filled ? primary : Colors.white,
      minimumSize: const Size(0, LaooTypography.buttonHeight),
      textStyle: const TextStyle(
        fontSize: LaooTypography.button,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
    );

Widget registrySurface(Widget child, {EdgeInsetsGeometry? padding, Key? key}) =>
    Container(
      key: key,
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(LaooLayout.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: child,
    );

class RegistryPagination extends StatelessWidget {
  const RegistryPagination({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.primary,
    required this.onPage,
  });
  final int page, pageSize, total;
  final Color primary;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final start = total == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = (page * pageSize).clamp(0, total);
    Widget arrow(IconData icon, VoidCallback? onPressed) => SizedBox(
      width: 34,
      height: 34,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: onPressed == null ? Colors.grey : primary,
          side: BorderSide(color: onPressed == null ? Colors.grey : primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 20),
      ),
    );
    return SizedBox(
      height: LaooLayout.paginationCardHeight,
      child: registrySurface(
        Row(
          children: [
            arrow(Icons.chevron_left, page > 1 ? () => onPage(page - 1) : null),
            const SizedBox(width: 6),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
              child: Text('$page', style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 6),
            arrow(
              Icons.chevron_right,
              page * pageSize < total ? () => onPage(page + 1) : null,
            ),
            const SizedBox(width: 12),
            Text('$start-$end จาก $total'),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmRegistryDelete(
  BuildContext context, {
  required String value,
}) async {
  final danger = Theme.of(context).colorScheme.error;
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: danger),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ยืนยันการลบข้อมูล',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: LaooTypography.workspaceCaption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(LaooLayout.cardPadding),
                color: danger.withValues(alpha: .1),
                child: Text(value),
              ),
              const SizedBox(height: 12),
              const Text('เมื่อลบแล้วจะไม่สามารถเรียกคืนได้'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: danger,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
              onPressed: () => Navigator.pop(dialog, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบ'),
            ),
          ],
        ),
      ) ??
      false;
}
