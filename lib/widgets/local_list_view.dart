import 'package:flutter/material.dart';
import '../models/local.dart';
import '../services/local_service.dart';
import 'local_form_dialog.dart';
import 'multi_select_filter_dialog.dart';
import '../utils/responsive.dart';

class LocalListView extends StatefulWidget {
  const LocalListView({super.key});

  @override
  State<LocalListView> createState() => _LocalListViewState();
}

class _LocalListViewState extends State<LocalListView> {
  final LocalService _localService = LocalService();
  List<Local> _locais = [];
  List<Local> _filteredLocais = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _descricaoFilterController = TextEditingController();
  final TextEditingController _sapFilterController = TextEditingController();
  
  final Set<String> _selectedLocalFilters = {};
  final Set<String> _selectedRegionalFilters = {};
  final Set<String> _selectedDivisaoFilters = {};
  final Set<String> _selectedSegmentoFilters = {};

  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadLocais();
    _searchController.addListener(_applyFilters);
    _descricaoFilterController.addListener(_applyFilters);
    _sapFilterController.addListener(_applyFilters);
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Responsive.isDesktop(context)) {
        setState(() {
          _isTableView = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _descricaoFilterController.dispose();
    _sapFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadLocais() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final locais = await _localService.getAllLocais();
      setState(() {
        _locais = locais;
        _filteredLocais = locais;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar locais: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar locais: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    final descQ = _descricaoFilterController.text.toLowerCase().trim();
    final sapQ = _sapFilterController.text.toLowerCase().trim();

    setState(() {
      _filteredLocais = _locais.where((l) {
        // Global search
        bool matchesGlobal = query.isEmpty ||
            l.local.toLowerCase().contains(query) ||
            (l.descricao?.toLowerCase().contains(query) ?? false) ||
            l.regional.toLowerCase().contains(query) ||
            l.divisao.toLowerCase().contains(query) ||
            l.segmento.toLowerCase().contains(query);

        if (!matchesGlobal) return false;

        // Column filters (Text)
        if (descQ.isNotEmpty && !(l.descricao?.toLowerCase().contains(descQ) ?? false)) return false;
        if (sapQ.isNotEmpty && !(l.localInstalacaoSap?.toLowerCase().contains(sapQ) ?? false)) return false;

        // Multi-select filters
        if (_selectedLocalFilters.isNotEmpty && !_selectedLocalFilters.contains(l.local)) return false;
        if (_selectedRegionalFilters.isNotEmpty && !_selectedRegionalFilters.contains(l.regional)) return false;
        if (_selectedDivisaoFilters.isNotEmpty && !_selectedDivisaoFilters.contains(l.divisao)) return false;
        if (_selectedSegmentoFilters.isNotEmpty && !_selectedSegmentoFilters.contains(l.segmento)) return false;

        return true;
      }).toList();
    });
  }

  Future<void> _createLocal() async {
    final result = await showDialog<Local>(
      context: context,
      builder: (context) => const LocalFormDialog(),
    );

    if (result != null) {
      final created = await _localService.createLocal(result);
      if (created != null) {
        await _loadLocais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Local criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar local'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateLocal(Local local) async {
    // Criar cópia com nome modificado
    final duplicated = local.copyWith(
      id: '',
      local: '${local.local} (Cópia)',
    );

    final result = await showDialog<Local>(
      context: context,
      builder: (context) => LocalFormDialog(local: duplicated),
    );

    if (result != null) {
      final created = await _localService.createLocal(result);
      if (created != null) {
        await _loadLocais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Local duplicado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao duplicar local'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editLocal(Local local) async {
    final result = await showDialog<Local>(
      context: context,
      builder: (context) => LocalFormDialog(local: local),
    );

    if (result != null) {
      final updated = await _localService.updateLocal(local.id, result);
      if (updated != null) {
        await _loadLocais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Local atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar local'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteLocal(Local local) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Deseja realmente excluir o local:\n\n'
          'Local: ${local.local}\n'
          'Associações: ${local.associacoesDescricao}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final deleted = await _localService.deleteLocal(local.id);
      if (deleted) {
        await _loadLocais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Local excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir local'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Locais'),
        actions: [
          // Toggle de visualização
          IconButton(
            icon: Icon(_isTableView ? Icons.view_list : Icons.table_chart),
            onPressed: () {
              setState(() {
                _isTableView = !_isTableView;
              });
            },
            tooltip: _isTableView ? 'Visualização em Lista' : 'Visualização em Tabela',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocais,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de busca e botão criar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por local ou descrição...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _createLocal,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Local'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista ou Tabela de locais
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLocais.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.place,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _locais.isEmpty
                                  ? 'Nenhum local cadastrado'
                                  : 'Nenhum local encontrado',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_locais.isEmpty) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _createLocal,
                                icon: const Icon(Icons.add),
                                label: const Text('Criar Primeiro Local'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : _isTableView
                        ? _buildTableView()
                        : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
                        itemCount: _filteredLocais.length,
                        itemBuilder: (context, index) {
                          final local = _filteredLocais[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal[100],
                                child: Icon(
                                  Icons.place,
                                  color: Colors.teal[700],
                                ),
                              ),
                              title: Text(
                                local.local,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (local.descricao != null && local.descricao!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        local.descricao!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          local.associacoesDescricao,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: Colors.blue,
                                    onPressed: () => _editLocal(local),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    color: Colors.orange,
                                    onPressed: () => _duplicateLocal(local),
                                    tooltip: 'Duplicar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    onPressed: () => _deleteLocal(local),
                                    tooltip: 'Excluir',
                                  ),
                                ],
                              ),
                            ),
                          );
        },
      );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
          headingRowHeight: 80, // Aumentado para acomodar os campos de busca
          columns: [
            DataColumn(
              label: _buildSelectableHeader('Local', _selectedLocalFilters, _locais.map((l) => l.local).toSet().toList()..sort()),
            ),
            DataColumn(
              label: _buildSortableHeader('Descrição', _descricaoFilterController),
            ),
            DataColumn(
              label: _buildSortableHeader('Local Instalação SAP', _sapFilterController),
            ),
            DataColumn(
              label: _buildSelectableHeader('Regional', _selectedRegionalFilters, _locais.map((l) => l.regional).where((s) => s.isNotEmpty).toSet().toList()..sort()),
            ),
            DataColumn(
              label: _buildSelectableHeader('Divisão', _selectedDivisaoFilters, _locais.map((l) => l.divisao).where((s) => s.isNotEmpty).toSet().toList()..sort()),
            ),
            DataColumn(
              label: _buildSelectableHeader('Segmento', _selectedSegmentoFilters, _locais.map((l) => l.segmento).where((s) => s.isNotEmpty).toSet().toList()..sort()),
            ),
            const DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredLocais.map((local) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    local.local,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Text(
                    local.descricao != null && local.descricao!.isNotEmpty
                        ? local.descricao!
                        : '-',
                  ),
                ),
                DataCell(
                  Text(
                    local.localInstalacaoSap != null && local.localInstalacaoSap!.isNotEmpty
                        ? local.localInstalacaoSap!
                        : '-',
                  ),
                ),
                DataCell(Text(local.regional.isNotEmpty ? local.regional : '-')),
                DataCell(Text(local.divisao.isNotEmpty ? local.divisao : '-')),
                DataCell(Text(local.segmento.isNotEmpty ? local.segmento : '-')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                        onPressed: () => _editLocal(local),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Colors.orange),
                        onPressed: () => _duplicateLocal(local),
                        tooltip: 'Duplicar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteLocal(local),
                        tooltip: 'Excluir',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSortableHeader(String label, TextEditingController controller) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Filtrar...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableHeader(String label, Set<String> selectedValues, List<String> options) {
    final hasFilter = selectedValues.isNotEmpty;
    
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              final result = await showDialog<Set<String>>(
                context: context,
                builder: (context) => MultiSelectFilterDialog(
                  title: 'Filtrar $label',
                  options: options,
                  selectedValues: selectedValues,
                  onSelectionChanged: (values) {},
                  searchHint: 'Pesquisar $label...',
                ),
              );
              if (result != null) {
                setState(() {
                  selectedValues.clear();
                  selectedValues.addAll(result);
                  _applyFilters();
                });
              }
            },
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: hasFilter ? Colors.blue[50] : Colors.white,
                border: Border.all(
                  color: hasFilter ? Colors.blue : Colors.grey[300]!,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasFilter ? '${selectedValues.length} selecionados' : 'Todos',
                      style: TextStyle(
                        fontSize: 11,
                        color: hasFilter ? Colors.blue[700] : Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.filter_list,
                    size: 14,
                    color: hasFilter ? Colors.blue : Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}







