import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/nota_sap.dart';
import '../utils/responsive.dart';

class NotaSAPSelectionDialog extends StatefulWidget {
  final List<NotaSAP> notas;
  final String title;
  final String? taskTarefa; // Nome da tarefa para contexto

  const NotaSAPSelectionDialog({
    super.key,
    required this.notas,
    this.title = 'Selecionar Nota SAP',
    this.taskTarefa,
  });

  @override
  State<NotaSAPSelectionDialog> createState() => _NotaSAPSelectionDialogState();
}

class _NotaSAPSelectionDialogState extends State<NotaSAPSelectionDialog> {
  List<NotaSAP> _filteredNotas = [];
  List<NotaSAP> _displayedNotas = [];
  final Set<String> _selectedNotaIds = {}; // IDs das notas selecionadas
  String _searchQuery = '';
  String _viewMode = 'cards'; // 'cards', 'list', 'table'
  Set<String> _filterStatus = {};
  Set<String> _filterTipo = {};
  Set<String> _filterPrioridade = {};
  Set<String> _filterNota = {};
  Set<String> _filterSala = {};
  Set<String> _filterLocal = {};
  Set<String> _filterOrdem = {};
  final int _itemsPerPage = 50;
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();
  bool _filtersExpandedMobile = false;
  bool _filtersExpandedDesktop = false;

  @override
  void initState() {
    super.initState();
    final tipos = _getUniqueTipos();
    if (tipos.contains('NM')) {
      _filterTipo = {'NM'};
    }
    _filteredNotas = widget.notas;
    _loadMoreItems();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No desktop, usar visualização de tabela por padrão
    if (_viewMode == 'cards') {
      final isDesktop = Responsive.isDesktop(context);
      if (isDesktop) {
        _viewMode = 'table';
      }
    }
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
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredNotas.length);
    
