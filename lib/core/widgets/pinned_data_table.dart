import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'list_display_preferences.dart';

/// Shared column definitions for operational list tables.
abstract final class LaooTableColumns {
  static const double idWidth = 56;

  static const DataColumn id = DataColumn(
    label: Text('ID'),
    columnWidth: FixedColumnWidth(idWidth),
  );

  static const DataColumn numericId = DataColumn(
    label: Text('ID'),
    columnWidth: FixedColumnWidth(idWidth),
    numeric: true,
  );
}

/// A [DataTable] whose heading stays visible while its rows scroll vertically.
///
/// The heading and body share one horizontal scroll view, so their columns stay
/// aligned. Short lists keep their natural height; long lists are capped by
/// [maxBodyHeight] and gain an internal vertical scrollbar.
class PinnedDataTable extends StatefulWidget {
  const PinnedDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSelectAll,
    this.decoration,
    this.dataRowColor,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.dataTextStyle,
    this.headingRowColor,
    this.headingRowHeight,
    this.headingTextStyle,
    this.horizontalMargin = 14,
    this.columnSpacing = 20,
    this.showCheckboxColumn = true,
    this.showBottomBorder = true,
    this.dividerThickness = 1,
    this.checkboxHorizontalMargin,
    this.border,
    this.clipBehavior = Clip.hardEdge,
    this.maxBodyHeight = 420,
    this.columnKeys,
    this.displayPreferences,
    this.padding = EdgeInsets.zero,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ValueSetter<bool?>? onSelectAll;
  final Decoration? decoration;
  final WidgetStateProperty<Color?>? dataRowColor;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final TextStyle? dataTextStyle;
  final WidgetStateProperty<Color?>? headingRowColor;
  final double? headingRowHeight;
  final TextStyle? headingTextStyle;
  final double? horizontalMargin;
  final double? columnSpacing;
  final bool showCheckboxColumn;
  final bool showBottomBorder;
  final double dividerThickness;
  final double? checkboxHorizontalMargin;
  final TableBorder? border;
  final Clip clipBehavior;
  final double maxBodyHeight;

  /// Stable keys, aligned with columns. ID and Action are never hidden.
  final List<String>? columnKeys;
  final ListDisplayPreferences? displayPreferences;
  final EdgeInsetsGeometry padding;

  @override
  State<PinnedDataTable> createState() => _PinnedDataTableState();
}

