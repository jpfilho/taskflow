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
  Set<String> _filterStatus = {};
  Set<String> _filterLocal = {};
  Set<String> _filterTipo = {};
  Task? _selectedTask; // Tarefa selecionada
  final int _itemsPerPage = 50;
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _filteredTasks = widget.tasks;
    _loadMoreItems();
    _scrollController.addListener(_onScroll);
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Responsive.isDesktop(context)) {
        setState(() {
          _viewMode = 'table';
        });
      }
    });
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

        // Filtro de status (multiseleção)
        if (_filterStatus.isNotEmpty && !_filterStatus.contains(task.status)) {
          return false;
        }

        // Filtro de local (multiseleção)
        if (_filterLocal.isNotEmpty && !task.locais.any((l) => _filterLocal.contains(l))) {
          return false;
        }

        // Filtro de tipo (multiseleção)
        if (_filterTipo.isNotEmpty && !_filterTipo.contains(task.tipo)) {
          return false;
        }

        return true;
      }).toList();
      _currentPage = 0;
      _displayedTasks = [];
      _loadMoreItems();
    });
  }

  List<String> _getUniqueStatuses() {
    return widget.tasks.map((t) => t.status).toSet().toList()..sort();
  }

  List<String> _getUniqueLocais() {
    final allLocais = <String>{};
    for (final task in widget.tasks) {
      allLocais.addAll(task.locais);
    }
    return allLocais.toList()..sort();
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

  Widget _buildMultiSelect({
    required String label,
    required Set<String> selected,
    required List<String> items,
  }) {
    final displayText = selected.isEmpty ? 'Todos' : selected.length == 1 ? selected.first : '${selected.length} selecionado(s)';
    return InkWell(
      onTap: () async {
        final result = await _showMultiSelectDialog(label, items, selected);
        if (result != null) {
          setState(() {
            selected
              ..clear()
              ..addAll(result);
            _applyFilters();
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            letterSpacing: 0.5,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Text(
                displayText,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<Set<String>?> _showMultiSelectDialog(
    String title,
    List<String> options,
    Set<String> current,
  ) async {
    final temp = {...current};
    String searchQuery = '';
    return showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filtered = searchQuery.isEmpty
                ? options
                : options.where((o) => o.toLowerCase().contains(searchQuery.toLowerCase())).toList();
            return AlertDialog(
              title: Text('Selecionar $title'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Pesquisar...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setStateDialog(() => searchQuery = v),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: filtered
                            .map(
                              (opt) => CheckboxListTile(
                                dense: true,
                                value: temp.contains(opt),
                                title: Text(opt, style: const TextStyle(fontSize: 13)),
                                onChanged: (checked) {
                                  setStateDialog(() {
                                    if (checked == true) {
                                      temp.add(opt);
                                    } else {
                                      temp.remove(opt);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(temp),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isMobile 
            ? double.infinity 
            : isDesktop 
                ? 1200  // Largura reduzida para ficar apenas da largura da tabela
                : 900,  // Tablet: tamanho médio
        height: isMobile 
            ? double.infinity 
            : isDesktop 
                ? 850   // Desktop: mais alto
                : 700,  // Tablet: altura padrão
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link,
                    color: Colors.blue[700],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (widget.notaSapNumero != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Nota SAP: ${widget.notaSapNumero}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.grey[700],
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
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // Campo de pesquisa
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Pesquisar tarefa, ordem, local, tipo, executor...',
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
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                      Expanded(
                        child: _buildMultiSelect(label: 'STATUS', selected: _filterStatus, items: _getUniqueStatuses()),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMultiSelect(label: 'LOCAL', selected: _filterLocal, items: _getUniqueLocais()),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMultiSelect(label: 'TIPO', selected: _filterTipo, items: _getUniqueTipos()),
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
                            _buildViewButton(Icons.table_chart, 'table'),
                            _buildViewButton(Icons.view_module, 'cards'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Status de sincronização e contador
                  Row(
                    children: [
                      // Status de sincronização
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SINCRONIZADO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Contador
                      Text(
                        'EXIBINDO ${_displayedTasks.length}${_displayedTasks.length < _filteredTasks.length ? '+' : ''} DE ${_filteredTasks.length} TAREFAS ENCONTRADAS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                          letterSpacing: 0.3,
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
                              _filterStatus.isNotEmpty ||
                              _filterLocal.isNotEmpty ||
                              _filterTipo.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _filterStatus = {};
                                    _filterLocal = {};
                                    _filterTipo = {};
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

            // Footer com botões de ação
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedTask != null ? '1' : '0'} tarefa${_selectedTask != null ? '' : 's'} selecionada${_selectedTask != null ? '' : 's'} para vinculação',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      side: BorderSide(color: Colors.grey[400]!),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedTask != null
                        ? () {
                            Navigator.of(context).pop(_selectedTask);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Vincular Selecionados',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
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
      controller: _scrollController,
      child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
          columns: [
            const DataColumn(
              label: SizedBox.shrink(),
            ),
            const DataColumn(
              label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const DataColumn(
              label: Text('LOCAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const DataColumn(
              label: Text('TAREFA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const DataColumn(
              label: Text('REGIONAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const DataColumn(
              label: Text('DIVISÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const DataColumn(
              label: Text('TIPO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const DataColumn(
              label: Text('INÍCIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const DataColumn(
              label: Text('FIM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const DataColumn(
              label: Text('EXECUTORES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
          rows: [
            ..._displayedTasks.map((task) {
            return DataRow(
              selected: _selectedTask == task,
              cells: [
                DataCell(
                  Radio<Task>(
                    value: task,
                    groupValue: _selectedTask,
                    onChanged: (value) {
                      setState(() {
                        _selectedTask = value;
                      });
                    },
                  ),
                ),
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 120,
                    child: Text(
                      task.locais.isNotEmpty ? task.locais.join(', ') : '-',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 250,
                    child: Text(
                      task.tarefa,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    task.regional,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    task.divisao,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    task.tipo,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    _formatDate(task.dataInicio),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    _formatDate(task.dataFim),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
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