    if (startIndex < _filteredNotas.length) {
      setState(() {
        _displayedNotas = _filteredNotas.sublist(0, endIndex);
        _currentPage++;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredNotas = widget.notas.where((nota) {
        // Filtro de pesquisa
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = 
              nota.nota.toLowerCase().contains(query) ||
              (nota.ordem != null && nota.ordem!.toLowerCase().contains(query)) ||
              (nota.descricao != null && nota.descricao!.toLowerCase().contains(query)) ||
              (nota.local != null && nota.local!.toLowerCase().contains(query)) ||
              (nota.localInstalacao != null && nota.localInstalacao!.toLowerCase().contains(query)) ||
              (nota.equipamento != null && nota.equipamento!.toLowerCase().contains(query)) ||
              (nota.denominacaoExecutor != null && nota.denominacaoExecutor!.toLowerCase().contains(query));
          
          if (!matchesSearch) return false;
        }

        if (_filterTipo.isNotEmpty && (nota.tipo == null || !_filterTipo.contains(nota.tipo!))) return false;
        if (_filterPrioridade.isNotEmpty &&
            (nota.textPrioridade == null || !_filterPrioridade.contains(nota.textPrioridade!))) {
          return false;
        }
        if (_filterNota.isNotEmpty && !_filterNota.contains(nota.nota)) return false;
        if (_filterSala.isNotEmpty && (nota.sala == null || !_filterSala.contains(nota.sala!))) return false;
        if (_filterLocal.isNotEmpty && (nota.local == null || !_filterLocal.contains(nota.local!))) return false;
        if (_filterStatus.isNotEmpty &&
            (nota.statusUsuario == null || !_filterStatus.contains(nota.statusUsuario!))) {
          return false;
        }
        if (_filterOrdem.isNotEmpty && (nota.ordem == null || !_filterOrdem.contains(nota.ordem!))) return false;

        return true;
      }).toList();
      // Resetar paginação quando filtrar
      _currentPage = 0;
      _displayedNotas = [];
      _loadMoreItems();
    });
  }

  List<String> _getUniqueStatuses() => widget.notas
      .where((n) => n.statusUsuario != null)
      .map((n) => n.statusUsuario!)
        .toSet()
        .toList()
      ..sort();

  List<String> _getUniqueTipos() => widget.notas
        .where((n) => n.tipo != null)
        .map((n) => n.tipo!)
        .toSet()
        .toList()
      ..sort();

  List<String> _getUniquePrioridades() => widget.notas
      .where((n) => n.textPrioridade != null)
      .map((n) => n.textPrioridade!)
      .toSet()
      .toList()
    ..sort();

  List<String> _getUniqueNotas() =>
      widget.notas.map((n) => n.nota).toSet().toList()..sort();

  List<String> _getUniqueSalas() => widget.notas
      .where((n) => n.sala != null)
      .map((n) => n.sala!)
      .toSet()
      .toList()
    ..sort();

  List<String> _getUniqueLocais() => widget.notas
        .where((n) => n.local != null)
        .map((n) => n.local!)
        .toSet()
        .toList()
      ..sort();

  List<String> _getUniqueOrdens() => widget.notas
      .where((n) => n.ordem != null)
      .map((n) => n.ordem!)
      .toSet()
      .toList()
    ..sort();

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('MSPR')) return Colors.orange;
    if (status.contains('MSPN')) return Colors.blue;
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: isMobile ? double.infinity : 1100,
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
                        if (widget.taskTarefa != null)
                          Text(
                            'Tarefa: ${widget.taskTarefa}',
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
                  // Campo de pesquisa (desktop com filtros colapsados e visualizações na mesma linha)
                  if (!isMobile)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Pesquisar nota, ordem, descrição, local, equipamento, executor...',
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
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                                setState(() {
                              _filtersExpandedDesktop = !_filtersExpandedDesktop;
                                });
                              },
                          icon: Icon(
                            _filtersExpandedDesktop ? Icons.close : Icons.filter_list,
                                ),
                          label: Text(_filtersExpandedDesktop ? 'Ocultar filtros' : 'Filtros'),
                            ),
                        const SizedBox(width: 8),
                        _buildViewChips(),
                      ],
                    )
                  else
                    TextField(
                              decoration: InputDecoration(
                        hintText: 'Pesquisar nota, ordem, descrição, local, equipamento, executor...',
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
                  if (isMobile) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                            Expanded(
                          child: Text(
                            _filtersExpandedMobile ? 'Filtros' : 'Filtros',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                                  ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                                  setState(() {
                              _filtersExpandedMobile = !_filtersExpandedMobile;
                                  });
                                },
                          icon: Icon(
                            _filtersExpandedMobile ? Icons.close : Icons.filter_list,
                                  ),
                          label: Text(_filtersExpandedMobile ? 'Ocultar' : 'Filtros'),
                                  ),
                      ],
                    ),
                    AnimatedCrossFade(
                      crossFadeState: _filtersExpandedMobile
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 200),
                      firstChild: Column(
                                children: [
                          _buildFilterDropdowns(isMobile: true),
                          const SizedBox(height: 8),
                          _buildViewChips(),
                        ],
                      ),
                      secondChild: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildViewChips(),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    AnimatedCrossFade(
                      crossFadeState: _filtersExpandedDesktop
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 200),
                      firstChild: _buildFilterDropdowns(isMobile: false),
                      secondChild: const SizedBox.shrink(),
                            ),
                          ],
                  const SizedBox(height: 8),
                  // Contador
                  Row(
                    children: [
                      Text(
                        '${_displayedNotas.length}${_displayedNotas.length < _filteredNotas.length ? '+' : ''} de ${_filteredNotas.length} notas (${widget.notas.length} total)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (_filterStatus.isNotEmpty ||
                          _filterTipo.isNotEmpty ||
                          _filterPrioridade.isNotEmpty ||
                          _filterNota.isNotEmpty ||
                          _filterSala.isNotEmpty ||
                          _filterLocal.isNotEmpty ||
                          _filterOrdem.isNotEmpty ||
                          _searchQuery.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _filterStatus.clear();
                              _filterPrioridade.clear();
                              _filterNota.clear();
                              _filterSala.clear();
                              _filterLocal.clear();
                              _filterOrdem.clear();
                              final tipos = _getUniqueTipos();
                              _filterTipo = tipos.contains('NM') ? {'NM'} : {};
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

            // Lista de notas
            Expanded(
              child: _filteredNotas.isEmpty
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
                            'Nenhuma nota encontrada',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_searchQuery.isNotEmpty ||
                              _filterStatus.isNotEmpty ||
                              _filterTipo.isNotEmpty ||
                              _filterPrioridade.isNotEmpty ||
                              _filterNota.isNotEmpty ||
                              _filterSala.isNotEmpty ||
                              _filterLocal.isNotEmpty ||
                              _filterOrdem.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _filterStatus.clear();
                                    _filterPrioridade.clear();
                                    _filterNota.clear();
                                    _filterSala.clear();
                                    _filterLocal.clear();
                                    _filterOrdem.clear();
                                    final tipos = _getUniqueTipos();
                                    _filterTipo = tipos.contains('NM') ? {'NM'} : {};
                                    _applyFilters();
                                  });
                                },
                                child: const Text('Limpar filtros'),
                              ),
                            ),
                        ],
                      ),
                    )
                  : _buildNotasView(),
            ),

            // Rodapé com botões
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedNotaIds.length} nota(s) selecionada(s)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop<List<NotaSAP>>(null),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedNotaIds.isEmpty
                        ? null
                        : () {
                            final selectedNotas = widget.notas
                                .where((n) => _selectedNotaIds.contains(n.id))
                                .toList();
                            Navigator.of(context).pop<List<NotaSAP>>(selectedNotas);
                          },
                    child: Text('Adicionar ${_selectedNotaIds.isEmpty ? '' : '(${_selectedNotaIds.length})'}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleNotaSelection(String notaId) {
    setState(() {
      if (_selectedNotaIds.contains(notaId)) {
        _selectedNotaIds.remove(notaId);
      } else {
        _selectedNotaIds.add(notaId);
      }
    });
  }

  Widget _buildFilterDropdowns({required bool isMobile}) {
    final tipos = _getUniqueTipos();
    final prioridades = _getUniquePrioridades();
    final notas = _getUniqueNotas();
    final salas = _getUniqueSalas();
    final locais = _getUniqueLocais();
    final statuses = _getUniqueStatuses();
    final ordens = _getUniqueOrdens();

    final dropdowns = [
      _buildMultiSelect(
        label: 'Tipo',
        selected: _filterTipo,
        items: tipos,
        onChanged: (values) {
          setState(() {
            _filterTipo = values;
            _applyFilters();
          });
        },
      ),
      _buildMultiSelect(
        label: 'Prioridade',
        selected: _filterPrioridade,
        items: prioridades,
        onChanged: (values) {
          setState(() {
            _filterPrioridade = values;
            _applyFilters();
          });
        },
      ),
      _buildMultiSelect(
        label: 'Nota',
        selected: _filterNota,
        items: notas,
        onChanged: (values) {
          setState(() {
            _filterNota = values;
            _applyFilters();
          });
        },
      ),
      _buildMultiSelect(
        label: 'Sala',
        selected: _filterSala,
        items: salas,
        onChanged: (values) {
          setState(() {
            _filterSala = values;
            _applyFilters();
          });
        },
      ),
      _buildMultiSelect(
        label: 'Local',
        selected: _filterLocal,
        items: locais,
        onChanged: (values) {
          setState(() {
            _filterLocal = values;
            _applyFilters();
          });
        },
      ),
      _buildMultiSelect(
        label: 'Status',
        selected: _filterStatus,
        items: statuses,
        onChanged: (values) {
          setState(() {
            _filterStatus = values;
            _applyFilters();
          });
        },
      ),
      _buildMultiSelect(
        label: 'Ordem',
        selected: _filterOrdem,
        items: ordens,
        onChanged: (values) {
          setState(() {
            _filterOrdem = values;
            _applyFilters();
          });
        },
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < dropdowns.length; i++) ...[
            dropdowns[i],
            if (i < dropdowns.length - 1) const SizedBox(height: 8),
          ]
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: dropdowns
          .map(
            (d) => SizedBox(
              width: 120,
              child: d,
            ),
          )
          .toList(),
    );
  }

  Widget _buildMultiSelect({
    required String label,
    required Set<String> selected,
    required List<String> items,
    required ValueChanged<Set<String>> onChanged,
  }) {
    final displayText = selected.isEmpty ? 'Todos' : selected.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        InkWell(
          onTap: () async {
            final result = await _showMultiSelectDialog(label, items, selected);
            if (result != null) {
              onChanged(result);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<Set<String>?> _showMultiSelectDialog(
    String title,
    List<String> options,
    Set<String> current,
  ) async {
    final temp = {...current};
    return showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Selecionar $title'),
          content: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return ListView(
                  shrinkWrap: true,
                  children: options
                      .map(
                        (opt) => CheckboxListTile(
                          dense: true,
                          value: temp.contains(opt),
                          title: Text(opt),
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
                );
              },
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
  }

  Widget _buildViewChips() {
    return Container(
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
    );
  }

  Future<void> _copiarNota(String texto) async {
    try {
      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota copiada!'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível copiar: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
    }
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

  Widget _buildNotasView() {
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
      itemCount: _displayedNotas.length + (_displayedNotas.length < _filteredNotas.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _displayedNotas.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final nota = _displayedNotas[index];
        final isSelected = _selectedNotaIds.contains(nota.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          color: isSelected ? Colors.blue[50] : null,
          child: InkWell(
            onTap: () => _toggleNotaSelection(nota.id),
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
                          color: _getStatusColor(nota.statusSistema),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          nota.statusSistema ?? '-',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (nota.localInstalacao != null) ...[
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
                                nota.localInstalacao!,
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
                          'Nota: ${nota.nota}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _copiarNota(nota.nota),
                        tooltip: 'Copiar nota',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (nota.descricao != null)
                    Text(
                      nota.descricao!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (nota.tipo != null)
                        _buildInfoChip(Icons.category, nota.tipo!),
                      if (nota.ordem != null)
                        _buildInfoChip(Icons.tag, nota.ordem!),
                      if (nota.equipamento != null)
                        _buildInfoChip(Icons.build, nota.equipamento!),
                      if (nota.textPrioridade != null)
                        _buildInfoChip(Icons.priority_high, nota.textPrioridade!),
                    ],
                  ),
                  if (nota.inicioDesejado != null || nota.conclusaoDesejada != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          nota.inicioDesejado != null && nota.conclusaoDesejada != null
                              ? '${_formatDate(nota.inicioDesejado!)} - ${_formatDate(nota.conclusaoDesejada!)}'
                              : nota.inicioDesejado != null
                                  ? 'Início: ${_formatDate(nota.inicioDesejado!)}'
                                  : 'Fim: ${_formatDate(nota.conclusaoDesejada!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
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
      itemCount: _displayedNotas.length + (_displayedNotas.length < _filteredNotas.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _displayedNotas.length) {
          // Mostrar indicador de carregamento no final
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final nota = _displayedNotas[index];
        final isSelected = _selectedNotaIds.contains(nota.id);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(nota.statusSistema),
            child: Text(
              nota.tipo ?? '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            'Nota: ${nota.nota}',
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nota.localInstalacao != null)
                Text(
                  'Local: ${nota.localInstalacao}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (nota.descricao != null)
                Text(
                  nota.descricao!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (nota.inicioDesejado != null || nota.conclusaoDesejada != null)
                Text(
                  nota.inicioDesejado != null && nota.conclusaoDesejada != null
                      ? '${_formatDate(nota.inicioDesejado!)} - ${_formatDate(nota.conclusaoDesejada!)}'
                      : nota.inicioDesejado != null
                          ? 'Início: ${_formatDate(nota.inicioDesejado!)}'
                          : 'Fim: ${_formatDate(nota.conclusaoDesejada!)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Colors.blue)
              : const Icon(Icons.chevron_right),
          selected: isSelected,
          selectedTileColor: Colors.blue[50],
          onTap: () => _toggleNotaSelection(nota.id),
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
          columnSpacing: 45,
          horizontalMargin: 8,
          headingRowHeight: 38,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 42,
          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Prioridade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),

            DataColumn(label: Text('Nota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Sala', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),

            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Prazo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Ordem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: [
            ..._displayedNotas.map((nota) {
            final isSelected = _selectedNotaIds.contains(nota.id);
            return DataRow(
              selected: isSelected,
              cells: [
                  // 1. Local
                DataCell(
                  SizedBox(
                      width: 40,
                    child: Text(
                      nota.local ?? '-',
                        style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                  // 2. Tipo
                DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        nota.tipo ?? '-',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  // 3. Prioridade
                  DataCell(
                    Text(
                      nota.textPrioridade ?? '-',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 4. Nota
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 95),
                      child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                          Flexible(
                            child: Text(
                        nota.nota,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                      ),
                          ),
                          const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _copiarNota(nota.nota),
                            child: const Icon(Icons.copy, size: 14, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                  ),
                  // 5. Sala
                DataCell(
                  SizedBox(
                      width: 55,
                    child: Text(
                      nota.sala ?? '-',
                        style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                  // 6. Descrição
                DataCell(
                  SizedBox(
                      width: 150,
                    child: Text(
                      nota.descricao ?? '-',
                        style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                  // 7. Status
                DataCell(
                    Container(
                      width: 55,
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                ),
                    child: Text(
                        nota.statusUsuario ?? '-',
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                  // 8. Prazo
                  DataCell(
                    _buildPrazoBadge(nota),
                  ),
                  // 9. Ordem
                  DataCell(Text(nota.ordem ?? '-', style: const TextStyle(fontSize: 11))),
              ],
              onSelectChanged: (_) => _toggleNotaSelection(nota.id),
            );
            }),
            if (_displayedNotas.length < _filteredNotas.length)
              DataRow(
                cells: List.generate(
                  9,
                  (_) => const DataCell(
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrazoBadge(NotaSAP nota) {
    final dias = nota.diasRestantes;
    final venc = nota.dataVencimento;

    String label = '-';
    Color bg = Colors.grey[200]!;
    Color fg = Colors.grey[800]!;

    if (dias != null) {
      if (dias < 0) {
        bg = Colors.red[100]!;
        fg = Colors.red[800]!;
        label = venc != null ? '${_formatDate(venc)} • Vencido' : 'Vencido';
      } else if (dias <= 2) {
        bg = Colors.orange[100]!;
        fg = Colors.orange[800]!;
        label = venc != null ? '${_formatDate(venc)} • ${dias}d' : '${dias}d';
      } else {
        bg = Colors.green[100]!;
        fg = Colors.green[800]!;
        label = venc != null ? '${_formatDate(venc)} • ${dias}d' : '${dias}d';
      }
    } else if (venc != null) {
      label = _formatDate(venc);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: fg,
          fontSize: 11,
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
