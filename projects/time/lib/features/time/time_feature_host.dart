import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef TimeWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

typedef TimeApiClientFactory = JsonApiClient Function();
typedef TimeApiClientDisposer = void Function(JsonApiClient client);
typedef TimeErrorText = String Function(Object error);
typedef TimeUiTokensProvider = TimeUiTokens Function();
typedef TimeMessageBuilder =
    Widget Function({
      required String message,
      required bool error,
      required VoidCallback onClose,
    });

class TimeListLayout {
  const TimeListLayout({
    required this.contentMargin,
    required this.cardPadding,
    required this.cardSpacing,
    required this.paginationHeight,
    required this.captionStyle,
  });

  final EdgeInsets contentMargin;
  final EdgeInsets cardPadding;
  final double cardSpacing;
  final double paginationHeight;
  final TextStyle captionStyle;
}

class TimeUiTokens {
  const TimeUiTokens({
    required this.contentMargin,
    required this.cardPadding,
    required this.cardSpacing,
    required this.itemSpacing,
    required this.radius,
    required this.compactBreakpoint,
    required this.paginationHeight,
    required this.captionStyle,
    required this.sectionStyle,
    required this.inputStyle,
    required this.inputLabelStyle,
    required this.tableStyle,
    required this.buttonStyle,
    required this.buttonHeight,
    required this.primaryColor,
    required this.borderColor,
    required this.backgroundColor,
    required this.businessDate,
    this.paginationButtonSize = 34,
    this.dialogInsetPadding = 24,
    this.popupHeaderMinHeight = 48,
    this.popupFieldSpacing = 16,
  });

  final EdgeInsets contentMargin;
  final EdgeInsets cardPadding;
  final double cardSpacing;
  final double itemSpacing;
  final double radius;
  final double compactBreakpoint;
  final double paginationHeight;
  final TextStyle captionStyle;
  final TextStyle sectionStyle;
  final TextStyle inputStyle;
  final TextStyle inputLabelStyle;
  final TextStyle tableStyle;
  final TextStyle buttonStyle;
  final double buttonHeight;
  final Color primaryColor;
  final Color borderColor;
  final Color backgroundColor;
  final DateTime businessDate;
  final double paginationButtonSize;
  final double dialogInsetPadding;
  final double popupHeaderMinHeight;
  final double popupFieldSpacing;

  LaooWorkspaceUiTokens get workspace => LaooWorkspaceUiTokens(
    contentMargin: contentMargin,
    cardPadding: cardPadding,
    sectionSpacing: itemSpacing,
    captionFilterSpacing: 6,
    itemSpacing: itemSpacing,
    radius: radius,
    compactBreakpoint: compactBreakpoint,
    paginationHeight: paginationHeight,
    captionStyle: captionStyle,
    sectionStyle: sectionStyle,
    inputStyle: inputStyle,
    tableStyle: tableStyle,
    buttonStyle: buttonStyle,
    buttonHeight: buttonHeight,
    primaryColor: primaryColor,
    borderColor: borderColor,
    backgroundColor: backgroundColor,
  );
}

TimeWorkspaceShellBuilder? _workspaceShellBuilder;
TimeApiClientFactory? _apiClientFactory;
TimeApiClientDisposer? _apiClientDisposer;
TimeErrorText? _errorText;
TimeMessageBuilder? _messageBuilder;
int Function()? _pageSizeProvider;
TimeListLayout? _listLayout;
TimeUiTokens? _uiTokens;
TimeUiTokensProvider? _uiTokensProvider;

void configureTimeFeatureHost(
  TimeWorkspaceShellBuilder builder, {
  TimeApiClientFactory? apiClientFactory,
  TimeApiClientDisposer? apiClientDisposer,
  TimeErrorText? errorText,
  TimeMessageBuilder? messageBuilder,
  int Function()? pageSizeProvider,
  TimeListLayout? listLayout,
  TimeUiTokens? uiTokens,
  TimeUiTokensProvider? uiTokensProvider,
}) {
  _workspaceShellBuilder = builder;
  _apiClientFactory = apiClientFactory;
  _apiClientDisposer = apiClientDisposer;
  _errorText = errorText;
  _messageBuilder = messageBuilder;
  _pageSizeProvider = pageSizeProvider;
  _listLayout = listLayout;
  _uiTokens = uiTokens;
  _uiTokensProvider = uiTokensProvider;
}

