import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../foundations/tf_density.dart';
import '../../foundations/tf_icons.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../feedback/tf_empty_state.dart';
import '../feedback/tf_loading.dart';

/// Definição de coluna orientada a dados para a [TFDataTable].
class TFDataColumn<T> {
  final String id;
  final Widget label;
  final Widget Function(BuildContext context, T item) cellBuilder;
  final double? width;
  final bool numeric;
  final Alignment alignment;

  const TFDataColumn({
    required this.id,
    required this.label,
    required this.cellBuilder,
    this.width,
    this.numeric = false,
    this.alignment = Alignment.centerLeft,
  });

  /// Construtor de conveniência para colunas com texto simples no cabeçalho
  factory TFDataColumn.text({
    required String id,
    required String title,
    required Widget Function(BuildContext context, T item) cellBuilder,
    double? width,
    bool numeric = false,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return TFDataColumn(
      id: id,
      label: Text(title),
      cellBuilder: cellBuilder,
      width: width,
      numeric: numeric,
      alignment: alignment,
    );
  }
}

/// Tabela de dados oficial do TaskFlow Design System.
///
/// Substitui o uso disperso de `DataTable` nativo com estilos manuais.
/// Oferece estrutura consistente orientada a dados tipados, suporte a densidades
/// (`comfortable`, `compact`, `dense`), modo zebra, estados vazios e de carregamento integrados.
class TFDataTable<T> extends StatelessWidget {
  final List<TFDataColumn<T>> columns;
  final List<T> items;
  final bool isLoading;
  final String? loadingMessage;
  final Widget? emptyState;
  final TFDensityMode? densityMode;
  final bool zebra;
  final ValueChanged<T>? onRowTap;

  const TFDataTable({
    super.key,
    required this.columns,
    required this.items,
    this.isLoading = false,
    this.loadingMessage,
    this.emptyState,
    this.densityMode,
    this.zebra = false,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final density = context.tfDensity;

    final activeDensity = densityMode != null
        ? TFDensity.fromMode(densityMode!)
        : density;

    // Alturas de linha conforme a densidade definida
    double headerHeight = 40.0;
    double rowHeight = 44.0;
    EdgeInsets cellPadding = EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs);

    switch (activeDensity.mode) {
      case TFDensityMode.comfortable:
        headerHeight = 48.0;
        rowHeight = 52.0;
        cellPadding = EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm);
        break;
      case TFDensityMode.compact:
        headerHeight = 40.0;
        rowHeight = 44.0;
        cellPadding = EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs);
        break;
      case TFDensityMode.dense:
        headerHeight = 32.0;
        rowHeight = 36.0;
        cellPadding = EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs);
        break;
    }

    if (isLoading) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TFRadius.borderRadiusMd,
          border: Border.all(color: colors.borderDefault),
        ),
        child: TFLoading(
          mode: TFLoadingMode.section,
          message: loadingMessage ?? 'Carregando dados da tabela...',
        ),
      );
    }

    if (items.isEmpty) {
      return Container(
        padding: EdgeInsets.all(spacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TFRadius.borderRadiusMd,
          border: Border.all(color: colors.borderDefault),
        ),
        child: emptyState ??
            const TFEmptyState(
              icon: TFIcons.search,
              title: 'Nenhum registro encontrado',
              description: 'Não há dados disponíveis para exibição no momento.',
            ),
      );
    }

    final double minTableWidth = columns.fold(0.0, (sum, col) => sum + (col.width ?? 160.0));

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TFRadius.borderRadiusMd,
        border: Border.all(color: colors.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : minTableWidth;
          final double effectiveWidth = math.max(minTableWidth, availableWidth);
          final bool hasBoundedHeight = constraints.maxHeight.isFinite;

          final headerRow = Container(
            height: headerHeight,
            color: colors.surfaceSecondary,
            child: Row(
              children: columns.map((col) {
                final headerContent = DefaultTextStyle(
                  style: typography.labelMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  child: col.label,
                );

                if (col.width != null) {
                  return Container(
                    width: col.width,
                    padding: cellPadding,
                    alignment: col.alignment,
                    child: headerContent,
                  );
                }
                return Expanded(
                  child: Container(
                    padding: cellPadding,
                    alignment: col.alignment,
                    child: headerContent,
                  ),
                );
              }).toList(),
            ),
          );

          final dataRows = items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isEven = index % 2 == 0;

            final rowBackgroundColor = zebra && !isEven
                ? colors.surfaceSecondary.withValues(alpha: 0.3)
                : colors.surface;

            return _TFDataTableRow(
              height: rowHeight,
              backgroundColor: rowBackgroundColor,
              hoverColor: colors.hover,
              onTap: onRowTap != null ? () => onRowTap!(item) : null,
              child: Row(
                children: columns.map((col) {
                  final cellContent = col.cellBuilder(context, item);

                  if (col.width != null) {
                    return Container(
                      width: col.width,
                      padding: cellPadding,
                      alignment: col.alignment,
                      child: cellContent,
                    );
                  }
                  return Expanded(
                    child: Container(
                      padding: cellPadding,
                      alignment: col.alignment,
                      child: cellContent,
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList();

          Widget tableBody;
          if (hasBoundedHeight) {
            tableBody = SizedBox(
              width: effectiveWidth,
              height: constraints.maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerRow,
                  Divider(height: 1, thickness: 1, color: colors.borderSubtle),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: dataRows,
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            tableBody = SizedBox(
              width: effectiveWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  headerRow,
                  Divider(height: 1, thickness: 1, color: colors.borderSubtle),
                  ...dataRows,
                ],
              ),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: tableBody,
          );
        },
      ),
    );
  }
}

class _TFDataTableRow extends StatefulWidget {
  final double height;
  final Color backgroundColor;
  final Color hoverColor;
  final VoidCallback? onTap;
  final Widget child;

  const _TFDataTableRow({
    required this.height,
    required this.backgroundColor,
    required this.hoverColor,
    this.onTap,
    required this.child,
  });

  @override
  State<_TFDataTableRow> createState() => _TFDataTableRowState();
}

class _TFDataTableRowState extends State<_TFDataTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: widget.height),
          decoration: BoxDecoration(
            color: _isHovered ? widget.hoverColor : widget.backgroundColor,
            border: Border(
              bottom: BorderSide(color: colors.borderSubtle, width: 1.0),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
