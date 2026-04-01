import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/at.dart';
import '../utils/responsive.dart';

class ATSelectionDialog extends StatefulWidget {
  final List<AT> ats;
  final String title;
  final String? taskTarefa; // Nome da tarefa para contexto
  final String? taskLocal; // Local da tarefa para pré-filtrar

  const ATSelectionDialog({
    super.key,
    required this.ats,
    this.title = 'Selecionar AT',
    this.taskTarefa,
    this.taskLocal,
  });

  @override
  State<ATSelectionDialog> createState() => _ATSelectionDialogState();
}

class _ATSelectionDialogState extends State<ATSelectionDialog> {
  List<AT> _filteredATs = [];
  List<AT> _displayedATs = [];
  final Set<String> _selectedATIds = {}; // IDs das ats selecionadas
  String _searchQuery = '';
  String _viewMode = 'cards'; // 'cards', 'list', 'table'
  Set<String> _filterStatus = {};
  Set<String> _filterTipo = {};
  Set<String> _filterLocal = {};
  final int _itemsPerPage = 50;
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.taskLocal != null && widget.taskLocal!.trim().isNotEmpty) {
      _filterLocal = {widget.taskLocal!.trim()};
    }
    _filteredATs = widget.ats;
    _applyFilters();
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
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredATs.length);
    
    if (startIndex < _filteredATs.length) {
      setState(() {
        _displayedATs = _filteredATs.sublist(0, endIndex);
        _currentPage++;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredATs = widget.ats.where((at) {
        // Filtro de pesquisa
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = 
              at.autorzTrab.toLowerCase().contains(query) ||
              (at.textoBreve != null && at.textoBreve!.toLowerCase().contains(query)) ||
              (at.localInstalacao != null && at.localInstalacao!.toLowerCase().contains(query)) ||
              (at.edificacao != null && at.edificacao!.toLowerCase().contains(query)) ||
              (at.cntrTrab != null && at.cntrTrab!.toLowerCase().contains(query)) ||
              (at.cen != null && at.cen!.toLowerCase().contains(query)) ||
              (at.si != null && at.si!.toLowerCase().contains(query));
          
          if (!matchesSearch) return false;
        }

        // Filtro de status (multiseleção)
        if (_filterStatus.isNotEmpty && (at.statusSistema == null || !_filterStatus.contains(at.statusSistema!))) {
          return false;
        }

        // Filtro de local (multiseleção; aceita contain ou match exato)
        if (_filterLocal.isNotEmpty) {
          final loc = (at.local != null && at.local!.isNotEmpty)
              ? at.local!
              : (at.localInstalacao ?? '');
          if (loc.isEmpty) return false;
          final locLower = loc.toLowerCase();
          final match = _filterLocal.any((f) => locLower.contains(f.toLowerCase()) || f.toLowerCase().contains(locLower));
          if (!match) return false;
        }

        return true;
      }).toList();
      _currentPage = 0;
      _displayedATs = [];
      _loadMoreItems();
    });
  }

  List<String> _getUniqueStatuses() {
    return widget.ats
        .where((o) => o.statusSistema != null)
        .map((o) => o.statusSistema!)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueTipos() {
    return []; // AT não tem tipo
  }

  List<String> _getUniqueLocais() {
    return widget.ats
        .where((o) =>
            (o.local != null && o.local!.isNotEmpty) ||
            (o.localInstalacao != null && o.localInstalacao!.isNotEmpty))
        .map((o) => (o.local != null && o.local!.isNotEmpty)
            ? o.local!
            : (o.localInstalacao ?? ''))
        .where((local) => local.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('ABER')) return Colors.orange;
    if (status.contains('CAPC')) return Colors.blue;
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
                  // Campo de pesquisa
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Pesquisar at, texto breve, local, objeto...',
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
                  isMobile
                      ? Column(
                          children: [
                            _buildMultiSelect(label: 'Status', selected: _filterStatus, items: _getUniqueStatuses()),
                            const SizedBox(height: 8),
                            _buildMultiSelect(label: 'Tipo', selected: _filterTipo, items: _getUniqueTipos()),
                            const SizedBox(height: 8),
                            _buildMultiSelect(label: 'Local', selected: _filterLocal, items: _getUniqueLocais()),
                            const SizedBox(height: 8),
                            // Botões de visualização
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildViewButton(Icons.view_module, 'cards'),
                                  _buildViewButton(Icons.view_list, 'list'),
                                  _buildViewButton(Icons.table_chart, 'table'),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildMultiSelect(label: 'Status', selected: _filterStatus, items: _getUniqueStatuses()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: _buildMultiSelect(label: 'Tipo', selected: _filterTipo, items: _getUniqueTipos()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: _buildMultiSelect(label: 'Local', selected: _filterLocal, items: _getUniqueLocais()),
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
                        '${_displayedATs.length}${_displayedATs.length < _filteredATs.length ? '+' : ''} de ${_filteredATs.length} ats (${widget.ats.length} total)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (_filterStatus.isNotEmpty ||
                          _filterTipo.isNotEmpty ||
                          _filterLocal.isNotEmpty ||
                          _searchQuery.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _filterStatus = {};
                              _filterTipo = {};
                              _filterLocal = {};
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

            // Lista de ats
            Expanded(
              child: _filteredATs.isEmpty
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
                            'Nenhuma at encontrada',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_searchQuery.isNotEmpty ||
                              _filterStatus.isNotEmpty ||
                              _filterTipo.isNotEmpty ||
                              _filterLocal.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _filterStatus = {};
                                    _filterTipo = {};
                                    _filterLocal = {};
                                    _applyFilters();
                                  });
                                },
                                child: const Text('Limpar filtros'),
                              ),
                            ),
                        ],
                      ),
                    )
                  : _buildATsView(),
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
                    '${_selectedATIds.length} at(ns) selecionada(s)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop<List<AT>>(null),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedATIds.isEmpty
                        ? null
                        : () {
                            final selectedATs = widget.ats
                                .where((o) => _selectedATIds.contains(o.id))
                                .toList();
                            Navigator.of(context).pop<List<AT>>(selectedATs);
                          },
                    child: Text('Adicionar ${_selectedATIds.isEmpty ? '' : '(${_selectedATIds.length})'}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleATSelection(String atId) {
    setState(() {
      if (_selectedATIds.contains(atId)) {
        _selectedATIds.remove(atId);
      } else {
        _selectedATIds.add(atId);
      }
    });
  }

  Future<void> _copiarAT(String texto) async {
    try {
      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AT copiada!'), duration: Duration(seconds: 1)),
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

  Widget _buildATsView() {
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
      itemCount: _displayedATs.length + (_displayedATs.length < _filteredATs.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _displayedATs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final at = _displayedATs[index];
        final isSelected = _selectedATIds.contains(at.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          color: isSelected ? Colors.blue[50] : null,
          child: InkWell(
            onTap: () => _toggleATSelection(at.id),
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
                          color: _getStatusColor(at.statusSistema),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          at.statusSistema ?? '-',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (at.localInstalacao != null) ...[
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
                                at.localInstalacao!,
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
                          'AT: ${at.autorzTrab}',
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
                        onPressed: () => _copiarAT(at.autorzTrab),
                        tooltip: 'Copiar AT',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (at.textoBreve != null)
                    Text(
                      at.textoBreve!,
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
                      if (at.statusSistema != null)
                        _buildInfoChip(Icons.category, at.statusSistema!),
                      if (at.edificacao != null)
                        _buildInfoChip(Icons.location_city, at.edificacao!),
                      if (at.cntrTrab != null)
                        _buildInfoChip(Icons.work, 'CT: ${at.cntrTrab}'),
                      if (at.cen != null)
                        _buildInfoChip(Icons.category, 'CEN: ${at.cen}'),
                      if (at.statusUsuario != null)
                        _buildInfoChip(Icons.person, at.statusUsuario!),
                    ],
                  ),
                  if (at.dataInicio != null || at.dataFim != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          at.dataInicio != null && at.dataFim != null
                              ? '${_formatDate(at.dataInicio!)} - ${_formatDate(at.dataFim!)}'
                              : at.dataInicio != null
                                  ? 'Início: ${_formatDate(at.dataInicio!)}'
                                  : at.dataFim != null
                                      ? 'Fim: ${_formatDate(at.dataFim!)}'
                                      : '-',
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
      itemCount: _displayedATs.length + (_displayedATs.length < _filteredATs.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _displayedATs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final at = _displayedATs[index];
        final isSelected = _selectedATIds.contains(at.id);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(at.statusSistema),
            child: Text(
              at.statusSistema ?? '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            'AT: ${at.autorzTrab}',
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (at.localInstalacao != null)
                Text(
                  'Local: ${at.localInstalacao}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (at.textoBreve != null)
                Text(
                  at.textoBreve!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (at.dataInicio != null || at.dataFim != null)
                Text(
                  at.dataInicio != null && at.dataFim != null
                      ? '${_formatDate(at.dataInicio!)} - ${_formatDate(at.dataFim!)}'
                      : at.dataInicio != null
                          ? 'Início: ${_formatDate(at.dataInicio!)}'
                          : at.dataFim != null
                              ? 'Fim: ${_formatDate(at.dataFim!)}'
                              : '-',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Colors.blue)
              : const Icon(Icons.chevron_right),
          selected: isSelected,
          selectedTileColor: Colors.blue[50],
          onTap: () => _toggleATSelection(at.id),
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
          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Local', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('AT', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Texto Breve', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Edificação', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Data Início', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Data Fim', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status Usuário', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Centro Trabalho', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: [
            ..._displayedATs.map((at) {
            final isSelected = _selectedATIds.contains(at.id);
            return DataRow(
              selected: isSelected,
              cells: [
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(at.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      at.statusSistema ?? '-',
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
                      at.localInstalacao ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        at.autorzTrab,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _copiarAT(at.autorzTrab),
                        child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(at.statusSistema ?? '-'),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      at.textoBreve ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      at.edificacao ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(at.dataInicio != null ? _formatDate(at.dataInicio!) : '-'),
                ),
                DataCell(
                  Text(at.dataFim != null ? _formatDate(at.dataFim!) : '-'),
                ),
                DataCell(Text(at.statusUsuario ?? '-')),
                DataCell(Text(at.cntrTrab ?? '-')),
              ],
              onSelectChanged: (_) => _toggleATSelection(at.id),
            );
            }),
            if (_displayedATs.length < _filteredATs.length)
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
