import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

typedef TimeWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

typedef TimeApiClientFactory = JsonApiClient Function();
typedef TimeApiClientDisposer = void Function(JsonApiClient client);
typedef TimeErrorText = String Function(Object error);
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
  final TextStyle tableStyle;
  final TextStyle buttonStyle;
  final double buttonHeight;
  final Color primaryColor;
  final Color borderColor;
  final Color backgroundColor;
  final DateTime businessDate;
}

TimeWorkspaceShellBuilder? _workspaceShellBuilder;
TimeApiClientFactory? _apiClientFactory;
TimeApiClientDisposer? _apiClientDisposer;
TimeErrorText? _errorText;
TimeMessageBuilder? _messageBuilder;
int Function()? _pageSizeProvider;
TimeListLayout? _listLayout;
TimeUiTokens? _uiTokens;

void configureTimeFeatureHost(
  TimeWorkspaceShellBuilder builder, {
  TimeApiClientFactory? apiClientFactory,
  TimeApiClientDisposer? apiClientDisposer,
  TimeErrorText? errorText,
  TimeMessageBuilder? messageBuilder,
  int Function()? pageSizeProvider,
  TimeListLayout? listLayout,
  TimeUiTokens? uiTokens,
}) {
  _workspaceShellBuilder = builder;
  _apiClientFactory = apiClientFactory;
  _apiClientDisposer = apiClientDisposer;
  _errorText = errorText;
  _messageBuilder = messageBuilder;
  _pageSizeProvider = pageSizeProvider;
  _listLayout = listLayout;
  _uiTokens = uiTokens;
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
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
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
        setState(() => favorite = data.any((item) {
              final value = Map<String, dynamic>.from(item as Map);
              return value['menuCode'] == widget.menuCode;
            }));
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
        await widget.api.post('/api/user-favorites', body: {'menuCode': widget.menuCode});
      }
      if (mounted) setState(() => favorite = !favorite);
    } catch (_) {
      // Favorite failure is non-blocking; the page remains usable.
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: favorite ? 'นำออกจากเมนูลัดของฉัน' : 'เพิ่มหน้านี้เป็นเมนูลัดของฉัน',
                onPressed: saving ? null : _toggle,
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: timeUiTokens.primaryColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.caption, style: timeUiTokens.captionStyle)),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      );
}

TimeUiTokens get timeUiTokens {
  final tokens = _uiTokens;
  if (tokens == null) throw StateError('Time UI tokens are not configured.');
  return tokens;
}
