import 'package:flutter/material.dart';

typedef VisitorWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

VisitorWorkspaceShellBuilder? _workspaceShellBuilder;
VisitorUiTokens Function()? _uiTokensProvider;

class VisitorUiTokens {
  const VisitorUiTokens({
    this.cardMargin = 10,
    this.cardPadding = 10,
    this.cardSpacing = 10,
    this.listSectionSpacing = 6,
    this.listItemSpacing = 6,
    this.paginationCardHeight = 56,
    this.paginationButtonSize = 34,
    this.popupFieldSpacing = 16,
    this.dialogInsetPadding = 24,
    this.popupHeaderMinHeight = 48,
    this.radius = 4,
    this.buttonHeight = 48,
    this.buttonFontSize = 13,
    this.floatingLabelSource = 18.6666666667,
    this.captionStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    ),
  });

  final double cardMargin;
  final double cardPadding;
  final double cardSpacing;
  final double listSectionSpacing;
  final double listItemSpacing;
  final double paginationCardHeight;
  final double paginationButtonSize;
  final double popupFieldSpacing;
  final double dialogInsetPadding;
  final double popupHeaderMinHeight;
  final double radius;
  final double buttonHeight;
  final double buttonFontSize;
  final double floatingLabelSource;
  final TextStyle captionStyle;
}

VisitorUiTokens get visitorUiTokens =>
    _uiTokensProvider?.call() ?? const VisitorUiTokens();

void configureVisitorFeatureHost(
  VisitorWorkspaceShellBuilder builder, {
  VisitorUiTokens Function()? uiTokensProvider,
}) {
  _workspaceShellBuilder = builder;
  _uiTokensProvider = uiTokensProvider;
}

Widget buildVisitorWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('Visitor feature host is not configured.');
  }
  return builder(
    pageTitle: pageTitle,
    activeMenu: activeMenu,
    child: VisitorWorkspaceTheme(child: child),
  );
}

class VisitorWorkspaceTheme extends StatelessWidget {
  const VisitorWorkspaceTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = visitorUiTokens;
    final base = Theme.of(context);
    final colors = base.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
    );
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    final buttonText = TextStyle(
      fontSize: tokens.buttonFontSize,
      fontWeight: FontWeight.w700,
    );
    return Theme(
      data: base.copyWith(
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: shape,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: shape,
        ),
        dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          border: outline,
          enabledBorder: outline,
          disabledBorder: outline,
          focusedBorder: outline.copyWith(
            borderSide: BorderSide(color: colors.primary),
          ),
          errorBorder: outline.copyWith(
            borderSide: BorderSide(color: colors.error),
          ),
          focusedErrorBorder: outline.copyWith(
            borderSide: BorderSide(color: colors.error),
          ),
          labelStyle: TextStyle(color: colors.primary),
          floatingLabelStyle: TextStyle(
            color: colors.primary,
            fontSize: tokens.floatingLabelSource,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: Size(0, tokens.buttonHeight),
            maximumSize: Size(double.infinity, tokens.buttonHeight),
            textStyle: buttonText,
            foregroundColor: colors.primary,
            shape: shape,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, tokens.buttonHeight),
            maximumSize: Size(double.infinity, tokens.buttonHeight),
            textStyle: buttonText,
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary),
            shape: shape,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: Size(0, tokens.buttonHeight),
            maximumSize: Size(double.infinity, tokens.buttonHeight),
            textStyle: buttonText,
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            shape: shape,
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: shape,
          headerBackgroundColor: Colors.white,
          headerForegroundColor: Colors.black,
          todayForegroundColor: WidgetStatePropertyAll(colors.primary),
          dayBackgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? colors.primary : null,
          ),
        ),
      ),
      child: child,
    );
  }
}

class VisitorPaginationCard extends StatelessWidget {
  const VisitorPaginationCard({
    super.key,
    required this.page,
    required this.pageCount,
    required this.pageSize,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int pageCount;
  final int pageSize;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final tokens = visitorUiTokens;
    final colors = Theme.of(context).colorScheme;
    final from = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final to = total == 0 ? 0 : (page * pageSize).clamp(0, total);
    Widget button(
      String label,
      VoidCallback? onPressed, {
      bool active = false,
    }) {
      final enabled = onPressed != null || active;
      return SizedBox.square(
        dimension: tokens.paginationButtonSize,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.square(tokens.paginationButtonSize),
            maximumSize: Size.square(tokens.paginationButtonSize),
            backgroundColor: active ? colors.primary : colors.surface,
            disabledBackgroundColor: active ? colors.primary : colors.surface,
            foregroundColor: active ? colors.onPrimary : colors.primary,
            disabledForegroundColor: active
                ? colors.onPrimary
                : colors.onSurfaceVariant,
            side: BorderSide(
              color: enabled ? colors.primary : colors.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
            ),
          ),
          child: Text(label),
        ),
      );
    }

    return SizedBox(
      height: tokens.paginationCardHeight,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              button('<', onPrevious),
              SizedBox(width: tokens.listItemSpacing),
              button('$page', null, active: true),
              SizedBox(width: tokens.listItemSpacing),
              button('>', onNext),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '$from-$to จาก $total',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VisitorActionDialog extends StatelessWidget {
  const VisitorActionDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
    this.destructive = false,
    this.maxWidth = 480,
  });

  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool destructive;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = visitorUiTokens;
    final colors = Theme.of(context).colorScheme;
    final availableWidth =
        (MediaQuery.sizeOf(context).width - tokens.dialogInsetPadding * 2)
            .clamp(0.0, double.infinity)
            .toDouble();
    final availableHeight =
        (MediaQuery.sizeOf(context).height - tokens.dialogInsetPadding * 2)
            .clamp(0.0, double.infinity)
            .toDouble();
    final dialogWidth = availableWidth < maxWidth ? availableWidth : maxWidth;
    final dividerColor = colors.outlineVariant;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.all(tokens.dialogInsetPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
        side: destructive ? BorderSide(color: colors.error) : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: dialogWidth,
          maxWidth: dialogWidth,
          maxHeight: availableHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.cardPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: tokens.popupHeaderMinHeight,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: destructive ? colors.error : colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: destructive ? colors.error : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(tokens.cardPadding),
                child: content,
              ),
            ),
            Divider(height: 1, color: dividerColor),
            Padding(
              padding: EdgeInsets.all(tokens.cardPadding),
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
    );
  }
}
