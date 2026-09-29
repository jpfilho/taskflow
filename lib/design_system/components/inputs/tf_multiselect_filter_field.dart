import 'package:flutter/material.dart';
import '../../../widgets/multi_select_filter_dialog.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Componente de filtro multiescolha pesquisável oficial do TaskFlow Design System.
///
/// Abre o [MultiSelectFilterDialog] e renderiza um campo compacto e elegante
/// com contagem de itens selecionados, suporte a limpeza rápida e integração visual
/// com as tabelas e barras de filtros do sistema.
class TFMultiSelectFilterField extends StatelessWidget {
  final String label;
  final Set<String> selectedValues;
  final List<String> options;
  final ValueChanged<Set<String>> onChanged;
  final String? searchHint;
  final bool isCompact;

  const TFMultiSelectFilterField({
    super.key,
    required this.label,
    required this.selectedValues,
    required this.options,
    required this.onChanged,
    this.searchHint,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final hasSelection = selectedValues.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(TFRadius.r8),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => MultiSelectFilterDialog(
            title: label,
            options: options,
            selectedValues: selectedValues,
            onSelectionChanged: onChanged,
            searchHint: searchHint ?? 'Pesquisar $label...',
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: isCompact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: hasSelection
              ? colors.primary.withValues(alpha: 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(
            color: hasSelection
                ? colors.primary
                : colors.borderSubtle,
            width: hasSelection ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: typography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: hasSelection ? colors.primary : colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedValues.isEmpty
                        ? 'Todos'
                        : selectedValues.length == 1
                            ? selectedValues.first
                            : '${selectedValues.length} selecionados',
                    style: typography.bodySmall.copyWith(
                      fontSize: 12,
                      fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
                      color: hasSelection ? colors.textPrimary : colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            if (hasSelection)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(<String>{}),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                ),
              )
            else
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: colors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
