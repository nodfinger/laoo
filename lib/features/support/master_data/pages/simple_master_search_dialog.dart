import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';

class SimpleMasterSearchDialog extends StatefulWidget {
  const SimpleMasterSearchDialog({
    super.key,
    required this.title,
    required this.rows,
  });

  final String title;
  final List<Map<String, dynamic>> rows;

  @override
  State<SimpleMasterSearchDialog> createState() =>
      _SimpleMasterSearchDialogState();
}

class _SimpleMasterSearchDialogState extends State<SimpleMasterSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = widget.rows
        .where(
          (row) =>
              (row['name']?.toString() ?? '').toLowerCase().contains(_query),
        )
        .toList();
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      title: Row(
        children: [
          Icon(Icons.search, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ค้นหา ${widget.title}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: LaooTypography.workspaceCaption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 360,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'ค้นหา',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: LaooLayout.popupFieldSpacing),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูล'))
                  : Scrollbar(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) => ListTile(
                          title: Text(rows[index]['name']?.toString() ?? ''),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(rows[index]['code']?.toString()),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
      ],
    );
  }
}
