import 'package:flutter/material.dart';

abstract final class VoteUiTokens {
  static const double contentMargin = 10;
  static const double sectionGap = 6;
  static const double itemGap = 6;
  static const double radius = 4;
  static const double captionHorizontalPadding = 16;
  static const double captionVerticalPadding = 14;
  static const double filterPadding = 16;
  static const double filterActionHeight = 40;
  static const double actionHeight = 48;
  static const double paginationHeight = 56;
  static const double paginationButtonSize = 34;
  static const double popupInset = 24;
  static const double popupPadding = 10;
  static const double popupWidth = 480;
  static const double popupWideWidth = 620;
  static const double popupHeaderHeight = 48;
  static const double fieldGap = 16;
  static const double breakpoint = 900;

  static const double captionFontSize = 18;
  static const double metricFontSize = 24;
  static const double sectionFontSize = 16;
  static const double bodyFontSize = 14;
  static const double buttonFontSize = 13;
  static const double supportFontSize = 12;
  static const double floatingLabelSource = 14 / .75;
}

RoundedRectangleBorder voteShape() => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(VoteUiTokens.radius),
  side: BorderSide.none,
);

TextStyle voteCaptionStyle(BuildContext context) => TextStyle(
  color: Colors.black,
  fontSize: VoteUiTokens.captionFontSize,
  height: 1.3,
  fontWeight: FontWeight.w700,
);

InputDecoration voteInputDecoration(BuildContext context, String label) {
  final theme = Theme.of(context);
  final borderColor = theme.dividerColor;
  final radius = BorderRadius.circular(VoteUiTokens.radius);
  OutlineInputBorder border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    floatingLabelStyle: TextStyle(
      color: theme.colorScheme.primary,
      fontSize: VoteUiTokens.floatingLabelSource,
    ),
    border: border(borderColor),
    enabledBorder: border(borderColor),
    focusedBorder: border(theme.colorScheme.primary, width: 1.5),
    errorBorder: border(theme.colorScheme.error),
    focusedErrorBorder: border(theme.colorScheme.error, width: 1.5),
  );
}

ButtonStyle voteFilledButtonStyle(BuildContext context, {double? height}) =>
    FilledButton.styleFrom(
      minimumSize: Size(0, height ?? VoteUiTokens.actionHeight),
      maximumSize: Size(double.infinity, height ?? VoteUiTokens.actionHeight),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: voteShape(),
      textStyle: const TextStyle(
        fontSize: VoteUiTokens.buttonFontSize,
        fontWeight: FontWeight.w700,
      ),
    );

ButtonStyle voteOutlinedButtonStyle(BuildContext context, {double? height}) =>
    OutlinedButton.styleFrom(
      minimumSize: Size(0, height ?? VoteUiTokens.actionHeight),
      maximumSize: Size(double.infinity, height ?? VoteUiTokens.actionHeight),
      foregroundColor: Theme.of(context).colorScheme.primary,
      side: BorderSide(color: Theme.of(context).colorScheme.primary),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: voteShape(),
      textStyle: const TextStyle(
        fontSize: VoteUiTokens.buttonFontSize,
        fontWeight: FontWeight.w700,
      ),
    );

class VotePageLayout extends StatelessWidget {
  const VotePageLayout({
    super.key,
    required this.title,
    required this.menuCode,
    required this.content,
    this.filter,
    this.summary,
    this.pagination,
    this.primaryAction,
    this.cardMode = false,
    this.onToggleMode,
  });

