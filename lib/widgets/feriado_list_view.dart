import 'package:flutter/material.dart';
import '../models/feriado.dart';
import '../services/feriado_service.dart';
import 'feriado_form_dialog.dart';
import 'multi_select_filter_dialog.dart';
import '../utils/responsive.dart';

class FeriadoListView extends StatefulWidget {
  const FeriadoListView({super.key});

  @override
  State<FeriadoListView> createState() => _FeriadoListViewState();
}

class _FeriadoListViewState extends State<FeriadoListView> {
  final _feriadoService = FeriadoService();
  List<Feriado> _feriados = [];
  List<Feriado> _filteredFeriados = [];
  bool _isLoading = true;
  String? _error;
  bool _isTableView = false; // false = lista (cards), true = tabela

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _descricaoFilterController = TextEditingController();
  
  final Set<String> _selectedTipoFilters = {};
  final Set<String> _selectedPaisFilters = {};
  final Set<String> _selectedEstadoFilters = {};
  final Set<String> _selectedCidadeFilters = {};
  final Set<String> _selectedAnoFilters = {};

  @override
  void initState() {
    super.initState();
    _loadFeriados();
    _searchController.addListener(_applyFilters);
    _descricaoFilterController.addListener(_applyFilters);
    
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
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    final descQ = _descricaoFilterController.text.toLowerCase().trim();

    setState(() {
      _filteredFeriados = _feriados.where((f) {
        // Global search
        bool matchesGlobal = query.isEmpty ||
            f.descricao.toLowerCase().contains(query) ||
            f.tipo.toLowerCase().contains(query) ||
            (f.pais?.toLowerCase().contains(query) ?? false) ||
            (f.estado?.toLowerCase().contains(query) ?? false) ||
            (f.cidade?.toLowerCase().contains(query) ?? false);

        if (!matchesGlobal) return false;

        // Column filters (Text)
        if (descQ.isNotEmpty && !f.descricao.toLowerCase().contains(descQ)) return false;

        // Multi-select filters
        if (_selectedTipoFilters.isNotEmpty && !_selectedTipoFilters.contains(f.tipo)) return false;
        if (_selectedPaisFilters.isNotEmpty && !_selectedPaisFilters.contains(f.pais ?? '-')) return false;
        if (_selectedEstadoFilters.isNotEmpty && !_selectedEstadoFilters.contains(f.estado ?? '-')) return false;
        if (_selectedCidadeFilters.isNotEmpty && !_selectedCidadeFilters.contains(f.cidade ?? '-')) return false;
        if (_selectedAnoFilters.isNotEmpty && !_selectedAnoFilters.contains(f.data.year.toString())) return false;

        return true;
      }).toList();
    });
  }