Widget buildTimeWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('Time feature host is not configured.');
  }
  final themedChild = hasTimeUiTokens
      ? TimeWorkspaceTheme(child: child)
      : child;
  return builder(
    pageTitle: pageTitle,
    activeMenu: activeMenu,
    child: themedChild,
  );
}

/// Applies the Center-owned visual contract to every Time route, including
/// pages that have not yet been rebuilt from individual widgets.
class TimeWorkspaceTheme extends StatelessWidget {
  const TimeWorkspaceTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = timeUiTokens;
    final base = Theme.of(context);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
      borderSide: BorderSide(color: tokens.borderColor),
    );
    final focusedOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
      borderSide: BorderSide(color: tokens.primaryColor),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radius),
    );
    final errorColor = base.colorScheme.error;
    return Theme(
      data: base.copyWith(
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: buttonShape,
          clipBehavior: Clip.antiAlias,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: buttonShape,
          titleTextStyle: tokens.captionStyle,
        ),
        dividerTheme: DividerThemeData(color: tokens.borderColor, space: 1),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          border: outline,
          enabledBorder: outline,
          disabledBorder: outline,
          focusedBorder: focusedOutline,
          errorBorder: outline.copyWith(
            borderSide: BorderSide(color: errorColor),
          ),
          focusedErrorBorder: focusedOutline.copyWith(
            borderSide: BorderSide(color: errorColor),
          ),
          labelStyle: tokens.sectionStyle.copyWith(
            fontWeight: FontWeight.normal,
            color: tokens.primaryColor,
          ),
          floatingLabelStyle: tokens.inputLabelStyle,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: Size(0, tokens.buttonHeight),
            maximumSize: Size(double.infinity, tokens.buttonHeight),
            textStyle: tokens.buttonStyle,
            foregroundColor: tokens.primaryColor,
            shape: buttonShape,
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: buttonShape,
          headerBackgroundColor: Colors.white,
          headerForegroundColor: Colors.black,
          todayForegroundColor: WidgetStatePropertyAll(tokens.primaryColor),
          dayForegroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? Colors.white : null,
          ),
          dayBackgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? tokens.primaryColor
                : null,
          ),
          cancelButtonStyle: TextButton.styleFrom(
            foregroundColor: tokens.primaryColor,
          ),
          confirmButtonStyle: TextButton.styleFrom(
            foregroundColor: tokens.primaryColor,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: Size(0, tokens.buttonHeight),
            maximumSize: Size(double.infinity, tokens.buttonHeight),
            textStyle: tokens.buttonStyle,
            backgroundColor: tokens.primaryColor,
            foregroundColor: Colors.white,
            shape: buttonShape,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, tokens.buttonHeight),
            maximumSize: Size(double.infinity, tokens.buttonHeight),
            textStyle: tokens.buttonStyle,
            foregroundColor: tokens.primaryColor,
            side: BorderSide(color: tokens.primaryColor),
            shape: buttonShape,
          ),
        ),
        textTheme: base.textTheme.apply(
          fontFamily: tokens.inputStyle.fontFamily,
          fontFamilyFallback: tokens.inputStyle.fontFamilyFallback,
          bodyColor: tokens.inputStyle.color,
          displayColor: tokens.inputStyle.color,
        ),
      ),
      child: child,
    );
  }
}