  final String title;
  final String menuCode;
  final Widget content;
  final Widget? filter;
  final Widget? summary;
  final Widget? pagination;
  final Widget? primaryAction;
  final bool cardMode;
  final VoidCallback? onToggleMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < VoteUiTokens.breakpoint;
          return ListView(
            padding: const EdgeInsets.all(VoteUiTokens.contentMargin),
            children: [
              Card(
                color: theme.colorScheme.surface,
                surfaceTintColor: theme.colorScheme.surface,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: voteShape(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VoteUiTokens.captionHorizontalPadding,
                    vertical: VoteUiTokens.captionVerticalPadding,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_border, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: voteCaptionStyle(context),
                        ),
                      ),
                      if (!compact && onToggleMode != null) ...[
                        const SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: .10,
                            ),
                            borderRadius: BorderRadius.circular(
                              VoteUiTokens.radius,
                            ),
                          ),
                          child: IconButton(
                            tooltip: cardMode
                                ? 'แสดงแบบรายการ'
                                : 'แสดงแบบการ์ด',
                            onPressed: onToggleMode,
                            color: theme.colorScheme.primary,
                            style: IconButton.styleFrom(shape: voteShape()),
                            icon: Icon(
                              cardMode
                                  ? Icons.view_list_outlined
                                  : Icons.grid_view_outlined,
                            ),
                          ),
                        ),
                      ],
                      if (primaryAction != null) ...[
                        const SizedBox(width: 8),
                        primaryAction!,
                      ],
                    ],
                  ),
                ),
              ),
              if (summary != null) ...[
                const SizedBox(height: VoteUiTokens.sectionGap),
                summary!,
              ],
              if (filter != null) ...[
                const SizedBox(height: VoteUiTokens.sectionGap),
                Card(
                  color: theme.colorScheme.surface,
                  surfaceTintColor: theme.colorScheme.surface,
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: voteShape(),
                  child: Padding(
                    padding: const EdgeInsets.all(VoteUiTokens.filterPadding),
                    child: filter,
                  ),
                ),
              ],
              const SizedBox(height: VoteUiTokens.sectionGap),
              content,
              if (pagination != null) ...[
                const SizedBox(height: VoteUiTokens.sectionGap),
                pagination!,
              ],
            ],
          );
        },
      ),
    );
  }
}

class VoteFilterBar extends StatelessWidget {
  const VoteFilterBar({
    super.key,
    this.searchController,
    this.searchLabel = 'ค้นหาเลขที่หรือหัวข้อ',
    this.status,
    this.statusItems = const <DropdownMenuItem<String>>[],
    this.onStatusChanged,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController? searchController;
  final String searchLabel;
  final String? status;
  final List<DropdownMenuItem<String>> statusItems;
  final ValueChanged<String?>? onStatusChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < VoteUiTokens.breakpoint;
      final search = searchController == null
          ? null
          : TextField(
              controller: searchController,
              style: const TextStyle(fontSize: VoteUiTokens.bodyFontSize),
              onSubmitted: (_) => onSearch(),
              decoration: voteInputDecoration(
                context,
                searchLabel,
              ).copyWith(prefixIcon: const Icon(Icons.search)),
            );
      final searchButton = FilledButton.icon(
        style: voteFilledButtonStyle(
          context,
          height: VoteUiTokens.filterActionHeight,
        ),
        onPressed: onSearch,
        icon: const Icon(Icons.search),
        label: const Text('ค้นหา'),
      );
      final clearButton = OutlinedButton.icon(
        style: voteOutlinedButtonStyle(
          context,
          height: VoteUiTokens.filterActionHeight,
        ),
        onPressed: onClear,
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('ล้าง Filter'),
      );
      final statusField = statusItems.isEmpty
          ? null
          : DropdownButtonFormField<String>(
              initialValue: status,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: VoteUiTokens.bodyFontSize,
              ),
              decoration: voteInputDecoration(context, 'สถานะ'),
              items: statusItems,
              onChanged: onStatusChanged,
            );

      if (compact) {
        final narrow = constraints.maxWidth < 360;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?search,
            if (search != null) const SizedBox(height: 8),
            if (narrow) ...[
              searchButton,
              const SizedBox(height: 8),
              clearButton,
            ] else
              Row(
                children: [
                  Expanded(child: searchButton),
                  const SizedBox(width: 8),
                  Expanded(child: clearButton),
                ],
              ),
            if (statusField != null) ...[
              const SizedBox(height: 10),
              statusField,
            ],
          ],
        );
      }
      return Row(
        children: [
          if (search != null) SizedBox(width: 280, child: search),
          if (search != null) const SizedBox(width: 8),
          searchButton,
          const SizedBox(width: 8),
          clearButton,
          if (statusField != null) ...[
            const SizedBox(width: 14),
            SizedBox(width: 220, child: statusField),
          ],
        ],
      );
    },
  );
}

class VoteTableCard extends StatelessWidget {
  const VoteTableCard({super.key, required this.columns, required this.rows});

  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) return const VoteEmptyCard();
    return Card(
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: voteShape(),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 56,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              horizontalMargin: 12,
              columnSpacing: 20,
              headingRowColor: WidgetStatePropertyAll(
                theme.colorScheme.primary.withValues(alpha: .10),
              ),
              headingTextStyle: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: VoteUiTokens.bodyFontSize,
                fontWeight: FontWeight.w700,
              ),
              dataTextStyle: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: VoteUiTokens.bodyFontSize,
              ),
              border: TableBorder(
                horizontalInside: BorderSide(color: theme.dividerColor),
                bottom: BorderSide(color: theme.dividerColor),
              ),
              columns: columns,
              rows: rows,
            ),
          ),
        ),
      ),
    );
  }
}

