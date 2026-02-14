import 'package:flutter/material.dart';

class FilterBarDocuments extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback? onClearFilters;
  final Widget? extraFilters;

  const FilterBarDocuments({
    super.key,
    required this.onSearch,
    this.onClearFilters,
    this.extraFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar por título/descrição/tags',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: onSearch,
        ),
        const SizedBox(height: 8),
        if (extraFilters != null) extraFilters!,
        if (onClearFilters != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Limpar filtros'),
            ),
          ),
      ],
    );
  }
}
