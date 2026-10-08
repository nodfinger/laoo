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
    this.paginationButtonSize = 34,
    this.dialogInsetPadding = 24,
    this.popupHeaderMinHeight = 48,
    this.popupMaxWidth = 480,
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
  final double paginationButtonSize;
  final double dialogInsetPadding;
  final double popupHeaderMinHeight;
  final double popupMaxWidth;
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

typedef LaooFavoriteButtonBuilder =
    Widget Function(BuildContext context, String menuKey);
typedef LaooMenuIconBuilder =
    Widget Function(BuildContext context, String menuKey, Color color);

class LaooWorkspaceFavoriteScope extends InheritedWidget {
  const LaooWorkspaceFavoriteScope({
    required this.activeMenu,
    required this.favoriteButtonBuilder,
    this.menuIconBuilder,
    required super.child,
    super.key,
  });

  final String? activeMenu;
  final LaooFavoriteButtonBuilder favoriteButtonBuilder;
  final LaooMenuIconBuilder? menuIconBuilder;

  static LaooWorkspaceFavoriteScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LaooWorkspaceFavoriteScope>();

  static Widget? buttonOf(BuildContext context, {String? menuKey}) {
    final scope = maybeOf(context);
    final key = (menuKey ?? scope?.activeMenu)?.trim();
    if (scope == null || key == null || key.isEmpty || key == 'home') {
      return null;
    }
    return scope.favoriteButtonBuilder(context, key);
  }

  static Widget? menuIconOf(
    BuildContext context, {
    required String? menuKey,
    required Color color,
  }) {
    final scope = maybeOf(context);
    final key = menuKey?.trim();
    if (scope == null ||
        scope.menuIconBuilder == null ||
        key == null ||
        key.isEmpty) {
      return null;
    }
    return scope.menuIconBuilder!(context, key, color);
  }

  @override
  bool updateShouldNotify(LaooWorkspaceFavoriteScope oldWidget) =>
      activeMenu != oldWidget.activeMenu ||
      favoriteButtonBuilder != oldWidget.favoriteButtonBuilder ||
      menuIconBuilder != oldWidget.menuIconBuilder;
}

class LaooPageMenuIcon extends StatelessWidget {
  const LaooPageMenuIcon({
    required this.menuKey,
    required this.color,
    this.size = 24,
    this.fallback,
    super.key,
  });

  final String? menuKey;
  final Color color;
  final double size;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) =>
      LaooWorkspaceFavoriteScope.menuIconOf(
        context,
        menuKey: menuKey,
        color: color,
      ) ??
      fallback ??
      Icon(Icons.apps_outlined, size: size, color: color);
}

class LaooPageFavoriteButton extends StatelessWidget {
  const LaooPageFavoriteButton({this.menuKey, this.spacing = 6, super.key});

  final String? menuKey;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final button = LaooWorkspaceFavoriteScope.buttonOf(
      context,
      menuKey: menuKey,
    );
    if (button == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(left: spacing),
      child: button,
    );
  }
}

class LaooCaptionCard extends StatelessWidget {
  const LaooCaptionCard({
    required this.tokens,
    required this.caption,
    this.leading,
    this.trailing,
    this.favoriteKey,
    super.key,
  });

  final LaooWorkspaceUiTokens tokens;
  final String caption;
  final Widget? leading;
  final Widget? trailing;
  final String? favoriteKey;

  @override
  Widget build(BuildContext context) {
    final activeMenu = LaooWorkspaceFavoriteScope.maybeOf(context)?.activeMenu;
    final menuKey = favoriteKey ?? activeMenu;
    final menuIcon = LaooWorkspaceFavoriteScope.menuIconOf(
      context,
      menuKey: menuKey,
      color: tokens.primaryColor,
    );
    final captionIcon = menuIcon ?? leading;
    return LaooSurfaceCard(
      tokens: tokens,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.popupHeaderMinHeight),
          child: constraints.maxWidth < 420 && trailing != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (captionIcon != null) ...[
                          captionIcon,
                          SizedBox(width: tokens.itemSpacing),
                        ],
                        Expanded(
                          child: Text(
                            caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.captionStyle,
                          ),
                        ),
                        LaooPageFavoriteButton(menuKey: menuKey),
                      ],
                    ),
                    SizedBox(height: tokens.itemSpacing),
                    Align(alignment: Alignment.centerRight, child: trailing),
                  ],
                )
              : Row(
                  children: [
                    if (captionIcon != null) ...[
                      captionIcon,
                      SizedBox(width: tokens.itemSpacing),
                    ],
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.captionStyle,
                      ),
                    ),
                    LaooPageFavoriteButton(menuKey: menuKey),
                    if (trailing != null) ...[
                      const Spacer(),
                      SizedBox(width: tokens.itemSpacing),
                      trailing!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
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
                  headingRowHeight: 56,
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
    style: IconButton.styleFrom(
      fixedSize: const Size.square(48),
      backgroundColor: tokens.primaryColor.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
    ),
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
    this.width = 480,
    super.key,
  });

  final LaooWorkspaceUiTokens tokens;
  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
    );
    final popupTheme = Theme.of(context).copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(100, tokens.buttonHeight),
          maximumSize: Size(double.infinity, tokens.buttonHeight),
          shape: shape,
          textStyle: tokens.buttonStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(84, tokens.buttonHeight),
          maximumSize: Size(double.infinity, tokens.buttonHeight),
          shape: shape,
          textStyle: tokens.buttonStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(84, tokens.buttonHeight),
          maximumSize: Size(double.infinity, tokens.buttonHeight),
          shape: shape,
          textStyle: tokens.buttonStyle,
        ),
      ),
    );
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height -
        media.viewInsets.vertical -
        media.viewPadding.vertical -
        (tokens.dialogInsetPadding * 2);
    final effectiveWidth = width.clamp(0, tokens.popupMaxWidth).toDouble();
    return Theme(
      data: popupTheme,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.all(tokens.dialogInsetPadding),
        shape: shape,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: effectiveWidth,
            maxHeight: availableHeight.clamp(160, double.infinity).toDouble(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: tokens.popupHeaderMinHeight,
                ),
                child: Padding(
                  padding: tokens.cardPadding,
                  child: Row(
                    children: [
                      Icon(icon, size: 24, color: tokens.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: tokens.captionStyle.copyWith(
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: tokens.borderColor),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: tokens.cardPadding,
                  child: content,
                ),
              ),
              Divider(height: 1, color: tokens.borderColor),
              Padding(
                padding: tokens.cardPadding,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
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
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.itemSpacing * 2,
            runSpacing: tokens.itemSpacing,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: onPrevious,
                    style: _buttonStyle(tokens),
                    child: const Text('<'),
                  ),
                  SizedBox(width: tokens.itemSpacing),
                  IgnorePointer(
                    child: FilledButton(
                      onPressed: () {},
                      style: _buttonStyle(tokens, current: true),
                      child: Text('$page'),
                    ),
                  ),
                  SizedBox(width: tokens.itemSpacing),
                  OutlinedButton(
                    onPressed: onNext,
                    style: _buttonStyle(tokens),
                    child: const Text('>'),
                  ),
                ],
              ),
              Text('$start-$end จาก $total', style: tokens.tableStyle),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(
    LaooWorkspaceUiTokens tokens, {
    bool current = false,
  }) => OutlinedButton.styleFrom(
    minimumSize: Size(tokens.paginationButtonSize, tokens.paginationButtonSize),
    maximumSize: Size(tokens.paginationButtonSize, tokens.paginationButtonSize),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