  Future<void> _loadFeriados() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final feriados = await _feriadoService.getAllFeriados();
      setState(() {
        _feriados = feriados;
        _filteredFeriados = feriados;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteFeriado(Feriado feriado) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o feriado "${feriado.descricao}"?'),
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
      try {
        await _feriadoService.deleteFeriado(feriado.id);
        _loadFeriados();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feriado excluído com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir feriado: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _duplicateFeriado(Feriado feriado) {
    // Criar cópia com descrição modificada
    final duplicated = feriado.copyWith(
      id: '',
      descricao: '${feriado.descricao} (Cópia)',
    );

    _showFeriadoForm(feriado: duplicated);
  }

  void _showFeriadoForm({Feriado? feriado}) {
    showDialog(
      context: context,
      builder: (context) => FeriadoFormDialog(
        feriado: feriado,
        onSaved: _loadFeriados,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feriados'),
        bottom: !_isTableView ? PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar feriados...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1e293b) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ) : null,
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
            icon: const Icon(Icons.add),
            onPressed: () => _showFeriadoForm(),
            tooltip: 'Novo Feriado',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Erro ao carregar feriados',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                      const SizedBox(height: 8),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFeriados,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _filteredFeriados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _feriados.isEmpty ? 'Nenhum feriado cadastrado' : 'Nenhum feriado encontrado',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_feriados.isEmpty)
                            ElevatedButton.icon(
                              onPressed: () => _showFeriadoForm(),
                              icon: const Icon(Icons.add),
                              label: const Text('Cadastrar Feriado'),
                            )
                          else
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                _descricaoFilterController.clear();
                                _selectedTipoFilters.clear();
                                _selectedPaisFilters.clear();
                                _selectedEstadoFilters.clear();
                                _selectedCidadeFilters.clear();
                                _selectedAnoFilters.clear();
                                _applyFilters();
                              },
                              child: const Text('Limpar filtros'),
                            ),
                        ],
                      ),
                    )
                  : _isTableView
                      ? _buildTableView()
                      : _buildListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFeriadoForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _feriados.length,
      itemBuilder: (context, index) {
        final feriado = _feriados[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: feriado.tipo == 'EVENTO' ? Colors.orange[100] : Colors.purple[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                feriado.tipo == 'EVENTO' ? Icons.notification_important : Icons.event,
                color: feriado.tipo == 'EVENTO' ? Colors.orange[700] : Colors.purple[700],
              ),
            ),
            title: Text(
              feriado.descricao,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${feriado.data.day.toString().padLeft(2, '0')}/${feriado.data.month.toString().padLeft(2, '0')}/${feriado.data.year}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        feriado.tipo,
                        style: TextStyle(
                          fontSize: 11,
                          color: feriado.tipo == 'EVENTO' ? Colors.orange[900] : null,
                        ),
                      ),
                      backgroundColor: feriado.tipo == 'EVENTO' ? Colors.orange[50] : null,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    if (feriado.pais != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        feriado.pais!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (feriado.estado != null) ...[
                      const Text(' - '),
                      Text(
                        feriado.estado!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (feriado.cidade != null) ...[
                      const Text(' - '),
                      Text(
                        feriado.cidade!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 20, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Duplicar', style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Excluir', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showFeriadoForm(feriado: feriado);
                } else if (value == 'duplicate') {
                  _duplicateFeriado(feriado);
                } else if (value == 'delete') {
                  _deleteFeriado(feriado);
                }
              },
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
        padding: const EdgeInsets.all(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
          headingRowHeight: 80,
          columns: [
            DataColumn(
              label: _buildSelectableHeader('Data (Ano)', _selectedAnoFilters, _feriados.map((f) => f.data.year.toString()).toSet().toList()..sort()),
            ),
            DataColumn(
              label: _buildSortableHeader('Descrição', _descricaoFilterController),
            ),
            DataColumn(
              label: _buildSelectableHeader('Tipo', _selectedTipoFilters, _feriados.map((f) => f.tipo).toSet().toList()..sort()),
            ),
            DataColumn(
              label: _buildSelectableHeader('País', _selectedPaisFilters, _feriados.map((f) => f.pais ?? '-').toSet().toList()..sort()),
            ),
            DataColumn(
              label: _buildSelectableHeader('Estado', _selectedEstadoFilters, _feriados.map((f) => f.estado ?? '-').toSet().toList()..sort()),
            ),
            DataColumn(
              label: _buildSelectableHeader('Cidade', _selectedCidadeFilters, _feriados.map((f) => f.cidade ?? '-').toSet().toList()..sort()),
            ),
            const DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredFeriados.map((feriado) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    '${feriado.data.day.toString().padLeft(2, '0')}/${feriado.data.month.toString().padLeft(2, '0')}/${feriado.data.year}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Text(
                    feriado.descricao,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Chip(
                    label: Text(
                      feriado.tipo,
                      style: TextStyle(
                        fontSize: 11,
                        color: feriado.tipo == 'EVENTO' ? Colors.orange[900] : null,
                      ),
                    ),
                    backgroundColor: feriado.tipo == 'EVENTO' ? Colors.orange[50] : null,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                DataCell(Text(feriado.pais ?? '-')),
                DataCell(Text(feriado.estado ?? '-')),
                DataCell(Text(feriado.cidade ?? '-')),
                DataCell(
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Excluir', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showFeriadoForm(feriado: feriado);
                      } else if (value == 'delete') {
                        _deleteFeriado(feriado);
                      }
                    },
                    child: const Icon(Icons.more_vert),
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
                });
                _applyFilters();
              }
            },
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: hasFilter ? Colors.blue[50] : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: hasFilter ? Colors.blue : Colors.grey[400]!,
                ),
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
                    Icons.arrow_drop_down,
                    size: 16,
                    color: hasFilter ? Colors.blue : Colors.grey[600],
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