class _PinnedDataTableState extends State<PinnedDataTable> {
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableTheme = DataTableTheme.of(context);
    final headingHeight =
        widget.headingRowHeight ?? tableTheme.headingRowHeight ?? 56;
    final rowMinHeight =
        widget.dataRowMinHeight ?? tableTheme.dataRowMinHeight ?? 48;
    final rowMaxHeight =
        widget.dataRowMaxHeight ?? tableTheme.dataRowMaxHeight ?? 56;
    final naturalBodyHeight = widget.rows.isEmpty
        ? 0.0
        : widget.rows.length * rowMaxHeight;
    final bodyHeight = math.min(naturalBodyHeight, widget.maxBodyHeight);
    final showVerticalScrollbar = naturalBodyHeight > widget.maxBodyHeight;
    final desktop = MediaQuery.sizeOf(context).width >= 900;

    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) => Scrollbar(
          controller: _horizontalController,
          thumbVisibility: desktop,
          notificationPredicate: (notification) => notification.depth == 0,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : 0,
              ),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: headingHeight,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minHeight: 0,
                          maxHeight: double.infinity,
                          child: _table(
                            dataRowMinHeight: rowMinHeight,
                            dataRowMaxHeight: rowMaxHeight,
                          ),
                        ),
                      ),
                    ),
                    if (widget.rows.isNotEmpty)
                      SizedBox(
                        height: bodyHeight,
                        child: Scrollbar(
                          controller: _verticalController,
                          thumbVisibility: desktop && showVerticalScrollbar,
                          child: SingleChildScrollView(
                            controller: _verticalController,
                            child: _table(
                              headingRowHeight: 0,
                              dataRowMinHeight: rowMinHeight,
                              dataRowMaxHeight: rowMaxHeight,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _table({
    double? headingRowHeight,
    required double dataRowMinHeight,
    required double dataRowMaxHeight,
  }) => Theme(
    data: Theme.of(context),
    child: DataTable(
      columns: _displayColumns,
      sortColumnIndex: _displaySortIndex,
      sortAscending: widget.sortAscending,
      onSelectAll: widget.onSelectAll,
      decoration: widget.decoration,
      dataRowColor: widget.dataRowColor,
      dataRowMinHeight: dataRowMinHeight,
      dataRowMaxHeight: dataRowMaxHeight,
      dataTextStyle: widget.dataTextStyle,
      headingRowColor: widget.headingRowColor,
      headingRowHeight: headingRowHeight ?? widget.headingRowHeight,
      headingTextStyle: widget.headingTextStyle,
      horizontalMargin: widget.horizontalMargin,
      columnSpacing: widget.columnSpacing,
      showCheckboxColumn: widget.showCheckboxColumn,
      showBottomBorder: widget.showBottomBorder,
      dividerThickness: widget.dividerThickness,
      rows: _displayRows,
      checkboxHorizontalMargin: widget.checkboxHorizontalMargin,
      border: widget.border,
      clipBehavior: widget.clipBehavior,
    ),
  );

  List<int> get _displayIndices {
    final keys = widget.columnKeys;
    final prefs = widget.displayPreferences;
    if (keys == null || prefs == null || keys.length != widget.columns.length) {
      return List.generate(widget.columns.length, (index) => index);
    }
    final byKey = <String, int>{
      for (var i = 0; i < keys.length; i++) keys[i]: i,
    };
    final indices = <int>[];
    void add(String key) {
      final index = byKey[key];
      if (index != null && !indices.contains(index)) indices.add(index);
    }

    add('id');
    if (!prefs.actionOnRight) add('action');
    for (final key in [...prefs.order, ...keys]) {
      if (key != 'id' && key != 'action' && !prefs.hidden.contains(key)) {
        add(key);
      }
    }
    if (prefs.actionOnRight) add('action');
    return indices;
  }

  int? get _displaySortIndex {
    final index = widget.sortColumnIndex;
    if (index == null) return null;
    final displayed = _displayIndices.indexOf(index);
    return displayed < 0 ? null : displayed;
  }

  List<DataColumn> get _displayColumns =>
      widget.columnKeys == null || widget.displayPreferences == null
      ? _resolvedColumns
      : _displayIndices
            .map((index) {
              final column = _resolvedColumns[index];
              return DataColumn(
                label: column.label,
                columnWidth: column.columnWidth,
                tooltip: column.tooltip,
                numeric: column.numeric,
                onSort: column.onSort == null
                    ? null
                    : (_, ascending) => column.onSort!(index, ascending),
                mouseCursor: column.mouseCursor,
                headingRowAlignment: column.headingRowAlignment,
              );
            })
            .toList(growable: false);

  List<DataRow> get _displayRows =>
      widget.columnKeys == null || widget.displayPreferences == null
      ? widget.rows
      : widget.rows
            .map(
              (row) => DataRow(
                key: row.key,
                selected: row.selected,
                onSelectChanged: row.onSelectChanged,
                onLongPress: row.onLongPress,
                color: row.color,
                mouseCursor: row.mouseCursor,
                cells: [for (final i in _displayIndices) row.cells[i]],
              ),
            )
            .toList(growable: false);

  List<DataColumn> get _resolvedColumns {
    if (!widget.columns.any((column) => column.columnWidth != null)) {
      return widget.columns;
    }
    return widget.columns
        .map(
          (column) => column.columnWidth != null
              ? column
              : DataColumn(
                  label: column.label,
                  columnWidth: const IntrinsicColumnWidth(flex: 1),
                  tooltip: column.tooltip,
                  numeric: column.numeric,
                  onSort: column.onSort,
                  mouseCursor: column.mouseCursor,
                  headingRowAlignment: column.headingRowAlignment,
                ),
        )
        .toList(growable: false);
  }
}
