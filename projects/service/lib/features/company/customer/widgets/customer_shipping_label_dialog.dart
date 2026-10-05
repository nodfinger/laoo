import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../services/customer_shipping_label_pdf_service.dart';

class CustomerShippingLabelDialog extends StatefulWidget {
  const CustomerShippingLabelDialog({
    required this.customer,
    required this.accent,
    super.key,
  });

  final Map<String, dynamic> customer;
  final Color accent;

  @override
  State<CustomerShippingLabelDialog> createState() =>
      _CustomerShippingLabelDialogState();
}

class _CustomerShippingLabelDialogState
    extends State<CustomerShippingLabelDialog> {
  bool _printing = false;

  String _text(String key) => widget.customer[key]?.toString().trim() ?? '';

  String _display(String key) {
    final value = _text(key);
    return value.isEmpty ? 'ยังไม่ได้กำหนด' : value;
  }

  Future<void> _print() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await CustomerShippingLabelPdfService.export(
        customer: widget.customer,
        accent: widget.accent,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height - 48;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: availableHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const Divider(height: 1, color: LaooColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: _preview(),
              ),
            ),
            const Divider(height: 1, color: LaooColors.border),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => ConstrainedBox(
    constraints: const BoxConstraints(
      minHeight: LaooLayout.popupHeaderMinHeight,
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(Icons.print_outlined, size: 24, color: widget.accent),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'ข้อมูลลูกค้า > พิมพ์ใบปะหน้า',
              style: TextStyle(
                color: Colors.black,
                fontSize: LaooTypography.workspaceCaption,
                height: LaooTypography.titleLineHeight,
                fontWeight: LaooTypography.workspaceCaptionWeight,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _preview() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: widget.accent),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ใบปะหน้าจัดส่ง',
                  style: TextStyle(
                    color: widget.accent,
                    fontSize: LaooTypography.sectionTitle,
                    fontWeight: LaooTypography.emphasizedWeight,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: LaooColors.border),
                const SizedBox(height: 10),
                const Text(
                  'ถึง',
                  style: TextStyle(fontSize: LaooTypography.body),
                ),
                const SizedBox(height: 4),
                Text(
                  _display('shippingLabelName'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: LaooTypography.workspaceCaption,
                    fontWeight: LaooTypography.workspaceCaptionWeight,
                  ),
                ),
                const SizedBox(height: 16),
                _previewValue('ที่อยู่', _display('shippingLabelAddress')),
                const SizedBox(height: 16),
                _previewValue('เบอร์โทร', _display('shippingLabelPhone')),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _previewValue(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: LaooTypography.bodySmall,
          color: Colors.black54,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          fontSize: LaooTypography.body,
          color: Colors.black,
          height: LaooTypography.bodyLineHeight,
        ),
      ),
    ],
  );

  Widget _footer() => Padding(
    padding: const EdgeInsets.all(10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _printing ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(84, LaooTypography.buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Text('ยกเลิก'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _printing ? null : _print,
          style: FilledButton.styleFrom(
            minimumSize: const Size(100, LaooTypography.buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          icon: _printing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print_outlined),
          label: Text(_printing ? 'กำลังพิมพ์' : 'พิมพ์'),
        ),
      ],
    ),
  );
}
