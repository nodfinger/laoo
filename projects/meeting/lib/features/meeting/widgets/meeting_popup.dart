import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';

/// Standard layout for Meeting popups without existing header/footer dividers.
class MeetingPopup extends StatelessWidget {
  const MeetingPopup({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.scrollable = false,
    this.footerDivider = true,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final bool scrollable;
  final bool footerDivider;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: LaooColors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
      side: BorderSide.none,
    ),
    titlePadding: const EdgeInsets.all(LaooLayout.cardPadding),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: LaooLayout.cardPadding,
    ),
    actionsPadding: const EdgeInsets.all(LaooLayout.cardPadding),
    titleTextStyle: LaooTypography.popupTitleStyle,
    scrollable: scrollable,
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const Divider(color: LaooColors.border),
      ],
    ),
    content: content,
    actions: [
      SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (footerDivider) const Divider(color: LaooColors.border),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    ],
  );
}

class MeetingDeletePopup extends StatelessWidget {
  const MeetingDeletePopup({
    super.key,
    required this.record,
    this.title = 'ยืนยันการลบข้อมูล',
    this.description,
  });

  final String record;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final primary = workspaceThemeController.value.primary;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    );
    return AlertDialog(
      backgroundColor: LaooColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        side: const BorderSide(color: LaooColors.error),
      ),
      titlePadding: const EdgeInsets.all(LaooLayout.cardPadding),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: LaooLayout.cardPadding,
      ),
      actionsPadding: const EdgeInsets.all(LaooLayout.cardPadding),
      scrollable: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.delete_outline, color: LaooColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: LaooTypography.popupTitleStyle),
              ),
            ],
          ),
          const Divider(color: LaooColors.border),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              decoration: BoxDecoration(
                color: LaooColors.error.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
              child: Text(
                record,
                style: const TextStyle(color: LaooColors.error),
              ),
            ),
            const SizedBox(height: 12),
            if (description != null) ...[
              Text(description!),
              const SizedBox(height: 8),
            ],
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(color: LaooColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        minimumSize: const Size(
                          80,
                          LaooTypography.buttonHeight,
                        ),
                        shape: buttonShape,
                        textStyle: const TextStyle(
                          fontSize: LaooTypography.button,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: LaooColors.error,
                        foregroundColor: LaooColors.white,
                        minimumSize: const Size(
                          80,
                          LaooTypography.buttonHeight,
                        ),
                        shape: buttonShape,
                        textStyle: const TextStyle(
                          fontSize: LaooTypography.button,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('ลบ'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MeetingPopupTitle extends StatelessWidget {
  const MeetingPopupTitle({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: workspaceThemeController.value.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: LaooTypography.popupTitleStyle)),
    ],
  );
}

Widget meetingPickerBuilder(BuildContext context, Widget? child) {
  final base = Theme.of(context);
  final preset = workspaceThemeController.value;
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(LaooRadius.xs),
    side: BorderSide.none,
  );
  final cancel = TextButton.styleFrom(
    foregroundColor: preset.primary,
    minimumSize: const Size(64, LaooTypography.buttonHeight),
    shape: shape,
    textStyle: const TextStyle(fontSize: LaooTypography.button),
  );
  final confirm = cancel.copyWith(
    backgroundColor: WidgetStatePropertyAll(preset.primary),
    foregroundColor: WidgetStatePropertyAll(base.colorScheme.onPrimary),
  );
  return Theme(
    data: base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: preset.primary,
        surface: LaooColors.white,
        onSurface: preset.textPrimary,
      ),
      datePickerTheme: base.datePickerTheme.copyWith(
        backgroundColor: LaooColors.white,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        headerBackgroundColor: LaooColors.white,
        headerForegroundColor: preset.textPrimary,
        headerHelpStyle: LaooTypography.popupTitleStyle,
        dividerColor: LaooColors.border,
        cancelButtonStyle: cancel,
        confirmButtonStyle: confirm,
      ),
      timePickerTheme: base.timePickerTheme.copyWith(
        backgroundColor: LaooColors.white,
        shape: shape,
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        helpTextStyle: LaooTypography.popupTitleStyle,
        entryModeIconColor: preset.primary,
        hourMinuteShape: shape,
        dayPeriodShape: shape,
        cancelButtonStyle: cancel,
        confirmButtonStyle: confirm,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: preset.primary),
      ),
    ),
    child: child!,
  );
}

class MeetingImagePopup extends StatelessWidget {
  const MeetingImagePopup({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => MeetingPopup(
    title: MeetingPopupTitle(icon: Icons.image_outlined, text: title),
    content: SizedBox(
      width: 900,
      height: MediaQuery.sizeOf(context).height * .6,
      child: child,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
    ],
  );
}
