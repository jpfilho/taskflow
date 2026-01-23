import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/responsive.dart';

class TaskSelectionDialog extends StatefulWidget {
  final List<Task> tasks;
  final String title;
  final String? notaSapNumero; // Número da nota SAP para contexto

  const TaskSelectionDialog({
    super.key,
    required this.tasks,
    this.title = 'Selecionar Tarefa',
    this.notaSapNumero,
  });

  @override
  State<TaskSelectionDialog> createState() => _TaskSelectionDialogState();
}

class _TaskSelectionDialogState extends State<TaskSelectionDialog> {
  List<Task> _filteredTasks = [];
  List<Task> _displayedTasks = [];
  String _searchQuery = '';
  String _viewMode = 'cards'; // 'cards', 'list', 'table'
  String? _filterStatus;
  String? _filterRegional;
  String? _filterTipo;
  final int _itemsPerPage = 50;
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _filteredTasks = widget.tasks;
    _loadMoreItems();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredTasks.length);
    
    if (startIndex < _filteredTasks.length) {
      setState(() {
        _displayedTasks = _filteredTasks.sublist(0, endIndex);
        _currentPage++;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTasks = widget.tasks.where((task) {
        // Filtro de pesquisa
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = 
              task.tarefa.toLowerCase().contains(query) ||
              (task.ordem != null && task.ordem!.toLowerCase().contains(query)) ||
              task.regional.toLowerCase().contains(query) ||
              task.divisao.toLowerCase().contains(query) ||
              task.tipo.toLowerCase().contains(query) ||
              task.executores.any((e) => e.toLowerCase().contains(query)) ||
              task.locais.any((l) => l.toLowerCase().contains(query));
          
          if (!matchesSearch) return false;
        }

        // Filtro de status
        if (_filterStatus != null && task.status != _filterStatus) {
          return false;
        }

        // Filtro de regional
        if (_filterRegional != null && task.regional != _filterRegional) {
          return false;
        }

        // Filtro de tipo
        if (_filterTipo != null && task.tipo != _filterTipo) {
          return false;
        }

        return true;
      }).toList();
      // Resetar paginação quando filtrar
      _currentPage = 0;
      _displayedTasks = [];
      _loadMoreItems();
    });
  }

  List<String> _getUniqueStatuses() {
    return widget.tasks.map((t) => t.status).toSet().toList()..sort();
  }

  List<String> _getUniqueRegionais() {
    return widget.tasks.map((t) => t.regional).toSet().toList()..sort();
  }

  List<String> _getUniqueTipos() {
    return widget.tasks.map((t) => t.tipo).toSet().toList()..sort();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'CONC':
        return Colors.green;
      case 'PROG':
        return Colors.blue;
      case 'ANDA':
        return Colors.orange;
      case 'CANC':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isMobile ? double.infinity : 900,
        height: isMobile ? double.infinity : 700,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.notaSapNumero != null)
                          Text(
                            'Nota SAP: ${widget.notaSapNumero}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Filtros e pesquisa
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                children: [
                  // Campo de pesquisa
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Pesquisar tarefa, ordem, regional, tipo, executor...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _applyFilters();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilters();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Filtros e visualização
                  Row(
                    children: [
                      // Filtro Status
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterStatus,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ..._getUniqueStatuses().map((status) =>
                                DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filterStatus = value;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filtro Regional
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterRegional,
                          decoration: InputDecoration(
                            labelText: 'Regional',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Todas'),
                            ),
                            ..._getUniqueRegionais().map((regional) =>
                                DropdownMenuItem<String>(
                                  value: regional,
                                  child: Text(regional),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filterRegional = value;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filtro Tipo
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterTipo,
                          decoration: InputDecoration(
                            labelText: 'Tipo',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ..._getUniqueTipos().map((tipo) =>
                                DropdownMenuItem<String>(
                                  value: tipo,
                                  child: Text(tipo),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filterTipo = value;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botões de visualização
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildViewButton(Icons.view_module, 'cards'),
                            _buildViewButton(Icons.view_list, 'list'),
                            _buildViewButton(Icons.table_chart, 'table'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Contador
                  Row(
                    children: [
                      Text(
                        '${_displayedTasks.length}${_displayedTasks.length < _filteredTasks.length ? '+' : ''} de ${_filteredTasks.length} tarefas (${widget.tasks.length} total)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (_filterStatus != null ||
                          _filterRegional != null ||
                          _filterTipo != null ||
                          _searchQuery.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _filterStatus = null;
                              _filterRegional = null;
                              _filterTipo = null;
                              _applyFilters();
                            });
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Limpar filtros'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Lista de tarefas
            Expanded(
              child: _filteredTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma tarefa encontrada',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_searchQuery.isNotEmpty ||
                              _filterStatus != null ||
                              _filterRegional != null ||
                              _filterTipo != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _filterStatus = null;
                                    _filterRegional = null;
                                    _filterTipo = null;
                                    _applyFilters();
                                  });
                                },
                                child: const Text('Limpar filtros'),
                              ),
                            ),
                        ],
                      ),
                    )
                  : _buildTasksView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewButton(IconData icon, String mode) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () {
        if (_viewMode == mode) return;
        // Atualiza o estado imediatamente de forma síncrona
        setState(() {
          _viewMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[100] : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.blue[700] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildTasksView() {
    if (_viewMode == 'list') {
      return _buildListView();
    } else if (_viewMode == 'table') {
      return _buildTableView();
    } else {
      return _buildCardsView();
    }
  }

  Widget _buildCardsView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _displayedTasks.length + (_displayedTasks.length < _filteredTasks.length ? 1 : 0),
      itemBuilder: (context, index) {
        final task = _filteredTasks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(task),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task.status),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (task.locais.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey[700]),
                              const SizedBox(width: 4),
                              Text(
                                task.locais.join(', '),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.tarefa,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(Icons.location_on, task.regional),
                      _buildInfoChip(Icons.business, task.divisao),
                      if (task.tipo.isNotEmpty)
                        _buildInfoChip(Icons.category, task.tipo),
                      if (task.ordem != null && task.ordem!.isNotEmpty)
                        _buildInfoChip(Icons.tag, task.ordem!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatDate(task.dataInicio)} - ${_formatDate(task.dataFim)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (task.executores.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            task.executores.join(', '),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _displayedTasks.length + (_displayedTasks.length < _filteredTasks.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _displayedTasks.length) {
          // Mostrar indicador de carregamento no final
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final task = _displayedTasks[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(task.status),
            child: Text(
              task.status.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            task.tarefa,
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.locais.isNotEmpty)
                Text(
                  'Local: ${task.locais.join(', ')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                '${task.regional} - ${task.divisao} | ${task.tipo}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${_formatDate(task.dataInicio)} - ${_formatDate(task.dataFim)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pop(task),
        );
      },
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Local', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tarefa', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Regional', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Divisão', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ordem', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Data Início', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Data Fim', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Executores', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: [
            ..._displayedTasks.map((task) {
            return DataRow(
              cells: [
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(task.status),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      task.locais.isNotEmpty ? task.locais.join(', ') : '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      task.tarefa,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(task.regional)),
                DataCell(Text(task.divisao)),
                DataCell(Text(task.tipo)),
                DataCell(Text(task.ordem ?? '-')),
                DataCell(Text(_formatDate(task.dataInicio))),
                DataCell(Text(_formatDate(task.dataFim))),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      task.executores.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onSelectChanged: (_) => Navigator.of(context).pop(task),
            );
            }),
            if (_displayedTasks.length < _filteredTasks.length)
              DataRow(
                cells: List.generate(10, (_) => const DataCell(
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