class TimeActionDialog extends StatelessWidget {
  const TimeActionDialog({
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
    this.iconColor,
    this.maxWidth = 480,
    this.maxHeight = 720,
    this.scrollable = true,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;
  final Color? iconColor;
  final double maxWidth;
  final double maxHeight;
  final bool scrollable;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = timeUiTokens;
    final errorColor = Theme.of(context).colorScheme.error;
    final availableWidth = math
        .max(
          0,
          MediaQuery.sizeOf(context).width - tokens.dialogInsetPadding * 2,
        )
        .toDouble();
    final availableHeight = math
        .max(
          0,
          MediaQuery.sizeOf(context).height - tokens.dialogInsetPadding * 2,
        )
        .toDouble();
    final body = scrollable
        ? SingleChildScrollView(padding: tokens.cardPadding, child: content)
        : Padding(padding: tokens.cardPadding, child: content);
    return TimeWorkspaceTheme(
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.all(tokens.dialogInsetPadding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
          side: destructive ? BorderSide(color: errorColor) : BorderSide.none,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(maxWidth, availableWidth),
            maxHeight: math.min(maxHeight, availableHeight),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: tokens.popupHeaderMinHeight,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color:
                            iconColor ??
                            (destructive ? errorColor : tokens.primaryColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: tokens.captionStyle.copyWith(
                            color: destructive ? errorColor : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: tokens.borderColor),
              Flexible(child: body),
              Divider(height: 1, color: tokens.borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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

class TimeDeleteDialog extends StatelessWidget {
  const TimeDeleteDialog({required this.itemLabel, super.key});

  final String itemLabel;

  @override
  Widget build(BuildContext context) => TimeActionDialog(
    icon: Icons.delete_outline,
    destructive: true,
    title: 'ยืนยันการลบข้อมูล',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.error.withValues(alpha: .08),
          child: Text(itemLabel),
        ),
        const SizedBox(height: 12),
        const Text('รายการที่ลบแล้วไม่สามารถเรียกคืนได้'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.delete_outline),
        label: const Text('ลบ'),
      ),
    ],
  );
}

JsonApiClient createTimeApiClient() {
  final factory = _apiClientFactory;
  if (factory == null) throw StateError('Time API client is not configured.');
  return factory();
}

void disposeTimeApiClient(JsonApiClient client) =>
    _apiClientDisposer?.call(client);

String timeErrorText(Object error) =>
    _errorText?.call(error) ?? error.toString();

Widget buildTimeMessage({
  required String message,
  required bool error,
  required VoidCallback onClose,
}) {
  final builder = _messageBuilder;
  if (builder == null) return const SizedBox.shrink();
  return builder(message: message, error: error, onClose: onClose);
}

int get timePageSize {
  final value = _pageSizeProvider?.call() ?? 30;
  return value > 0 ? value : 30;
}

TimeListLayout get timeListLayout =>
    _listLayout ??
    const TimeListLayout(
      contentMargin: EdgeInsets.all(10),
      cardPadding: EdgeInsets.all(10),
      cardSpacing: 10,
      paginationHeight: 56,
      captionStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );

class TimePaginationCard extends StatelessWidget {
  const TimePaginationCard({
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
    final start = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final end = total == 0 ? 0 : (page * pageSize).clamp(0, total);
    final size = timeUiTokens.paginationButtonSize;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    Widget button(
      String label,
      VoidCallback? onPressed, {
      bool current = false,
    }) => SizedBox.square(
      dimension: size,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(size),
          maximumSize: Size.square(size),
          backgroundColor: current ? tokens.primaryColor : tokens.surfaceColor,
          disabledBackgroundColor: current
              ? tokens.primaryColor
              : tokens.surfaceColor,
          foregroundColor: current ? onPrimary : tokens.primaryColor,
          disabledForegroundColor: current ? onPrimary : muted,
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
        color: tokens.surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              button('<', onPrevious),
              const SizedBox(width: 6),
              button('${total == 0 ? 0 : page}', null, current: true),
              const SizedBox(width: 6),
              button('>', onNext),
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

class TimeCaptionCard extends StatelessWidget {
  const TimeCaptionCard({
    required this.api,
    required this.menuCode,
    required this.caption,
    this.trailing,
    super.key,
  });

  final JsonApiClient api;
  final String menuCode;
  final String caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LaooCaptionCard(
    tokens: timeUiTokens.workspace,
    caption: caption,
    favoriteKey: menuCode,
    trailing: trailing,
  );
}

TimeUiTokens get timeUiTokens {
  final tokens = _uiTokensProvider?.call() ?? _uiTokens;
  if (tokens == null) throw StateError('Time UI tokens are not configured.');
  return tokens;
}

bool get hasTimeUiTokens => _uiTokensProvider != null || _uiTokens != null;
