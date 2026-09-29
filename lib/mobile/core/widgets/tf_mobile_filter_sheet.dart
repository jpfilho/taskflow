import 'package:flutter/material.dart';
import '../theme/tf_mobile_spacing.dart';
import '../theme/tf_mobile_typography.dart';
import '../theme/tf_mobile_colors.dart';
import '../theme/tf_mobile_touch_targets.dart';
import 'tf_mobile_bottom_sheet.dart';
import 'tf_mobile_buttons.dart';
import 'tf_mobile_text_field.dart';

/// Item de filtro para o TFMobileFilterSheet.
class TFFilterOption {
  final String id;
  final String label;
  final String? category;

  const TFFilterOption({
    required this.id,
    required this.label,
    this.category,
  });
}

/// Folha inferior de filtros do TaskFlow Mobile com chips de toque confortável.
class TFMobileFilterSheet extends StatefulWidget {
  final String title;
  final List<TFFilterOption> options;
  final Set<String> initialSelectedIds;
  final ValueChanged<Set<String>> onApply;
  final VoidCallback? onClear;

  const TFMobileFilterSheet({
    super.key,
    this.title = 'Filtrar Resultados',
    required this.options,
    required this.initialSelectedIds,
    required this.onApply,
    this.onClear,
  });

  static Future<void> show({
    required BuildContext context,
    String title = 'Filtrar Resultados',
    required List<TFFilterOption> options,
    required Set<String> initialSelectedIds,
    required ValueChanged<Set<String>> onApply,
    VoidCallback? onClear,
  }) {
    return TFMobileBottomSheet.show(
      context: context,
      title: title,
      content: TFMobileFilterSheet(
        title: title,
        options: options,
        initialSelectedIds: initialSelectedIds,
        onApply: onApply,
        onClear: onClear,
      ),
    );
  }

  @override
  State<TFMobileFilterSheet> createState() => _TFMobileFilterSheetState();
}

class _TFMobileFilterSheetState extends State<TFMobileFilterSheet> {
  late Set<String> _selected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = TFMobileColors.textPrimary(context);

    final filtered = widget.options.where((opt) {
      if (_searchQuery.isEmpty) return true;
      return opt.label.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Busca rápida
        TFMobileTextField(
          hint: 'Buscar opção de filtro...',
          prefixIcon: const Icon(Icons.search_rounded),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
        const SizedBox(height: TFMobileSpacing.lg),

        // Contador de ativos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selected.length} selecionado(s)',
              style: TFMobileTypography.titleMedium.copyWith(
                color: TFMobileColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_selected.isNotEmpty)
              TFTertiaryButton(
                label: 'Limpar seleção',
                onPressed: () {
                  setState(() {
                    _selected.clear();
                  });
                  widget.onClear?.call();
                },
              ),
          ],
        ),
        const SizedBox(height: TFMobileSpacing.md),

        // Grade de chips com touch target ergonômico
        Wrap(
          spacing: TFMobileSpacing.sm,
          runSpacing: TFMobileSpacing.sm,
          children: filtered.map((opt) {
            final isSelected = _selected.contains(opt.id);
            return FilterChip(
              label: Text(opt.label),
              selected: isSelected,
              labelStyle: TFMobileTypography.titleMedium.copyWith(
                color: isSelected ? Colors.white : textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              selectedColor: TFMobileColors.primaryBlue,
              checkmarkColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: TFMobileSpacing.md,
                vertical: TFMobileSpacing.sm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
                side: BorderSide(
                  color: isSelected ? TFMobileColors.primaryBlue : Colors.grey.shade300,
                  width: 1.2,
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selected.add(opt.id);
                  } else {
                    _selected.remove(opt.id);
                  }
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: TFMobileSpacing.xxl),

        // Botão de ação aplicar na base
        TFPrimaryButton(
          label: 'Aplicar Filtros (${_selected.length})',
          height: TFMobileTouchTargets.large, // 56px
          onPressed: () {
            widget.onApply(_selected);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
