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

  LaooWorkspaceUiTokens get workspace => LaooWorkspaceUiTokens(
    contentMargin: contentMargin,
    cardPadding: cardPadding,
    sectionSpacing: cardSpacing,
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
          focusedBorder: focusedOutline,
          errorBorder: outline.copyWith(
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: focusedOutline.copyWith(
            borderSide: const BorderSide(color: Colors.red),
          ),
          labelStyle: tokens.inputStyle,
          floatingLabelStyle: tokens.inputLabelStyle,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: Size(0, tokens.buttonHeight),
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
            textStyle: tokens.buttonStyle,
            backgroundColor: tokens.primaryColor,
            foregroundColor: Colors.white,
            shape: buttonShape,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, tokens.buttonHeight),
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

  @override
  Widget build(BuildContext context) {
    final tokens = timeUiTokens;
    final availableWidth = math
        .max(0, MediaQuery.sizeOf(context).width - 32)
        .toDouble();
    final availableHeight = math
        .max(0, MediaQuery.sizeOf(context).height - 32)
        .toDouble();
    final body = scrollable
        ? SingleChildScrollView(padding: tokens.cardPadding, child: content)
        : Padding(padding: tokens.cardPadding, child: content);
    return TimeWorkspaceTheme(
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Icon(icon, color: iconColor ?? tokens.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title, style: tokens.captionStyle)),
                  ],
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
    iconColor: Colors.red,
    title: 'ยืนยันการลบ',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.red.shade50,
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
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

class TimeCaptionCard extends StatefulWidget {
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
  State<TimeCaptionCard> createState() => _TimeCaptionCardState();
}

class _TimeCaptionCardState extends State<TimeCaptionCard> {
  bool favorite = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.get('/api/user-favorites') as List<dynamic>;
      if (mounted) {
        setState(
          () => favorite = data.any((item) {
            final value = Map<String, dynamic>.from(item as Map);
            return value['menuCode'] == widget.menuCode;
          }),
        );
      }
    } catch (_) {
      // Favorite availability must not block the business screen.
    }
  }

  Future<void> _toggle() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      if (favorite) {
        await widget.api.delete('/api/user-favorites/${widget.menuCode}');
      } else {
        await widget.api.post(
          '/api/user-favorites',
          body: {'menuCode': widget.menuCode},
        );
      }
      if (mounted) setState(() => favorite = !favorite);
    } catch (_) {
      // Favorite failure is non-blocking; the page remains usable.
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LaooCaptionCard(
    tokens: timeUiTokens.workspace,
    caption: widget.caption,
    leading: IconButton(
      tooltip: favorite
          ? 'นำออกจากเมนูลัดของฉัน'
          : 'เพิ่มหน้านี้เป็นเมนูลัดของฉัน',
      onPressed: saving ? null : _toggle,
      icon: Icon(
        favorite ? Icons.star_rounded : Icons.star_border_rounded,
        color: timeUiTokens.primaryColor,
      ),
    ),
    trailing: widget.trailing,
  );
}

TimeUiTokens get timeUiTokens {
  final tokens = _uiTokensProvider?.call() ?? _uiTokens;
  if (tokens == null) throw StateError('Time UI tokens are not configured.');
  return tokens;
}

bool get hasTimeUiTokens => _uiTokensProvider != null || _uiTokens != null;
