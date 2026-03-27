/// Zuralog Design System — Data Table Component.
///
/// A dark-themed data table that matches the brand bible. Wraps columnar data
/// in branded surfaces with proper typography, header/footer styling, and
/// accessible table semantics.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

// ── Data Models ──────────────────────────────────────────────────────────────

/// Describes a single column in a [ZDataTable].
///
/// Each column has a text [label] shown in the header row. Optionally set a
/// fixed [width] (leave `null` for equal flex distribution) and an [alignment]
/// for the cell contents.
class ZDataColumn {
  /// Creates a column descriptor.
  const ZDataColumn({
    required this.label,
    this.width,
    this.alignment = Alignment.centerLeft,
  });

  /// Header text displayed in the column — rendered uppercase automatically.
  final String label;

  /// Optional fixed width in logical pixels. When `null`, the column expands
  /// equally with other flexible columns.
  final double? width;

  /// How the cell content is aligned within its available space.
  final Alignment alignment;
}

/// A single row of cell widgets inside a [ZDataTable].
///
/// Supply one [Widget] per column in [cells]. An optional [onTap] callback
/// makes the entire row tappable (e.g. to navigate to a detail screen).
class ZDataRow {
  /// Creates a data row.
  const ZDataRow({
    required this.cells,
    this.onTap,
  });

  /// Cell widgets — must have the same length as [ZDataTable.columns].
  final List<Widget> cells;

  /// Called when the user taps this row. When `null` the row is inert.
  final VoidCallback? onTap;
}

// ── Widget ───────────────────────────────────────────────────────────────────

/// A branded data table with rounded corners, a tinted header, row dividers,
/// and an optional footer.
///
/// ```dart
/// ZDataTable(
///   columns: [
///     ZDataColumn(label: 'Metric'),
///     ZDataColumn(label: 'Value', alignment: Alignment.centerRight),
///   ],
///   rows: [
///     ZDataRow(cells: [Text('Steps'), Text('8,421')]),
///     ZDataRow(cells: [Text('Calories'), Text('2,140')]),
///   ],
/// )
/// ```
class ZDataTable extends StatelessWidget {
  /// Creates a data table.
  const ZDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.footer,
  });

  /// Column definitions that drive the header and cell layout.
  final List<ZDataColumn> columns;

  /// Body rows to display beneath the header.
  final List<ZDataRow> rows;

  /// An optional footer widget displayed at the bottom of the table.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Semantics(
      label: 'Data table',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.surface),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _HeaderRow(columns: columns),

              // Body rows
              for (int i = 0; i < rows.length; i++)
                _BodyRow(
                  columns: columns,
                  row: rows[i],
                  isLast: i == rows.length - 1,
                ),

              // Optional footer
              if (footer != null) _Footer(child: footer!),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header Row ───────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns});

  final List<ZDataColumn> columns;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      color: colors.surfaceRaised.withValues(alpha: 0.5),
      child: Row(
        children: [
          for (final column in columns) _buildHeaderCell(context, column),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, ZDataColumn column) {
    final colors = AppColorsOf(context);

    final cell = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 12,
      ),
      child: Align(
        alignment: column.alignment,
        child: Text(
          column.label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );

    if (column.width != null) {
      return SizedBox(width: column.width, child: cell);
    }
    return Expanded(child: cell);
  }
}

// ── Body Row ─────────────────────────────────────────────────────────────────

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.columns,
    required this.row,
    required this.isLast,
  });

  final List<ZDataColumn> columns;
  final ZDataRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // Divider color: rgba(240,238,233,0.04)
    final dividerColor = const Color(0xFFF0EEE9).withValues(alpha: 0.04);

    final content = Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++)
            _buildBodyCell(context, columns[i], row.cells[i]),
        ],
      ),
    );

    if (row.onTap != null) {
      return _TappableRow(onTap: row.onTap!, child: content);
    }
    return content;
  }

  Widget _buildBodyCell(
    BuildContext context,
    ZDataColumn column,
    Widget child,
  ) {
    final colors = AppColorsOf(context);

    final cell = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 12,
      ),
      child: Align(
        alignment: column.alignment,
        child: DefaultTextStyle.merge(
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
          ),
          child: child,
        ),
      ),
    );

    if (column.width != null) {
      return SizedBox(width: column.width, child: cell);
    }
    return Expanded(child: cell);
  }
}

// ── Tappable Row Wrapper ─────────────────────────────────────────────────────

/// Wraps a row in a [StatefulWidget] that shows a hover/press highlight.
class _TappableRow extends StatefulWidget {
  const _TappableRow({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TappableRow> createState() => _TappableRowState();
}

class _TappableRowState extends State<_TappableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: _isHovered
              ? colors.surfaceRaised.withValues(alpha: 0.3)
              : const Color(0x00000000),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Footer ───────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Top border: same divider color as rows
    final dividerColor = const Color(0xFFF0EEE9).withValues(alpha: 0.04);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceRaised.withValues(alpha: 0.3),
        border: Border(top: BorderSide(color: dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 12,
      ),
      child: child,
    );
  }
}
