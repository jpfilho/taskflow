import 'package:flutter/material.dart';

class MultiSelectFilterDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> selectedValues;
  final Function(Set<String>) onSelectionChanged;
  final String? searchHint;

  const MultiSelectFilterDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onSelectionChanged,
    this.searchHint,
  });

  @override
  State<MultiSelectFilterDialog> createState() =>
      _MultiSelectFilterDialogState();
}

class _MultiSelectFilterDialogState extends State<MultiSelectFilterDialog> {
  late Set<String> _selectedValues;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedValues = Set<String>.from(widget.selectedValues);
    _searchController.text = _searchQuery;
  }

  List<String> get _filteredOptions {
    if (_searchQuery.isEmpty) {
      return widget.options;
    }
    final query = _searchQuery.toLowerCase();
    return widget.options
        .where((option) => option.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final dialogWidth = media.width > 560 ? 560.0 : media.width * 0.94;
    final dialogHeight = media.height * 0.86;

    final allFilteredSelected =
        _filteredOptions.isNotEmpty &&
        _filteredOptions.every((o) => _selectedValues.contains(o));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: dialogWidth,
          height: dialogHeight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint ?? 'Pesquisar empregado...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: 'Limpar',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // Selected count + Select All
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_selectedValues.length} selecionado(s)',
                    style: const TextStyle(
                      color: Color(0xFF1726C8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1726C8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.done_all, size: 18),
                    onPressed: _filteredOptions.isEmpty
                        ? null
                        : () {
                            setState(() {
                              if (allFilteredSelected) {
                                _filteredOptions.forEach(
                                  _selectedValues.remove,
                                );
                              } else {
                                _selectedValues.addAll(_filteredOptions);
                              }
                            });
                          },
                    label: Text(
                      allFilteredSelected
                          ? 'Desmarcar Todos'
                          : 'Selecionar Todos',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Options list
            Expanded(
              child: _filteredOptions.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum empregado encontrado',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        itemCount: _filteredOptions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final option = _filteredOptions[index];
                          final isSelected = _selectedValues.contains(option);
                          return CheckboxListTile(
                            dense: false,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedValues.add(option);
                                } else {
                                  _selectedValues.remove(option);
                                }
                              });
                            },
                            title: Text(
                              option,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            const Divider(height: 1),

            // Footer actions
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1726C8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        widget.onSelectionChanged(_selectedValues);
                        Navigator.of(context).pop(_selectedValues);
                      },
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
