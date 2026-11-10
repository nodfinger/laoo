import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/laoo_design_tokens.dart';

/// Pagination for company document lists; [pageIndex] is zero based.
class StandardPaginationCard extends StatelessWidget {
  const StandardPaginationCard({
    super.key,
    required this.pageIndex,
    required this.pageSize,
    required this.total,
    required this.primary,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageIndex;
  final int pageSize;
  final int total;
  final Color primary;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onPrimary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    );
    final start = total == 0 ? 0 : pageIndex * pageSize + 1;
    final end = math.min((pageIndex + 1) * pageSize, total);

    Widget button(IconData icon, VoidCallback? callback) => SizedBox.square(
      dimension: LaooLayout.paginationButtonSize,
      child: IconButton.filled(
        onPressed: callback,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: foreground,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade700,
          shape: shape,
        ),
        icon: Icon(icon, size: 22),
      ),
    );

    return Container(
      height: LaooLayout.paginationCardHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: LaooLayout.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(Icons.chevron_left, onPrevious),
            const SizedBox(width: 6),
            SizedBox.square(
              dimension: LaooLayout.paginationButtonSize,
              child: FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  disabledBackgroundColor: primary,
                  disabledForegroundColor: foreground,
                  shape: shape,
                ),
                child: Text('${pageIndex + 1}'),
              ),
            ),
            const SizedBox(width: 6),
            button(Icons.chevron_right, onNext),
            const SizedBox(width: 12),
            Text('$start-$end จาก $total'),
          ],
        ),
      ),
    );
  }
}
