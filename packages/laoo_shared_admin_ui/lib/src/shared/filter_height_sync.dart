import 'package:flutter/material.dart';

/// Matches filter actions to the rendered search field, including text scaling.
class FilterHeightSync extends StatefulWidget {
  const FilterHeightSync({super.key, required this.builder});

  final Widget Function(BuildContext context, Key searchKey, double height)
  builder;

  @override
  State<FilterHeightSync> createState() => _FilterHeightSyncState();
}

class _FilterHeightSyncState extends State<FilterHeightSync> {
  final _searchKey = GlobalKey();
  double _height = 48;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _searchKey.currentContext?.findRenderObject();
      if (!mounted || box is! RenderBox || !box.hasSize) return;
      if (_height != box.size.height) setState(() => _height = box.size.height);
    });
    return widget.builder(context, _searchKey, _height);
  }
}

ButtonStyle filterActionHeightStyle(double height) {
  final actionHeight = height < 48 ? 48.0 : height;
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, actionHeight)),
    maximumSize: WidgetStatePropertyAll(Size(double.infinity, actionHeight)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
