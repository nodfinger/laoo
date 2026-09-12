import 'package:flutter/material.dart';

@immutable
class LaooWorkspaceUiTokens {
  const LaooWorkspaceUiTokens({
    required this.contentMargin,
    required this.cardPadding,
    required this.sectionSpacing,
    required this.captionFilterSpacing,
    required this.itemSpacing,
    required this.radius,
    required this.compactBreakpoint,
    required this.paginationHeight,
    required this.captionStyle,
    required this.sectionStyle,
    required this.inputStyle,
    required this.tableStyle,
    required this.buttonStyle,
    required this.buttonHeight,
    required this.primaryColor,
    required this.borderColor,
    required this.backgroundColor,
    this.surfaceColor = Colors.white,
  });

  final EdgeInsets contentMargin;
  final EdgeInsets cardPadding;
  final double sectionSpacing;
  final double captionFilterSpacing;
  final double itemSpacing;
  final double radius;
  final double compactBreakpoint;
  final double paginationHeight;
  final TextStyle captionStyle;
  final TextStyle sectionStyle;
  final TextStyle inputStyle;
  final TextStyle tableStyle;
  final TextStyle buttonStyle;
  final double buttonHeight;
  final Color primaryColor;
  final Color borderColor;
  final Color backgroundColor;
  final Color surfaceColor;
}

class LaooSurfaceCard extends StatelessWidget {
  const LaooSurfaceCard({
    required this.tokens,
    required this.child,
    this.padding,
    super.key,
  });

  final LaooWorkspaceUiTokens tokens;
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: tokens.surfaceColor,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
    ),
    child: Padding(padding: padding ?? tokens.cardPadding, child: child),
  );
}

class LaooCaptionCard extends StatelessWidget {
  const LaooCaptionCard({
    required this.tokens,
    required this.caption,
    this.leading,
    this.trailing,
    super.key,
  });

  final LaooWorkspaceUiTokens tokens;
  final String caption;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LaooSurfaceCard(
    tokens: tokens,
    padding: EdgeInsets.symmetric(
      horizontal: tokens.cardPadding.horizontal / 2,
      vertical: tokens.cardPadding.vertical / 2,
    ),
    child: Row(
      children: [
        if (leading != null) ...[leading!, SizedBox(width: tokens.itemSpacing)],
        Expanded(child: Text(caption, style: tokens.captionStyle)),
        if (trailing != null) ...[
          SizedBox(width: tokens.itemSpacing),
          trailing!,
        ],
      ],
    ),
  );
}

class LaooFilterCard extends StatelessWidget {
  const LaooFilterCard({required this.tokens, required this.child, super.key});

  final LaooWorkspaceUiTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      LaooSurfaceCard(tokens: tokens, child: child);
}

class LaooTableCard extends StatelessWidget {
  const LaooTableCard({required this.tokens, required this.child, super.key});

  final LaooWorkspaceUiTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      LaooSurfaceCard(tokens: tokens, padding: EdgeInsets.zero, child: child);
}

abstract final class LaooWorkspaceTableColumns {
  static const double idWidth = 56;

  static const DataColumn id = DataColumn(
    label: Text('ID'),
    columnWidth: FixedColumnWidth(idWidth),
  );
}

/// A full-width operational table with the row dividers and dimensions used by
/// the Center registries. It keeps wide tables horizontally scrollable while
/// preserving the available workspace width for normal desktop lists.
class LaooWorkspaceDataTable extends StatelessWidget {
  const LaooWorkspaceDataTable({
    required this.tokens,
    required this.columns,
    required this.rows,
    this.headingRowColor,
    this.headingTextStyle,
    this.dataTextStyle,
    super.key,
  });