class VoteRecordCard extends StatelessWidget {
  const VoteRecordCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.meta,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String? meta;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: voteShape(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VoteUiTokens.radius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: VoteUiTokens.bodyFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: VoteUiTokens.bodyFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (meta != null && meta!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: VoteUiTokens.bodyFontSize,
                      ),
                    ),
                  ],
                ],
              );
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    if (trailing != null) ...[
                      const SizedBox(height: VoteUiTokens.itemGap),
                      Align(alignment: Alignment.centerRight, child: trailing!),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class VoteCardList extends StatelessWidget {
  const VoteCardList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const VoteEmptyCard();
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1)
            const SizedBox(height: VoteUiTokens.itemGap),
        ],
      ],
    );
  }
}

class VoteEmptyCard extends StatelessWidget {
  const VoteEmptyCard({super.key, this.message = 'ไม่พบรายการ', this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: voteShape(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: VoteUiTokens.sectionGap),
                OutlinedButton(
                  style: voteOutlinedButtonStyle(context),
                  onPressed: onRetry,
                  child: const Text('ลองอีกครั้ง'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class VotePaginationCard extends StatelessWidget {
  const VotePaginationCard({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onChanged,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = total == 0 ? 1 : (total / pageSize).ceil();
    final start = total == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = total == 0 ? 0 : (page * pageSize).clamp(0, total);
    Widget button(IconData icon, int target, bool enabled) => SizedBox(
      width: VoteUiTokens.paginationButtonSize,
      height: VoteUiTokens.paginationButtonSize,
      child: OutlinedButton(
        onPressed: enabled ? () => onChanged(target) : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: theme.colorScheme.primary,
          disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
          side: BorderSide(
            color: enabled ? theme.colorScheme.primary : theme.dividerColor,
          ),
          shape: voteShape(),
        ),
        child: Icon(icon, size: 20),
      ),
    );
    return Card(
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: voteShape(),
      child: SizedBox(
        height: VoteUiTokens.paginationHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              button(Icons.chevron_left, page - 1, page > 1),
              const SizedBox(width: 6),
              Semantics(
                label: 'หน้าปัจจุบัน $page',
                child: Container(
                  width: VoteUiTokens.paginationButtonSize,
                  height: VoteUiTokens.paginationButtonSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    border: Border.all(color: theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(VoteUiTokens.radius),
                  ),
                  child: Text(
                    '$page',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: VoteUiTokens.buttonFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              button(Icons.chevron_right, page + 1, page < pages),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '$start-$end จาก $total',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: VoteUiTokens.bodyFontSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoteDialogFrame extends StatelessWidget {
  const VoteDialogFrame({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon = Icons.edit_outlined,
    this.iconColor,
    this.maxWidth = VoteUiTokens.popupWidth,
    this.isDestructive = false,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData icon;
  final Color? iconColor;
  final double maxWidth;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final popupTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        surface: Colors.white,
        onSurface: Colors.black,
        onSurfaceVariant: Colors.black54,
      ),
      textTheme: theme.textTheme.apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
    );
    return Theme(
      data: popupTheme,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.all(VoteUiTokens.popupInset),
        shape: isDestructive
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VoteUiTokens.radius),
                side: BorderSide(color: theme.colorScheme.error),
              )
            : voteShape(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.sizeOf(context).width - VoteUiTokens.popupInset * 2 <
                    maxWidth
                ? MediaQuery.sizeOf(context).width - VoteUiTokens.popupInset * 2
                : maxWidth,
            maxHeight:
                ((MediaQuery.sizeOf(context).height -
                            MediaQuery.viewInsetsOf(context).bottom -
                            VoteUiTokens.popupInset * 2) *
                        .88)
                    .clamp(0.0, double.infinity),
          ),
          child: Padding(
            padding: const EdgeInsets.all(VoteUiTokens.popupPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: VoteUiTokens.popupHeaderHeight,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: iconColor ?? theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: voteCaptionStyle(context).copyWith(
                            color: isDestructive
                                ? theme.colorScheme.error
                                : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: 12),
                Flexible(child: SingleChildScrollView(child: content)),
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VoteStatusLabel extends StatelessWidget {
  const VoteStatusLabel(this.value, {super.key});
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(VoteUiTokens.radius),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: VoteUiTokens.supportFontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
