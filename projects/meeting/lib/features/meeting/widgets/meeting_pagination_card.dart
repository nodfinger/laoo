import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';

class MeetingPaginationCard extends StatelessWidget {
  const MeetingPaginationCard({
    super.key,
    required this.total,
    required this.pageIndex,
    required this.pageSize,
    required this.primary,
    required this.onPrevious,
    required this.onNext,
  });

  final int total;
  final int pageIndex;
  final int pageSize;
  final Color primary;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final pageCount = (total / pageSize).ceil();
    final currentPage = pageCount == 0 ? 0 : pageIndex + 1;
    final start = total == 0 ? 0 : pageIndex * pageSize + 1;
    final end = ((pageIndex + 1) * pageSize).clamp(0, total);
    final muted = Theme.of(context).colorScheme.surfaceContainerHighest;
    final mutedText = Theme.of(context).colorScheme.onSurfaceVariant;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    );

    Widget navigationButton({
      required IconData icon,
      required VoidCallback? onPressed,
      required String tooltip,
    }) => Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 40,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: muted,
            disabledBackgroundColor: muted,
            foregroundColor: mutedText,
            disabledForegroundColor: mutedText.withValues(alpha: .55),
            side: BorderSide.none,
            shape: shape,
          ),
          onPressed: onPressed,
          child: Icon(icon, size: 20),
        ),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      color: LaooColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        side: BorderSide.none,
      ),
      child: SizedBox(
        width: double.infinity,
        height: LaooLayout.paginationCardHeight,
        child: Column(
          children: [
            const Divider(height: 1, thickness: 1, color: LaooColors.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LaooLayout.cardPadding,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        navigationButton(
                          icon: Icons.chevron_left,
                          onPressed: onPrevious,
                          tooltip: 'หน้าก่อนหน้า',
                        ),
                        const SizedBox(width: 8),
                        SizedBox.square(
                          dimension: 40,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: primary,
                              disabledBackgroundColor: primary,
                              foregroundColor: onPrimary,
                              disabledForegroundColor: onPrimary,
                              shape: shape,
                            ),
                            onPressed: null,
                            child: Text(
                              '$currentPage',
                              style: const TextStyle(
                                fontSize: LaooTypography.tableBody,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        navigationButton(
                          icon: Icons.chevron_right,
                          onPressed: onNext,
                          tooltip: 'หน้าถัดไป',
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$start-$end จาก $total',
                          style: const TextStyle(
                            fontSize: LaooTypography.tableBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