  final LaooWorkspaceUiTokens tokens;
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final WidgetStateProperty<Color?>? headingRowColor;
  final TextStyle? headingTextStyle;
  final TextStyle? dataTextStyle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Theme(
      data: Theme.of(context).copyWith(dividerColor: tokens.borderColor),
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SizedBox(
              height: constraints.maxHeight,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 52,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  horizontalMargin: 14,
                  columnSpacing: 20,
                  dividerThickness: 1,
                  border: TableBorder(
                    horizontalInside: BorderSide(color: tokens.borderColor),
                    bottom: BorderSide(color: tokens.borderColor),
                  ),
                  headingRowColor: headingRowColor,
                  headingTextStyle:
                      headingTextStyle ??
                      tokens.tableStyle.copyWith(
                        color: tokens.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                  dataTextStyle: dataTextStyle ?? tokens.tableStyle,
                  columns: columns,
                  rows: rows,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class LaooListCardToggle extends StatelessWidget {
  const LaooListCardToggle({
    required this.tokens,
    required this.cards,
    required this.onChanged,
    super.key,
  });

  final LaooWorkspaceUiTokens tokens;
  final bool cards;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'สลับ Card/List',
    color: tokens.primaryColor,
    onPressed: () => onChanged(!cards),
    icon: Icon(cards ? Icons.view_list : Icons.grid_view),
  );
}

class LaooActionDialog extends StatelessWidget {
  const LaooActionDialog({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
    this.width = 560,
    super.key,
  });

  final LaooWorkspaceUiTokens tokens;
  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    contentPadding: EdgeInsets.zero,
    titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
    ),
    title: Row(
      children: [
        Icon(icon, color: tokens.primaryColor),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: tokens.captionStyle)),
      ],
    ),
    content: SizedBox(
      width: width,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: tokens.borderColor),
            const SizedBox(height: 12),
            content,
            const SizedBox(height: 12),
            Divider(height: 1, color: tokens.borderColor),
          ],
        ),
      ),
    ),
    actions: actions,
  );
}

class LaooPaginationCard extends StatelessWidget {
  const LaooPaginationCard({
    required this.tokens,
    required this.page,
    required this.pageCount,
    required this.pageSize,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    super.key,
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
    return SizedBox(
      height: tokens.paginationHeight,
      child: LaooSurfaceCard(
        tokens: tokens,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.cardPadding.horizontal / 2,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: tokens.itemSpacing,
          runSpacing: tokens.itemSpacing,
          children: [
            OutlinedButton(
              onPressed: onPrevious,
              style: _buttonStyle(tokens),
              child: const Text('<'),
            ),
            IgnorePointer(
              child: FilledButton(
                onPressed: () {},
                style: _buttonStyle(tokens, current: true),
                child: Text('$page'),
              ),
            ),
            OutlinedButton(
              onPressed: onNext,
              style: _buttonStyle(tokens),
              child: const Text('>'),
            ),
            SizedBox(width: tokens.itemSpacing),
            Text('$start-$end จาก $total', style: tokens.tableStyle),
          ],
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(
    LaooWorkspaceUiTokens tokens, {
    bool current = false,
  }) => OutlinedButton.styleFrom(
    minimumSize: Size(tokens.buttonHeight, tokens.buttonHeight),
    maximumSize: Size(tokens.buttonHeight, tokens.buttonHeight),
    padding: EdgeInsets.zero,
    textStyle: tokens.buttonStyle,
    foregroundColor: current ? Colors.white : tokens.primaryColor,
    backgroundColor: current ? tokens.primaryColor : tokens.surfaceColor,
    side: BorderSide(color: tokens.primaryColor),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
    ),
  );
}

class LaooListWorkspace extends StatelessWidget {
  const LaooListWorkspace({
    required this.tokens,
    required this.caption,
    required this.filter,
    required this.table,
    required this.pagination,
    super.key,
  });

  final LaooWorkspaceUiTokens tokens;
  final Widget caption;
  final Widget filter;
  final Widget table;
  final Widget pagination;

  @override
  Widget build(BuildContext context) => Padding(
    padding: tokens.contentMargin,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption,
        SizedBox(height: tokens.captionFilterSpacing),
        LaooFilterCard(tokens: tokens, child: filter),
        SizedBox(height: tokens.sectionSpacing),
        Expanded(
          child: LaooTableCard(tokens: tokens, child: table),
        ),
        SizedBox(height: tokens.sectionSpacing),
        pagination,
      ],
    ),
  );
}
