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
  State<MultiSelectFilterDialog> createState() => _MultiSelectFilterDialogState();
}

class _MultiSelectFilterDialogState extends State<MultiSelectFilterDialog> {
  late Set<String> _selectedValues;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedValues = Set<String>.from(widget.selectedValues);
  }

  List<String> get _filteredOptions {
    if (_searchQuery.isEmpty) {
      return widget.options;
    }
    final query = _searchQuery.toLowerCase();
    return widget.options.where((option) => option.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final dialogWidth = media.width > 480 ? 420.0 : media.width * 0.9;
    final dialogHeight = media.height * 0.8;

    return Dialog(
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Título
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            // Campo de busca
            TextField(
              decoration: InputDecoration(
                hintText: widget.searchHint ?? 'Pesquisar...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 8),
            // Contador de selecionados
            Row(
              children: [
                Text(
                  '${_selectedValues.length} selecionado(s)',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedValues.length == _filteredOptions.length) {
                        _selectedValues.clear();
                      } else {
                        _selectedValues = Set<String>.from(_filteredOptions);
                      }
                    });
                  },
                  child: Text(
                    _selectedValues.length == _filteredOptions.length
                        ? 'Desmarcar Todos'
                        : 'Selecionar Todos',
                  ),
                ),
              ],
            ),
            const Divider(),
            // Lista de opções
            Expanded(
              child: _filteredOptions.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma opção encontrada',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredOptions.length,
                      itemBuilder: (context, index) {
                        final option = _filteredOptions[index];
                        final isSelected = _selectedValues.contains(option);
                        return CheckboxListTile(
                          title: Text(option),
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
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
            ),
            const Divider(),
            // Botões de ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onSelectionChanged(_selectedValues);
                    Navigator.of(context).pop(_selectedValues);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
