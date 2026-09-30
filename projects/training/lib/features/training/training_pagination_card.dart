import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'training_feature_host.dart';

/// Presentation-only pagination for Training list screens.
class TrainingPaginationCard extends StatelessWidget {
  const TrainingPaginationCard({
    super.key,
    required this.tokens,
    required this.page,
    required this.pageCount,
    required this.pageSize,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final LaooWorkspaceUiTokens tokens;
  final int page;
  final int pageCount;
  final int pageSize;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final start = total == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = total == 0 ? 0 : (page * pageSize).clamp(0, total);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final buttonSize = trainingUiTokens.paginationButtonSize;

    Widget button({
      required String label,
      required VoidCallback? onPressed,
      bool current = false,
    }) => SizedBox.square(
      dimension: buttonSize,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(buttonSize),
          maximumSize: Size.square(buttonSize),
          backgroundColor: current ? tokens.primaryColor : tokens.surfaceColor,
          foregroundColor: current
              ? onPrimary
              : onPressed == null
              ? muted
              : tokens.primaryColor,
          disabledForegroundColor: current ? onPrimary : muted,
          disabledBackgroundColor: current
              ? tokens.primaryColor
              : tokens.surfaceColor,
          side: BorderSide(
            color: current
                ? tokens.primaryColor
                : onPressed == null
                ? tokens.borderColor
                : tokens.primaryColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        ),
        child: Text(label, style: tokens.buttonStyle),
      ),
    );

    return SizedBox(
      height: tokens.paginationHeight,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: tokens.surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              button(label: '<', onPressed: onPrevious),
              const SizedBox(width: 6),
              button(
                label: '${total == 0 ? 0 : page}',
                onPressed: null,
                current: true,
              ),
              const SizedBox(width: 6),
              button(label: '>', onPressed: onNext),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '$start-$end จาก $total',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.tableStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
